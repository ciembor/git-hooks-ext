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

# Installs using the automatic compatibility path without depending on the
# version of Git that runs the test suite.
with_legacy_git() {
	legacy_git=$(command -v git)
	legacy_bin="$TEST_DIR/legacy-git-bin"
	mkdir -p "$legacy_bin"
	cat >"$legacy_bin/git" <<SH
#!/bin/sh
if test "\${1:-}" = --version; then
	printf '%s\\n' 'git version 2.53.0'
	exit 0
fi
exec "$legacy_git" "\$@"
SH
	chmod +x "$legacy_bin/git"
	PATH="$legacy_bin:$PATH" "$@"
}

install_legacy_bridge() {
	with_legacy_git "$bin" install "$@"
}

install_config_bridge() {
	config_git=$(command -v git)
	config_bin="$TEST_DIR/config-git-bin"
	mkdir -p "$config_bin"
	cat >"$config_bin/git" <<SH
#!/bin/sh
if test "\${1:-}" = --version; then
	printf '%s\\n' 'git version 2.54.0'
	exit 0
fi
exec "$config_git" "\$@"
SH
	chmod +x "$config_bin/git"
	PATH="$config_bin:$PATH" "$bin" install "$@"
}

coverage_only() {
	test "${GIT_HOOKS_EXT_COVERAGE:-0}" = 1
}
