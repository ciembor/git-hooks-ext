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
events using the `ghe worktree` frontend, and 18 higher-level Git command
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
`ghe worktree` uses the extension's frontend; plain `git worktree`
does not run these hooks.

<table width="100%">
  <thead>
    <tr><th>Hook</th><th>Command</th><th>Supported Git versions</th></tr>
  </thead>
  <tbody>
    <tr><td><code>branch-created</code></td><td><code>git branch topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>branch-updated</code></td><td><code>git commit</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>branch-deleted</code></td><td><code>git branch -D topic</code></td><td><code>2.28 ≤ Git ≤ 2.30</code> <a href="#git-bugs">²</a></td></tr>
    <tr><td><code>branch-deleted</code></td><td><code>git update-ref -d refs/heads/topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>branch-renamed</code></td><td><code>git branch -m old new</code></td><td>❌ <a href="#git-bugs">¹</a></td></tr>
    <tr><td><code>branch-renamed</code></td><td><code>git update-ref --stdin</code> (heads)</td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-branch-created</code></td><td><code>git fetch origin</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-branch-updated</code></td><td><code>git fetch origin</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-branch-deleted</code></td><td><code>git remote prune origin</code></td><td>❌ <a href="#git-bugs">²</a></td></tr>
    <tr><td><code>remote-branch-deleted</code></td><td><code>git update-ref -d refs/remotes/origin/topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-branch-renamed</code></td><td><code>git remote rename origin upstream</code></td><td>Git <code>≥ 2.55</code></td></tr>
    <tr><td><code>remote-branch-renamed</code></td><td><code>git update-ref --stdin</code> (remotes)</td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>tag-created</code></td><td><code>git tag v1</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>tag-updated</code></td><td><code>git tag -f v1</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>tag-deleted</code></td><td><code>git tag -d v1</code></td><td><code>2.28 ≤ Git ≤ 2.30</code> <a href="#git-bugs">²</a></td></tr>
    <tr><td><code>tag-deleted</code></td><td><code>git update-ref -d refs/tags/topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>tag-renamed</code></td><td><code>git update-ref --stdin</code> (tags)</td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>stash-created</code></td><td>first <code>git stash push</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>stash-updated</code></td><td>second <code>git stash push</code></td><td>❌</td></tr>
    <tr><td><code>stash-updated</code></td><td><code>git update-ref refs/stash</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>stash-deleted</code></td><td><code>git stash clear</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>note-created</code></td><td><code>git notes add</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>note-updated</code></td><td><code>git notes append</code></td><td>❌</td></tr>
    <tr><td><code>note-updated</code></td><td><code>git notes remove</code></td><td>❌</td></tr>
    <tr><td><code>note-updated</code></td><td><code>git update-ref refs/notes/topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>note-deleted</code></td><td><code>git update-ref -d refs/notes/topic</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>note-renamed</code></td><td><code>git update-ref --stdin</code> (notes)</td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-head-created</code></td><td><code>git remote set-head origin main</code></td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>remote-head-created</code></td><td><code>git remote set-head origin topic</code> after fetch</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>remote-head-updated</code></td><td><code>git update-ref --stdin</code> (<code>symref-update</code>)</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>remote-head-deleted</code></td><td><code>git remote set-head -d origin</code></td><td>❌</td></tr>
    <tr><td><code>remote-head-deleted</code></td><td><code>git update-ref --stdin</code> (<code>symref-delete</code>)</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>replace-created</code></td><td><code>git replace &lt;old&gt; &lt;new&gt;</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>replace-updated</code></td><td><code>git replace -f &lt;old&gt; &lt;new&gt;</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>replace-deleted</code></td><td><code>git replace -d &lt;old&gt;</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>prefetch-created</code></td><td><code>git fetch --prefetch origin</code></td><td>Git <code>≥ 2.32</code></td></tr>
    <tr><td><code>prefetch-updated</code></td><td>second <code>git fetch --prefetch origin</code></td><td>Git <code>≥ 2.32</code></td></tr>
    <tr><td><code>bisect-ref-created</code></td><td><code>git bisect start &lt;bad&gt; &lt;good&gt;</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>remote-head-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>replace-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>prefetch-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>bisect-ref-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>rewritten-ref-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>worktree-ref-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>ref-*</code></td><td>direct <code>git update-ref</code></td><td>Git <code>≥ 2.28</code></td></tr>
    <tr><td><code>head-updated</code></td><td>symbolic/ref-backend transaction</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>head-attached</code></td><td>symbolic/ref-backend transaction</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>head-switched</code></td><td>symbolic/ref-backend transaction</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>remote-head-created</code></td><td>symbolic/ref-backend transaction</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>root-ref-*</code></td><td>symbolic/ref-backend transaction</td><td>Git <code>≥ 2.54</code></td></tr>
    <tr><td><code>head-detached</code></td><td><code>git checkout --detach</code></td><td>❌</td></tr>
    <tr><td><code>worktree-created</code></td><td><code>ghe worktree add</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-removed</code></td><td><code>ghe worktree remove</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-moved</code></td><td><code>ghe worktree move</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-locked</code></td><td><code>ghe worktree lock</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-unlocked</code></td><td><code>ghe worktree unlock</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-pruned</code></td><td><code>ghe worktree prune</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-repaired</code></td><td><code>ghe worktree repair</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
  </tbody>
</table>

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
