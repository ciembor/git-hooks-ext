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

assert_ref_family_events() {
	family=$1
	short=$2
	refname=$3

	assert_ref_event \
		"$zero $one $refname" \
		"$family-created $short $refname $zero $one"
	assert_ref_event \
		"$one $two $refname" \
		"$family-updated $short $refname $one $two"
	assert_ref_event \
		"$two $zero $refname" \
		"$family-deleted $short $refname $two $zero"
}

test_additional_ref_families() {
	assert_ref_family_events remote-head origin/HEAD refs/remotes/origin/HEAD
	assert_ref_event \
		"ref:refs/remotes/origin/main ref:refs/remotes/origin/topic refs/remotes/origin/HEAD" \
		"remote-head-updated origin/HEAD refs/remotes/origin/HEAD ref:refs/remotes/origin/main ref:refs/remotes/origin/topic"
	assert_ref_event \
		"ref:refs/remotes/origin/topic $zero refs/remotes/origin/HEAD" \
		"remote-head-deleted origin/HEAD refs/remotes/origin/HEAD ref:refs/remotes/origin/topic $zero"
	# A nested branch named HEAD is indistinguishable from a slash-named
	# remote's HEAD in a ref-only transaction; use the first path component.
	assert_ref_event \
		"$zero $one refs/remotes/origin/topic/HEAD" \
		"remote-branch-created origin/topic/HEAD refs/remotes/origin/topic/HEAD $zero $one"
	assert_ref_family_events replace deadbeef refs/replace/deadbeef
	assert_ref_family_events prefetch remotes/origin/main \
		refs/prefetch/remotes/origin/main
	assert_ref_family_events bisect-ref good-1 refs/bisect/good-1
	assert_ref_family_events rewritten-ref topic refs/rewritten/topic
	assert_ref_family_events worktree-ref private refs/worktree/private
	assert_ref_family_events root-ref AUTO_MERGE AUTO_MERGE
	assert_ref_family_events ref custom/topic refs/custom/topic
}

test_ref_namespace_boundaries() {
	assert_ref_event \
		"$zero $one refs/remotes/HEAD" \
		"ref-created remotes/HEAD refs/remotes/HEAD $zero $one"
	assert_ref_event \
		"$zero $one refs/remotes/origin" \
		"ref-created remotes/origin refs/remotes/origin $zero $one"
	assert_ref_event \
		"$zero $one refs/stash/topic" \
		"ref-created stash/topic refs/stash/topic $zero $one"
	assert_ref_event \
		"$zero $one refs/prefetcher/topic" \
		"ref-created prefetcher/topic refs/prefetcher/topic $zero $one"
	assert_ref_event \
		"$zero $one refs/worktrees/topic" \
		"ref-created worktrees/topic refs/worktrees/topic $zero $one"
}

test_root_ref_classification() {
	for refname in BISECT_EXPECTED_REV NOTES_MERGE_PARTIAL NOTES_MERGE_REF \
		MERGE_AUTOSTASH CHERRY_PICK_HEAD CUSTOM lower_HEAD; do
		assert_ref_event \
			"$zero $one $refname" \
			"root-ref-created $refname $refname $zero $one"
	done
	assert_ref_event \
		"$zero $one misc/path" \
		"root-ref-created misc/path misc/path $zero $one"

	for refname in FETCH_HEAD MERGE_HEAD; do
		printf '%s %s %s\n' "$zero" "$one" "$refname" |
			"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
		test ! -s "$TEST_DIR/out"
	done
}

