test_install_writes_config_based_bridge() {
	create_repo

	(
		cd "$repo"
		"$bin" install
		test "$(git config --local hook.git-hooks-ext.event)" = \
			"reference-transaction"
		test "$(git config --local hook.git-hooks-ext.command)" = \
			"git-hooks-ext reference-transaction"
	)
}

test_install_accepts_local_scope() {
	create_repo

	(
		cd "$repo"
		"$bin" install --local
		test "$(git config --local hook.git-hooks-ext.event)" = \
			"reference-transaction"
	)
}

test_install_rejects_bad_args() {
	create_repo

	(
		cd "$repo"
		assert_fails "$bin" install --bad >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		assert_fails "$bin" install --local extra >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
	)
}

test_install_returns_first_config_failure() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
exit 9
SH

	(
		cd "$repo"
		assert_fails env PATH="$fakebin:$PATH" "$bin" install
	)
}

test_legacy_creates_hooks_directory() {
	create_repo
	(
		cd "$repo"
		git config core.hooksPath new-hooks
		"$bin" install --legacy
		test -x new-hooks/reference-transaction
	)
}

test_legacy_reports_directory_creation_error() {
	create_repo
	(
		cd "$repo"
		hooks_dir="$TEST_DIR/missing-parent/hooks"
		git config core.hooksPath "$hooks_dir"
		assert_exit_code 1 "$bin" install --legacy >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		case "$(cat "$TEST_DIR/err")" in
			"$hooks_dir":*) ;;
			*) return 1 ;;
		esac
		test ! -e "$hooks_dir/reference-transaction"
	)
}

test_empty_hooks_path_uses_current_directory() {
	create_repo
	(
		cd "$repo"
		git config core.hooksPath ""
		"$bin" install --legacy
		test -x reference-transaction
		test ! -e .git/hooks/reference-transaction
	)
}

test_legacy_install_fails_without_git_hooks_dir() {
	repo="$TEST_DIR/repo"
	mkdir -p "$repo/.git"
	touch "$repo/.git/hooks"

	(
		cd "$repo"
		assert_fails "$bin" install --legacy >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	)
}

register_install_tests() {
	test_expect_success "installs config-based bridge" test_install_writes_config_based_bridge
	test_expect_success "installs config bridge with explicit scope" test_install_accepts_local_scope
	test_expect_success "rejects bad install args" test_install_rejects_bad_args
	test_expect_success "returns first install config failure" test_install_returns_first_config_failure
	test_expect_success "creates a missing hooks directory" test_legacy_creates_hooks_directory
	test_expect_success "reports directory creation errors before writing a hook" test_legacy_reports_directory_creation_error
	test_expect_success "empty hooks path uses the current directory" test_empty_hooks_path_uses_current_directory
	test_expect_success "legacy install reports invalid hooks dir" test_legacy_install_fails_without_git_hooks_dir
}
