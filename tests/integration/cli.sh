test_events_command_lists_supported_events() {
	"$bin" events >"$TEST_DIR/events"
	assert_has_line branch-created "$TEST_DIR/events"
	assert_has_line remote-branch-created "$TEST_DIR/events"
	assert_has_line stash-created "$TEST_DIR/events"
	assert_has_line note-updated "$TEST_DIR/events"
	assert_has_line tag-renamed "$TEST_DIR/events"
	assert_has_line remote-head-created "$TEST_DIR/events"
	assert_has_line replace-updated "$TEST_DIR/events"
	assert_has_line prefetch-deleted "$TEST_DIR/events"
	assert_has_line bisect-ref-created "$TEST_DIR/events"
	assert_has_line rewritten-ref-updated "$TEST_DIR/events"
	assert_has_line worktree-ref-deleted "$TEST_DIR/events"
	assert_has_line head-attached "$TEST_DIR/events"
	assert_has_line head-detached "$TEST_DIR/events"
	assert_has_line head-switched "$TEST_DIR/events"
	assert_has_line root-ref-created "$TEST_DIR/events"
	assert_has_line ref-updated "$TEST_DIR/events"
	assert_has_line worktree-created "$TEST_DIR/events"
	assert_has_line worktree-repaired "$TEST_DIR/events"
}

test_events_rejects_extra_args() {
	assert_fails "$bin" events extra >"$TEST_DIR/out" 2>"$TEST_DIR/err"
}

test_doctor_reports_repository_compatibility() {
	create_repo

	(
		cd "$repo"
		"$bin" doctor >"$TEST_DIR/doctor"
		grep -Eq '^Git version: +[0-9]' "$TEST_DIR/doctor"
		grep -Eq '^Ref backend: +(files|reftable|unknown)$' "$TEST_DIR/doctor"
		grep -Eq '^Config-based hooks: +(supported|not supported)$' "$TEST_DIR/doctor"
		grep -Eq '^Bridge installed: +(yes \((config-based|legacy)\)|no)$' "$TEST_DIR/doctor"
		grep -Eq '^branch-created +supported$' "$TEST_DIR/doctor"
		grep -Eq '^branch-renamed +affected by Git bug$' "$TEST_DIR/doctor"
	)
}

test_doctor_requires_a_repository() {
	(
		cd "$TEST_DIR"
		assert_fails "$bin" doctor >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	)
}

test_doctor_reports_version_specific_compatibility() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
case "$1 $2" in
  "--version ") printf '%s\n' "git version $DOCTOR_GIT_VERSION" ;;
  "rev-parse --git-dir") printf '%s\n' .git ;;
  "rev-parse --git-path") printf '%s\n' .git/hooks ;;
  "rev-parse --show-ref-format") printf '%s\n' reftable ;;
  "config --get")
    case "$3" in
      hook.git-hooks-ext.event) printf '%s\n' reference-transaction ;;
      hook.git-hooks-ext.command) printf '%s\n' 'git-hooks-ext reference-transaction' ;;
      *) exit 1 ;;
    esac ;;
  *) exec /usr/bin/git "$@" ;;
esac
SH

	(
		cd "$repo"
		env PATH="$fakebin:$PATH" DOCTOR_GIT_VERSION=2.27.0 "$bin" doctor >"$TEST_DIR/old-doctor"
		grep -Eq '^branch-created +requires Git 2.28\+$' "$TEST_DIR/old-doctor"
		grep -Eq '^branch-deleted +requires Git 2.28\+$' "$TEST_DIR/old-doctor"
		grep -Eq '^Ref backend: +files$' "$TEST_DIR/old-doctor"

		env PATH="$fakebin:$PATH" DOCTOR_GIT_VERSION=2.28.0 "$bin" doctor >"$TEST_DIR/2.28-doctor"
		grep -Eq '^tag-deleted +supported$' "$TEST_DIR/2.28-doctor"

		env PATH="$fakebin:$PATH" DOCTOR_GIT_VERSION=2.54.0 "$bin" doctor >"$TEST_DIR/new-doctor"
		grep -Eq '^Ref backend: +reftable$' "$TEST_DIR/new-doctor"
		grep -Eq '^Config-based hooks: +supported$' "$TEST_DIR/new-doctor"
		grep -Eq '^Bridge installed: +yes \(config-based\)$' "$TEST_DIR/new-doctor"
		grep -Eq '^remote-branch-renamed +requires Git 2.55\+$' "$TEST_DIR/new-doctor"

		env PATH="$fakebin:$PATH" DOCTOR_GIT_VERSION=3.0.0 "$bin" doctor >"$TEST_DIR/major-doctor"
		grep -Eq '^remote-branch-renamed +supported$' "$TEST_DIR/major-doctor"
	)
}

