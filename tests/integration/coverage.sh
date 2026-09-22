test_coverage_forced_failures() {
	coverage_only || test_skip "requires a coverage build"

	create_repo
	(
		cd "$repo"
		assert_fails with_legacy_git env GHE_TEST_MKDIR_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_SHELL_QUOTE_MALLOC_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_INSTALLED_PROGRAM_STRDUP_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_FOPEN_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_FPUTS_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_FCLOSE_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_CHMOD_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_POPEN_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_READ_COMMAND_MALLOC_FAIL=1 "$bin" install
		assert_fails with_legacy_git env GHE_TEST_PCLOSE_COMMAND_FAIL=1 "$bin" install
		with_legacy_git env GHE_TEST_REALPATH_FAIL=1 "$bin" install

		mkdir -p "$TEST_DIR/path-bin"
		ln -sf "$bin" "$TEST_DIR/path-bin/git-hooks-ext"
		with_legacy_git env PATH="$TEST_DIR/path-bin:$PATH" git-hooks-ext install

		assert_fails env GHE_TEST_XMALLOC_FAIL=1 "$bin" add branch-created x ./x
		"$bin" add branch-created managed ./managed
		assert_fails env GHE_TEST_HOOK_KEY_MALLOC_FAIL=1 "$bin" show managed
		assert_fails env GHE_TEST_HOOK_KEY_MALLOC_FAIL=1 "$bin" list
		assert_fails env GHE_TEST_HOOK_COMMAND_KEY_MALLOC_FAIL=1 "$bin" remove managed
		assert_fails env GHE_TEST_HOOK_MANAGE_COMMAND_MALLOC_FAIL=1 "$bin" show managed
		assert_fails env GHE_TEST_HOOK_MANAGE_STRNDUP_FAIL=1 "$bin" list
		assert_fails env GHE_TEST_SHELL_QUOTE_MALLOC_FAIL=1 "$bin" show managed
		assert_fails env GHE_TEST_JOIN_COMMAND_MALLOC_FAIL=1 "$bin" add branch-created x ./x
		assert_fails with_legacy_git env GHE_TEST_JOIN_HOOK_PATH_MALLOC_FAIL=1 "$bin" install

		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_REF_STRDUP_FAIL=1 "$bin" reference-transaction committed --dry-run
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_REALLOC_FAIL=1 "$bin" reference-transaction committed --dry-run
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_STDIN_ERROR=1 "$bin" reference-transaction committed --dry-run

		printf '%s\n' "$zero $one refs/heads/topic" |
			env GHE_TEST_CONFIG_HOOKS_UNSUPPORTED=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_CONFIG_HOOKS_SUPPORTED=1 GHE_TEST_HOOK_RUN_CALLOC_FAIL=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_CONFIG_HOOKS_SUPPORTED=1 \
				GHE_TEST_JOIN_HOOK_PATH_MALLOC_FAIL=1 \
				GHE_TEST_HOOK_RUN_CALLOC_FAIL=1 \
				"$bin" reference-transaction committed

		install_legacy_bridge
		cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
exit 0
SH
		chmod +x .git/hooks/branch-created
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_LEGACY_CALLOC_FAIL=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_SPAWN_FAIL=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_WAITPID_FAIL=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_PROCESS_SIGNALED=1 "$bin" reference-transaction committed
		printf '%s\n' "$zero $one refs/heads/topic" |
			assert_fails env GHE_TEST_PROCESS_UNKNOWN=1 "$bin" reference-transaction committed

		cat > .git/hooks/head-attached <<'SH'
#!/bin/sh
exit 1
SH
		chmod +x .git/hooks/head-attached
		printf '%s\n' "$one ref:refs/heads/main HEAD" |
			assert_fails "$bin" reference-transaction committed

		assert_fails env GHE_TEST_READ_ALL_POPEN_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_READ_ALL_MALLOC_FAIL=1 "$bin" worktree prune --dry-run
		env GHE_TEST_READ_ALL_SMALL_BUFFER=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_READ_ALL_SMALL_BUFFER=1 \
			GHE_TEST_READ_ALL_REALLOC_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_READ_ALL_FREAD_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_READ_ALL_PCLOSE_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_WORKTREE_STRNDUP_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_WORKTREE_REALLOC_FAIL=1 "$bin" worktree prune --dry-run
		assert_fails env GHE_TEST_WORKTREE_CALLOC_FAIL=1 "$bin" worktree prune --dry-run
	)
}

register_coverage_tests() {
	test_expect_success "covers forced failure paths" test_coverage_forced_failures
}