test_worktree_ref_aliases() {
	assert_ref_family_events root-ref AUTO_MERGE main-worktree/AUTO_MERGE
	assert_ref_family_events root-ref AUTO_MERGE worktrees/topic/AUTO_MERGE
	assert_ref_family_events bisect-ref good main-worktree/refs/bisect/good
	assert_ref_family_events rewritten-ref commit \
		worktrees/topic/refs/rewritten/commit
	assert_ref_family_events worktree-ref private \
		main-worktree/refs/worktree/private
	assert_ref_family_events worktree-ref private \
		worktrees/topic/refs/worktree/private
	assert_ref_event \
		"$zero $one main-worktree/AUTO_MERGE" \
		"root-ref-created AUTO_MERGE main-worktree/AUTO_MERGE $zero $one"
	assert_ref_event \
		"$zero $one main-worktree/refs/bisect/good" \
		"bisect-ref-created good main-worktree/refs/bisect/good $zero $one"
	assert_ref_event \
		"$zero $one worktrees/topic/refs/rewritten/commit" \
		"rewritten-ref-created commit worktrees/topic/refs/rewritten/commit $zero $one"
	assert_ref_event \
		"ref:refs/heads/main ref:refs/heads/topic worktrees/topic/HEAD" \
		"head-updated HEAD worktrees/topic/HEAD ref:refs/heads/main ref:refs/heads/topic
head-switched HEAD worktrees/topic/HEAD ref:refs/heads/main ref:refs/heads/topic"
	assert_ref_event \
		"$one ref:refs/heads/main main-worktree/HEAD" \
		"head-updated HEAD main-worktree/HEAD $one ref:refs/heads/main
head-attached HEAD main-worktree/HEAD $one ref:refs/heads/main"
	assert_ref_event \
		"ref:refs/heads/main $one worktrees/topic/HEAD" \
		"head-updated HEAD worktrees/topic/HEAD ref:refs/heads/main $one
head-detached HEAD worktrees/topic/HEAD ref:refs/heads/main $one"
	assert_ref_event \
		"$zero $one main-worktree/refs/heads/topic" \
		"root-ref-created main-worktree/refs/heads/topic main-worktree/refs/heads/topic $zero $one"
	assert_ref_event \
		"$zero $one main-worktree/FETCH_HEAD" \
		"root-ref-created FETCH_HEAD main-worktree/FETCH_HEAD $zero $one"
	assert_ref_event \
		"$zero $one main-worktree/MERGE_HEAD" \
		"root-ref-created MERGE_HEAD main-worktree/MERGE_HEAD $zero $one"
	assert_ref_event \
		"$zero $one worktrees/topic/FETCH_HEAD" \
		"root-ref-created FETCH_HEAD worktrees/topic/FETCH_HEAD $zero $one"
	assert_ref_event \
		"$zero $one worktrees/topic/MERGE_HEAD" \
		"root-ref-created MERGE_HEAD worktrees/topic/MERGE_HEAD $zero $one"
}

test_head_events() {
	assert_ref_event \
		"$one $two HEAD" \
		"head-updated HEAD HEAD $one $two"
	assert_ref_event \
		"$one ref:refs/heads/main HEAD" \
		"head-updated HEAD HEAD $one ref:refs/heads/main
head-attached HEAD HEAD $one ref:refs/heads/main"
	assert_ref_event \
		"ref:refs/heads/main $one HEAD" \
		"head-updated HEAD HEAD ref:refs/heads/main $one
head-detached HEAD HEAD ref:refs/heads/main $one"
	assert_ref_event \
		"ref:refs/heads/main ref:refs/heads/topic HEAD" \
		"head-updated HEAD HEAD ref:refs/heads/main ref:refs/heads/topic
head-switched HEAD HEAD ref:refs/heads/main ref:refs/heads/topic"
	assert_ref_event \
		"$zero ref:refs/heads/main HEAD" \
		"head-updated HEAD HEAD $zero ref:refs/heads/main"
	assert_ref_event \
		"ref:refs/heads/main $zero HEAD" \
		"head-updated HEAD HEAD ref:refs/heads/main $zero"
	assert_ref_event \
		"$zero $one HEAD" \
		"head-updated HEAD HEAD $zero $one"
	printf '%s\n' 'ref:refs/heads/main ref:refs/heads/main HEAD' |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	test ! -s "$TEST_DIR/out"
}

test_non_rename_families_emit_individual_updates() {
	assert_ref_event \
		"$one $zero refs/custom/old
$zero $one refs/custom/new" \
		"ref-deleted custom/old refs/custom/old $one $zero
ref-created custom/new refs/custom/new $zero $one"
	assert_ref_event \
		"$one $zero refs/remotes/origin/HEAD
$zero $one refs/remotes/upstream/HEAD" \
		"remote-head-deleted origin/HEAD refs/remotes/origin/HEAD $one $zero
remote-head-created upstream/HEAD refs/remotes/upstream/HEAD $zero $one"
	assert_ref_event \
		"$one $zero refs/prefetch/old
$zero $one refs/prefetch/new" \
		"prefetch-deleted old refs/prefetch/old $one $zero
prefetch-created new refs/prefetch/new $zero $one"
	assert_ref_event \
		"$one $zero AUTO_MERGE
$zero $one MERGE_AUTOSTASH" \
		"root-ref-deleted AUTO_MERGE AUTO_MERGE $one $zero
root-ref-created MERGE_AUTOSTASH MERGE_AUTOSTASH $zero $one"
}

test_ref_other_is_ignored() {
	for refname in FETCH_HEAD MERGE_HEAD; do
		printf '%s\n' "$zero $one $refname" |
			"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
		test ! -s "$TEST_DIR/out"
	done
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
		input="${input}${zero} ${one} FETCH_HEAD
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
	test_expect_success "classifies additional ref families" test_additional_ref_families
	test_expect_success "keeps namespace boundary refs in fallback" test_ref_namespace_boundaries
	test_expect_success "classifies supported root refs" test_root_ref_classification
	test_expect_success "classifies worktree ref aliases" test_worktree_ref_aliases
	test_expect_success "emits semantic HEAD events" test_head_events
	test_expect_success "does not infer unsupported renames" test_non_rename_families_emit_individual_updates
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
