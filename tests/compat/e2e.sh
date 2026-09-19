#!/bin/sh
set -eu

if test "$#" -ne 4; then
	printf 'usage: %s <git-binary> <git-hooks-ext-binary> <files|reftable> <six-result-csv>\n' "$0" >&2
	exit 2
fi

git_dir=$(CDPATH= cd "$(dirname "$1")" && pwd)
git_bin="$git_dir/$(basename "$1")"
helper_bin=$(CDPATH= cd "$(dirname "$2")" && pwd)/$(basename "$2")
ref_format=$3
expected_csv=$4

test -x "$git_bin" && test -x "$helper_bin"
case "$ref_format" in
files|reftable) ;;
*) exit 2 ;;
esac

old_ifs=$IFS
IFS=,
set -- $expected_csv
IFS=$old_ifs
test "$#" -eq 6 || exit 2
branch_create=$1
branch_delete=$2
branch_rename=$3
tag_create=$4
tag_delete=$5
update_ref_delete=$6

PATH="$git_dir:$PATH"
export PATH
if test -f "$git_dir/Makefile"; then
	GIT_EXEC_PATH=$git_dir
	export GIT_EXEC_PATH
fi
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE

version=$($git_bin version | sed 's/^git version //')
root=$(mktemp -d "${TMPDIR:-/tmp}/git-hooks-ext-e2e.XXXXXX")
root=$(CDPATH= cd "$root" && pwd -P)
trap 'rm -rf "$root"' EXIT

check_events() {
	name=$1
	expected=$2
	actual="$root/$name.events"
	if test -n "$expected"; then
		printf '%s\n' "$expected" >"$root/expected"
	else
		: >"$root/expected"
	fi
	if test ! -f "$actual"; then
		: >"$actual"
	fi
	if ! diff -u "$root/expected" "$actual"; then
		printf '%s %s %s: event mismatch\n' "$version" "$ref_format" "$name" >&2
		exit 1
	fi
	printf '%s\t%s\t%s\tok\n' "$version" "$ref_format" "$name"
}

prepare_repo() {
	name=$1
	repo="$root/$name"
	if test "$ref_format" = reftable; then
		"$git_bin" init -q --ref-format=reftable "$repo"
	else
		"$git_bin" init -q "$repo"
	fi
	"$git_bin" -C "$repo" config user.name Compatibility
	"$git_bin" -C "$repo" config user.email compatibility@example.com
	"$git_bin" -C "$repo" commit --allow-empty -qm initial
	"$git_bin" -C "$repo" branch -M main
	case "$name" in
	branch-delete|update-ref-delete) "$git_bin" -C "$repo" branch topic ;;
	branch-rename) "$git_bin" -C "$repo" branch old ;;
	tag-delete|tag-update) "$git_bin" -C "$repo" tag v1 ;;
	esac
	oid=$("$git_bin" -C "$repo" rev-parse HEAD)
	zero=$(printf "%0${#oid}d" 0)
	"$helper_bin" --version >/dev/null
	(
		cd "$repo"
		"$helper_bin" install --legacy
		cat >.git/hooks/record-event <<'SH'
#!/bin/sh
printf '%s' "${0##*/}" >>"$GHE_E2E_LOG"
for arg do printf '|%s' "$arg" >>"$GHE_E2E_LOG"; done
printf '\n' >>"$GHE_E2E_LOG"
SH
		chmod +x .git/hooks/record-event
		for family in branch remote-branch tag stash note; do
			for action in created deleted updated renamed; do
				if test "$family" != stash || test "$action" != renamed; then
					ln -s record-event ".git/hooks/$family-$action"
				fi
			done
		done
		for event in worktree-created worktree-removed worktree-moved \
			worktree-locked worktree-unlocked worktree-pruned \
			worktree-repaired; do
			ln -s record-event ".git/hooks/$event"
		done
	)
	GHE_E2E_LOG="$root/$name.events"
	export GHE_E2E_LOG
}

