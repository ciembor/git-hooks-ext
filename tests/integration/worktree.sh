setup_worktree_repo() {
	create_repo
	(
		cd "$repo"
		git config user.name Test
		git config user.email test@example.com
		printf '%s\n' initial >tracked
		git add tracked
		git commit -qm initial
		"$bin" install --legacy
		cat >.git/hooks/worktree-event <<'SH'
#!/bin/sh
printf '%s' "${0##*/}" >>"$GHE_EVENT_LOG"
for arg do
	printf '|%s' "$arg" >>"$GHE_EVENT_LOG"
done
printf '\n' >>"$GHE_EVENT_LOG"
SH
		chmod +x .git/hooks/worktree-event
		for event in worktree-created worktree-removed worktree-moved \
			worktree-locked worktree-unlocked worktree-pruned \
			worktree-repaired; do
			ln -s worktree-event ".git/hooks/$event"
		done
	)
}

test_worktree_lifecycle_events() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	tree="$root/tree one"
	moved="$root/tree moved"
	log="$TEST_DIR/events"
	oid=$(git -C "$repo" rev-parse HEAD)

	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add -b topic "$tree"
		GHE_EVENT_LOG="$log" "$bin" worktree lock --reason "portable disk" "$tree"
		GHE_EVENT_LOG="$log" "$bin" worktree unlock "$tree"
		GHE_EVENT_LOG="$log" "$bin" worktree move "$tree" "$moved"
		GHE_EVENT_LOG="$log" "$bin" worktree remove "$moved"
	)

	assert_file_equals "worktree-created|$tree|$oid|refs/heads/topic
worktree-locked|$tree|portable disk
worktree-unlocked|$tree|portable disk
worktree-moved|$tree|$moved|$oid|refs/heads/topic
worktree-removed|$moved|$oid|refs/heads/topic" "$log"
}

test_worktree_add_locked_emits_two_events() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	tree="$root/locked"
	log="$TEST_DIR/events"
	oid=$(git -C "$repo" rev-parse HEAD)

	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add --detach --lock \
			--reason "offline" "$tree"
	)

	assert_file_equals "worktree-created|$tree|$oid|
worktree-locked|$tree|offline" "$log"
}

test_worktree_pruned_event() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	tree="$root/stale"
	log="$TEST_DIR/events"
	oid=$(git -C "$repo" rev-parse HEAD)

	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add --detach "$tree"
		rm -rf "$tree"
		: >"$log"
		GHE_EVENT_LOG="$log" "$bin" worktree prune --expire now
	)

	assert_file_equals "worktree-pruned|$tree|$oid|" "$log"
}

test_worktree_repaired_event() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	old="$root/repair-old"
	new="$root/repair-new"
	log="$TEST_DIR/events"
	oid=$(git -C "$repo" rev-parse HEAD)

	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add --detach "$old"
		mv "$old" "$new"
		: >"$log"
		GHE_EVENT_LOG="$log" "$bin" worktree repair "$new"
	)

	assert_file_equals "worktree-repaired|$new|$oid|" "$log"
}

test_worktree_proxies_read_only_commands() {
	setup_worktree_repo
	(
		cd "$repo"
		"$bin" worktree list >"$TEST_DIR/actual-short"
		git worktree list >"$TEST_DIR/expected-short"
		"$bin" worktree list --porcelain >"$TEST_DIR/actual"
		git worktree list --porcelain >"$TEST_DIR/expected-list"
	)
	diff -u "$TEST_DIR/expected-short" "$TEST_DIR/actual-short"
	diff -u "$TEST_DIR/expected-list" "$TEST_DIR/actual"
}

test_worktree_rejects_missing_command() {
	assert_exit_code 2 "$bin" worktree >"$TEST_DIR/out" 2>"$TEST_DIR/err"
}

test_worktree_failed_git_command_emits_nothing() {
	setup_worktree_repo
	(
		cd "$repo"
		assert_fails env GHE_EVENT_LOG="$TEST_DIR/events" \
			"$bin" worktree remove "$TEST_DIR/missing"
	)
	test ! -e "$TEST_DIR/events"
}

replace_worktree_hook_with_failure() {
	event=$1
	rm -f "$repo/.git/hooks/$event"
	cat >"$repo/.git/hooks/$event" <<'SH'
#!/bin/sh
exit 9
SH
	chmod +x "$repo/.git/hooks/$event"
}

test_worktree_returns_created_and_locked_hook_failures() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	log="$TEST_DIR/events"
	replace_worktree_hook_with_failure worktree-created
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree add \
			--detach "$root/created-fails"
	)

	rm -f "$repo/.git/hooks/worktree-created"
	ln -s worktree-event "$repo/.git/hooks/worktree-created"
	replace_worktree_hook_with_failure worktree-locked
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree add \
			--detach --lock "$root/locked-fails"
	)
}

test_worktree_returns_remove_and_lock_hook_failures() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	tree="$root/tree"
	log="$TEST_DIR/events"
	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add --detach "$tree"
	)
	replace_worktree_hook_with_failure worktree-locked
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree lock "$tree"
	)
	replace_worktree_hook_with_failure worktree-unlocked
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree unlock "$tree"
	)
	replace_worktree_hook_with_failure worktree-removed
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree remove "$tree"
	)
}

