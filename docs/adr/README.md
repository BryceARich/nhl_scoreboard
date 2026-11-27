# Architecture decision records

Each file records one decision that had real alternatives: the context, what we chose, what we
didn't, and what follows.

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`, where `NNNN` is the issue
   number padded to four digits, not the next free number. Two ADRs from one issue share a number;
   the slug keeps them apart, so link to the file.
2. Start with status **Proposed**; change it to **Accepted** when the PR merges.
3. Add a row below.
4. A ticket that defers a decision to another ticket adds a row here as **Open**, naming the ticket
   that owns it, and closes it with a link to the ADR that decides it.
5. Never rewrite an accepted decision. Write a new ADR and mark the old one
   **Superseded by [NNNN](NNNN-title.md)**.

| # | Decision | Status |
|---|---|---|
| [0001](0001-licensed-data-guard.md) | Copy the licensed-data guard from `sports_ingest` | Proposed |
| [0001](0001-small-docs-layout.md) | Keep docs small, with the README as an index | Proposed |
| [0002](0002-ffi-to-librgbmatrix.md) | Bind librgbmatrix with Ruby FFI, loaded at runtime | Proposed |
| [0003](0003-pure-ruby-fake-canvas.md) | Draw the Mac preview in pure Ruby, with no new gems | Proposed |
| [0004](0004-ppm-logos-presized.md) | Pre-size the team logos to 20×20 and read P6 PPM in pure Ruby | Proposed |
| [0005](0005-layout-reads-game-state-by-duck-type.md) | Draw the scoreboard from the game state by its methods, without the sports_ingest gem | Proposed |
| [0006](0006-ticker-band-below-the-boards.md) | Put the goal ticker in a band below the boards, across the whole canvas | Superseded by [0007](0007-board-grid-and-row-tickers.md) |
| [0007](0007-board-grid-and-row-tickers.md) | Lay boards out on a grid of any size, with each row of boards owning its own goal ticker | Proposed |
| [0007](0007-sports-ingest-as-git-gem.md) | Read the NHL through sports_ingest, from its git repo and pinned to a commit | Proposed |
| [0007](0007-main-loop-picker-and-offline-reads.md) | Pick the favorite team's live game first, then rotate; keep the last games when reads fail | Proposed |
| [0019](0019-replay-recordings-one-frame-a-second.md) | Store a game recording as JSON Lines of timed states, and replay one frame a second | Proposed |
| [0019](0019-night-replay-through-the-main-loop.md) | Play a night of recorded games through the main loop on one clock, with the boards and columns as inputs | Proposed |
| [0019](0019-backfill-recordings-from-play-by-play.md) | Build a finished game's recording from its play-by-play, one read a second, in this repo | Proposed |
