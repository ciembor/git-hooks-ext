test_coverage_forced_failures() {
	coverage_only || test_skip "requires a coverage build"

	create_repo
	(
		cd "$repo"
		assert_fails env GHE_TEST_MKDIR_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_SHELL_QUOTE_MALLOC_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_INSTALLED_PROGRAM_STRDUP_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_FOPEN_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_FPUTS_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_FCLOSE_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_CHMOD_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_POPEN_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_READ_COMMAND_MALLOC_FAIL=1 "$bin" install --legacy
		assert_fails env GHE_TEST_PCLOSE_COMMAND_FAIL=1 "$bin" install --legacy
		env GHE_TEST_REALPATH_FAIL=1 "$bin" install --legacy

		mkdir -p "$TEST_DIR/path-bin"
		ln -sf "$bin" "$TEST_DIR/path-bin/git-hooks-ext"
		env PATH="$TEST_DIR/path-bin:$PATH" git-hooks-ext install --legacy

		assert_fails env GHE_TEST_XMALLOC_FAIL=1 "$bin" add branch-created x ./x
		assert_fails env GHE_TEST_JOIN_COMMAND_MALLOC_FAIL=1 "$bin" add branch-created x ./x
		assert_fails env GHE_TEST_JOIN_HOOK_PATH_MALLOC_FAIL=1 "$bin" install --legacy

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

		"$bin" install --legacy
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
	)
}

register_coverage_tests() {
	test_expect_success "covers forced failure paths" test_coverage_forced_failures
}
