test_recovers_real_branch_and_tag_deletions() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" branch topic
	git -C "$repo" tag v1
	git -C "$repo" pack-refs --all
	: >"$log"
	git -C "$repo" branch -D topic >/dev/null
	git -C "$repo" tag -d v1 >/dev/null
	assert_file_equals "branch-deleted|topic|refs/heads/topic|$oid|$zero
tag-deleted|v1|refs/tags/v1|$oid|$zero" "$log"
}

test_recovers_real_notes_and_stash_updates() {
	setup_real_git_events
	git -C "$repo" notes add -m first HEAD
	old_note=$(git -C "$repo" rev-parse refs/notes/commits)
	: >"$log"
	git -C "$repo" notes append -m second HEAD
	new_note=$(git -C "$repo" rev-parse refs/notes/commits)
	assert_file_equals "note-updated|commits|refs/notes/commits|$old_note|$new_note" "$log"
	: >"$log"
	git -C "$repo" notes remove HEAD >/dev/null
	final_note=$(git -C "$repo" rev-parse refs/notes/commits)
	assert_file_equals "note-updated|commits|refs/notes/commits|$new_note|$final_note" "$log"
	printf 'first\n' >>"$repo/tracked"
	git -C "$repo" stash push -qm first
	old_stash=$(git -C "$repo" rev-parse refs/stash)
	printf 'second\n' >>"$repo/tracked"
	: >"$log"
	git -C "$repo" stash push -qm second
	new_stash=$(git -C "$repo" rev-parse refs/stash)
	assert_file_equals "stash-updated|stash|refs/stash|$old_stash|$new_stash" "$log"
}

test_snapshot_suppresses_noops_and_discards_aborts() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" branch topic
	printf '%s %s refs/heads/topic\n' "$zero" "$zero" >"$TEST_DIR/transaction"
	: >"$log"
	(
		cd "$repo"
		"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
		"$bin" reference-transaction committed <"$TEST_DIR/transaction"
		"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
		"$bin" reference-transaction aborted <"$TEST_DIR/transaction"
		git -c core.hooksPath=/dev/null update-ref -d refs/heads/topic
		"$bin" reference-transaction committed <"$TEST_DIR/transaction"
	)
	test ! -s "$log"
}

test_snapshot_recovers_symbolic_values() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	printf '%s %s HEAD\n' "$zero" "$oid" >"$TEST_DIR/transaction"
	: >"$log"
	(
		cd "$repo"
		ln -s event-log .git/hooks/head-updated
		ln -s event-log .git/hooks/head-detached
		"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
		git -c core.hooksPath=/dev/null update-ref --no-deref HEAD "$oid"
		"$bin" reference-transaction committed <"$TEST_DIR/transaction"
	)
	assert_file_equals "head-updated|HEAD|HEAD|ref:refs/heads/main|$oid
head-detached|HEAD|HEAD|ref:refs/heads/main|$oid" "$log"
}

test_snapshot_isolates_parallel_git_processes() {
	setup_real_git_events
	old=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" commit --allow-empty -qm next
	new=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" update-ref refs/heads/first "$old"
	git -C "$repo" update-ref refs/heads/second "$new"
	: >"$log"
	GHE_EVENT_LOG="$TEST_DIR/first-events" git -C "$repo" branch -D first >"$TEST_DIR/first-output" &
	first_pid=$!
	GHE_EVENT_LOG="$TEST_DIR/second-events" git -C "$repo" branch -D second >"$TEST_DIR/second-output" &
	second_pid=$!
	wait "$first_pid"
	wait "$second_pid"
	assert_file_equals "branch-deleted|first|refs/heads/first|$old|$zero" "$TEST_DIR/first-events"
	assert_file_equals "branch-deleted|second|refs/heads/second|$new|$zero" "$TEST_DIR/second-events"
}

