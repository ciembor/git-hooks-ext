#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/packaging/common.sh"
package_version
dist=${DIST_DIR:-$root/dist}
mkdir -p "$dist"
dist=$(CDPATH= cd "$dist" && pwd)
archive="$dist/git-hooks-ext-$version.tar.gz"
tmp_tar="$dist/.git-hooks-ext-$version-$$.tar"
tmp_archive="$archive.tmp.$$"
trap 'rm -f "$tmp_tar" "$tmp_archive"' EXIT
# Keep checksum-bearing release recipes outside the archive to avoid a
# self-referential checksum. They are published as separate release assets.
tar -cf "$tmp_tar" --exclude=.build \
	--exclude=packaging/arch/PKGBUILD \
	--exclude=packaging/alpine/APKBUILD \
	--exclude=packaging/fedora/Containerfile -C "$root" \
	Makefile VERSION README.md LICENSE COPYRIGHT src tests packaging .containerignore
gzip -n -c "$tmp_tar" >"$tmp_archive"
mv "$tmp_archive" "$archive"
printf '%s\n' "$archive"
