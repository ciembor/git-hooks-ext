test_full_update_array() {
	i=0
	while test "$i" -lt 8; do
		printf '%s %s refs/heads/topic-%d\n' "$zero" "$one" "$i"
		i=$((i + 1))
	done >"$TEST_DIR/input"
	"$bin" reference-transaction committed --dry-run <"$TEST_DIR/input" >"$TEST_DIR/out"
	i=0
	while test "$i" -lt 8; do
		printf 'branch-created topic-%d refs/heads/topic-%d %s %s\n' "$i" "$i" "$zero" "$one"
		i=$((i + 1))
	done >"$TEST_DIR/expected"
	diff -u "$TEST_DIR/expected" "$TEST_DIR/out"
}

test_branch_created() {
	assert_ref_event \
		"$zero $one refs/heads/topic" \
		"branch-created topic refs/heads/topic $zero $one"
}

test_branch_deleted() {
	assert_ref_event \
		"$one $zero refs/heads/topic" \
		"branch-deleted topic refs/heads/topic $one $zero"
}

test_branch_updated() {
	assert_ref_event \
		"$one $two refs/heads/topic" \
		"branch-updated topic refs/heads/topic $one $two"
}

test_branch_renamed() {
	assert_ref_event \
		"$one $zero refs/heads/old
$zero $one refs/heads/new" \
		"branch-renamed old new refs/heads/old refs/heads/new $one"
}

test_ambiguous_rename_emits_delete_and_creates() {
	assert_ref_event \
		"$one $zero refs/heads/old
$zero $one refs/heads/new-a
$zero $one refs/heads/new-b" \
		"branch-deleted old refs/heads/old $one $zero
branch-created new-a refs/heads/new-a $zero $one
branch-created new-b refs/heads/new-b $zero $one"
}

test_ambiguous_rename_sources() {
	assert_ref_event \
		"$one $zero refs/heads/old-a
$one $zero refs/heads/old-b
$zero $one refs/heads/new" \
		"branch-deleted old-a refs/heads/old-a $one $zero
branch-deleted old-b refs/heads/old-b $one $zero
branch-created new refs/heads/new $zero $one"
	assert_ref_event \
		"$zero $one refs/heads/new
$one $zero refs/heads/old-b
$one $zero refs/heads/old-a" \
		"branch-created new refs/heads/new $zero $one
branch-deleted old-b refs/heads/old-b $one $zero
branch-deleted old-a refs/heads/old-a $one $zero"
}

test_sha256_ref_events() {
	zero256=$(printf '%064d' 0)
	one256=$(printf '%064d' 1)
	assert_ref_event \
		"$zero256 $one256 refs/heads/topic" \
		"branch-created topic refs/heads/topic $zero256 $one256"
	assert_ref_event \
		"$one256 $zero256 refs/heads/topic" \
		"branch-deleted topic refs/heads/topic $one256 $zero256"
	assert_ref_event \
		"$one256 $zero256 refs/heads/old
$zero256 $one256 refs/heads/new" \
		"branch-renamed old new refs/heads/old refs/heads/new $one256"
}

test_mixed_transaction_renames_stay_in_namespace() {
	assert_ref_event \
		"$one $zero refs/heads/old
$one $zero refs/tags/v1
$zero $one refs/tags/v2
$zero $one refs/heads/new" \
		"branch-renamed old new refs/heads/old refs/heads/new $one
tag-renamed v1 v2 refs/tags/v1 refs/tags/v2 $one"
}

test_sha256_git_transactions_run_hooks() {
	create_repo --object-format=sha256
	(
		cd "$repo"
		git -c user.name=Test -c user.email=test@example.com commit --allow-empty -qm initial
		oid=$(git rev-parse HEAD)
		zero256=$(printf '%064d' 0)
		"$bin" install --legacy
		cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
printf 'created %s %s %s\n' "$1" "$3" "$4" >> events.out
SH
		cat > .git/hooks/branch-deleted <<'SH'
#!/bin/sh
printf 'deleted %s %s %s\n' "$1" "$3" "$4" >> events.out
SH
		chmod +x .git/hooks/branch-created .git/hooks/branch-deleted
		git branch topic
		git update-ref -d refs/heads/topic "$oid"
		assert_file_equals "created topic $zero256 $oid
deleted topic $oid $zero256" events.out
	)
}

test_delete_create_different_objects_is_not_rename() {
	assert_ref_event \
		"$one $zero refs/heads/old
$zero $two refs/heads/new" \
		"branch-deleted old refs/heads/old $one $zero
branch-created new refs/heads/new $zero $two"
}

test_tag_renamed() {
	assert_ref_event \
		"$one $zero refs/tags/old
$zero $one refs/tags/new" \
		"tag-renamed old new refs/tags/old refs/tags/new $one"
}

test_tag_created() {
	assert_ref_event \
		"$zero $one refs/tags/v1.0.0" \
		"tag-created v1.0.0 refs/tags/v1.0.0 $zero $one"
}

