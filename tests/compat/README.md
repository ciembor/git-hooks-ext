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
both TSV results. It tests 40 ref events (branch, remote branch, remote HEAD,
tag, stash, note, replace, prefetch, bisect, rewritten, per-worktree and
fallback refs) using actual `git update-ref` transactions, seven worktree
events using the `git-hooks-ext worktree` frontend, and 18 higher-level Git command
scenarios. On Git 2.54+, it additionally checks symbolic `HEAD`, symbolic remote
`HEAD`, custom ref names outside `refs/*`, worktree aliases and root-ref
transactions on both ref backends. The end-to-end suite
also confirms Git 2.27 does not emit ref
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
| `branch-deleted` | `git branch -D topic` | `2.28 ≤ Git ≤ 2.30` [²](#git-bugs) |
| `branch-deleted` | `git update-ref -d refs/heads/topic` | Git `≥ 2.28` |
| `branch-renamed` | `git branch -m old new` | ❌ [¹](#git-bugs) |
| `branch-renamed` | `git update-ref --stdin` (heads) | Git `≥ 2.28` |
| `remote-branch-created` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-updated` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-deleted` | `git remote prune origin` | ❌ [²](#git-bugs) |
| `remote-branch-deleted` | `git update-ref -d refs/remotes/origin/topic` | Git `≥ 2.28` |
| `remote-branch-renamed` | `git remote rename origin upstream` | Git `≥ 2.55` |
| `remote-branch-renamed` | `git update-ref --stdin` (remotes) | Git `≥ 2.28` |
| `tag-created` | `git tag v1` | Git `≥ 2.28` |
| `tag-updated` | `git tag -f v1` | Git `≥ 2.28` |
| `tag-deleted` | `git tag -d v1` | `2.28 ≤ Git ≤ 2.30` [²](#git-bugs) |
| `tag-deleted` | `git update-ref -d refs/tags/topic` | Git `≥ 2.28` |
| `tag-renamed` | `git update-ref --stdin` (tags) | Git `≥ 2.28` |
| `stash-created` | first `git stash push` | Git `≥ 2.28` |
| `stash-updated` | second `git stash push` | ❌ |
| `stash-updated` | `git update-ref refs/stash` | Git `≥ 2.28` |
| `stash-deleted` | `git stash clear` | Git `≥ 2.28` |
| `note-created` | `git notes add` | Git `≥ 2.28` |
| `note-updated` | `git notes append` | ❌ |
| `note-updated` | `git notes remove` | ❌ |
| `note-updated` | `git update-ref refs/notes/topic` | Git `≥ 2.28` |
| `note-deleted` | `git update-ref -d refs/notes/topic` | Git `≥ 2.28` |
| `note-renamed` | `git update-ref --stdin` (notes) | Git `≥ 2.28` |
| `remote-head-created` | `git remote set-head origin main` | Git `≥ 2.54` |
| `remote-head-created` | `git remote set-head origin topic` after fetch | Git `≥ 2.54` |
| `remote-head-updated` | `git update-ref --stdin` (`symref-update`) | Git `≥ 2.54` |
| `remote-head-deleted` | `git remote set-head -d origin` | ❌ |
| `remote-head-deleted` | `git update-ref --stdin` (`symref-delete`) | Git `≥ 2.54` |
| `replace-created` | `git replace <old> <new>` | Git `≥ 2.28` |
| `replace-updated` | `git replace -f <old> <new>` | Git `≥ 2.28` |
| `replace-deleted` | `git replace -d <old>` | Git `≥ 2.28` |
| `prefetch-created` | `git fetch --prefetch origin` | Git `≥ 2.32` |
| `prefetch-updated` | second `git fetch --prefetch origin` | Git `≥ 2.32` |
| `bisect-ref-created` | `git bisect start <bad> <good>` | Git `≥ 2.28` |
| `remote-head-*` | direct `git update-ref` | Git `≥ 2.28` |
| `replace-*` | direct `git update-ref` | Git `≥ 2.28` |
| `prefetch-*` | direct `git update-ref` | Git `≥ 2.28` |
| `bisect-ref-*` | direct `git update-ref` | Git `≥ 2.28` |
| `rewritten-ref-*` | direct `git update-ref` | Git `≥ 2.28` |
| `worktree-ref-*` | direct `git update-ref` | Git `≥ 2.28` |
| `ref-*` | direct `git update-ref` | Git `≥ 2.28` |
| `head-updated` | symbolic/ref-backend transaction | Git `≥ 2.54` |
| `head-attached` | symbolic/ref-backend transaction | Git `≥ 2.54` |
| `head-switched` | symbolic/ref-backend transaction | Git `≥ 2.54` |
| `remote-head-created` | symbolic/ref-backend transaction | Git `≥ 2.54` |
| `root-ref-*` | symbolic/ref-backend transaction | Git `≥ 2.54` |
| `head-detached` | `git checkout --detach` | ❌ |
| `worktree-created` | `git-hooks-ext worktree add` | Git `≥ 2.39.3` |
| `worktree-removed` | `git-hooks-ext worktree remove` | Git `≥ 2.39.3` |
| `worktree-moved` | `git-hooks-ext worktree move` | Git `≥ 2.39.3` |
| `worktree-locked` | `git-hooks-ext worktree lock` | Git `≥ 2.39.3` |
| `worktree-unlocked` | `git-hooks-ext worktree unlock` | Git `≥ 2.39.3` |
| `worktree-pruned` | `git-hooks-ext worktree prune` | Git `≥ 2.39.3` |
| `worktree-repaired` | `git-hooks-ext worktree repair` | Git `≥ 2.39.3` |

## Git bugs

Some compatibility gaps are caused by Git bugs, rather than limitations in
`git-hooks-ext`. I filed these reports upstream with proposed fixes:

1. [¹ `git branch -m` omits the destination ref from the `reference-transaction` hook](https://lore.kernel.org/git/CAOLa=ZTN1TU2A1sgEhiw=ymMYr6Ge11cMEubSaeKqr4WNU=2EQ@mail.gmail.com/T/#t).
2. [² `git branch -D` and `git tag -d` report zero OIDs from Git 2.31 onward](https://lore.kernel.org/git/CACQ=SRHthWOLVXmY6wgknOPgpQ+oB1vV-Q0AL=mK9mXb2Xy9Nw@mail.gmail.com/T/#t).

The CI runs every upstream minor release from Git 2.27 through 2.55 with the
files backend, plus Git 2.55 with reftable. Git 2.39.3 is measured locally as
the Apple Git comparison build.

With the files backend from Git 2.28 onward, `branch -m` reports the old branch
deletion but omits the new branch creation. The tested reftable backend emits
no rename payload. From Git 2.31 onward, ordinary branch and tag deletion calls
the hook with a `zero -> zero` record, which cannot identify a deletion. Direct
`git update-ref -d` remains usable.
