test_count=0
failed=0
skipped=0

test_skip() {
	printf '%s\n' "$1" >"$TEST_DIR/skip-reason"
	exit 77
}

test_expect_success() {
	harness_name=$1
	harness_fn=$2
	test_count=$((test_count + 1))
	harness_dir="$tmp/t$test_count"
	mkdir -p "$harness_dir"

	# A fresh shell keeps errexit active inside the test function.
	if "$runner" --run-test "$harness_fn" "$harness_dir"; then
		printf 'ok %d - %s\n' "$test_count" "$harness_name"
	else
		harness_status=$?
		if test "$harness_status" -eq 77 && test -f "$harness_dir/skip-reason"; then
			printf 'ok %d - %s # SKIP %s\n' "$test_count" "$harness_name" \
				"$(cat "$harness_dir/skip-reason")"
			skipped=$((skipped + 1))
		else
			printf 'not ok %d - %s\n' "$test_count" "$harness_name"
			failed=$((failed + 1))
		fi
	fi
}

test_finish() {
	printf '1..%d\n' "$test_count"
	if test "$failed" -ne 0; then
		printf '# failed %d of %d test(s); skipped %d\n' "$failed" "$test_count" "$skipped"
		return 1
	fi
	printf '# passed %d test(s); skipped %d\n' "$((test_count - skipped))" "$skipped"
}
