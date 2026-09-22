#!/bin/sh
set -eu

binary=$1
version=$2
test -x "$binary"
PATH="$(dirname "$binary"):$PATH"
export PATH
test "$(command -v git-hooks-ext)" = "$binary"
test "$(git-hooks-ext --version)" = "git-hooks-ext $version"
git-hooks-ext events | grep -Fx branch-created
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q "$work/repo"
cd "$work/repo"
git -c user.name='Package Test' -c user.email=test@example.com commit --allow-empty -qm initial
git-hooks-ext install
test -x .git/hooks/reference-transaction
cat >.git/hooks/branch-created <<'SH'
#!/bin/sh
printf 'created %s\n' "$1" >> events.out
SH
cat >.git/hooks/branch-deleted <<'SH'
#!/bin/sh
printf 'deleted %s\n' "$1" >> events.out
SH
chmod +x .git/hooks/branch-created .git/hooks/branch-deleted
git branch packaged
git update-ref -d refs/heads/packaged "$(git rev-parse HEAD)"
printf 'created packaged\ndeleted packaged\n' >expected
diff -u expected events.out
printf 'Installed hook smoke test passed: %s\n' "$binary"
