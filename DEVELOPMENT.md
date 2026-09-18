# Development

Development and release notes for `git-hooks-ext`. For installation and usage,
see the [README](README.md).

## Build

```sh
make
make test
make lint
make coverage
```

`make coverage-html` writes an HTML report to `coverage/html/index.html`.

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

## Debugging

For local development or tests, inspect events without running hooks:

```sh
printf '%s\n' \
  '0000000000000000000000000000000000000000 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/topic' |
  ./git-hooks-ext reference-transaction committed --dry-run
```

Example output:

```text
branch-created topic refs/heads/topic 0000000000000000000000000000000000000000 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

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

## Distribution and Packaging

### Other Linux Distributions

Debian 13 and Ubuntu 24.04 / 26.04 LTS use the `.deb` installation commands in
the [README](README.md#debian-12-amd64--arm64). Compatibility tests install the
published Debian 12 package rather than producing redundant
distribution-specific packages.

Native package recipes are available for:

- Fedora 44: `packaging/fedora/git-hooks-ext.spec` (RPM, x86-64 / AArch64).
- Arch Linux: `packaging/arch/PKGBUILD` (x86-64; not yet submitted to AUR).
- Alpine 3.24: `packaging/alpine/APKBUILD` (APK, x86-64 / AArch64).

Native binary packages and recipes are attached to the
[v0.1.0 release](https://github.com/ciembor/git-hooks-ext/releases/tag/v0.1.0).
Download the file for your distribution and architecture (`uname -m`), plus
`SHA256SUMS`, and verify it with `sha256sum --check --ignore-missing SHA256SUMS`.
The package installation matrix passed all 11 combinations; see the
[Podman test run](https://github.com/ciembor/git-hooks-ext/actions/runs/35344574755).

These recipes use the checksummed release source. To build and test them with
Podman on the corresponding architecture:

```sh
make test-package-fedora
make test-package-arch
make test-package-alpine
```

Outputs are exported to `dist/fedora/`, `dist/arch/` and `dist/alpine/`.
The `Linux distribution packages` GitHub Actions workflow runs native builds
and installation, hook and removal tests, plus the Debian / Ubuntu tests.
Arch Linux is tested only on x86-64, not on the separate Arch Linux ARM project.
Build dependencies remain in builder containers, not consumer containers.

Install a downloaded native package with its distribution's package manager:

```sh
# Fedora
sudo dnf install ./git-hooks-ext-0.1.0-1.fc44.*.rpm
# Arch Linux
sudo pacman -U ./git-hooks-ext-0.1.0-1-x86_64.pkg.tar.zst
# Alpine (verify the release checksum first; no trusted APK repository yet)
sudo apk add --allow-untrusted ./git-hooks-ext-0.1.0-r0-alpine3.24-*.apk
```

Alpine packages are signed with a disposable build key; that key is not added
to users' trusted keys. `--allow-untrusted` is required for standalone APKs.
No DNF, pacman or APK update repository is configured by these downloads.

### Package Builds

`VERSION` is the single build/package version; `git-hooks-ext --version`
reports it. The initial version is `0.1.0`, licensed under GPL-2.0-only.

#### Homebrew (local macOS)

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

#### APT / Debian

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

The `Debian packages` GitHub Actions workflow builds a selected release tag on
native AMD64 and ARM64 runners. Each runner uses Podman with Debian 12 to run
the regular suite, build its native package, and test APT installation, actual
hooks and removal in a separate container. Tested `.deb` files are retained as
workflow artifacts; publication to a release is a separate step.

#### Installation Tests

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
