setup_real_git_events() {
	create_repo
	log="$TEST_DIR/events"
	(
		cd "$repo"
		git config user.name Test
		git config user.email test@example.com
		printf '%s\n' initial >tracked
		git add tracked
		git commit -qm initial
		git branch -M main
		install_legacy_bridge
		cat >.git/hooks/event-log <<'SH'
#!/bin/sh
printf '%s' "${0##*/}" >>"$GHE_EVENT_LOG"
for arg do
	printf '|%s' "$arg" >>"$GHE_EVENT_LOG"
done
printf '\n' >>"$GHE_EVENT_LOG"
SH
		chmod +x .git/hooks/event-log
		for event in branch-created branch-deleted branch-updated branch-renamed \
			remote-branch-created remote-branch-deleted remote-branch-updated \
			remote-branch-renamed tag-created tag-deleted tag-updated tag-renamed \
			stash-created stash-deleted stash-updated note-created note-deleted \
			note-updated note-renamed remote-head-created replace-created \
			prefetch-created bisect-ref-created rewritten-ref-created \
			worktree-ref-created ref-created; do
			ln -s event-log ".git/hooks/$event"
		done
	)
	export GHE_EVENT_LOG="$log"
}

test_real_git_additional_ref_namespaces() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	(
		cd "$repo"
		{
			printf 'start\n'
			printf 'create refs/remotes/origin/HEAD %s\n' "$oid"
			printf 'create refs/remotes/HEAD %s\n' "$oid"
			printf 'create refs/replace/%s %s\n' "$oid" "$oid"
			printf 'create refs/prefetch/remotes/origin/main %s\n' "$oid"
			printf 'create refs/bisect/good-1 %s\n' "$oid"
			printf 'create refs/rewritten/topic %s\n' "$oid"
			printf 'create refs/worktree/private %s\n' "$oid"
			printf 'create refs/custom/topic %s\n' "$oid"
			printf 'create refs/stash/topic %s\n' "$oid"
			printf 'create refs/prefetcher/topic %s\n' "$oid"
			printf 'prepare\ncommit\n'
		} | GHE_EVENT_LOG="$log" git update-ref --stdin >/dev/null
	)
	assert_file_equals \
		"remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|$oid
ref-created|remotes/HEAD|refs/remotes/HEAD|$zero|$oid
replace-created|$oid|refs/replace/$oid|$zero|$oid
prefetch-created|remotes/origin/main|refs/prefetch/remotes/origin/main|$zero|$oid
bisect-ref-created|good-1|refs/bisect/good-1|$zero|$oid
rewritten-ref-created|topic|refs/rewritten/topic|$zero|$oid
worktree-ref-created|private|refs/worktree/private|$zero|$oid
ref-created|custom/topic|refs/custom/topic|$zero|$oid
ref-created|stash/topic|refs/stash/topic|$zero|$oid
ref-created|prefetcher/topic|refs/prefetcher/topic|$zero|$oid" \
		"$log"
}

test_real_git_symbolic_head_changes() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later symbolic ref transactions"
	fi
	setup_real_git_events
	old=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" branch topic
	: >"$log"
	(
		cd "$repo"
		for event in head-updated head-attached head-detached head-switched; do
			ln -s event-log ".git/hooks/$event"
		done
		GHE_EVENT_LOG="$log" git symbolic-ref HEAD refs/heads/topic
		GHE_EVENT_LOG="$log" git checkout -q --detach main
		printf 'option no-deref\nsymref-update HEAD refs/heads/main oid %s\n' "$old" |
			GHE_EVENT_LOG="$log" git update-ref --stdin
		printf 'option no-deref\nsymref-update HEAD refs/heads/topic ref refs/heads/main\n' |
			GHE_EVENT_LOG="$log" git update-ref --stdin
	)
	assert_file_equals \
		"head-updated|HEAD|HEAD|$zero|ref:refs/heads/topic
head-updated|HEAD|HEAD|$zero|$old
head-updated|HEAD|HEAD|$old|ref:refs/heads/main
head-attached|HEAD|HEAD|$old|ref:refs/heads/main
head-updated|HEAD|HEAD|ref:refs/heads/main|ref:refs/heads/topic
head-switched|HEAD|HEAD|ref:refs/heads/main|ref:refs/heads/topic" \
		"$log"
}

