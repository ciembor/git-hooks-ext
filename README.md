[![Release](https://img.shields.io/github/v/release/ciembor/git-hooks-ext?display_name=tag&sort=semver)](https://github.com/ciembor/git-hooks-ext/releases/latest)
[![License](https://img.shields.io/github/license/ciembor/git-hooks-ext)](LICENSE)
[![Lint](https://github.com/ciembor/git-hooks-ext/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/ciembor/git-hooks-ext/actions/workflows/lint.yml)
[![Tests](https://github.com/ciembor/git-hooks-ext/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/ciembor/git-hooks-ext/actions/workflows/tests.yml)
[![Coverage: 100%](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/ciembor/git-hooks-ext/actions/workflows/coverage.yml)

# git-hooks-ext

[About](#about) · [Quick Start](#quick-start) · [Install](#install) ·
[Worktrees](#worktree-lifecycle) · [Configuration](#advanced-configuration) ·
[Hook Arguments](#hook-arguments) · [Compatibility](#compatibility) ·
[Development](DEVELOPMENT.md) · [Website ↗](https://ciembor.github.io/git-hooks-ext/)

## About

Git's `reference-transaction` hook reports raw old and new values together
with ref names. It does not tell a hook that a branch was created, a tag was
deleted or a ref was renamed.

`git-hooks-ext` turns those low-level updates into semantic events such as
`branch-created`, `tag-deleted`, `remote-head-updated` and `ref-created`. It
also adds the worktree lifecycle events that Git does not provide.

Supported ref events are grouped by purpose:

### Everyday refs

<table width="100%">
  <thead>
    <tr><th>Ref</th><th>Created</th><th>Deleted</th><th>Updated</th><th>Renamed</th></tr>
  </thead>
  <tbody>
    <tr><td>Branch</td><td><code>branch-created</code></td><td><code>branch-deleted</code></td><td><code>branch-updated</code></td><td><code>branch-renamed</code></td></tr>
    <tr><td>Remote branch</td><td><code>remote-branch-created</code></td><td><code>remote-branch-deleted</code></td><td><code>remote-branch-updated</code></td><td><code>remote-branch-renamed</code></td></tr>
    <tr><td>Tag</td><td><code>tag-created</code></td><td><code>tag-deleted</code></td><td><code>tag-updated</code></td><td><code>tag-renamed</code></td></tr>
    <tr><td>Note</td><td><code>note-created</code></td><td><code>note-deleted</code></td><td><code>note-updated</code></td><td><code>note-renamed</code></td></tr>
    <tr><td>Stash</td><td><code>stash-created</code></td><td><code>stash-deleted</code></td><td><code>stash-updated</code></td><td>—</td></tr>
  </tbody>
</table>

### Specialized refs

<table width="100%">
  <thead>
    <tr><th>Ref</th><th>Created</th><th>Deleted</th><th>Updated</th></tr>
  </thead>
  <tbody>
    <tr><td>Replace</td><td><code>replace-created</code></td><td><code>replace-deleted</code></td><td><code>replace-updated</code></td></tr>
    <tr><td>Prefetch</td><td><code>prefetch-created</code></td><td><code>prefetch-deleted</code></td><td><code>prefetch-updated</code></td></tr>
    <tr><td>Bisect ref</td><td><code>bisect-ref-created</code></td><td><code>bisect-ref-deleted</code></td><td><code>bisect-ref-updated</code></td></tr>
    <tr><td>Rewritten ref</td><td><code>rewritten-ref-created</code></td><td><code>rewritten-ref-deleted</code></td><td><code>rewritten-ref-updated</code></td></tr>
    <tr><td>Per-worktree ref</td><td><code>worktree-ref-created</code></td><td><code>worktree-ref-deleted</code></td><td><code>worktree-ref-updated</code></td></tr>
  </tbody>
</table>

### Fallback refs

<table width="100%">
  <thead>
    <tr><th>Ref</th><th>Created</th><th>Deleted</th><th>Updated</th></tr>
  </thead>
  <tbody>
    <tr><td>Other <code>refs/*</code></td><td><code>ref-created</code></td><td><code>ref-deleted</code></td><td><code>ref-updated</code></td></tr>
    <tr><td>Root ref</td><td><code>root-ref-created</code></td><td><code>root-ref-deleted</code></td><td><code>root-ref-updated</code></td></tr>
  </tbody>
</table>

### Remote HEAD

<table width="100%">
  <thead>
    <tr><th>Ref</th><th>Created</th><th>Deleted</th><th>Updated</th></tr>
  </thead>
  <tbody>
    <tr><td>Remote HEAD</td><td><code>remote-head-created</code></td><td><code>remote-head-deleted</code></td><td><code>remote-head-updated</code></td></tr>
  </tbody>
</table>

### HEAD

<table width="100%">
  <thead>
    <tr><th>HEAD</th><th>Updated</th><th>Attached</th><th>Detached</th><th>Switched</th></tr>
  </thead>
  <tbody>
    <tr><td>HEAD</td><td><code>head-updated</code></td><td><code>head-attached</code></td><td><code>head-detached</code></td><td><code>head-switched</code></td></tr>
  </tbody>
</table>

The `worktree-ref-*` events describe updates under `refs/worktree/*`. They are
separate from the lifecycle events below.

### Worktree lifecycle

Git has no hook for observing
worktree lifecycle operations, so `worktree-*` events are available only when
the command is run through the `git-hooks-ext worktree` wrapper.

<table width="100%">
  <thead>
    <tr><th>Wrapper command</th><th>Event</th></tr>
  </thead>
  <tbody>
    <tr><td><code>git-hooks-ext worktree add</code></td><td><code>worktree-created</code></td></tr>
    <tr><td><code>git-hooks-ext worktree remove</code></td><td><code>worktree-removed</code></td></tr>
    <tr><td><code>git-hooks-ext worktree move</code></td><td><code>worktree-moved</code></td></tr>
    <tr><td><code>git-hooks-ext worktree lock</code></td><td><code>worktree-locked</code></td></tr>
    <tr><td><code>git-hooks-ext worktree unlock</code></td><td><code>worktree-unlocked</code></td></tr>
    <tr><td><code>git-hooks-ext worktree prune</code></td><td><code>worktree-pruned</code></td></tr>
    <tr><td><code>git-hooks-ext worktree repair</code></td><td><code>worktree-repaired</code></td></tr>
  </tbody>
</table>

The wrapper forwards all arguments to `git worktree`, compares the worktree
state before and after a successful mutating command, and emits the observed
lifecycle events. Calling `git worktree` directly bypasses it and cannot emit
these events.

Event names are identical in Git config, classic hook filenames and dry-run
output. The [command compatibility matrix](#compatibility)
shows which commands produced each event in end-to-end tests.

## Quick Start

Enable the extension in a Git repository and add a hook:

```sh
git-hooks-ext install

cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
echo "created branch: $1"
SH
chmod +x .git/hooks/branch-created
```

Now create a branch:

```sh
git branch topic
```

The hook prints:

```text
created branch: topic
```

Run `git-hooks-ext events` to list every supported event. If you use
`core.hooksPath`, put the event hook in that directory instead.

## Install

### Homebrew

```sh
brew tap ciembor/git-hooks-ext
# Homebrew 7+: trust this formula (omit on older versions).
brew trust --formula ciembor/git-hooks-ext/git-hooks-ext
brew install ciembor/git-hooks-ext/git-hooks-ext
```

The public tap builds from the checksummed source archive in the GitHub release;
it does not depend on local files or paths.

### Debian 12 (AMD64 / ARM64)

Download the package and checksums from the
[v0.3.0 release](https://github.com/ciembor/git-hooks-ext/releases/tag/v0.3.0):

```sh
arch=$(dpkg --print-architecture)
curl -fLO "https://github.com/ciembor/git-hooks-ext/releases/download/v0.3.0/git-hooks-ext_0.3.0-1_${arch}.deb"
curl -fLO https://github.com/ciembor/git-hooks-ext/releases/download/v0.3.0/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install "./git-hooks-ext_0.3.0-1_${arch}.deb"
```

Packages are available for AMD64 (Intel/AMD 64-bit) and ARM64 (AArch64).
Other architectures are not currently published.
This is a downloadable package installed with APT, not an APT repository:
automatic upgrades via `apt upgrade` are not yet available.
The release also contains the corresponding GPL-2.0-only source archive.

### Container Image

A multi-platform image is published to GitHub Container Registry:

```sh
docker run --rm ghcr.io/ciembor/git-hooks-ext:latest --version
```

Native packages are recommended when installing hooks in a repository. The
container image is useful for inspecting the CLI and processing input from a
mounted or piped-in repository environment.

After installing the package, enable it in each repository:

```sh
git-hooks-ext install
```

The command detects the installed Git version. With Git 2.54 or later it uses
config-based hooks; with Git 2.53 or older it installs a legacy
`reference-transaction` hook and prints migration instructions. After upgrading
Git, remove that legacy bridge and run `git-hooks-ext install` again.

Remove the bridge with:

```sh
git-hooks-ext uninstall
```

This removes the config-based bridge and a legacy bridge installed by a current
version of `git-hooks-ext`, while leaving any other `reference-transaction`
hook untouched.

Fedora, Arch Linux and Alpine packages are also available. See
[Distribution and Packaging](DEVELOPMENT.md#distribution-and-packaging) for
package details, build recipes and installation tests.

## Worktree Lifecycle

Git has no native hooks for removing, moving, locking, pruning or repairing a
worktree. Run worktree commands through `git-hooks-ext` to add those events:

```sh
git-hooks-ext worktree add -b feature ../feature
git-hooks-ext worktree lock --reason "offline disk" ../feature
git-hooks-ext worktree move ../feature ../feature-renamed
git-hooks-ext worktree remove ../feature-renamed
```

All arguments are forwarded to `git worktree`. The command snapshots
`git worktree list --porcelain -z` before and after a successful mutation and
emits events only for observed lifecycle changes. Read-only commands are also
forwarded, so `git-hooks-ext worktree list` behaves like `git worktree list`.
Commands run directly as `git worktree ...` bypass this frontend and do not
emit lifecycle events.

For example, a classic hook can react to a newly created worktree:

```sh
cat >.git/hooks/worktree-created <<'SH'
#!/bin/sh
printf 'worktree %s created at %s\n' "$3" "$1"
SH
chmod +x .git/hooks/worktree-created
git-hooks-ext worktree add -b feature ../feature
```

## Advanced Configuration

With Git 2.54+ config-based hooks, you can also configure hooks through Git
config:

```sh
git-hooks-ext install
git-hooks-ext add branch-created create-branch-env ./scripts/create-branch-env
```

## Hook Arguments

Reference create, update and delete hooks receive positional arguments:

```text
<short-name> <full-ref> <old-value> <new-value>
```

Rename hooks receive:

```text
<old-short-name> <new-short-name> <old-ref> <new-ref> <object-value>
```

Rename events are detected for branches, remote branches, tags and notes.
The `head-attached`, `head-detached` and `head-switched` hooks use the same
four arguments as `head-updated`. Symbolic values use Git's
`ref:refs/heads/<name>` representation.

Worktree creation, removal, pruning and repair hooks receive:

```text
<path> <head-value> <branch-ref>
```

The branch ref is empty for a detached worktree. Move hooks receive:

```text
<old-path> <new-path> <head-value> <branch-ref>
```

Lock and unlock hooks receive the path and lock reason. The reason is empty
when none was supplied:

```text
<path> <reason>
```

By default, events are emitted only for the `committed` transaction state. This
keeps user hooks post-factum and avoids aborting Git ref transactions.

## Notes

Rename detection is best-effort. Git's `reference-transaction` hook reports ref
updates, not user intent, so a delete and create of refs pointing at the same
object can look like a rename. A rename is emitted only when both the deletion
and creation have a unique match within the same ref namespace.

Events depend on Git providing a usable `reference-transaction` payload. The
hook is available from Git 2.28, but the tested versions do not report both
sides of `git branch -m`. From Git 2.31 through 2.55, ordinary `git branch -D`
and `git tag -d` report `zero -> zero`, so they cannot produce semantic delete
events through this bridge. Creation and explicit `git update-ref -d` remain
usable. See the [Git compatibility matrix](#compatibility) for tested
versions, ref backends and the reproducible probe.

References not covered by a named namespace still produce `ref-created`,
`ref-updated` or `ref-deleted` when their name is below `refs/`. Ref names
outside `refs/*` that pass through the ref backend, including custom names
such as `CUSTOM` and `misc/path`, produce `root-ref-*`. Direct `FETCH_HEAD`
and `MERGE_HEAD` are pseudorefs and are not classified as root refs. Git's
`main-worktree/` and `worktrees/<name>/` aliases for per-worktree refs are
classified by their underlying ref name; hook arguments retain the full
alias-qualified name. Git can pass alias-qualified `FETCH_HEAD` and
`MERGE_HEAD` through the ref backend, and these emit `root-ref-*`.

Every changed `HEAD` value produces `head-updated`. A known direct value
changing to a symbolic value also produces `head-attached`; a symbolic value
changing to a known direct value produces `head-detached`; and a change between
different symbolic targets produces `head-switched`. Git can report an all-zero
old value for ordinary `git symbolic-ref`, checkout and even explicit
`git update-ref --no-deref HEAD` operations when `HEAD` already exists. In
that case the extension emits only `head-updated`:
it cannot safely infer the previous attachment state from a zero value.

`remote-head-*` uses the first path component after `refs/remotes/` as the
remote name. Remote names containing `/` are ambiguous with branch names
ending in `/HEAD` when only the ref name is available; these are treated as
remote branches by this classifier.

Other ref commands can provide incomplete information too. In the tested Git
versions, `git notes append`, `git notes remove` and a second `git stash push`
report a zero old value even though those refs already exist; the bridge
therefore emits another `note-created` or `stash-created` instead of an update.
`git remote prune` removes its tracking branch without a semantic deletion.
The command matrix below separates these limitations from events emitted when
Git supplies complete transactions.

## Compatibility

### Commands and emitted events

Measured on 2026-09-19. The detailed CI matrix tests Git 2.27–2.55, Apple Git
2.39.3 and the files and reftable backends. Git versions `< 2.28` do not
provide the required `reference-transaction` hook.

This table lists each tested command, its expected event and the Git versions
that emit it. The direct `update-ref` rows show which events remain reachable
when a higher-level command omits usable transaction data. Rows for
`git-hooks-ext worktree` use the extension's frontend; plain `git worktree`
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
    <tr><td><code>worktree-created</code></td><td><code>git-hooks-ext worktree add</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-removed</code></td><td><code>git-hooks-ext worktree remove</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-moved</code></td><td><code>git-hooks-ext worktree move</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-locked</code></td><td><code>git-hooks-ext worktree lock</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-unlocked</code></td><td><code>git-hooks-ext worktree unlock</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-pruned</code></td><td><code>git-hooks-ext worktree prune</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
    <tr><td><code>worktree-repaired</code></td><td><code>git-hooks-ext worktree repair</code></td><td>Git <code>≥ 2.39.3</code></td></tr>
  </tbody>
</table>

### Git bugs

Some compatibility gaps are caused by Git bugs, rather than limitations in
`git-hooks-ext`. I filed the following reports upstream with proposed fixes
for the transaction payloads that prevent the corresponding semantic events:

1. [¹ `git branch -m` omits the destination ref from the `reference-transaction` hook](https://lore.kernel.org/git/CAOLa=ZTN1TU2A1sgEhiw=ymMYr6Ge11cMEubSaeKqr4WNU=2EQ@mail.gmail.com/T/#t).
2. [² `git branch -D` and `git tag -d` report zero OIDs from Git 2.31 onward](https://lore.kernel.org/git/CACQ=SRHthWOLVXmY6wgknOPgpQ+oB1vV-Q0AL=mK9mXb2Xy9Nw@mail.gmail.com/T/#t).

The [compatibility notes](tests/compat/README.md) explain the test method and Git's raw transaction behavior.

## Development

Build instructions, source layout, test documentation and packaging notes are
in [DEVELOPMENT.md](DEVELOPMENT.md).
