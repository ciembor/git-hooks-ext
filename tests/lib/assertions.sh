assert_file_equals() {
	expected=$1
	actual_file=$2

	printf '%s\n' "$expected" >"$TEST_DIR/expected"
	diff -u "$TEST_DIR/expected" "$actual_file"
}

assert_ref_event() {
	input=$1
	expected=$2

	printf '%s\n' "$input" |
		"$bin" reference-transaction committed --dry-run >"$TEST_DIR/out"
	assert_file_equals "$expected" "$TEST_DIR/out"
}

assert_has_line() {
	expected=$1
	file=$2

	grep -qx "$expected" "$file"
}

assert_fails() {
	if "$@" 2>"$TEST_DIR/command.err"; then
		cat "$TEST_DIR/command.err" >&2
		printf 'expected failure:'
		printf ' %s' "$@"
		printf '\n'
		return 1
	fi
	cat "$TEST_DIR/command.err" >&2
	assert_no_sanitizer_errors "$TEST_DIR/command.err"
}

assert_no_sanitizer_errors() {
	if grep -Eq 'AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:' "$1"; then
		printf 'sanitizer failure is not an expected command error\n' >&2
		return 1
	fi
}

assert_exit_code() {
	assert_exit_expected=$1
	shift
	assert_exit_actual=0
	"$@" 2>"$TEST_DIR/command.err" || assert_exit_actual=$?
	cat "$TEST_DIR/command.err" >&2
	assert_no_sanitizer_errors "$TEST_DIR/command.err"
	test "$assert_exit_actual" -eq "$assert_exit_expected"
}