test_worktree_returns_move_and_repair_hook_failures() {
	setup_worktree_repo
	root=$(cd "$TEST_DIR" && pwd -P)
	old="$root/old"
	moved="$root/moved"
	repaired="$root/repaired"
	log="$TEST_DIR/events"
	(
		cd "$repo"
		GHE_EVENT_LOG="$log" "$bin" worktree add --detach "$old"
	)
	replace_worktree_hook_with_failure worktree-moved
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree move "$old" "$moved"
	)
	mv "$moved" "$repaired"
	replace_worktree_hook_with_failure worktree-repaired
	(
		cd "$repo"
		assert_exit_code 9 env GHE_EVENT_LOG="$log" "$bin" worktree repair "$repaired"
	)
}

test_worktree_parser_rejects_invalid_snapshots() {
	create_fake_git <<'SH'
#!/bin/sh
case "$GHE_FAKE_STATE" in
missing-nul)
	printf 'worktree /a'
	;;
duplicate)
	printf 'worktree /a\0worktree /b\0'
	;;
partial)
	printf 'worktree /a\0HEAD a\0\0broken'
	;;
empty-path)
	printf 'worktree \0HEAD a\0\0'
	;;
esac
SH
	for state in missing-nul duplicate partial empty-path; do
		assert_fails env PATH="$fakebin:$PATH" GHE_FAKE_STATE="$state" \
			"$bin" worktree prune --dry-run
	done
}

test_worktree_reads_snapshots_larger_than_initial_buffer() {
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2 $3" = "worktree list --porcelain"; then
	printf 'worktree /'
	awk 'BEGIN { for (i = 0; i < 3000; i++) printf "x" }'
	printf '\0HEAD a\0branch refs/heads/main\0\0'
fi
SH
	env PATH="$fakebin:$PATH" "$bin" worktree prune --dry-run
}

test_worktree_parser_accepts_complete_porcelain_forms() {
	coverage_only || test_skip "requires a coverage build"
	create_fake_git <<'SH'
#!/bin/sh
printf '\0'
printf 'worktree /a\0bare\0locked\0\0'
printf 'worktree /b\0HEAD b\0detached\0\0'
printf 'worktree /c\0HEAD c\0branch refs/heads/c\0\0'
printf 'worktree /d\0HEAD d\0branch refs/heads/d\0\0'
printf 'worktree /e\0HEAD e\0branch refs/heads/e\0'
SH
	assert_fails env PATH="$fakebin:$PATH" GHE_TEST_WORKTREE_CALLOC_FAIL=1 \
		"$bin" worktree prune --dry-run
}

test_worktree_reports_second_snapshot_failure() {
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2 $3" = "worktree list --porcelain"; then
	count=0
	test ! -f "$GHE_FAKE_COUNT" || count=$(cat "$GHE_FAKE_COUNT")
	count=$((count + 1))
	printf '%s\n' "$count" >"$GHE_FAKE_COUNT"
	if test "$count" -eq 1; then
		printf 'worktree /repo\0HEAD a\0branch refs/heads/main\0\0'
	else
		exit 1
	fi
fi
exit 0
SH
	assert_fails env PATH="$fakebin:$PATH" GHE_FAKE_COUNT="$TEST_DIR/count" \
		"$bin" worktree prune --dry-run
}

test_worktree_ignores_unmatched_path_changes() {
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2 $3" = "worktree list --porcelain"; then
	count=0
	test ! -f "$GHE_FAKE_COUNT" || count=$(cat "$GHE_FAKE_COUNT")
	count=$((count + 1))
	printf '%s\n' "$count" >"$GHE_FAKE_COUNT"
	if test "$count" -eq 1; then
		printf 'worktree /old\0HEAD old\0detached\0\0'
	else
		printf 'worktree /new\0HEAD new\0detached\0\0'
	fi
fi
exit 0
SH
	env PATH="$fakebin:$PATH" GHE_FAKE_COUNT="$TEST_DIR/count" \
		"$bin" worktree move /old /new
}

register_worktree_tests() {
	test_expect_success "emits worktree lifecycle events" test_worktree_lifecycle_events
	test_expect_success "emits created and locked for worktree add --lock" test_worktree_add_locked_emits_two_events
	test_expect_success "emits worktree-pruned" test_worktree_pruned_event
	test_expect_success "emits worktree-repaired" test_worktree_repaired_event
	test_expect_success "proxies read-only worktree commands" test_worktree_proxies_read_only_commands
	test_expect_success "rejects a missing worktree command" test_worktree_rejects_missing_command
	test_expect_success "does not emit after a failed worktree command" test_worktree_failed_git_command_emits_nothing
	test_expect_success "returns created and locked hook failures" test_worktree_returns_created_and_locked_hook_failures
	test_expect_success "returns remove, lock and unlock hook failures" test_worktree_returns_remove_and_lock_hook_failures
	test_expect_success "returns move and repair hook failures" test_worktree_returns_move_and_repair_hook_failures
	test_expect_success "rejects invalid worktree snapshots" test_worktree_parser_rejects_invalid_snapshots
	test_expect_success "reads large worktree snapshots" test_worktree_reads_snapshots_larger_than_initial_buffer
	test_expect_success "parses all worktree porcelain forms" test_worktree_parser_accepts_complete_porcelain_forms
	test_expect_success "reports second worktree snapshot failure" test_worktree_reports_second_snapshot_failure
	test_expect_success "ignores unmatched worktree path changes" test_worktree_ignores_unmatched_path_changes
}
