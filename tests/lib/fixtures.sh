zero=0000000000000000000000000000000000000000
one=1111111111111111111111111111111111111111
two=2222222222222222222222222222222222222222

create_repo() {
	repo="$TEST_DIR/repo"
	git init -q "$@" "$repo"
}

# Reads the fake executable from stdin; tests control its behavior.
create_fake_git() {
	fakebin="$TEST_DIR/bin"
	mkdir -p "$fakebin"
	cat >"$fakebin/git"
	chmod +x "$fakebin/git"
}

coverage_only() {
	test "${GIT_HOOKS_EXT_COVERAGE:-0}" = 1
}