test_doctor_handles_an_unavailable_ref_backend() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
case "$1 $2" in
  "rev-parse --git-dir") printf '%s\n' .git ;;
  "--version ") printf '%s\n' 'git version 2.54.0' ;;
  "rev-parse --show-ref-format") exit 1 ;;
  "rev-parse --git-path") printf '%s\n' .git/hooks/reference-transaction ;;
  "config --get") exit 1 ;;
  *) exec /usr/bin/git "$@" ;;
esac
SH
	(
		cd "$repo"
		env PATH="$fakebin:$PATH" "$bin" doctor >"$TEST_DIR/doctor"
		grep -Eq '^Ref backend: +unknown$' "$TEST_DIR/doctor"
	)
}

test_doctor_rejects_an_unreadable_git_version() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2" = "rev-parse --git-dir"; then
	printf '%s\n' .git
	exit 0
fi
if test "$1" = --version; then
	printf '%s\n' 'unknown version'
	exit 0
fi
exec /usr/bin/git "$@"
SH

	(
		cd "$repo"
		assert_fails env PATH="$fakebin:$PATH" "$bin" doctor >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		grep -Fqx 'git-hooks-ext: failed to determine the Git version' "$TEST_DIR/command.err"
	)
}

test_doctor_reports_unknown_legacy_bridge_path() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
case "$1 $2" in
  "rev-parse --git-dir") printf '%s\n' .git ;;
  "--version ") printf '%s\n' 'git version 2.54.0' ;;
  "rev-parse --show-ref-format") printf '%s\n' files ;;
  "rev-parse --git-path") exit 1 ;;
  "config --get") exit 1 ;;
  *) exec /usr/bin/git "$@" ;;
esac
SH
	(
		cd "$repo"
		env PATH="$fakebin:$PATH" "$bin" doctor >"$TEST_DIR/doctor"
		grep -Eq '^Legacy bridge: +unknown$' "$TEST_DIR/doctor"
	)
}

test_doctor_handles_a_malformed_version_from_the_compatibility_probe() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2" = "rev-parse --git-dir"; then
	printf '%s\n' .git
	exit 0
fi
if test "$1" = --version; then
	if test -e "$DOCTOR_VERSION_PROBED"; then
		printf '%s\n' 'malformed version'
	else
		touch "$DOCTOR_VERSION_PROBED"
		printf '%s\n' 'git version 2.54.0'
	fi
	exit 0
fi
exec /usr/bin/git "$@"
SH

	(
		cd "$repo"
		env PATH="$fakebin:$PATH" DOCTOR_VERSION_PROBED="$TEST_DIR/version-probed" \
			"$bin" doctor >"$TEST_DIR/doctor"
		grep -Eq '^Config-based hooks: +not supported$' "$TEST_DIR/doctor"
	)
}

test_doctor_reports_an_installed_legacy_bridge() {
	create_repo
	(
		cd "$repo"
		install_legacy_bridge
		with_legacy_git "$bin" doctor >"$TEST_DIR/doctor"
		grep -Eq '^Bridge installed: +yes \(legacy\)$' "$TEST_DIR/doctor"
		grep -Eq '^Legacy bridge: +yes$' "$TEST_DIR/doctor"
	)
}

test_add_writes_config_based_hook() {
	create_repo

	(
		cd "$repo"
		"$bin" add branch-created create-env ./scripts/create-env --verbose
		test "$(git config --local hook.create-env.event)" = \
			"branch-created"
		test "$(git config --local hook.create-env.command)" = \
			"'./scripts/create-env' '--verbose'"
	)
}

test_add_accepts_scope() {
	create_repo

	(
		cd "$repo"
		"$bin" add --local tag-created tag-env ./scripts/tag-env
		test "$(git config --local hook.tag-env.event)" = \
			"tag-created"
		test "$(git config --local hook.tag-env.command)" = \
			"'./scripts/tag-env'"
	)
}

test_add_quotes_command_arguments() {
	create_repo

	(
		cd "$repo"
		"$bin" add branch-created quoted "./script with space" "it's ok"
		test "$(git config --local hook.quoted.command)" = \
			"'./script with space' 'it'\\''s ok'"
	)
}

test_add_command_roundtrips_special_arguments() {
	create_repo
	(
		cd "$repo"
		quote_arg="''''''''''''''''"
		literal_arg='$(touch unexpected)'
		"$bin" add branch-created quoted /bin/sh -c 'printf "%s\n" "$@"' sh \
			"" "$quote_arg" "$literal_arg" 'with spaces'
		command=$(git config --local hook.quoted.command)
		/bin/sh -c "$command" >"$TEST_DIR/out"
		assert_file_equals "
$quote_arg
$literal_arg
with spaces" "$TEST_DIR/out"
		test ! -e unexpected
	)
}

