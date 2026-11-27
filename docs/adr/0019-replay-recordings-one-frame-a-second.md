# 0019. Store a game recording as JSON Lines of timed states, and replay one frame a second

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #19

## Context

C1-09 replays a real game on the fake panels, so the scoreboard and goal ticker can be checked
against real events. A recording is the states read from the live feed, saved as they came. The
replay has to show the frames the main loop would have drawn, and the recordings are kept outside
the repo (CLAUDE.md, the licensed-data rule).

Two decisions had real alternatives: the file format, and how the replay turns reads into frames.

## Decision

- **A recording is JSON Lines.** Each line is a `GameState` as `GameState#as_hash` writes it (the
  format `GameState.from_h` reads), plus an `at` key with the read time in seconds since the epoch.
  One file per game, appended to on each read.
- **Replay makes one frame a second.** Second 0 is the first read's time. Each second shows the
  newest read at or before it. Reads that come closer than a second are skipped in the frames; a
  gap holds the last state until the next read.

## Alternatives considered

- **One frame per read.** Simple, but a poll every 15 seconds would replay as 15 seconds of
  nothing, and the clock would jump. It would not match what the main loop drew.
- **A single JSON array per file.** Rewritten whole on every read, so a crash mid-write loses the
  game. Lines can be appended and a torn last line is the only damage.
- **SQLite.** A new native dependency for a file that is only read in order. CLAUDE.md asks that
  installs work on a Pi, and this needs nothing beyond `json`.
- **Store the raw NHL payloads.** Replay would then need the `sports_ingest` parser to run, and
  the recording would break when the gem changes. The state format is the one the layout reads.

## Consequences

- Replay needs no gem and no network; the specs use a synthetic fixture in `spec/fixtures/`.
- The `at` key is a read time, not a game clock. A recording made while the loop was offline has a
  gap, and the replay holds the last state through it.
- Who writes recordings is open. The recorder takes states and times, so the `sports_ingest` read
  can call it once the gem question in #19 is settled (see the issue comments).
