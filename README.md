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

| Ref | Created | Deleted | Updated | Renamed |
| --- | --- | --- | --- | --- |
| Branch | `branch-created` | `branch-deleted` | `branch-updated` | `branch-renamed` |
| Remote branch | `remote-branch-created` | `remote-branch-deleted` | `remote-branch-updated` | `remote-branch-renamed` |
| Tag | `tag-created` | `tag-deleted` | `tag-updated` | `tag-renamed` |
| Note | `note-created` | `note-deleted` | `note-updated` | `note-renamed` |
| Stash | `stash-created` | `stash-deleted` | `stash-updated` | — |

### Specialized refs

| Ref | Created | Deleted | Updated |
| --- | --- | --- | --- |
| Replace | `replace-created` | `replace-deleted` | `replace-updated` |
| Prefetch | `prefetch-created` | `prefetch-deleted` | `prefetch-updated` |
| Bisect ref | `bisect-ref-created` | `bisect-ref-deleted` | `bisect-ref-updated` |
| Rewritten ref | `rewritten-ref-created` | `rewritten-ref-deleted` | `rewritten-ref-updated` |
| Per-worktree ref | `worktree-ref-created` | `worktree-ref-deleted` | `worktree-ref-updated` |

### Fallback refs

| Ref | Created | Deleted | Updated |
| --- | --- | --- | --- |
| Other `refs/*` | `ref-created` | `ref-deleted` | `ref-updated` |
| Root ref | `root-ref-created` | `root-ref-deleted` | `root-ref-updated` |

### Remote HEAD

| Ref | Created | Deleted | Updated |
| --- | --- | --- | --- |
| Remote HEAD | `remote-head-created` | `remote-head-deleted` | `remote-head-updated` |

### HEAD events

| Event | Emitted when |
| --- | --- |
| `head-updated` | Every changed `HEAD` value |
| `head-attached` | `HEAD` changes from a known direct OID to a symbolic target |
| `head-detached` | `HEAD` changes from a symbolic target to a known direct OID |
| `head-switched` | `HEAD` changes between symbolic targets |

The `worktree-ref-*` events describe updates under `refs/worktree/*`. They are
separate from the `worktree-*` lifecycle events emitted by the extension's
`git-hooks-ext worktree` frontend.

| Worktree lifecycle |
| --- |
| `worktree-created` |
| `worktree-removed` |
| `worktree-moved` |
| `worktree-locked` / `worktree-unlocked` |
| `worktree-pruned` |
| `worktree-repaired` |

Event names are identical in Git config, classic hook filenames and dry-run
output. The [command compatibility matrix](#compatibility)
shows which commands produced each event in end-to-end tests.

## Quick Start

Enable the extension in a Git repository and add a hook:

```sh
# Git 2.54+ (config-based hooks)
git-hooks-ext install

# Git 2.53 and older (use this instead)
# git-hooks-ext install --legacy

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
[v0.2.0 release](https://github.com/ciembor/git-hooks-ext/releases/tag/v0.2.0):

```sh
arch=$(dpkg --print-architecture)
curl -fLO "https://github.com/ciembor/git-hooks-ext/releases/download/v0.2.0/git-hooks-ext_0.2.0-1_${arch}.deb"
curl -fLO https://github.com/ciembor/git-hooks-ext/releases/download/v0.2.0/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install "./git-hooks-ext_0.2.0-1_${arch}.deb"
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

After installing the package, enable it in each repository with the command
matching your Git version:

```sh
# Git 2.54+
git-hooks-ext install

# Git 2.53 and older
git-hooks-ext install --legacy
```

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

| Hook | Command | Supported Git versions |
|:---|:---|:---:|
| `branch-created` | `git branch topic` | Git `≥ 2.28` |
| `branch-updated` | `git commit` | Git `≥ 2.28` |
| `branch-deleted` | `git branch -D topic` | `2.28 ≤ Git ≤ 2.30` |
| `branch-deleted` | `git update-ref -d refs/heads/topic` | Git `≥ 2.28` |
| `branch-renamed` | `git branch -m old new` | ❌ |
| `branch-renamed` | `git update-ref --stdin` (heads) | Git `≥ 2.28` |
| `remote-branch-created` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-updated` | `git fetch origin` | Git `≥ 2.28` |
| `remote-branch-deleted` | `git remote prune origin` | ❌ |
| `remote-branch-deleted` | `git update-ref -d refs/remotes/origin/topic` | Git `≥ 2.28` |
| `remote-branch-renamed` | `git remote rename origin upstream` | Git `≥ 2.55` |
| `remote-branch-renamed` | `git update-ref --stdin` (remotes) | Git `≥ 2.28` |
| `tag-created` | `git tag v1` | Git `≥ 2.28` |
| `tag-updated` | `git tag -f v1` | Git `≥ 2.28` |
| `tag-deleted` | `git tag -d v1` | `2.28 ≤ Git ≤ 2.30` |
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

The [compatibility notes](tests/compat/README.md) explain the test method and Git's raw transaction behavior.

## Development

Build instructions, source layout, test documentation and packaging notes are
in [DEVELOPMENT.md](DEVELOPMENT.md).
