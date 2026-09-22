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
	test_expect_success "adds config-based hook" test_add_writes_config_based_hook
	test_expect_success "adds config-based hook with explicit scope" test_add_accepts_scope
	test_expect_success "quotes added hook command" test_add_quotes_command_arguments
	test_expect_success "roundtrips empty, quoted and literal shell arguments" test_add_command_roundtrips_special_arguments
	test_expect_success "rejects bad add args" test_add_rejects_bad_args
	test_expect_success "rejects bad top-level args" test_main_rejects_bad_args
}
