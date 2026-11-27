# 0007. Pick the favorite team's live game first, then rotate; keep the last games when reads fail

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #7

## Context

The scoreboard runs unattended through a game (#7 acceptance). It has to decide which game to show
when several are on, poll at a rate that fits each game's phase, and keep showing something when
the NHL or the network stops answering. `sports_ingest` (ADR 0025 there) recommends a poll
interval per phase and leaves the loop to the caller.

## Decision

- **Picker (`GamePicker`).** A live game with the favorite team always wins. Otherwise the day's
  games take turns, each for `dwell` seconds (default 10). The rotation position comes from the
  time since it started, so the picker keeps no game data. The favorite is set with
  `--favorite` or `NHL_FAVORITE_TEAM`; with none set, the picker only rotates.
- **Polling (`MainLoop`).** The next read comes after the shortest wait the poll rule gives any
  game. With no game left to poll (all final, or no games today), it rereads every 300 s.
  The loop wakes at least every `dwell` seconds to rotate, and at each read.
- **Offline (`MainLoop`).** A failed read keeps the last good games on the panels and logs one
  line. It retries after 5 s, then doubles up to 300 s, and resets on the first good read. Any
  `StandardError` counts as a failed read, so a dropped socket, a bad payload and a changed
  schema all behave the same. A failure never ends the process.

## Alternatives considered

- **Favorite team's game always, even before it starts.** Would leave the panels on a pre-game
  screen for hours. Only live games preempt; a pre-game favorite is shown in the rotation.
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
  rotation, the favorite preemption, the backoff and the idle reread without the network.
- A stuck read that never raises and never returns blocks the loop. `sports_ingest`'s HTTP client
  sets timeouts, so this shouldn't happen, but C1-07's service should restart a process that
  stops logging.
- The goal ticker (C1-05) isn't drawn yet; the right half of the panels stays dark until then.
