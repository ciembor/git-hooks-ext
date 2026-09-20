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
git_minor=$(printf '%s\n' "$version" | sed -n 's/^[0-9]*\.\([0-9]*\).*/\1/p')
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

check_event_set() {
	name=$1
	expected=$2
	actual="$root/$name.events"
	if test -n "$expected"; then
		printf '%s\n' "$expected" | sort >"$root/expected"
	else
		: >"$root/expected"
	fi
	if test ! -f "$actual"; then
		: >"$actual"
	fi
	sort "$actual" >"$root/actual"
	if ! diff -u "$root/expected" "$root/actual"; then
		printf '%s %s %s: event mismatch\n' "$version" "$ref_format" "$name" >&2
		exit 1
	fi
	printf '%s\t%s\t%s\tok\n' "$version" "$ref_format" "$name"
}

use_event_log() {
	GHE_E2E_LOG="$root/$1.events"
	export GHE_E2E_LOG
	: >"$GHE_E2E_LOG"
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
		for family in remote-head replace prefetch bisect-ref rewritten-ref \
			worktree-ref ref; do
			for action in created deleted updated; do
				ln -s record-event ".git/hooks/$family-$action"
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

# Exercise higher-level commands beyond branch and tag operations. Several of
# them invoke the hook but report incomplete old/new IDs; assert those results
# as well, so the command matrix cannot silently claim the intended event.
prepare_repo command-remote-create
remote="$root/remote.git"
"$git_bin" init -q --bare "$remote"
"$git_bin" -C "$repo" remote add origin "$remote"
"$git_bin" -C "$repo" push -q origin HEAD:main
"$git_bin" -C "$repo" update-ref -d refs/remotes/origin/main
use_event_log command-remote-create
"$git_bin" -C "$repo" fetch -q origin
test "$("$git_bin" -C "$repo" rev-parse refs/remotes/origin/main)" = "$oid"
if test "$branch_create" = yes; then
	want="remote-branch-created|origin/main|refs/remotes/origin/main|$zero|$oid"
else
	want=
fi
check_events command-remote-create "$want"

seed="$root/seed"
"$git_bin" clone -q --no-checkout "$remote" "$seed"
"$git_bin" -C "$seed" config user.name Compatibility
"$git_bin" -C "$seed" config user.email compatibility@example.com
"$git_bin" -C "$seed" checkout -q main
"$git_bin" -C "$seed" commit --allow-empty -qm next
"$git_bin" -C "$seed" push -q origin HEAD:main
new_oid=$("$git_bin" -C "$seed" rev-parse HEAD)
use_event_log command-remote-update
"$git_bin" -C "$repo" fetch -q origin
test "$("$git_bin" -C "$repo" rev-parse refs/remotes/origin/main)" = "$new_oid"
if test "$branch_create" = yes; then
	want="remote-branch-updated|origin/main|refs/remotes/origin/main|$oid|$new_oid"
else
	want=
fi
check_events command-remote-update "$want"

"$git_bin" -C "$seed" push -q origin :main
use_event_log command-remote-prune
"$git_bin" -C "$repo" remote prune origin >/dev/null
! "$git_bin" -C "$repo" show-ref --verify --quiet refs/remotes/origin/main
check_events command-remote-prune ''

prepare_repo command-remote-rename
remote="$root/rename.git"
"$git_bin" init -q --bare "$remote"
"$git_bin" -C "$repo" remote add origin "$remote"
"$git_bin" -C "$repo" push -q origin HEAD:main
use_event_log command-remote-rename
"$git_bin" -C "$repo" remote rename origin upstream
test "$("$git_bin" -C "$repo" rev-parse refs/remotes/upstream/main)" = "$oid"
if test "$branch_create" != yes; then
	want=
elif test "$git_minor" -ge 55; then
	want="remote-branch-renamed|origin/main|upstream/main|refs/remotes/origin/main|refs/remotes/upstream/main|$oid"
else
	want="remote-branch-deleted|origin/main|refs/remotes/origin/main|$oid|$zero"
fi
check_events command-remote-rename "$want"

prepare_repo command-note-create
"$git_bin" -C "$repo" notes add -m first HEAD
note_oid=$("$git_bin" -C "$repo" rev-parse refs/notes/commits)
if test "$branch_create" = yes; then
	want="note-created|commits|refs/notes/commits|$zero|$note_oid"
else
	want=
fi
check_events command-note-create "$want"

use_event_log command-note-append
"$git_bin" -C "$repo" notes append -m second HEAD
note_oid=$("$git_bin" -C "$repo" rev-parse refs/notes/commits)
if test "$branch_create" = yes; then
	want="note-created|commits|refs/notes/commits|$zero|$note_oid"
else
	want=
fi
check_events command-note-append "$want"

use_event_log command-note-remove
"$git_bin" -C "$repo" notes remove HEAD >/dev/null
note_oid=$("$git_bin" -C "$repo" rev-parse refs/notes/commits)
if test "$branch_create" = yes; then
	want="note-created|commits|refs/notes/commits|$zero|$note_oid"
else
	want=
fi
check_events command-note-remove "$want"

prepare_repo command-stash-create
printf 'tracked\n' >"$repo/tracked"
"$git_bin" -C "$repo" add tracked
"$git_bin" -C "$repo" commit -qm tracked
printf 'first\n' >>"$repo/tracked"
use_event_log command-stash-create
"$git_bin" -C "$repo" stash push -qm first
stash_oid=$("$git_bin" -C "$repo" rev-parse refs/stash)
if test "$branch_create" = yes; then
	want="stash-created|stash|refs/stash|$zero|$stash_oid"
else
	want=
fi
check_events command-stash-create "$want"

printf 'second\n' >>"$repo/tracked"
use_event_log command-stash-update
"$git_bin" -C "$repo" stash push -qm second
stash_oid=$("$git_bin" -C "$repo" rev-parse refs/stash)
if test "$branch_create" = yes; then
	want="stash-created|stash|refs/stash|$zero|$stash_oid"
else
	want=
fi
check_events command-stash-update "$want"

use_event_log command-stash-clear
"$git_bin" -C "$repo" stash clear
if test "$branch_create" = yes; then
	want="stash-deleted|stash|refs/stash|$stash_oid|$zero"
else
	want=
fi
check_events command-stash-clear "$want"

prepare_repo command-remote-head-create
remote="$root/remote-head.git"
"$git_bin" init -q --bare "$remote"
"$git_bin" -C "$remote" symbolic-ref HEAD refs/heads/main
"$git_bin" -C "$repo" remote add origin "$remote"
"$git_bin" -C "$repo" push -q origin HEAD:main
"$git_bin" -C "$repo" fetch -q origin
use_event_log command-remote-head-create
"$git_bin" -C "$repo" remote set-head origin main
if test "$branch_create" = yes && test "$git_minor" -ge 54; then
	want="remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|ref:refs/remotes/origin/main"
else
	want=
fi
check_events command-remote-head-create "$want"

"$git_bin" -C "$repo" branch topic
"$git_bin" -C "$repo" push -q origin topic
"$git_bin" -C "$repo" fetch -q origin
use_event_log command-remote-head-update
"$git_bin" -C "$repo" remote set-head origin topic
if test "$branch_create" = yes && test "$git_minor" -ge 54; then
	want="remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|ref:refs/remotes/origin/topic"
else
	want=
fi
check_events command-remote-head-update "$want"

use_event_log command-remote-head-delete
"$git_bin" -C "$repo" remote set-head -d origin
check_events command-remote-head-delete ''

prepare_repo command-replace-create
base_oid=$oid
"$git_bin" -C "$repo" commit --allow-empty -qm second
replacement_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
"$git_bin" -C "$repo" commit --allow-empty -qm third
next_replacement_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
use_event_log command-replace-create
"$git_bin" -C "$repo" replace "$base_oid" "$replacement_oid"
if test "$branch_create" = yes; then
	want="replace-created|$base_oid|refs/replace/$base_oid|$zero|$replacement_oid"
else
	want=
fi
check_events command-replace-create "$want"

use_event_log command-replace-update
"$git_bin" -C "$repo" replace -f "$base_oid" "$next_replacement_oid"
if test "$branch_create" = yes; then
	want="replace-updated|$base_oid|refs/replace/$base_oid|$replacement_oid|$next_replacement_oid"
else
	want=
fi
check_events command-replace-update "$want"

use_event_log command-replace-delete
"$git_bin" -C "$repo" replace -d "$base_oid" >/dev/null
if test "$branch_create" = yes; then
	want="replace-deleted|$base_oid|refs/replace/$base_oid|$next_replacement_oid|$zero"
else
	want=
fi
check_events command-replace-delete "$want"

if test "$git_minor" -ge 32; then
	prepare_repo command-prefetch-create
	remote="$root/prefetch.git"
	"$git_bin" init -q --bare "$remote"
	"$git_bin" -C "$remote" symbolic-ref HEAD refs/heads/main
	"$git_bin" -C "$repo" remote add origin "$remote"
	"$git_bin" -C "$repo" push -q origin HEAD:main
	use_event_log command-prefetch-create
	"$git_bin" -C "$repo" fetch -q --prefetch origin
	if test "$branch_create" = yes; then
		want="prefetch-created|remotes/origin/main|refs/prefetch/remotes/origin/main|$zero|$oid"
		if test "$git_minor" -ge 54; then
			want="$want
remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|ref:refs/remotes/origin/main"
		fi
	else
		want=
	fi
	check_events command-prefetch-create "$want"

	"$git_bin" -C "$repo" commit --allow-empty -qm next
	"$git_bin" -C "$repo" push -q origin HEAD:main
	new_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
	use_event_log command-prefetch-update
	"$git_bin" -C "$repo" fetch -q --prefetch origin
	if test "$branch_create" = yes; then
		want="prefetch-updated|remotes/origin/main|refs/prefetch/remotes/origin/main|$oid|$new_oid"
	else
		want=
	fi
	check_events command-prefetch-update "$want"
fi

prepare_repo command-bisect
"$git_bin" -C "$repo" commit --allow-empty -qm second
"$git_bin" -C "$repo" commit --allow-empty -qm third
bad_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
use_event_log command-bisect
"$git_bin" -C "$repo" bisect start "$bad_oid" "$oid" >/dev/null
if test "$branch_create" = yes; then
	want=$("$git_bin" -C "$repo" for-each-ref \
		--format='bisect-ref-created|%(refname:strip=2)|%(refname)|'"$zero"'|%(objectname)' \
		refs/bisect)
else
	want=
fi
check_event_set command-bisect "$want"

# Exercise every ref event using real transactions, including event kinds for
# which high-level Git commands do not supply sufficient old/new object IDs.
run_ref_event() {
	family=$1
	action=$2
	case "$family" in
	branch) prefix=refs/heads; short=topic; renamed=renamed ;;
	remote-branch) prefix=refs/remotes/origin; short=topic; renamed=renamed ;;
	remote-head) prefix=refs/remotes/origin; short=HEAD; renamed= ;;
	tag) prefix=refs/tags; short=topic; renamed=renamed ;;
	note) prefix=refs/notes; short=topic; renamed=renamed ;;
	stash) prefix=refs; short=stash; renamed= ;;
	replace) prefix=refs/replace; short=topic; renamed= ;;
	prefetch) prefix=refs/prefetch; short=topic; renamed= ;;
	bisect-ref) prefix=refs/bisect; short=topic; renamed= ;;
	rewritten-ref) prefix=refs/rewritten; short=topic; renamed= ;;
	worktree-ref) prefix=refs/worktree; short=topic; renamed= ;;
	ref) prefix=refs/custom; short=topic; renamed= ;;
	esac
	if test "$family" = stash; then
		old_ref=refs/stash
		new_ref=
		old_short=stash
		new_short=
	else
		old_ref="$prefix/$short"
		new_ref="$prefix/$renamed"
		if test "$family" = remote-branch || test "$family" = remote-head; then
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
	if test "$family" = replace; then
		old_ref="refs/replace/$base_oid"
		old_short=$base_oid
	elif test "$family" = ref; then
		old_short="custom/$short"
	fi
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

