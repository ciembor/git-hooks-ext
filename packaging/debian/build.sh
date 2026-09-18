#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
. "$root/packaging/common.sh"
package_version
for tool in dpkg-deb dpkg-shlibdeps dpkg-buildflags; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'Debian build tools required; on macOS use make test-package-apt.\n' >&2
		exit 1
	}
done
dpkg --validate-version "$version-1"
DIST_DIR=${DIST_DIR:-$root/dist/debian}
export DIST_DIR
archive=$(sh "$root/packaging/source.sh")
dist=$(dirname "$archive")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
stage="$work/package"
arch=$(dpkg --print-architecture)
maintainer=${DEB_MAINTAINER:-Local package builder <root@localhost>}
case "$maintainer" in
	*'
'*) printf 'Maintainer must be a single line\n' >&2; exit 1 ;;
esac
mkdir -p "$stage/DEBIAN" "$stage/usr/share/doc/git-hooks-ext" "$work/debian"
make -C "$root" BIN="$work/git-hooks-ext" \
	CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS)" \
	CFLAGS="-std=c99 -Wall -Wextra -Werror -pedantic $(dpkg-buildflags --get CFLAGS)" \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"
make -C "$root" install BIN="$work/git-hooks-ext" PREFIX=/usr DESTDIR="$stage"
strip --strip-unneeded "$stage/usr/bin/git-hooks-ext"
cat "$root/COPYRIGHT" "$root/LICENSE" >"$stage/usr/share/doc/git-hooks-ext/copyright"
gzip -n -c "$root/README.md" >"$stage/usr/share/doc/git-hooks-ext/README.md.gz"
printf 'Source: git-hooks-ext\nMaintainer: %s\n\nPackage: git-hooks-ext\nArchitecture: any\n' \
	"$maintainer" >"$work/debian/control"
dependencies=$(cd "$work" && dpkg-shlibdeps -O -e"$stage/usr/bin/git-hooks-ext")
dependencies=${dependencies#shlibs:Depends=}
size=$(du -sk "$stage/usr" | awk '{print $1}')
{
	printf 'Package: git-hooks-ext\nVersion: %s-1\nArchitecture: %s\n' "$version" "$arch"
	printf 'Maintainer: %s\nSection: vcs\nPriority: optional\n' "$maintainer"
	printf 'Depends: git (>= 2.29), %s\nInstalled-Size: %s\n' "$dependencies" "$size"
	printf 'Description: semantic Git hooks for reference changes\n'
	printf ' Turns reference-transaction input into branch, tag and other ref events.\n'
} >"$stage/DEBIAN/control"
dpkg-deb --root-owner-group --build "$stage" "$dist/git-hooks-ext_${version}-1_${arch}.deb"
