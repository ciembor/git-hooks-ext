# Mutation Review

Measured on 2026-09-18 with Mull 0.34.1 / LLVM 19, ASan and UBSan:

- 90 mutants: 86 killed, 4 survived, no timeouts.
- Raw mutation score: 95.56% (Mull prints a truncated 95%).
- `make mutation` fails at the unchanged default threshold of 100%.
- No mutator exclusions or adjusted-score calculation are used.

This is a pre-refactor snapshot, not an allowlist or a measured score for the
current source layout. The refactor moves installation into `hook_install.c`,
process handling into `process.c` (`run_process` becomes `process_run`), and
quoting into `shell_command.c`. Regenerate reports with `make mutation` after
code changes; old reports refer to the previous file locations.

## Fixed Test Gaps

The suite now detects the previously surviving changes to apostrophe buffer
sizing, command buffer sizing, the full reference-event array boundary,
missing `add` arguments, directory creation error handling and both boundaries
of the `free_updates` loop. Tests verify exact allocation cleanup and execute
the shell command stored in Git config, rather than only comparing its text.
Negative tests also reject sanitizer diagnostics and check the exit code for
missing arguments.

Redundant manual `core.hooksPath` resolution was removed: Git already resolves
it through `git rev-parse --git-path hooks`. Tests cover relative, absolute,
missing and empty hook paths; an empty path selects the current directory.

## Remaining Survivors

1. `cmd_install_legacy`: `mkdir(...) < 0` becomes `<= 0`.
   On success, the newly created directory exists, so the following
   `access(..., F_OK) != 0` is false and both expressions accept it.
   On failure both evaluate `access`. This is equivalent for a stable
   filesystem, not a proof under concurrent deletion or permission changes
   between the calls. The suite does not simulate those races.
2. `cmd_install_legacy`: `fprintf(...) < 0` becomes `<= 0`.
   The format always writes a nonempty bridge script. A successful write
   returns a positive character count; an error returns a negative value.
   Zero is not a reachable result for this call.
3. `run_process`: `waitpid(...) < 0` becomes `<= 0`.
   The call waits for one positive child PID with options `0`. Success returns
   that PID, and failure returns `-1`. Zero requires `WNOHANG`, which is absent.
4. `read_command_line`: `len > 0` becomes `len >= 0`.
   In the measured pre-refactor version, successful `fgets` of real Git path
   output reads at least one non-NUL
   character, so `len` is positive. EOF fails earlier; a newline-only line
   has length one. This relies on Git emitting text without an initial NUL.
   A replacement Git executable emitting binary output is not tested and
   could expose an out-of-bounds read in the mutant.

The latter input-domain assumption and the filesystem-race assumption are
explicit limits of this review, not grounds for claiming 100% mutation score.
