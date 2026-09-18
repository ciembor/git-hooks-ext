# git-hooks-ext

Version: 0.1.0. License: [GPL-2.0-only](LICENSE).

`git-hooks-ext` is a small C helper that turns Git's low-level
`reference-transaction` hook input into semantic ref events.

It is meant to be installed as a `reference-transaction` hook. On Git versions
with config-based hooks and `git hook run --allow-unknown-hook-name`, it can
then fan out events such as:

- `branch-created`
- `branch-deleted`
- `branch-updated`
- `branch-renamed`
- `remote-branch-created`
- `remote-branch-deleted`
- `remote-branch-updated`
- `remote-branch-renamed`
- `tag-created`
- `tag-deleted`
- `tag-updated`
- `tag-renamed`
- `stash-created`
- `stash-deleted`
- `stash-updated`
- `note-created`
- `note-deleted`
- `note-updated`
- `note-renamed`

Event names are identical in Git config, classic hook filenames and dry-run
output.

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

### Debian 12 ARM64

Download the package and checksums from the
[v0.1.0 release](https://github.com/ciembor/git-hooks-ext/releases/tag/v0.1.0):

```sh
curl -fLO https://github.com/ciembor/git-hooks-ext/releases/download/v0.1.0/git-hooks-ext_0.1.0-1_arm64.deb
curl -fLO https://github.com/ciembor/git-hooks-ext/releases/download/v0.1.0/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install ./git-hooks-ext_0.1.0-1_arm64.deb
```

The published Debian package currently supports ARM64 only, not AMD64.
This is a downloadable package installed with APT, not an APT repository:
automatic upgrades via `apt upgrade` are not yet available.
The release also contains the corresponding GPL-2.0-only source archive.

After installation, run `git-hooks-ext install --legacy` in each repository
where you want to enable the additional hook events.

## Build

```sh
make
make test
make lint
make coverage
```

`make coverage-html` writes an HTML report to `coverage/html/index.html`.

## Packages

`VERSION` is the single build/package version; `git-hooks-ext --version`
reports it. The initial version is `0.1.0`, licensed under GPL-2.0-only.

### Homebrew (local macOS)

```sh
make package-brew
brew tap --custom-remote local/git-hooks-ext "$PWD/dist/homebrew-git-hooks-ext"
# Homebrew 7+: trust only this formula before installing.
brew trust --formula local/git-hooks-ext/git-hooks-ext
brew install --build-from-source local/git-hooks-ext/git-hooks-ext
```

The generated tap is `dist/homebrew-git-hooks-ext/`, and the matching source
archive is `dist/git-hooks-ext-0.1.0.tar.gz`. Its formula contains an absolute
local source URL and SHA-256 checksum; keep the archive available. This is a
local tap, not a published Homebrew repository. Publishing requires replacing
the local URL with a permanent release URL and adding the project homepage.
On older Homebrew versions without `brew trust`, omit that command.

For a release formula, set `SOURCE_ARCHIVE` to the exact archive uploaded to
GitHub and `SOURCE_URL` to its permanent HTTPS release URL when running
`make package-brew`. Do not recreate an already-published archive: its checksum
must match the public asset.

### APT / Debian

On Debian, install `build-essential`, `dpkg-dev` and `git`, then:

```sh
make package-deb
sudo apt install ./dist/debian/git-hooks-ext_0.1.0-1_*.deb
```

The `.deb` uses the build system's architecture, installs to `/usr/bin`, and
derives libc dependencies with `dpkg-shlibdeps`. A matching source archive,
license and documentation are included in the package outputs. Distribute
the corresponding source archive alongside the binary package.
`DEB_MAINTAINER` can override the explicitly local default package maintainer.
This builds a local-installable `.deb`; no public APT repository is configured.

### Installation Tests

```sh
make test-package-brew
brew install podman
podman machine init --cpus 2 --memory 2048 --disk-size 10 git-hooks-ext-test
podman machine start git-hooks-ext-test
make test-package-apt
```

The Homebrew test runs locally on macOS: it creates a temporary tap, installs,
runs `brew test` and actual Git branch hooks, then uninstalls and removes the
temporary tap. It refuses to overwrite any existing `git-hooks-ext` install.
The generated distribution files remain available for subsequent installation.

The APT test uses Podman and Debian 12 (`bookworm-slim`): a builder runs the
regular suite and builds the package, then a separate runtime container
installs it with APT, executes real branch hooks and purges the package.
Artifacts are exported to `dist/debian/`; containers are automatically removed.
Podman needs a Linux VM on macOS, not a macOS container. Linux hosts do not need
the `podman machine` initialization steps.
The default Podman VM uses Fedora CoreOS; this is the container engine's host,
not the package test environment. The APT test itself runs in Debian.

Installation tests are opt-in, separate from `make test`, coverage and Mull,
because they modify the package-manager state or require a container engine.
`DIST_DIR` overrides output paths; `DEBIAN_TEST_IMAGE` overrides the locally
built Debian test image tag. The test leaves the Podman machine and image
available for reruns; use `podman machine stop git-hooks-ext-test` when finished.

`make test-release-brew` installs from the public GitHub tap and exercises the
same installation checks. After building the Debian test image with
`make test-package-apt`, `make test-release-apt` downloads the published `.deb`,
verifies its checksum, installs it with APT, runs hooks and purges it in Podman.

## Source Layout

- `git-hooks-ext.c`: argument validation and CLI dispatch.
- `hook_install.c`: classic reference-transaction bridge installation.
- `hook_config.c`: config-based bridge and event hook registration.
- `shell_command.c`: shell quoting and command construction.
- `process.c`: process execution and dynamically sized output line reading.
- `git_runner.c`: Git hook paths and legacy/config-based event dispatch.
- `ref_update.c` / `ref_events.c`: ref parsing and semantic event detection.

Hook paths remain dynamically allocated through installation and execution.
Command construction measures the required size, then writes each quoted
argument once into the final buffer. `tests/unit/runtime_unit.c` exercises the
process-output and quoting helpers independently of a Git repository.

## Tests

`tests/run.sh` loads the suites and launches each test in a separate shell.
This keeps `set -e` active within test functions. Shared assertions and
repository/fake-Git fixtures live in `tests/lib/`; integration suites are
grouped by behavior in `tests/integration/`. C unit tests live in `tests/unit/`.

The runner prints TAP-style results, including explicit `SKIP` reasons for
coverage-only cases, and counts executed and skipped tests separately.
`make test`, `make coverage` and `make mutation` use the same runner.

## Static Analysis

`make lint` runs [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) on the
production sources and C test code, with and without coverage fault injection.
The `.clang-tidy` configuration checks
memory errors, suspicious expressions, dead code and function complexity.
Enabled warnings fail the command, so it can also be used in CI.

On macOS, install it with `brew install llvm`. The Makefile detects `clang-tidy`
in `PATH` and the standard Homebrew LLVM locations. For another installation:

```sh
make lint CLANG_TIDY=/path/to/clang-tidy
```

## Mutation Testing

`make mutation` uses [Mull](https://mull-project.com/getting-started/setup/) to
change comparisons, boundary conditions and negations in production C code,
then runs `tests/run.sh` against each mutant. A killed mutant means the tests
detected the change; a surviving mutant needs review for a missing assertion
or a change that does not affect observable behavior.

Install the matching Mull and Clang versions on macOS:

```sh
brew install llvm@19 mull-project/mull/mull@19
make mutation
```

The build and JSON/HTML reports are written to `mutation/`. The `.yml`
configuration is `mull.yml`; test code and coverage fault injection are not
mutated. The original instrumented build must pass the tests before mutation
analysis starts. The default required mutation score is 100%, so surviving
mutants cause the command to fail while preserving the report.
Mutation builds enable AddressSanitizer and UndefinedBehaviorSanitizer.
Negative tests reject sanitizer diagnostics instead of treating memory errors
as expected command failures. A C unit test also verifies that `free_updates`
releases every allocation exactly once, including on platforms without leak
sanitizer support. Command quoting tests execute the configured command with
empty arguments, apostrophes and literal shell expressions.
See [mutation review notes](tests/mutation-notes.md) for the measured result
and the remaining survivors. These notes do not exclude any mutants or change
the score threshold.
The HTML viewer needs an HTTP server to load `report.json` and an internet
connection for its web component. `mutation/report.txt` and
`mutation/report.json` can be inspected directly.

To collect an initial report without requiring 100%:

```sh
make mutation MUTATION_SCORE_THRESHOLD=0
```

`MUTATION_TIMEOUT` sets the timeout per test-suite run in milliseconds
(default: 30000). For installations outside the detected Homebrew locations,
set `MUTATION_CC`, `MULL_RUNNER` and `MULL_PLUGIN`. The compiler, runner and
plugin must use the same LLVM major version; `MULL_LLVM_VERSION` defaults to 19.

## Usage

For local development or tests, inspect what would be emitted:

```sh
printf '%s\n' \
  '0000000000000000000000000000000000000000 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/topic' |
  ./git-hooks-ext reference-transaction committed --dry-run
```

Example output:

```text
branch-created topic refs/heads/topic 0000000000000000000000000000000000000000 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

To use classic hook files, install the bridge:

```sh
git-hooks-ext install --legacy
```

Then create executable hook files named after semantic events:

```sh
cat > .git/hooks/branch-created <<'SH'
#!/bin/sh
echo "created branch: $1"
SH
chmod +x .git/hooks/branch-created
```

Now `git branch topic` will run `.git/hooks/branch-created`.

With Git 2.54+ config-based hooks, you can also configure hooks through Git
config:

```sh
git-hooks-ext install
git-hooks-ext add branch-created create-branch-env ./scripts/create-branch-env
```

Run `git-hooks-ext events` to list supported event names. In classic hook-file
mode, use those names directly under `.git/hooks/`, for example:

```text
.git/hooks/remote-branch-updated
.git/hooks/stash-created
.git/hooks/note-updated
```

When invoked, branch, remote-branch, tag, stash and note hooks receive
positional arguments:

```text
<short-name> <full-ref> <old-value> <new-value>
```

Rename hooks receive:

```text
<old-short-name> <new-short-name> <old-ref> <new-ref> <object-value>
```

By default, events are emitted only for the `committed` transaction state. This
keeps user hooks post-factum and avoids aborting Git ref transactions.

## Notes

Rename detection is best-effort. Git's `reference-transaction` hook reports ref
updates, not user intent, so a delete and create of refs pointing at the same
object can look like a rename. A rename is emitted only when both the deletion
and creation have a unique match within the same ref namespace.

Events depend on Git actually invoking `reference-transaction`. In the tested
Apple Git 2.39.3, `git branch -D` did not invoke it, so it cannot produce a
`branch-deleted` event through this bridge. Integration tests verify creation
with `git branch` and deletion with `git update-ref -d` and an explicit old OID,
including in SHA-256 repositories. Other Git versions and ref backends may
behave differently.
