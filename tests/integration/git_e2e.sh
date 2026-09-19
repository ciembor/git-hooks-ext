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
		"$bin" install --legacy
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
			note-updated note-renamed; do
			ln -s event-log ".git/hooks/$event"
		done
	)
	export GHE_EVENT_LOG="$log"
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
	test_expect_success "real Git fetch emits remote branch creation and update" test_real_git_fetch_creates_remote_branch
	test_expect_success "real Git atomic transaction emits rename and delete" test_real_git_atomic_rename_and_delete
	test_expect_success "ignores real no-op transaction payloads" test_real_git_ignores_noop_transactions
	test_expect_success "real Git runs config-based event hooks" test_real_git_config_based_hooks
}