printf 'git_version\tref_format\toperation\tresult\n'
prepare_repo branch-create
"$git_bin" -C "$repo" branch topic
test "$("$git_bin" -C "$repo" rev-parse refs/heads/topic)" = "$oid"
if test "$branch_create" = yes; then
	want="branch-created|topic|refs/heads/topic|$zero|$oid"
else
	want=
fi
check_events branch-create "$want"

prepare_repo branch-update
"$git_bin" -C "$repo" commit --allow-empty -qm next
new_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
if test "$branch_create" = yes; then
	want="branch-updated|main|refs/heads/main|$oid|$new_oid"
else
	want=
fi
check_events branch-update "$want"

prepare_repo branch-delete
"$git_bin" -C "$repo" branch -D topic >/dev/null
if test "$branch_delete" = yes; then
	want="branch-deleted|topic|refs/heads/topic|$oid|$zero"
else
	want=
fi
check_events branch-delete "$want"

prepare_repo branch-rename
"$git_bin" -C "$repo" branch -m old new
test "$("$git_bin" -C "$repo" rev-parse refs/heads/new)" = "$oid"
test "$branch_rename" = no
if test "$branch_create" = yes && test "$ref_format" = files; then
	want="branch-deleted|old|refs/heads/old|$oid|$zero"
else
	want=
fi
check_events branch-rename "$want"

prepare_repo tag-create
"$git_bin" -C "$repo" tag v1
if test "$tag_create" = yes; then
	want="tag-created|v1|refs/tags/v1|$zero|$oid"
else
	want=
fi
check_events tag-create "$want"

prepare_repo tag-update
"$git_bin" -C "$repo" commit --allow-empty -qm next
new_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
: >"$GHE_E2E_LOG"
"$git_bin" -C "$repo" tag -f v1 >/dev/null
if test "$tag_create" = yes; then
	want="tag-updated|v1|refs/tags/v1|$oid|$new_oid"
else
	want=
fi
check_events tag-update "$want"

prepare_repo tag-delete
"$git_bin" -C "$repo" tag -d v1 >/dev/null
if test "$tag_delete" = yes; then
	want="tag-deleted|v1|refs/tags/v1|$oid|$zero"
else
	want=
fi
check_events tag-delete "$want"

prepare_repo update-ref-delete
"$git_bin" -C "$repo" update-ref -d refs/heads/topic "$oid"
if test "$update_ref_delete" = yes; then
	want="branch-deleted|topic|refs/heads/topic|$oid|$zero"
else
	want=
fi
check_events update-ref-delete "$want"

# Exercise every ref event using real transactions, including event kinds for
# which high-level Git commands do not supply sufficient old/new object IDs.
run_ref_event() {
	family=$1
	action=$2
	case "$family" in
	branch) prefix=refs/heads; short=topic; renamed=renamed ;;
	remote-branch) prefix=refs/remotes/origin; short=topic; renamed=renamed ;;
	tag) prefix=refs/tags; short=topic; renamed=renamed ;;
	note) prefix=refs/notes; short=topic; renamed=renamed ;;
	stash) prefix=refs; short=stash; renamed= ;;
	esac
	if test "$family" = stash; then
		old_ref=refs/stash
		new_ref=
		old_short=stash
		new_short=
	else
		old_ref="$prefix/$short"
		new_ref="$prefix/$renamed"
		if test "$family" = remote-branch; then
			old_short="origin/$short"
			new_short="origin/$renamed"
		else
			old_short=$short
			new_short=$renamed
		fi
	fi
	name="ref-$family-$action"
	prepare_repo "$name"
	base_oid=$oid
	if test "$action" = update; then
		"$git_bin" -C "$repo" commit --allow-empty -qm next
		new_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
	fi
	if test "$action" != create; then
		"$git_bin" -C "$repo" update-ref "$old_ref" "$base_oid"
	fi
	: >"$GHE_E2E_LOG"
	case "$action" in
	create)
		"$git_bin" -C "$repo" update-ref "$old_ref" "$base_oid"
		want="$family-created|$old_short|$old_ref|$zero|$base_oid"
		;;
	update)
		"$git_bin" -C "$repo" update-ref "$old_ref" "$new_oid" "$base_oid"
		want="$family-updated|$old_short|$old_ref|$base_oid|$new_oid"
		;;
	delete)
		"$git_bin" -C "$repo" update-ref -d "$old_ref" "$base_oid"
		want="$family-deleted|$old_short|$old_ref|$base_oid|$zero"
		;;
	rename)
		printf 'start\ndelete %s %s\ncreate %s %s\nprepare\ncommit\n' \
			"$old_ref" "$base_oid" "$new_ref" "$base_oid" |
			"$git_bin" -C "$repo" update-ref --stdin >/dev/null
		want="$family-renamed|$old_short|$new_short|$old_ref|$new_ref|$base_oid"
		;;
	esac
	if test "$branch_create" != yes; then
		want=
	fi
	check_events "$name" "$want"
}

