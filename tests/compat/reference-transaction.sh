#!/bin/sh
set -eu

git_bin=${1:-git}
ref_format=${2:-files}
root=$(mktemp -d "${TMPDIR:-/tmp}/git-hooks-ext-compat.XXXXXX")
trap 'rm -rf "$root"' EXIT

case "$git_bin" in
*/*)
	git_dir=$(CDPATH= cd "$(dirname "$git_bin")" && pwd)
	git_bin="$git_dir/$(basename "$git_bin")"
	GIT_EXEC_PATH=$git_dir
	PATH="$git_dir:$PATH"
	export GIT_EXEC_PATH PATH
	;;
esac
version=$($git_bin version | sed 's/^git version //')

run_case() {
	name=$1
	repo="$root/$name"
	log="$root/$name.log"

	if test "$ref_format" = files; then
		init_args=
	else
		init_args="--ref-format=$ref_format"
	fi
	if ! "$git_bin" init -q $init_args "$repo" 2>/dev/null; then
		printf '%s\t%s\t%s\tunsupported\tunsupported\t-\n' \
			"$version" "$ref_format" "$name"
		return
	fi
	(
		cd "$repo"
		"$git_bin" config user.name Compatibility
		"$git_bin" config user.email compatibility@example.com
		"$git_bin" commit --allow-empty -qm initial
		case "$name" in
		branch-delete) "$git_bin" branch topic ;;
		branch-rename) "$git_bin" branch old ;;
		tag-delete) "$git_bin" tag v1 ;;
		update-ref-delete) "$git_bin" branch topic ;;
		esac
		mkdir -p .git/hooks
		cat >.git/hooks/reference-transaction <<'SH'
#!/bin/sh
test "$1" = committed || exit 0
cat >>"$GHE_COMPAT_LOG"
SH
		chmod +x .git/hooks/reference-transaction
		export GHE_COMPAT_LOG="$log"
		case "$name" in
		branch-create) "$git_bin" branch topic ;;
		branch-delete) "$git_bin" branch -D topic >/dev/null ;;
		branch-rename) "$git_bin" branch -m old new ;;
		tag-create) "$git_bin" tag v1 ;;
		tag-delete) "$git_bin" tag -d v1 >/dev/null ;;
		update-ref-delete)
			oid=$("$git_bin" rev-parse refs/heads/topic)
			"$git_bin" update-ref -d refs/heads/topic "$oid"
			;;
		esac
	)
	if test -s "$log"; then
		refs=$(awk '
			function value_kind(value) { return value ~ /^0+$/ ? "zero" : "oid" }
			{ values = values separator $3 ":" value_kind($1) "->" value_kind($2); separator = "," }
			END { print values }
		' "$log")
		case "$name" in
		branch-create)
			awk '$3 == "refs/heads/topic" && $1 ~ /^0+$/ && $2 !~ /^0+$/' "$log" | grep -q .
			;;
		branch-delete|update-ref-delete)
			awk '$3 == "refs/heads/topic" && $1 !~ /^0+$/ && $2 ~ /^0+$/' "$log" | grep -q .
			;;
		branch-rename)
			awk '$3 == "refs/heads/old" && $1 !~ /^0+$/ && $2 ~ /^0+$/' "$log" | grep -q . &&
				awk '$3 == "refs/heads/new" && $1 ~ /^0+$/ && $2 !~ /^0+$/' "$log" | grep -q .
			;;
		tag-create)
			awk '$3 == "refs/tags/v1" && $1 ~ /^0+$/ && $2 !~ /^0+$/' "$log" | grep -q .
			;;
		tag-delete)
			awk '$3 == "refs/tags/v1" && $1 !~ /^0+$/ && $2 ~ /^0+$/' "$log" | grep -q .
			;;
		esac && usable=yes || usable=no
		printf '%s\t%s\t%s\tyes\t%s\t%s\n' \
			"$version" "$ref_format" "$name" "$usable" "$refs"
	else
		printf '%s\t%s\t%s\tno\tno\t-\n' "$version" "$ref_format" "$name"
	fi
}

printf 'git_version\tref_format\toperation\thook_called\tusable_update\trefs\n'
for operation in branch-create branch-delete branch-rename tag-create tag-delete \
	update-ref-delete; do
	run_case "$operation"
done
