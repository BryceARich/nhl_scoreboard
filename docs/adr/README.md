# Architecture decision records

Each file records one decision that had real alternatives: the context, what we chose, what we
didn't, and what follows.

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`, where `NNNN` is the issue
   number padded to four digits, not the next free number. Two ADRs from one issue share a number;
   the slug keeps them apart, so link to the file.
2. Start with status **Proposed**; change it to **Accepted** when the PR merges.
3. Add a row below.
4. Never rewrite an accepted decision. Write a new ADR and mark the old one
   **Superseded by [NNNN](NNNN-title.md)**.

| # | Decision | Status |
|---|---|---|
| [0001](0001-licensed-data-guard.md) | Copy the licensed-data guard from `sports_ingest` | Proposed |
| [0001](0001-small-docs-layout.md) | Keep docs small, with the README as an index | Proposed |