test_real_git_does_not_infer_unknown_head_detach() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later symbolic ref transactions"
	fi
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	(
		cd "$repo"
		ln -s event-log .git/hooks/head-updated
		ln -s event-log .git/hooks/head-detached
		GHE_EVENT_LOG="$log" git update-ref --no-deref HEAD "$oid"
	)
	assert_file_equals \
		"head-updated|HEAD|HEAD|$zero|$oid" \
		"$log"
}

test_real_git_symbolic_remote_head() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later symbolic ref transactions"
	fi
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" update-ref refs/remotes/origin/main "$oid"
	: >"$log"
	GHE_EVENT_LOG="$log" git -C "$repo" symbolic-ref \
		refs/remotes/origin/HEAD refs/remotes/origin/main
	assert_file_equals \
		"remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|ref:refs/remotes/origin/main" \
		"$log"
}

test_real_git_root_ref_changes() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later root refs"
	fi
	setup_real_git_events
	old=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" commit --allow-empty -qm next
	new=$(git -C "$repo" rev-parse HEAD)
	: >"$log"
	(
		cd "$repo"
		for event in root-ref-created root-ref-updated root-ref-deleted; do
			ln -s event-log ".git/hooks/$event"
		done
		GHE_EVENT_LOG="$log" git update-ref AUTO_MERGE "$old"
		GHE_EVENT_LOG="$log" git update-ref AUTO_MERGE "$new" "$old"
		GHE_EVENT_LOG="$log" git update-ref -d AUTO_MERGE "$new"
	)
	assert_file_equals \
		"root-ref-created|AUTO_MERGE|AUTO_MERGE|$zero|$old
root-ref-updated|AUTO_MERGE|AUTO_MERGE|$old|$new
root-ref-deleted|AUTO_MERGE|AUTO_MERGE|$new|$zero" \
		"$log"
}

test_real_git_nonstandard_ref_names() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later worktree ref aliases"
	fi
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" worktree add -q --detach "$TEST_DIR/linked"
	(
		cd "$repo"
		ln -s event-log .git/hooks/root-ref-created
		GHE_EVENT_LOG="$log" git update-ref CUSTOM "$oid"
		GHE_EVENT_LOG="$log" git update-ref lower_HEAD "$oid"
		GHE_EVENT_LOG="$log" git update-ref misc/path "$oid"
		GHE_EVENT_LOG="$log" git update-ref main-worktree/AUTO_MERGE "$oid"
		GHE_EVENT_LOG="$log" git update-ref main-worktree/refs/bisect/good "$oid"
		GHE_EVENT_LOG="$log" git update-ref worktrees/linked/refs/rewritten/topic "$oid"
		GHE_EVENT_LOG="$log" git update-ref main-worktree/FETCH_HEAD "$oid"
		GHE_EVENT_LOG="$log" git update-ref main-worktree/MERGE_HEAD "$oid"
		GHE_EVENT_LOG="$log" git update-ref worktrees/linked/FETCH_HEAD "$oid"
		GHE_EVENT_LOG="$log" git update-ref worktrees/linked/MERGE_HEAD "$oid"
	)
	assert_file_equals \
		"root-ref-created|CUSTOM|CUSTOM|$zero|$oid
root-ref-created|lower_HEAD|lower_HEAD|$zero|$oid
root-ref-created|misc/path|misc/path|$zero|$oid
root-ref-created|AUTO_MERGE|main-worktree/AUTO_MERGE|$zero|$oid
bisect-ref-created|good|main-worktree/refs/bisect/good|$zero|$oid
rewritten-ref-created|topic|worktrees/linked/refs/rewritten/topic|$zero|$oid
root-ref-created|FETCH_HEAD|main-worktree/FETCH_HEAD|$zero|$oid
root-ref-created|MERGE_HEAD|main-worktree/MERGE_HEAD|$zero|$oid
root-ref-created|FETCH_HEAD|worktrees/linked/FETCH_HEAD|$zero|$oid
root-ref-created|MERGE_HEAD|worktrees/linked/MERGE_HEAD|$zero|$oid" \
		"$log"
}

test_real_git_branch_create_and_commit_update() {
	setup_real_git_events
	old=$(git -C "$repo" rev-parse HEAD)
	(
		cd "$repo"
		GHE_EVENT_LOG="$log" git branch topic
		printf '%s\n' changed >>tracked
		git add tracked
		GHE_EVENT_LOG="$log" git commit -qm second
	)
	new=$(git -C "$repo" rev-parse HEAD)
	assert_file_equals "branch-created|topic|refs/heads/topic|$zero|$old
branch-updated|main|refs/heads/main|$old|$new" "$log"
}