for family in remote-head replace prefetch bisect-ref rewritten-ref \
	worktree-ref ref; do
	for action in create update delete; do
		run_ref_event "$family" "$action"
	done
done

if test "$git_minor" -ge 54; then
	prepare_repo symbolic-head
	"$git_bin" -C "$repo" branch topic
	for event in head-updated head-attached head-detached head-switched; do
		ln -s record-event "$repo/.git/hooks/$event"
	done
	use_event_log symbolic-head
	"$git_bin" -C "$repo" symbolic-ref HEAD refs/heads/topic
	printf 'option no-deref\nsymref-update HEAD refs/heads/main ref refs/heads/topic\n' |
		"$git_bin" -C "$repo" update-ref --stdin
	check_events symbolic-head "head-updated|HEAD|HEAD|$zero|ref:refs/heads/topic
head-updated|HEAD|HEAD|ref:refs/heads/topic|ref:refs/heads/main
head-switched|HEAD|HEAD|ref:refs/heads/topic|ref:refs/heads/main"

	use_event_log symbolic-head-detach
	"$git_bin" -C "$repo" checkout -q --detach
	check_events symbolic-head-detach "head-updated|HEAD|HEAD|$zero|$oid"

	use_event_log symbolic-head-attach
	printf 'option no-deref\nsymref-update HEAD refs/heads/topic oid %s\n' "$oid" |
		"$git_bin" -C "$repo" update-ref --stdin
	check_events symbolic-head-attach "head-updated|HEAD|HEAD|$oid|ref:refs/heads/topic
