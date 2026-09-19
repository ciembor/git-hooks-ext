# Mutation Review

Measured on 2026-09-18 with Mull 0.34.1 / LLVM 19, ASan and UBSan:

- 136 mutants generated and killed.
- Mutation score: 100%.
- No mutator exclusions or adjusted-score calculation were used.
- `make mutation` passed with the default 100% threshold.

The review added coverage for shell quoting made entirely of apostrophes,
worktree snapshots larger than the initial read buffer, empty worktree paths,
and one-argument read-only `worktree` commands. Equivalent boundary mutations
were removed by expressing POSIX error results directly and by simplifying
argument copying and newline removal.

The report is generated at `mutation/report.txt` and
`mutation/report.json`. Regenerate it with `make mutation` after source or test
changes.