test_real_git_tag_create_and_update() {
	setup_real_git_events
	old=$(git -C "$repo" rev-parse HEAD)
	(
		cd "$repo"
		git commit --allow-empty -qm second
		new=$(git rev-parse HEAD)
		: >"$log"
		GHE_EVENT_LOG="$log" git tag v1 "$old"
		GHE_EVENT_LOG="$log" git tag -f v1 "$new" >/dev/null
	)
	new=$(git -C "$repo" rev-parse HEAD)
	assert_file_equals "tag-created|v1|refs/tags/v1|$zero|$old
tag-updated|v1|refs/tags/v1|$old|$new" "$log"
}

test_real_git_notes_and_stash_creation() {
	setup_real_git_events
	(
		cd "$repo"
		GHE_EVENT_LOG="$log" git notes add -m note HEAD
		note_oid=$(git rev-parse refs/notes/commits)
		printf '%s\n' dirty >>tracked
		GHE_EVENT_LOG="$log" git stash push -qm saved
		stash_oid=$(git rev-parse refs/stash)
		printf '%s\n' "$note_oid" >"$TEST_DIR/note-oid"
		printf '%s\n' "$stash_oid" >"$TEST_DIR/stash-oid"
	)
	note_oid=$(cat "$TEST_DIR/note-oid")
	stash_oid=$(cat "$TEST_DIR/stash-oid")
	assert_file_equals "note-created|commits|refs/notes/commits|$zero|$note_oid
stash-created|stash|refs/stash|$zero|$stash_oid" "$log"
}

test_real_git_fetch_creates_remote_branch() {
	setup_real_git_events
	remote="$TEST_DIR/remote.git"
	git init -q --bare "$remote"
	git -C "$remote" symbolic-ref HEAD refs/heads/main
	git -C "$repo" remote add origin "$remote"
	git -C "$repo" push -q origin HEAD:main
	: >"$log"
	git -C "$repo" update-ref -d refs/remotes/origin/main
	: >"$log"
	GHE_EVENT_LOG="$log" git -C "$repo" fetch -q origin \
		main:refs/remotes/origin/main
	oid=$(git -C "$repo" rev-parse refs/remotes/origin/main)
	assert_file_equals \
		"remote-branch-created|origin/main|refs/remotes/origin/main|$zero|$oid" \
		"$log"
	seed="$TEST_DIR/seed"
	git clone -q --no-checkout "$remote" "$seed"
	git -C "$seed" config user.name Test
	git -C "$seed" config user.email test@example.com
	git -C "$seed" checkout -q main
	git -C "$seed" commit --allow-empty -qm next
	git -C "$seed" push -q origin HEAD:main
	new=$(git -C "$seed" rev-parse HEAD)
	: >"$log"
	GHE_EVENT_LOG="$log" git -C "$repo" fetch -q origin \
		main:refs/remotes/origin/main
	assert_file_equals \
		"remote-branch-updated|origin/main|refs/remotes/origin/main|$oid|$new" \
		"$log"
}

test_real_git_atomic_rename_and_delete() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	git -C "$repo" branch old
	: >"$log"
	(
		cd "$repo"
		printf 'start\ndelete refs/heads/old %s\ncreate refs/heads/new %s\nprepare\ncommit\n' \
			"$oid" "$oid" |
			GHE_EVENT_LOG="$log" git update-ref --stdin >/dev/null
		GHE_EVENT_LOG="$log" git update-ref -d refs/heads/new "$oid"
	)
	assert_file_equals "branch-renamed|old|new|refs/heads/old|refs/heads/new|$oid
branch-deleted|new|refs/heads/new|$oid|$zero" "$log"
}

