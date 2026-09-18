test_rename_failure_is_returned() {
	create_repo

	(
		cd "$repo"
		"$bin" install --legacy
		cat > .git/hooks/branch-renamed <<'SH'
#!/bin/sh
exit 7
SH
		chmod +x .git/hooks/branch-renamed

		printf '%s\n' "$one $zero refs/heads/old
$zero $one refs/heads/new" |
			assert_fails "$bin" reference-transaction committed
	)
}

test_legacy_hook_file_runs() {
	create_repo

	(
		cd "$repo"
		"$bin" install --legacy
		test -x .git/hooks/reference-transaction

		cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
printf '%s %s\n' "$1" "$2" > legacy.out
SH
		chmod +x .git/hooks/branch-created

		printf '%s\n' "$zero $one refs/heads/legacy" |
			"$bin" reference-transaction committed
		test "$(cat legacy.out)" = "legacy refs/heads/legacy"
	)
}

test_legacy_respects_core_hooks_path() {
	create_repo

	(
		cd "$repo"
		for hooks_dir in custom-hooks "$TEST_DIR/custom hooks"; do
			git config core.hooksPath "$hooks_dir"
			"$bin" install --legacy
			test -x "$hooks_dir/reference-transaction"

			cat > "$hooks_dir/branch-created" <<'SH'
#!/bin/sh
printf '%s %s\n' "$1" "$2" > legacy-hooks-path.out
SH
			chmod +x "$hooks_dir/branch-created"

			printf '%s\n' "$zero $one refs/heads/custom" |
				"$bin" reference-transaction committed
			test "$(cat legacy-hooks-path.out)" = "custom refs/heads/custom"
			rm legacy-hooks-path.out
		done
	)
}

test_legacy_hook_failure_is_returned() {
	create_repo

	(
		cd "$repo"
		"$bin" install --legacy
		cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
exit 7
SH
		chmod +x .git/hooks/branch-created

		printf '%s\n' "$zero $one refs/heads/fail" |
			assert_fails "$bin" reference-transaction committed
	)
}

test_missing_legacy_hook_falls_back_to_git_hook_run() {
	create_repo

	(
		cd "$repo"
		printf '%s\n' "$zero $one refs/heads/no-legacy" |
			"$bin" reference-transaction committed >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	)
}

test_git_hook_run_success_path() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1" = hook && test "$2" = run; then
	exit 0
fi
exec /usr/bin/git "$@"
SH

	(
		cd "$repo"
		printf '%s\n' "$zero $one refs/heads/ok" |
			PATH="$fakebin:$PATH" "$bin" reference-transaction committed
	)
}

test_git_hook_run_rename_arguments() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1" = hook && test "$2" = run; then
	if test "$5" != git-hooks-ext-probe; then
		printf '%s\n' "$@" > hook-args
	fi
	exit 0
fi
exec /usr/bin/git "$@"
SH
	(
		cd "$repo"
		printf '%s\n' "$one $zero refs/heads/old
$zero $one refs/heads/new" |
			PATH="$fakebin:$PATH" "$bin" reference-transaction committed
		assert_file_equals "hook
run
--allow-unknown-hook-name
--ignore-missing
branch-renamed
--
old
new
refs/heads/old
refs/heads/new
$one" hook-args
	)
}

register_hook_runner_tests() {
	test_expect_success "returns rename hook failure" test_rename_failure_is_returned
	test_expect_success "runs legacy hook file" test_legacy_hook_file_runs
	test_expect_success "legacy mode respects core.hooksPath" test_legacy_respects_core_hooks_path
	test_expect_success "returns legacy hook failure" test_legacy_hook_failure_is_returned
	test_expect_success "missing legacy hook is ignored on older Git" test_missing_legacy_hook_falls_back_to_git_hook_run
	test_expect_success "handles successful git hook run fallback" test_git_hook_run_success_path
	test_expect_success "passes all rename arguments to git hook run" test_git_hook_run_rename_arguments
}
