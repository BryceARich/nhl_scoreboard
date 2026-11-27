# 0007. Put the favorite team's game on the first board, rotate the rest with live games preferred; keep the last games when reads fail

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #7

## Context

The scoreboard runs unattended through a game (#7 acceptance). It has to decide which game to show
when several are on, poll at a rate that fits each game's phase, and keep showing something when
the NHL or the network stops answering. `sports_ingest` (ADR 0025 there) recommends a poll
interval per phase and leaves the loop to the caller.

## Decision

- **Picker (`GamePicker`).** The board count comes from the matrix: its columns across the chain
  divided by the 64-column board width (`GamePicker.board_count_for`), so 2 today and more when the
  panels grow. The favorite team's game takes the first board whenever it's playing today, pre-game and
  final included. The other boards take the rest in turn, each game holding its board for `dwell`
  seconds (default 10), and live games are preferred.
  - **No more games than boards:** nothing rotates. The favorite comes first, then live games, then
    the rest, in a fixed order until a game's state changes.
  - **More games than boards:** every board shows a different game. The rotation takes the live
    games when there are enough for the free boards, else live games first and then the rest.
  - One game today takes the first board and the other boards stay empty.
  The rotation position comes from the time since it started, so the picker keeps no game data.
  The favorite is set with `--favorite` or `NHL_FAVORITE_TEAM`.
- **Polling (`MainLoop`).** The next read comes after the shortest wait the poll rule gives any
  game. With no game left to poll (all final, or no games today), it rereads every 300 s.
  The loop wakes at least every `dwell` seconds to rotate, and at each read.
- **Offline (`MainLoop`).** A failed read keeps the last good games on the panels and logs one
  line. It retries after 5 s, then doubles up to 300 s, and resets on the first good read. Any
  `StandardError` counts as a failed read, so a dropped socket, a bad payload and a changed
  schema all behave the same. A failure never ends the process.

## Alternatives considered

- **Only a live favorite preempts.** The first version did this, so a pre-game favorite sat in the
  rotation. The maintainer wants the favorite on the first board whenever it's playing today, so the
  preference holds across the whole game.
- **Rotate only, ignore the favorite.** Simpler, but a home-team fan would miss the game they
  care about during a busy night. Rejected.
- **Exit on a read error and let systemd restart it (C1-07).** The panels would go dark during
  every network blip. Keeping the last frame is better for a display in a room. The service
  manager still restarts the process if it crashes.
- **Rescue only `SportsIngest::Error`.** Socket and timeout errors from Net::HTTP may not all be
  wrapped, so the loop would crash on some outages. Rescuing `StandardError` and logging it is
  the safer default; a bug in drawing isn't rescued, since it's outside the read.
- **Threads: one for reads, one for drawing.** The rotation is a pure function of time and the
  reads are rare, so one loop with a computed sleep is enough. Threads would add locking around
  the game list for no gain.

## Consequences

- The loop is testable with a fake source, a fake display and a fake clock; the specs cover the
  board pairing for any board count, the live preference, the rotation, the stillness on a short day, the backoff and the idle reread without the network.
- A stuck read that never raises and never returns blocks the loop. `sports_ingest`'s HTTP client
  sets timeouts, so this shouldn't happen, but C1-07's service should restart a process that
  stops logging.
- The goal ticker (C1-05) isn't drawn yet; the right half of the panels stays dark until then.