test_snapshot_rejects_corruption() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	printf '%s %s refs/heads/main\n%s %s refs/heads/topic\n' "$zero" "$oid" "$zero" "$oid" >"$TEST_DIR/transaction"
	(
		cd "$repo"
		for corruption in trailing header nul truncated missing; do
			: >"$log"
			"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
			for snapshot in .git/git-hooks-ext-state/*; do
				case "$corruption" in
				trailing) printf 'corrupt\n' >>"$snapshot" ;;
				header) printf 'corrupt\n' >"$snapshot" ;;
				nul) printf '%s %s refs/heads/main\n\000\n' "$zero" "$oid" >"$snapshot" ;;
				truncated) printf '%s %s refs/heads/main\n%s' "$zero" "$oid" "$oid" >"$snapshot" ;;
				missing) printf '%s %s refs/heads/main\n' "$zero" "$oid" >"$snapshot" ;;
				esac
			done
			"$bin" reference-transaction committed <"$TEST_DIR/transaction"
			assert_file_equals "branch-created|main|refs/heads/main|$zero|$oid
branch-created|topic|refs/heads/topic|$zero|$oid" "$log"
		done
	)
}

test_snapshot_rejects_unsafe_storage() {
	printf '%s %s refs/heads/topic\n' "$zero" "$one" >"$TEST_DIR/transaction"
	(
		cd "$TEST_DIR"
		"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
		"$bin" reference-transaction committed <"$TEST_DIR/transaction"
		"$bin" reference-transaction aborted <"$TEST_DIR/transaction"
	)
	create_repo
	(
		cd "$repo"
		mkdir .git/git-hooks-ext-state
		chmod 0777 .git/git-hooks-ext-state
		"$bin" reference-transaction prepared <"$TEST_DIR/transaction"
		"$bin" reference-transaction committed <"$TEST_DIR/transaction"
		"$bin" reference-transaction aborted <"$TEST_DIR/transaction"
		test -z "$(ls -A .git/git-hooks-ext-state)"
	)
}

test_snapshot_failures() {
	coverage_only || test_skip "requires a coverage build"
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	printf '%s %s HEAD\n' "$zero" "$oid" >"$TEST_DIR/head-transaction"
	printf '%s %s refs/heads/main\n' "$zero" "$oid" >"$TEST_DIR/branch-transaction"
	printf '%s %s refs/heads/main\n' "$zero" "$zero" >"$TEST_DIR/delete-transaction"
	(
		cd "$repo"
		for failure in SYMBOLIC_COMMAND_ALLOC OID_COMMAND_ALLOC VALUE_ALLOC PATH_ALLOC RECORD_ALLOC OPEN FDOPEN WRITE CLOSE; do
			for transaction in head branch; do
				env "GHE_TEST_SNAPSHOT_${failure}_FAIL=1" "$bin" reference-transaction prepared <"$TEST_DIR/$transaction-transaction"
				"$bin" reference-transaction aborted <"$TEST_DIR/$transaction-transaction"
			done
		done
		for failure in OLD_ALLOC RESTORE_READ; do
			"$bin" reference-transaction prepared <"$TEST_DIR/head-transaction"
			env "GHE_TEST_SNAPSHOT_${failure}_FAIL=1" "$bin" reference-transaction committed <"$TEST_DIR/head-transaction"
		done
		"$bin" reference-transaction prepared <"$TEST_DIR/delete-transaction"
		: >"$log"
		env GHE_TEST_SNAPSHOT_READ_FAIL=1 "$bin" reference-transaction committed <"$TEST_DIR/delete-transaction"
		test ! -s "$log"
		"$bin" reference-transaction aborted <"$TEST_DIR/delete-transaction"
		"$bin" reference-transaction preparing <"$TEST_DIR/delete-transaction"
		"$bin" verbose --local on
		git branch covered >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		grep -Fqx "[git-hooks-ext] branch-created ➠ branch-created" "$TEST_DIR/err"
		assert_exit_code 2 "$bin" verbose --local invalid
	)
}

register_ref_snapshot_tests() {
	test_expect_success "recovers packed branch and tag deletions once" test_recovers_real_branch_and_tag_deletions
	test_expect_success "recovers actual old values for notes and stash" test_recovers_real_notes_and_stash_updates
	test_expect_success "discards aborted snapshots and ignores ref maintenance" test_snapshot_suppresses_noops_and_discards_aborts
	test_expect_success "recovers the symbolic HEAD before detaching" test_snapshot_recovers_symbolic_values
	test_expect_success "isolates snapshots of parallel Git processes" test_snapshot_isolates_parallel_git_processes
	test_expect_success "rejects a corrupt snapshot before recovering any ref" test_snapshot_rejects_corruption
	test_expect_success "snapshot failures never abort Git transactions" test_snapshot_failures
	test_expect_success "handles snapshot storage outside repositories and in unsafe directories" test_snapshot_rejects_unsafe_storage
}