head-attached|HEAD|HEAD|$oid|ref:refs/heads/topic"

	prepare_repo symbolic-remote-head
	"$git_bin" -C "$repo" update-ref refs/remotes/origin/main "$oid"
	use_event_log symbolic-remote-head
	"$git_bin" -C "$repo" symbolic-ref refs/remotes/origin/HEAD \
		refs/remotes/origin/main
	check_events symbolic-remote-head "remote-head-created|origin/HEAD|refs/remotes/origin/HEAD|$zero|ref:refs/remotes/origin/main"
	"$git_bin" -C "$repo" update-ref refs/remotes/origin/topic "$oid"
	use_event_log symbolic-remote-head-update
	printf 'option no-deref\nsymref-update refs/remotes/origin/HEAD refs/remotes/origin/topic ref refs/remotes/origin/main\n' |
		"$git_bin" -C "$repo" update-ref --stdin
	check_events symbolic-remote-head-update "remote-head-updated|origin/HEAD|refs/remotes/origin/HEAD|ref:refs/remotes/origin/main|ref:refs/remotes/origin/topic"

	use_event_log symbolic-remote-head-delete
	printf 'option no-deref\nsymref-delete refs/remotes/origin/HEAD refs/remotes/origin/topic\n' |
		"$git_bin" -C "$repo" update-ref --stdin
	check_events symbolic-remote-head-delete "remote-head-deleted|origin/HEAD|refs/remotes/origin/HEAD|ref:refs/remotes/origin/topic|$zero"

	prepare_repo root-ref
	base_oid=$oid
	"$git_bin" -C "$repo" commit --allow-empty -qm next
	next_oid=$("$git_bin" -C "$repo" rev-parse HEAD)
	for event in root-ref-created root-ref-updated root-ref-deleted; do
		ln -s record-event "$repo/.git/hooks/$event"
	done
	use_event_log root-ref
	"$git_bin" -C "$repo" update-ref AUTO_MERGE "$base_oid"
	"$git_bin" -C "$repo" update-ref AUTO_MERGE "$next_oid" "$base_oid"
	"$git_bin" -C "$repo" update-ref -d AUTO_MERGE "$next_oid"
	check_events root-ref "root-ref-created|AUTO_MERGE|AUTO_MERGE|$zero|$base_oid
