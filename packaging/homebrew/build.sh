#!/bin/sh
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
. "$root/packaging/common.sh"
package_version
archive=${SOURCE_ARCHIVE:-$(sh "$root/packaging/source.sh")}
dist=$(dirname "$archive")
tap="$dist/homebrew-git-hooks-ext"
mkdir -p "$tap/Formula"
ruby "$root/packaging/homebrew/render.rb" "$archive" "$version" \
	"$root/packaging/homebrew/git-hooks-ext.rb.erb" "$tap/Formula/git-hooks-ext.rb"
git -C "$tap" init -q
git -C "$tap" add Formula/git-hooks-ext.rb
if ! git -C "$tap" diff --cached --quiet; then
	git -C "$tap" -c user.name='Local package builder' -c user.email=root@localhost \
		commit -qm "Package git-hooks-ext $version"
fi
printf 'Homebrew tap: %s\n' "$tap"