test_remote_branch_created() {
	assert_ref_event \
		"$zero $one refs/remotes/origin/topic" \
		"remote-branch-created origin/topic refs/remotes/origin/topic $zero $one"
}

test_stash_created() {
	assert_ref_event \
		"$zero $one refs/stash" \
		"stash-created stash refs/stash $zero $one"
}

test_note_updated() {
	assert_ref_event \
		"$one $two refs/notes/commits" \
		"note-updated commits refs/notes/commits $one $two"
}

test_ref_other_is_ignored() {
	printf '%s\n' "$zero $one refs/changes/1" |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
}

test_unchanged_ref_is_ignored() {
	printf '%s %s refs/heads/main\n' "$one" "$one" |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
	printf '%s %s refs/heads/main\n' "$zero" "$zero" |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
}

test_large_transaction_grows_update_array() {
	input=
	i=0
	while test "$i" -lt 9; do
		input="${input}${zero} ${one} refs/changes/$i
"
		i=$((i + 1))
	done

	printf '%s' "$input" |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
}

test_invalid_reference_transaction_input_fails() {
	printf '%s\n' "not-enough-fields" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	assert_has_line "git-hooks-ext: invalid reference-transaction input" "$TEST_DIR/err"
}

test_malformed_spacing_is_rejected() {
	printf '%s\n' " $zero $one refs/heads/topic" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	printf '%s\n' "$zero  $one refs/heads/topic" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
	printf '%s\n' "$zero $one  refs/heads/topic" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out3" 2>"$TEST_DIR/err3"
	printf '%s\n' "$zero $one refs/heads/topic extra" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out4" 2>"$TEST_DIR/err4"
	printf '%s\t%s %s\n' "$zero" "$one" refs/heads/topic |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out5" 2>"$TEST_DIR/err5"
	printf '%s %s refs/heads/topic\tbad\n' "$zero" "$one" |
		assert_fails "$bin" reference-transaction committed >"$TEST_DIR/out6" 2>"$TEST_DIR/err6"
}

test_embedded_nul_is_rejected() {
	printf '%s %s refs/heads/topic\000ignored\n' "$zero" "$one" |
		assert_fails "$bin" reference-transaction committed --dry-run >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	test ! -s "$TEST_DIR/out"
}

test_invalid_later_line_emits_no_events() {
	printf '%s\n' "$zero $one refs/heads/topic" invalid |
		assert_fails "$bin" reference-transaction committed --dry-run >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	test ! -s "$TEST_DIR/out"
}

test_ignores_non_committed_transactions() {
	printf '%s\n' "$zero $one refs/heads/topic" |
		"$bin" reference-transaction prepared --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
}

test_reference_transaction_rejects_bad_args() {
	assert_fails "$bin" reference-transaction >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	assert_fails "$bin" reference-transaction committed --wat >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
}

register_ref_events_tests() {
	test_expect_success "processes a full update array" test_full_update_array
	test_expect_success "emits branch-created" test_branch_created
	test_expect_success "emits branch-deleted" test_branch_deleted
	test_expect_success "emits branch-updated" test_branch_updated
	test_expect_success "detects branch-renamed" test_branch_renamed
	test_expect_success "does not guess ambiguous rename" test_ambiguous_rename_emits_delete_and_creates
	test_expect_success "does not guess between ambiguous rename sources" test_ambiguous_rename_sources
	test_expect_success "supports SHA-256 ref events" test_sha256_ref_events
	test_expect_success "keeps mixed transaction renames in their namespace" test_mixed_transaction_renames_stay_in_namespace
	test_expect_success "runs hooks from real Git transactions in a SHA-256 repository" test_sha256_git_transactions_run_hooks
	test_expect_success "does not rename different objects" test_delete_create_different_objects_is_not_rename
	test_expect_success "detects tag-renamed" test_tag_renamed
	test_expect_success "emits tag-created" test_tag_created
	test_expect_success "emits remote-branch-created" test_remote_branch_created
	test_expect_success "emits stash-created" test_stash_created
	test_expect_success "emits note-updated" test_note_updated
	test_expect_success "ignores unsupported refs" test_ref_other_is_ignored
	test_expect_success "ignores unchanged refs" test_unchanged_ref_is_ignored
	test_expect_success "grows update array" test_large_transaction_grows_update_array
	test_expect_success "rejects invalid reference input" test_invalid_reference_transaction_input_fails
	test_expect_success "rejects malformed spacing" test_malformed_spacing_is_rejected
	test_expect_success "rejects embedded NUL bytes" test_embedded_nul_is_rejected
	test_expect_success "emits no events after a later invalid line" test_invalid_later_line_emits_no_events
	test_expect_success "ignores non-committed transactions" test_ignores_non_committed_transactions
	test_expect_success "rejects bad reference-transaction args" test_reference_transaction_rejects_bad_args
}
