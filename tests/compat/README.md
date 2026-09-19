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

## Commands and emitted events

Measured on 2026-09-19. The detailed CI matrix tests Git 2.27–2.55, Apple Git
2.39.3 and the files and reftable backends. Git versions `< 2.28` do not
provide the required `reference-transaction` hook.

This table lists each tested command, its expected event and the Git versions
that emit it. The direct `update-ref` rows show which events remain reachable
when a higher-level command omits usable transaction data. Rows for
`git-hooks-ext worktree` use the extension's frontend; plain `git worktree`
does not run these hooks.

| Hook | Command | Supported Git versions |
|:---|:---|:---:|
| `branch-created` | `git branch topic` | Git `≥ 2.28` |
| `branch-updated` | `git commit` | Git `≥ 2.28` |
| `branch-deleted` | `git branch -D topic` | `2.28 ≤ Git ≤ 2.30` |
| `branch-deleted` | `git update-ref -d refs/heads/topic` | Git `≥ 2.28` |
| `branch-renamed` | `git branch -m old new` | Not observed for `2.28 ≤ Git ≤ 2.55` |
| `branch-renamed` | `git update-ref --stdin` (heads) | Git `≥ 2.28` |
| `remote-branch-created` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-updated` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-deleted` | `git remote prune origin` | Not observed for `2.28 ≤ Git ≤ 2.55` |
| `remote-branch-deleted` | `git update-ref -d refs/remotes/origin/topic` | Git `≥ 2.28` |
| `remote-branch-renamed` | `git remote rename origin upstream` | Git `≥ 2.55` |
| `remote-branch-renamed` | `git update-ref --stdin` (remotes) | Git `≥ 2.28` |
| `tag-created` | `git tag v1` | Git `≥ 2.28` |
| `tag-updated` | `git tag -f v1` | Git `≥ 2.28` |
| `tag-deleted` | `git tag -d v1` | `2.28 ≤ Git ≤ 2.30` |
| `tag-deleted` | `git update-ref -d refs/tags/topic` | Git `≥ 2.28` |
| `tag-renamed` | `git update-ref --stdin` (tags) | Git `≥ 2.28` |
| `stash-created` | first `git stash push` | Git `≥ 2.28` |
| `stash-updated` | second `git stash push` | Not observed for `2.28 ≤ Git ≤ 2.55`; emits `stash-created` |
| `stash-updated` | `git update-ref refs/stash` | Git `≥ 2.28` |
| `stash-deleted` | `git stash clear` | Git `≥ 2.28` |
| `note-created` | `git notes add` | Git `≥ 2.28` |
| `note-updated` | `git notes append` | Not observed for `2.28 ≤ Git ≤ 2.55`; emits `note-created` |
| `note-updated` | `git notes remove` | Not observed for `2.28 ≤ Git ≤ 2.55`; emits `note-created` |
| `note-updated` | `git update-ref refs/notes/topic` | Git `≥ 2.28` |
| `note-deleted` | `git update-ref -d refs/notes/topic` | Git `≥ 2.28` |
| `note-renamed` | `git update-ref --stdin` (notes) | Git `≥ 2.28` |
| `worktree-created` | `git-hooks-ext worktree add` | Git `≥ 2.39.3` |
| `worktree-removed` | `git-hooks-ext worktree remove` | Git `≥ 2.39.3` |
| `worktree-moved` | `git-hooks-ext worktree move` | Git `≥ 2.39.3` |
| `worktree-locked` | `git-hooks-ext worktree lock` | Git `≥ 2.39.3` |
| `worktree-unlocked` | `git-hooks-ext worktree unlock` | Git `≥ 2.39.3` |
| `worktree-pruned` | `git-hooks-ext worktree prune` | Git `≥ 2.39.3` |
| `worktree-repaired` | `git-hooks-ext worktree repair` | Git `≥ 2.39.3` |

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