test_list_show_and_remove_configured_hooks() {
	create_repo

	(
		cd "$repo"
		"$bin" add branch-created notify-branch ./notify
		"$bin" add branch-deleted cleanup ./cleanup --stale
		"$bin" list >"$TEST_DIR/list"
		grep -Eq '^NAME +EVENT +COMMAND$' "$TEST_DIR/list"
		grep -Eq '^notify-branch +branch-created +[[:print:]]*notify' "$TEST_DIR/list"
		grep -Eq '^cleanup +branch-deleted +[[:print:]]*cleanup.*--stale' "$TEST_DIR/list"
		"$bin" show notify-branch >"$TEST_DIR/show"
		grep -Eq '^notify-branch +branch-created +[[:print:]]*notify' "$TEST_DIR/show"
		"$bin" remove notify-branch
		! git config --local --get hook.notify-branch.event
		! git config --local --get hook.notify-branch.command
		"$bin" list >"$TEST_DIR/after-remove"
		! grep -F notify-branch "$TEST_DIR/after-remove"
	)
}

test_list_handles_empty_configuration_and_hides_bridge() {
	create_repo

	(
		cd "$repo"
		install_config_bridge
		"$bin" list >"$TEST_DIR/list"
		assert_file_equals "NAME                 EVENT              COMMAND" "$TEST_DIR/list"
	)
}

test_list_ignores_malformed_final_config_line() {
	create_repo
	create_fake_git <<'SH'
#!/bin/sh
if test "$1 $2 $3" = "config --local --get-regexp"; then
		printf '%s' 'hook..event branch-created'
		exit 0
fi
exec /usr/bin/git "$@"
SH
	(
		cd "$repo"
		env PATH="$fakebin:$PATH" "$bin" list >"$TEST_DIR/list"
		assert_file_equals "NAME                 EVENT              COMMAND" "$TEST_DIR/list"
	)
}

test_remove_cleans_partial_hook_configuration() {
	create_repo

	(
		cd "$repo"
		git config --local hook.partial.event branch-created
		"$bin" list >"$TEST_DIR/list"
		grep -Eq '^partial +branch-created +<missing command>$' "$TEST_DIR/list"
		"$bin" show partial >"$TEST_DIR/show"
		grep -Eq '^partial +branch-created +<missing command>$' "$TEST_DIR/show"
		"$bin" remove partial
		! git config --local --get hook.partial.event

		git config --local hook.orphan.command ./orphan
		"$bin" remove orphan
		! git config --local --get hook.orphan.command
	)
}

test_hook_configuration_commands_support_global_scope() {
	create_repo
	global_config="$TEST_DIR/global.gitconfig"

	(
		cd "$repo"
		env GIT_CONFIG_GLOBAL="$global_config" GIT_CONFIG_NOSYSTEM=1 \
			"$bin" add --global branch-created global-hook ./global-command
		env GIT_CONFIG_GLOBAL="$global_config" GIT_CONFIG_NOSYSTEM=1 \
			"$bin" list --global >"$TEST_DIR/global-list"
		grep -Eq '^global-hook +branch-created +[[:print:]]*global-command' "$TEST_DIR/global-list"
		env GIT_CONFIG_GLOBAL="$global_config" GIT_CONFIG_NOSYSTEM=1 \
			"$bin" show --global global-hook >"$TEST_DIR/global-show"
		grep -Eq '^global-hook +branch-created +[[:print:]]*global-command' "$TEST_DIR/global-show"
		env GIT_CONFIG_GLOBAL="$global_config" GIT_CONFIG_NOSYSTEM=1 \
			"$bin" remove --global global-hook
		! git config --file "$global_config" --get hook.global-hook.event
	)
}

test_hook_configuration_commands_protect_bridge_and_require_repository() {
	create_repo

	(
		cd "$repo"
		assert_exit_code 2 "$bin" show git-hooks-ext >"$TEST_DIR/out0" 2>"$TEST_DIR/err0"
		assert_exit_code 2 "$bin" remove git-hooks-ext >"$TEST_DIR/out1" 2>"$TEST_DIR/err1"
	)
	(
		cd "$TEST_DIR"
		assert_fails "$bin" list >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
		assert_fails "$bin" show missing >"$TEST_DIR/out3" 2>"$TEST_DIR/err3"
		assert_fails "$bin" remove missing >"$TEST_DIR/out4" 2>"$TEST_DIR/err4"
	)
}

test_list_and_show_preserve_quoted_commands() {
	create_repo

	(
		cd "$repo"
		"$bin" add branch-created quoted "./command with space" "it's quoted"
		"$bin" list >"$TEST_DIR/list"
		"$bin" show quoted >"$TEST_DIR/show"
		grep -Fq "'./command with space' 'it'\\''s quoted'" "$TEST_DIR/list"
		grep -Fq "'./command with space' 'it'\\''s quoted'" "$TEST_DIR/show"
	)
}

