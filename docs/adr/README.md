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
| [0002](0002-ffi-to-librgbmatrix.md) | Bind librgbmatrix with Ruby FFI, loaded at runtime | Proposed |
| [0003](0003-pure-ruby-fake-canvas.md) | Draw the Mac preview in pure Ruby, with no new gems | Proposed |
| [0004](0004-ppm-logos-presized.md) | Pre-size the team logos to 20×20 and read P6 PPM in pure Ruby | Proposed |
| [0005](0005-layout-reads-game-state-by-duck-type.md) | Draw the scoreboard from the game state by its methods, without the sports_ingest gem | Proposed |