for family in branch remote-branch tag stash note; do
	for action in create update delete; do
		run_ref_event "$family" "$action"
	done
	if test "$family" != stash; then
		run_ref_event "$family" rename
	fi
done

# The worktree frontend needs NUL-delimited porcelain output. Older Git
# versions reject `git worktree list --porcelain -z` before running a command.
prepare_repo worktree-availability
if "$git_bin" -C "$repo" worktree list --porcelain -z \
	>/dev/null 2>"$root/worktree-support.err"; then
	worktree_supported=yes
else
	worktree_supported=no
fi

tree="$root/worktree-unavailable"
if test "$worktree_supported" = no; then
	if (cd "$repo" && "$helper_bin" worktree add --detach "$tree" \
		>"$root/worktree.out" 2>"$root/worktree.err"); then
		printf 'worktree add unexpectedly succeeded on Git %s\n' "$version" >&2
		exit 1
	fi
	test ! -e "$tree"
	check_events worktree-availability ''
else
	check_events worktree-availability ''
	for name in worktree-created worktree-removed worktree-moved \
		worktree-locked worktree-unlocked worktree-pruned worktree-repaired; do
		prepare_repo "$name"
		tree="$root/$name-tree"
		moved="$root/$name-moved"
		if test "$name" = worktree-created; then
			(cd "$repo" && "$helper_bin" worktree add --detach "$tree" \
				>"$root/worktree.out")
			want="$name|$tree|$oid|"
		else
			"$git_bin" -C "$repo" worktree add --detach "$tree" \
				>"$root/worktree.out" 2>"$root/worktree.err"
			case "$name" in
			worktree-removed)
				(cd "$repo" && "$helper_bin" worktree remove "$tree")
				want="$name|$tree|$oid|"
				;;
			worktree-moved)
				(cd "$repo" && "$helper_bin" worktree move "$tree" "$moved")
				want="$name|$tree|$moved|$oid|"
				;;
			worktree-locked)
				(cd "$repo" && "$helper_bin" worktree lock --reason offline "$tree")
				want="$name|$tree|offline"
				;;
			worktree-unlocked)
				"$git_bin" -C "$repo" worktree lock --reason offline "$tree"
				(cd "$repo" && "$helper_bin" worktree unlock "$tree")
				want="$name|$tree|offline"
				;;
			worktree-pruned)
				rm -rf "$tree"
				(cd "$repo" && "$helper_bin" worktree prune --expire now)
				want="$name|$tree|$oid|"
				;;
			worktree-repaired)
				mv "$tree" "$moved"
				(cd "$repo" && "$helper_bin" worktree repair "$moved")
				want="$name|$moved|$oid|"
				;;
			esac
		fi
		check_events "$name" "$want"
	done
fi
