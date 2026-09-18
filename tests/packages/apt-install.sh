#!/bin/sh
set -eu

set -- "${PACKAGE_DIR:-/packages}"/*.deb
test "$#" -eq 1
test -f "$1"
package=$1
version=$(dpkg-deb -f "$package" Version)
test "$(dpkg-deb -f "$package" Architecture)" = "$(dpkg --print-architecture)"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y "$package"
test "$(dpkg-query -W -f='${Status}' git-hooks-ext)" = 'install ok installed'
test "$(dpkg-query -W -f='${Version}' git-hooks-ext)" = "$version"
test -s /usr/share/doc/git-hooks-ext/copyright
/bin/sh /checks/smoke.sh /usr/bin/git-hooks-ext "${version%-1}"
apt-get purge -y git-hooks-ext
test ! -e /usr/bin/git-hooks-ext
if dpkg-query -W git-hooks-ext >/dev/null 2>&1; then
	printf 'Package still present after purge\n' >&2
	exit 1
fi
printf 'APT install, hook execution and uninstall passed.\n'
