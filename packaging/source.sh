#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/packaging/common.sh"
package_version
dist=${DIST_DIR:-$root/dist}
mkdir -p "$dist"
dist=$(CDPATH= cd "$dist" && pwd)
archive="$dist/git-hooks-ext-$version.tar.gz"
tar -czf "$archive" --exclude=.build -C "$root" \
	Makefile VERSION README.md LICENSE COPYRIGHT src tests packaging .containerignore
printf '%s\n' "$archive"
