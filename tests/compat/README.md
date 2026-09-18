# Git compatibility matrix

This probe measures the payload produced by Git itself, independently of
`git-hooks-ext`. A hook call is useful only when it contains the real old or
new object ID required to classify the ref update.

Run it against the installed Git:

```sh
tests/compat/reference-transaction.sh "$(command -v git)" files
```

Build and probe an upstream release:

```sh
tests/compat/build-git.sh 2.55.0 files
tests/compat/build-git.sh 2.55.0 reftable
```

Source archives and builds are cached outside the repository under
`${TMPDIR:-/tmp}/git-hooks-ext-git-compat`. Set `GHE_COMPAT_CACHE` or
`GHE_COMPAT_JOBS` to override the cache or build parallelism.
The `Git compatibility` workflow runs the measured version and backend matrix,
checks the expected `usable_update` column and uploads each raw TSV result.

## Results

Measured on 2026-09-19. `Yes` means the committed transaction contained all
object IDs needed for the semantic event.

| Git | Ref format | Branch create | `branch -D` | `branch -m` | Tag create | `tag -d` | `update-ref -d` |
|---|---|---:|---:|---:|---:|---:|---:|
| 2.27.0 | files | No | No | No | No | No | No |
| 2.28.0 | files | Yes | Yes | No | Yes | Yes | Yes |
| 2.29.0 | files | Yes | Yes | No | Yes | Yes | Yes |
| 2.30.0 | files | Yes | Yes | No | Yes | Yes | Yes |
| 2.31.0 | files | Yes | No | No | Yes | No | Yes |
| 2.35.0 | files | Yes | No | No | Yes | No | Yes |
| 2.39.3 upstream | files | Yes | No | No | Yes | No | Yes |
| 2.39.3 Apple Git-146 | files | Yes | No | No | Yes | No | Yes |
| 2.42.0 | files | Yes | No | No | Yes | No | Yes |
| 2.55.0 | files | Yes | No | No | Yes | No | Yes |
| 2.55.0 | reftable | Yes | No | No | Yes | No | Yes |

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
