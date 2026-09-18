test_failure_followed_by_success() {
	false
	printf 'failure was ignored\n' >"$TEST_DIR/sentinel"
}

test_harness_stops_at_first_failure() {
	assert_fails "$runner" --run-test test_failure_followed_by_success "$TEST_DIR"
	test ! -e "$TEST_DIR/sentinel"
}

test_skip_followed_by_success() {
	test_skip "intentional harness skip"
	printf 'skip was ignored\n' >"$TEST_DIR/skip-sentinel"
}

test_harness_skip_stops_execution() {
	child_status=0
	"$runner" --run-test test_skip_followed_by_success "$TEST_DIR" || child_status=$?
	test "$child_status" -eq 77
	assert_has_line "intentional harness skip" "$TEST_DIR/skip-reason"
	test ! -e "$TEST_DIR/skip-sentinel"
}

test_sanitizer_followed_by_success() {
	assert_fails /bin/sh -c 'printf "AddressSanitizer: simulated failure\\n" >&2; exit 1'
	printf 'sanitizer was ignored\n' >"$TEST_DIR/sanitizer-sentinel"
}

test_harness_rejects_sanitizer_failure() {
	child_status=0
	"$runner" --run-test test_sanitizer_followed_by_success "$TEST_DIR" \
		2>"$TEST_DIR/sanitizer.err" || child_status=$?
	test "$child_status" -ne 0
	assert_has_line "sanitizer failure is not an expected command error" "$TEST_DIR/sanitizer.err"
	test ! -e "$TEST_DIR/sanitizer-sentinel"
}

test_unexpected_exit_77() {
	exit 77
}

test_harness_unexpected_exit_is_failure() {
	(
		tmp="$TEST_DIR/nested"
		mkdir -p "$tmp"
		test_count=0
		failed=0
		skipped=0
		test_expect_success "unexpected exit 77" test_unexpected_exit_77 >"$TEST_DIR/nested.out"
		test "$failed" -eq 1
		test "$skipped" -eq 0
		assert_has_line "not ok 1 - unexpected exit 77" "$TEST_DIR/nested.out"
		if test_finish >>"$TEST_DIR/nested.out"; then
			return 1
		fi
	)
}

register_harness_tests() {
	test_expect_success "harness stops at the first failed assertion" test_harness_stops_at_first_failure
	test_expect_success "harness skip stops test execution" test_harness_skip_stops_execution
	test_expect_success "harness rejects sanitizer failures" test_harness_rejects_sanitizer_failure
	test_expect_success "harness does not treat an unexpected exit 77 as a skip" test_harness_unexpected_exit_is_failure
}
