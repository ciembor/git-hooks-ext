[![Release](https://img.shields.io/github/v/release/ciembor/git-hooks-ext?display_name=tag&sort=semver)](https://github.com/ciembor/git-hooks-ext/releases/latest)
[![License](https://img.shields.io/github/license/ciembor/git-hooks-ext)](LICENSE)
[![Lint](https://github.com/ciembor/git-hooks-ext/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/ciembor/git-hooks-ext/actions/workflows/lint.yml)
[![Tests](https://github.com/ciembor/git-hooks-ext/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/ciembor/git-hooks-ext/actions/workflows/tests.yml)
[![Coverage: 100%](https://img.shields.io/badge/coverage-100%25-brightgreen)](https://github.com/ciembor/git-hooks-ext/actions/workflows/coverage.yml)

# git-hooks-ext

[About](#about) · [Quick Start](#quick-start) · [Install](#install) ·
[Worktrees](#worktree-lifecycle) · [Configuration](#advanced-configuration) ·
[Hook Arguments](#hook-arguments) ·
[Development](DEVELOPMENT.md) · [Website ↗](https://ciembor.github.io/git-hooks-ext/)

## About

Git's `reference-transaction` hook reports raw object IDs and ref names. It
does not tell a hook that a branch was created, a tag was deleted or a ref was
renamed.

`git-hooks-ext` turns those low-level updates into semantic events such as
`branch-created`, `branch-deleted`, `tag-created` and `branch-renamed`. It also
adds the worktree lifecycle events that Git does not provide.

Supported events are:

| Branch | Remote branch | Tag | Stash | Note |
| --- | --- | --- | --- | --- |
| `branch-created` | `remote-branch-created` | `tag-created` | `stash-created` | `note-created` |
| `branch-deleted` | `remote-branch-deleted` | `tag-deleted` | `stash-deleted` | `note-deleted` |
| `branch-updated` | `remote-branch-updated` | `tag-updated` | `stash-updated` | `note-updated` |
| `branch-renamed` | `remote-branch-renamed` | `tag-renamed` | — | `note-renamed` |

| Worktree lifecycle |
| --- |
| `worktree-created` |
| `worktree-removed` |
| `worktree-moved` |
| `worktree-locked` / `worktree-unlocked` |
| `worktree-pruned` |
| `worktree-repaired` |

Event names are identical in Git config, classic hook filenames and dry-run
output.

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
[v0.1.0 release](https://github.com/ciembor/git-hooks-ext/releases/tag/v0.1.0):

```sh
arch=$(dpkg --print-architecture)
curl -fLO "https://github.com/ciembor/git-hooks-ext/releases/download/v0.1.0/git-hooks-ext_0.1.0-1_${arch}.deb"
curl -fLO https://github.com/ciembor/git-hooks-ext/releases/download/v0.1.0/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install "./git-hooks-ext_0.1.0-1_${arch}.deb"
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

When invoked, branch, remote-branch, tag, stash and note hooks receive
positional arguments:

```text
<short-name> <full-ref> <old-value> <new-value>
```

Rename hooks receive:

```text
<old-short-name> <new-short-name> <old-ref> <new-ref> <object-value>
```

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
usable. See the [Git compatibility matrix](tests/compat/README.md) for tested
versions, ref backends and the reproducible probe.

## Development

Build instructions, source layout, test documentation and packaging notes are
in [DEVELOPMENT.md](DEVELOPMENT.md).
