# 0019. Play a night of recorded games through the main loop on one clock

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #19

## Context

A replay of one game (ADR 0019 in this repo) isn't enough to test the scoreboard: the panels show
several games at once, rotate them, and keep finished games on the boards. C1-06 built the main loop,
the game picker and the board grid for live games. A night of recorded games should go through the
same code, so a test or a run on the fake panels shows what a live day would.

Two decisions had real alternatives: how the games share a clock, and what the boards and columns
inputs mean.

## Decision

- **`NightReplay` holds each game's snapshots and answers "what would the loop see at this time".**
  `states_at(seconds)` returns the state of each game that has started. A game starts at its first
  snapshot and holds its last state after its last one, so finished games stay on the boards as
  final.
- **The main loop does the rest.** `bin/replay_night` and the specs give `MainLoop` a source that
  reads `NightReplay`, a clock, and the same picker and grid as `bin/scoreboard`. Nothing about
  rotation or favourites is repeated.
- **Games share one clock by their start times.** Recordings from `GameRecording` carry epoch times.
  Play-by-play payloads start at `startTimeUTC` (or a `start:` time), so the night lines up.
- **`--panels` is the number of boards, `--columns` the boards per row.** Each board is one
  64-column panel's width, as `BoardGrid` lays it out. `--variations` is how many of the night's games
  to play, first by file name. I took "variations" to mean the games of one night, not separate runs.

## Alternatives considered

- **Replay each game in its own run and join the frames.** Simple, but the picker's rotation and the
  "never the same game twice" rule would only be tested per game, and the boards would never share
  a clock.
- **Count panels as 64-column units across one row.** That is how the canvas is laid out, but it
  leaves out the rows of boards and their tickers, which `--columns` is for.
- **Drive the night from a fixed list of states per second.** Each game's reads would be
  resampled, so gaps between reads would show as stale states, not as the last read held.

## Consequences

- The spec plays a three-game night through `MainLoop` for each board and column variation, with a
  test clock. It checks the number of boards, that no game shows twice in one draw, and that every
  game gets a turn. It also draws each layout on a canvas sized by the grid.
- The night starts at its earliest game, so the first game is on a board from second zero. A game
  that starts later joins the rotation when its first read arrives.
- The night reads files, so it runs offline and never touches the NHL. The live recorder is still
  to come.
