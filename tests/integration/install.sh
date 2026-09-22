test_install_writes_config_based_bridge() {
	create_repo

	(
		cd "$repo"
		install_config_bridge
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
		install_config_bridge --local
		test "$(git config --local hook.git-hooks-ext.event)" = \
			"reference-transaction"
	)
}

test_uninstall_removes_config_based_bridge() {
	create_repo

	(
		cd "$repo"
		install_config_bridge
		"$bin" uninstall
		! git config --local --get hook.git-hooks-ext.event
		! git config --local --get hook.git-hooks-ext.command
	)
}

test_uninstall_removes_owned_legacy_bridge() {
	create_repo

	(
		cd "$repo"
		install_legacy_bridge
		test -e .git/hooks/reference-transaction
		"$bin" uninstall
		test ! -e .git/hooks/reference-transaction
	)
}

test_uninstall_preserves_unrecognized_legacy_hook() {
	create_repo

	(
		cd "$repo"
		printf '%s\n' '#!/bin/sh' 'exit 0' >.git/hooks/reference-transaction
		chmod +x .git/hooks/reference-transaction
		"$bin" uninstall
		test -x .git/hooks/reference-transaction
	)
}

test_install_rejects_bad_args() {
	create_repo

	(
		cd "$repo"
		assert_fails "$bin" install --bad >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		assert_fails "$bin" install --legacy >"$TEST_DIR/legacy-out" 2>"$TEST_DIR/legacy-err"
		assert_fails "$bin" install --local extra >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
	)
}

test_install_returns_first_config_failure() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1" = --version; then
	printf '%s\n' 'git version 2.54.0'
	exit 0
fi
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
		install_legacy_bridge
		test -x new-hooks/reference-transaction
	)
}

test_legacy_install_explains_upgrade() {
	create_repo

	(
		cd "$repo"
		install_legacy_bridge >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		grep -Fqx "git-hooks-ext: legacy hook bridge installed. After upgrading to Git 2.54 or later, remove this reference-transaction hook and run 'git-hooks-ext install' again." "$TEST_DIR/err"
	)
}

test_legacy_install_rejects_nonlocal_scope() {
	create_repo

	(
		cd "$repo"
		assert_exit_code 2 with_legacy_git "$bin" install --global >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		test ! -e .git/hooks/reference-transaction
	)
}

test_legacy_reports_directory_creation_error() {
	create_repo
	(
		cd "$repo"
		hooks_dir="$TEST_DIR/missing-parent/hooks"
		git config core.hooksPath "$hooks_dir"
		assert_exit_code 1 install_legacy_bridge >"$TEST_DIR/out" 2>"$TEST_DIR/err"
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
		install_legacy_bridge
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
		assert_fails install_legacy_bridge >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	)
}

register_install_tests() {
	test_expect_success "installs config-based bridge" test_install_writes_config_based_bridge
	test_expect_success "installs config bridge with explicit scope" test_install_accepts_local_scope
	test_expect_success "uninstalls config-based bridge" test_uninstall_removes_config_based_bridge
	test_expect_success "uninstalls its legacy bridge" test_uninstall_removes_owned_legacy_bridge
	test_expect_success "preserves an unrecognized legacy hook" test_uninstall_preserves_unrecognized_legacy_hook
	test_expect_success "rejects bad install args" test_install_rejects_bad_args
	test_expect_success "returns first install config failure" test_install_returns_first_config_failure
	test_expect_success "creates a missing hooks directory" test_legacy_creates_hooks_directory
	test_expect_success "legacy install explains the Git upgrade migration" test_legacy_install_explains_upgrade
	test_expect_success "legacy install rejects nonlocal scope" test_legacy_install_rejects_nonlocal_scope
	test_expect_success "reports directory creation errors before writing a hook" test_legacy_reports_directory_creation_error
	test_expect_success "empty hooks path uses the current directory" test_empty_hooks_path_uses_current_directory
	test_expect_success "legacy install reports invalid hooks dir" test_legacy_install_fails_without_git_hooks_dir
}