test_hook_configuration_commands_reject_invalid_arguments() {
	create_repo

	(
		cd "$repo"
		assert_exit_code 2 "$bin" list extra >"$TEST_DIR/out0" 2>"$TEST_DIR/err0"
		assert_exit_code 2 "$bin" show >"$TEST_DIR/out1" 2>"$TEST_DIR/err1"
		assert_exit_code 2 "$bin" remove one two >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
		assert_exit_code 2 "$bin" uninstall --bad >"$TEST_DIR/out3" 2>"$TEST_DIR/err3"
		assert_exit_code 2 "$bin" doctor extra >"$TEST_DIR/out4" 2>"$TEST_DIR/err4"
		assert_fails "$bin" show missing >"$TEST_DIR/out5" 2>"$TEST_DIR/err5"
		assert_fails "$bin" remove missing >"$TEST_DIR/out6" 2>"$TEST_DIR/err6"
	)
}

test_add_rejects_bad_args() {
	create_repo

	(
		cd "$repo"
		assert_exit_code 2 "$bin" add >"$TEST_DIR/out0" 2>"$TEST_DIR/err0"
		assert_exit_code 2 "$bin" add --local >"$TEST_DIR/out1" 2>"$TEST_DIR/err1"
		assert_fails "$bin" add branch-created only-name >"$TEST_DIR/out" 2>"$TEST_DIR/err"
		assert_fails "$bin" add unknown-event name ./cmd >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
		assert_fails "$bin" add git-hooks-ext-branch-created name ./cmd >"$TEST_DIR/out3" 2>"$TEST_DIR/err3"
		git config --local --get-regexp '^hook\.' >"$TEST_DIR/hooks" && return 1
		test ! -s "$TEST_DIR/hooks"
	)
}

test_main_rejects_bad_args() {
	assert_fails "$bin" >"$TEST_DIR/out" 2>"$TEST_DIR/err"
	assert_fails "$bin" wat >"$TEST_DIR/out2" 2>"$TEST_DIR/err2"
}

test_version_command() {
	"$bin" --version >"$TEST_DIR/version"
	assert_file_equals "git-hooks-ext $(cat "$project_root/VERSION")" "$TEST_DIR/version"
	assert_exit_code 2 "$bin" --version extra >"$TEST_DIR/out" 2>"$TEST_DIR/err"
}

register_cli_tests() {
	test_expect_success "reports the package version" test_version_command
	test_expect_success "lists supported events" test_events_command_lists_supported_events
	test_expect_success "rejects bad events args" test_events_rejects_extra_args
	test_expect_success "reports repository compatibility" test_doctor_reports_repository_compatibility
	test_expect_success "requires a repository for doctor" test_doctor_requires_a_repository
	test_expect_success "reports version-specific doctor compatibility" test_doctor_reports_version_specific_compatibility
	test_expect_success "rejects an unreadable Git version in doctor" test_doctor_rejects_an_unreadable_git_version
	test_expect_success "reports an unknown legacy bridge path" test_doctor_reports_unknown_legacy_bridge_path
	test_expect_success "handles an unavailable ref backend" test_doctor_handles_an_unavailable_ref_backend
	test_expect_success "handles a malformed compatibility-probe version" test_doctor_handles_a_malformed_version_from_the_compatibility_probe
	test_expect_success "reports an installed legacy bridge" test_doctor_reports_an_installed_legacy_bridge
	test_expect_success "adds config-based hook" test_add_writes_config_based_hook
	test_expect_success "adds config-based hook with explicit scope" test_add_accepts_scope
	test_expect_success "quotes added hook command" test_add_quotes_command_arguments
	test_expect_success "roundtrips empty, quoted and literal shell arguments" test_add_command_roundtrips_special_arguments
	test_expect_success "lists, shows and removes configured hooks" test_list_show_and_remove_configured_hooks
	test_expect_success "lists an empty configuration without the bridge" test_list_handles_empty_configuration_and_hides_bridge
	test_expect_success "ignores a malformed final config line" test_list_ignores_malformed_final_config_line
	test_expect_success "removes partial hook configuration" test_remove_cleans_partial_hook_configuration
	test_expect_success "manages hooks in global configuration" test_hook_configuration_commands_support_global_scope
	test_expect_success "protects the bridge and requires a repository" test_hook_configuration_commands_protect_bridge_and_require_repository
	test_expect_success "preserves quoted commands in list and show" test_list_and_show_preserve_quoted_commands
	test_expect_success "rejects invalid hook configuration commands" test_hook_configuration_commands_reject_invalid_arguments
	test_expect_success "rejects bad add args" test_add_rejects_bad_args
	test_expect_success "rejects bad top-level args" test_main_rejects_bad_args
}
