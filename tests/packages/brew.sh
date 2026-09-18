#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
test "$(uname -s)" = Darwin || {
	printf 'Homebrew installation test must run locally on macOS.\n' >&2
	exit 1
}
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
prefix=$(brew --prefix)
if brew list --versions git-hooks-ext >/dev/null 2>&1 || \
	test -e "$prefix/bin/git-hooks-ext" || test -L "$prefix/bin/git-hooks-ext"; then
	printf 'Refusing to replace an existing git-hooks-ext installation.\n' >&2
	exit 1
fi
sh "$root/packaging/homebrew/build.sh"
dist=${DIST_DIR:-$root/dist}
dist=$(CDPATH= cd "$dist" && pwd)
tap="git-hooks-ext/package-test-$$"
formula="$tap/git-hooks-ext"
tap_owned=0
install_owned=0
cleanup() {
	status=$?
	trap - EXIT
	if test "$install_owned" -eq 1 && brew list --versions git-hooks-ext >/dev/null 2>&1; then
		brew uninstall --force "$formula" || status=1
	fi
	if test "$tap_owned" -eq 1; then
		brew untap "$tap" || status=1
	fi
	exit "$status"
}
trap cleanup EXIT
brew tap --custom-remote "$tap" "$dist/homebrew-git-hooks-ext"
tap_owned=1
if brew help trust >/dev/null 2>&1; then
	brew trust --formula "$formula"
fi
install_owned=1
brew install --build-from-source "$formula"
brew test "$formula"
sh "$root/tests/packages/smoke.sh" "$prefix/bin/git-hooks-ext" "$(cat "$root/VERSION")"
brew uninstall "$formula"
install_owned=0
test ! -e "$prefix/bin/git-hooks-ext"
test ! -L "$prefix/bin/git-hooks-ext"
brew untap "$tap"
tap_owned=0
printf 'Homebrew install, formula test, hook execution and uninstall passed.\n'