test_real_git_mixed_rename_and_fallback_updates() {
	setup_real_git_events
	oid=$(git -C "$repo" rev-parse HEAD)
	(
		cd "$repo"
		ln -s event-log .git/hooks/ref-deleted
		ln -s event-log .git/hooks/remote-head-deleted
		git update-ref refs/heads/old "$oid"
		git update-ref refs/custom/old "$oid"
		git update-ref refs/remotes/origin/HEAD "$oid"
		: >"$log"
		{
			printf 'start\n'
			printf 'delete refs/heads/old %s\n' "$oid"
			printf 'create refs/heads/new %s\n' "$oid"
			printf 'delete refs/custom/old %s\n' "$oid"
			printf 'create refs/custom/new %s\n' "$oid"
			printf 'delete refs/remotes/origin/HEAD %s\n' "$oid"
			printf 'create refs/remotes/upstream/HEAD %s\n' "$oid"
			printf 'prepare\ncommit\n'
		} | GHE_EVENT_LOG="$log" git update-ref --stdin >/dev/null
	)
	assert_has_line "branch-renamed|old|new|refs/heads/old|refs/heads/new|$oid" "$log"
	assert_has_line "ref-deleted|custom/old|refs/custom/old|$oid|$zero" "$log"
	assert_has_line "ref-created|custom/new|refs/custom/new|$zero|$oid" "$log"
	assert_has_line "remote-head-deleted|origin/HEAD|refs/remotes/origin/HEAD|$oid|$zero" "$log"
	assert_has_line "remote-head-created|upstream/HEAD|refs/remotes/upstream/HEAD|$zero|$oid" "$log"
	test "$(wc -l <"$log" | tr -d ' ')" -eq 5
}

test_real_git_ignores_noop_transactions() {
	setup_real_git_events
	(
		cd "$repo"
		git branch old
		git tag v1
		: >"$log"
		GHE_EVENT_LOG="$log" git branch -D old >/dev/null
		GHE_EVENT_LOG="$log" git tag -d v1 >/dev/null
	)
	# Git 2.28–2.30 reports real deletes; newer versions may report
	# zero -> zero. Neither should produce a fabricated update.
	if test -e "$log" && grep -Ev \
		'^(branch-deleted\|old\|refs/heads/old\||tag-deleted\|v1\|refs/tags/v1\|)' \
		"$log" >"$TEST_DIR/unexpected"; then
		cat "$TEST_DIR/unexpected" >&2
		return 1
	fi
}

test_real_git_config_based_hooks() {
	git_minor=$(git --version | sed -n 's/^git version [0-9]*\.\([0-9]*\)\..*/\1/p')
	if test -z "$git_minor" || test "$git_minor" -lt 54; then
		test_skip "requires Git 2.54 or later"
	fi
	create_repo
	(
		cd "$repo"
		git config user.name Test
		git config user.email test@example.com
		git commit --allow-empty -qm initial
		mkdir -p "$TEST_DIR/bin"
		ln -s "$bin" "$TEST_DIR/bin/git-hooks-ext"
		PATH="$TEST_DIR/bin:$PATH"
		export PATH
		git-hooks-ext install
		cat >"$TEST_DIR/log-event" <<'SH'
#!/bin/sh
printf '%s|%s\n' "$1" "$2" >>"$GHE_EVENT_LOG"
SH
		chmod +x "$TEST_DIR/log-event"
		git-hooks-ext add branch-created log-created "$TEST_DIR/log-event"
		GHE_EVENT_LOG="$TEST_DIR/events" git branch topic
	)
	assert_file_equals 'topic|refs/heads/topic' "$TEST_DIR/events"
}

register_git_e2e_tests() {
	test_expect_success "real Git emits branch create and commit update events" test_real_git_branch_create_and_commit_update
	test_expect_success "real Git emits tag create and update events" test_real_git_tag_create_and_update
	test_expect_success "real Git emits notes and stash creation events" test_real_git_notes_and_stash_creation
	test_expect_success "real Git classifies additional ref namespaces" test_real_git_additional_ref_namespaces
	test_expect_success "real Git emits symbolic HEAD transitions" test_real_git_symbolic_head_changes
	test_expect_success "real Git does not infer HEAD detach from an unknown old value" test_real_git_does_not_infer_unknown_head_detach
	test_expect_success "real Git emits symbolic remote HEAD" test_real_git_symbolic_remote_head
	test_expect_success "real Git emits root ref transitions" test_real_git_root_ref_changes
	test_expect_success "real Git emits nonstandard and worktree-alias refs" test_real_git_nonstandard_ref_names
	test_expect_success "real Git fetch emits remote branch creation and update" test_real_git_fetch_creates_remote_branch
	test_expect_success "real Git atomic transaction emits rename and delete" test_real_git_atomic_rename_and_delete
	test_expect_success "real Git keeps rename separate from fallback refs" test_real_git_mixed_rename_and_fallback_updates
	test_expect_success "ignores real no-op transaction payloads" test_real_git_ignores_noop_transactions
	test_expect_success "real Git runs config-based event hooks" test_real_git_config_based_hooks
}
