# Git compatibility matrix

The raw probe measures the payload produced by Git itself, independently of
`git-hooks-ext`. A hook call is useful only when it contains the real old or
new object ID required to classify the ref update. The end-to-end suite then
runs real Git commands through the installed helper and checks every emitted
event, including names and arguments.

Run it against the installed Git:

```sh
tests/compat/reference-transaction.sh "$(command -v git)" files
```

Build and probe an upstream release:

```sh
tests/compat/build-git.sh 2.55.0 files
tests/compat/build-git.sh 2.55.0 reftable
```

Build the helper and run all end-to-end cases against that release:

```sh
make
tests/compat/e2e.sh "${GHE_COMPAT_CACHE:-${TMPDIR:-/tmp}/git-hooks-ext-git-compat}/git-2.55.0/git" "$PWD/git-hooks-ext" files yes,no,no,yes,no,yes
```

Source archives and builds are cached outside the repository under
`${TMPDIR:-/tmp}/git-hooks-ext-git-compat`. Set `GHE_COMPAT_CACHE` or
`GHE_COMPAT_JOBS` to override the cache or build parallelism.
The `Git compatibility` workflow builds each release in the matrix, checks the
expected `usable_update` column, runs the real end-to-end suite and uploads
both TSV results. It tests 19 ref events (branch, remote branch, tag, note and
stash) using actual `git update-ref` transactions, seven worktree events using
the `git-hooks-ext worktree` frontend, and 18 higher-level Git command
scenarios. The end-to-end suite also confirms Git 2.27 does not emit ref
events and Git versions before 2.39 in this matrix cannot run the worktree
frontend because they lack `git worktree list --porcelain -z`. The Apple Git
2.39.3 row is measured locally, separately from the upstream CI matrix.

## Hook availability by Git version

Measured on 2026-09-19. ✅ means the end-to-end test observed the exact hook
name and arguments after a real Git operation; ❌ means no usable event was
produced. For ref hooks, the test uses real `git update-ref` transactions
(including atomic renames), because Git's higher-level commands do not always
supply usable old and new object IDs. A green check therefore does **not** mean
every Git command that changes that ref emits the event. Worktree hooks are
tested through `git-hooks-ext worktree`. Each column uses the files ref backend
unless marked `reftable`.

| Hook | 2.27 | 2.28 | 2.29 | 2.30 | 2.31 | 2.35 | 2.39.3 | 2.39.3 Apple | 2.42 | 2.55 | 2.55 reftable |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `branch-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `branch-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `branch-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `branch-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `remote-branch-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `remote-branch-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `remote-branch-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `remote-branch-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `tag-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `tag-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `tag-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `tag-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stash-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stash-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stash-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `note-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `note-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `note-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `note-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-created` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-removed` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-moved` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-locked` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-unlocked` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-pruned` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `worktree-repaired` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |

The worktree frontend cannot run on the tested Git 2.27–2.35 releases because
they reject `git worktree list --porcelain -z`. Git 2.27 does not call
`reference-transaction`, so none of the ref hooks fire.

## Commands and emitted events

This matrix tests the named command and expected hook with exact arguments. ✅
means that hook fired; ❌ means it did not, even if the Git command succeeded.
The direct `update-ref` rows show which events remain reachable when a
higher-level command omits usable transaction data. `git-hooks-ext worktree`
rows use the extension's frontend; plain `git worktree` does not run these
hooks. A `git branch -m` or `git remote rename` may emit a separate deletion
without producing the requested rename. `git notes append`, `git notes
remove`, and a second `git stash push` emit *created* instead of the expected
*updated* event in tested versions. `git remote prune` removes the ref but
emits no semantic deletion.

| Command → hook | 2.27 | 2.28 | 2.29 | 2.30 | 2.31 | 2.35 | 2.39.3 | 2.39.3 Apple | 2.42 | 2.55 | 2.55 reftable |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `git branch topic` → `branch-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git commit` → `branch-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git branch -D topic` → `branch-deleted` | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref -d refs/heads/topic` → `branch-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git branch -m old new` → `branch-renamed` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref --stdin` (heads) → `branch-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git fetch origin` → `remote-branch-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git fetch origin` → `remote-branch-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git remote prune origin` → `remote-branch-deleted` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref -d refs/remotes/origin/topic` → `remote-branch-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git remote rename origin upstream` → `remote-branch-renamed` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `git update-ref --stdin` (remotes) → `remote-branch-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git tag v1` → `tag-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git tag -f v1` → `tag-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git tag -d v1` → `tag-deleted` | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref -d refs/tags/topic` → `tag-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git update-ref --stdin` (tags) → `tag-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| first `git stash push` → `stash-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| second `git stash push` → `stash-updated` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref refs/stash` → `stash-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git stash clear` → `stash-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git notes add` → `note-created` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git notes append` → `note-updated` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git notes remove` → `note-updated` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `git update-ref refs/notes/topic` → `note-updated` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git update-ref -d refs/notes/topic` → `note-deleted` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git update-ref --stdin` (notes) → `note-renamed` | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree add` → `worktree-created` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree remove` → `worktree-removed` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree move` → `worktree-moved` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree lock` → `worktree-locked` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree unlock` → `worktree-unlocked` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree prune` → `worktree-pruned` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `git-hooks-ext worktree repair` → `worktree-repaired` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |

The versions were selected by divide and conquer. Testing 2.27 and 2.55 found
the supported range; 2.28 established the introduction boundary. Tests at
2.42, 2.35, 2.32, 2.30 and 2.31 narrowed the deletion behavior change to
2.31.0. Versions 2.29 and 2.39.3 verify both sides and compare upstream Git
with Apple's build.

With the files backend from Git 2.28 onward, `branch -m` reports the old branch
deletion but omits the new branch creation. The tested reftable backend emits
no rename payload. From Git 2.31 onward, ordinary branch and tag deletion calls
the hook with a `zero -> zero` record, which cannot identify a deletion. Direct
`git update-ref -d` remains usable.