root-ref-updated|AUTO_MERGE|AUTO_MERGE|$base_oid|$next_oid
root-ref-deleted|AUTO_MERGE|AUTO_MERGE|$next_oid|$zero"

	prepare_repo nonstandard-refs
	"$git_bin" -C "$repo" worktree add -q --detach "$root/nonstandard-tree"
	for event in root-ref-created root-ref-updated root-ref-deleted; do
		ln -s record-event "$repo/.git/hooks/$event"
	done
	use_event_log nonstandard-refs
	"$git_bin" -C "$repo" update-ref CUSTOM "$oid"
	"$git_bin" -C "$repo" update-ref lower_HEAD "$oid"
	"$git_bin" -C "$repo" update-ref misc/path "$oid"
	"$git_bin" -C "$repo" update-ref main-worktree/AUTO_MERGE "$oid"
	"$git_bin" -C "$repo" update-ref main-worktree/refs/bisect/good "$oid"
	"$git_bin" -C "$repo" update-ref worktrees/nonstandard-tree/refs/rewritten/topic "$oid"
	"$git_bin" -C "$repo" update-ref main-worktree/FETCH_HEAD "$oid"
	"$git_bin" -C "$repo" update-ref main-worktree/MERGE_HEAD "$oid"
	"$git_bin" -C "$repo" update-ref worktrees/nonstandard-tree/FETCH_HEAD "$oid"
	"$git_bin" -C "$repo" update-ref worktrees/nonstandard-tree/MERGE_HEAD "$oid"
	check_events nonstandard-refs "root-ref-created|CUSTOM|CUSTOM|$zero|$oid
root-ref-created|lower_HEAD|lower_HEAD|$zero|$oid
root-ref-created|misc/path|misc/path|$zero|$oid
root-ref-created|AUTO_MERGE|main-worktree/AUTO_MERGE|$zero|$oid
bisect-ref-created|good|main-worktree/refs/bisect/good|$zero|$oid
rewritten-ref-created|topic|worktrees/nonstandard-tree/refs/rewritten/topic|$zero|$oid
root-ref-created|FETCH_HEAD|main-worktree/FETCH_HEAD|$zero|$oid
root-ref-created|MERGE_HEAD|main-worktree/MERGE_HEAD|$zero|$oid
root-ref-created|FETCH_HEAD|worktrees/nonstandard-tree/FETCH_HEAD|$zero|$oid
root-ref-created|MERGE_HEAD|worktrees/nonstandard-tree/MERGE_HEAD|$zero|$oid"

fi

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
