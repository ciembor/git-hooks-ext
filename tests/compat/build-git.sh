#!/bin/sh
set -eu

if test "$#" -lt 1 || test "$#" -gt 2; then
	printf 'usage: %s <git-version> [files|reftable]\n' "$0" >&2
	exit 2
fi

version=$1
ref_format=${2:-files}
case "$version" in
*[!0-9.]*|'')
	printf 'invalid Git version: %s\n' "$version" >&2
	exit 2
	;;
esac
case "$ref_format" in
files|reftable) ;;
*)
	printf 'invalid ref format: %s\n' "$ref_format" >&2
	exit 2
	;;
esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
cache=${GHE_COMPAT_CACHE:-${TMPDIR:-/tmp}/git-hooks-ext-git-compat}
archive="$cache/v$version.tar.gz"
source_dir="$cache/git-$version"
jobs=${GHE_COMPAT_JOBS:-4}

mkdir -p "$cache"
if test ! -f "$archive"; then
	curl -fsSL "https://github.com/git/git/archive/refs/tags/v$version.tar.gz" \
		-o "$archive"
fi
if test ! -d "$source_dir"; then
	tar -xzf "$archive" -C "$cache"
fi

platform_flags=
if test "$(uname -s)" = Darwin; then
	platform_flags=APPLE_COMMON_CRYPTO=YesPlease
fi
build_log="$cache/build-$version.log"
if ! make -C "$source_dir" -j"$jobs" \
	NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_CURL=YesPlease \
	NO_EXPAT=YesPlease NO_OPENSSL=YesPlease $platform_flags \
	git git-bisect git-sh-setup git-sh-i18n \
	>"$build_log" 2>&1; then
	cat "$build_log" >&2
	exit 1
fi

exec "$script_dir/reference-transaction.sh" "$source_dir/git" "$ref_format"
