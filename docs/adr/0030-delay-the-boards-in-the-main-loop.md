# 0030. Hold the boards back by a delay, by buffering the reads in the main loop

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #33

## Context

A viewer may watch the game on TV, and the TV feed can run about 10 seconds behind the live game.
The scoreboard then shows a goal before the viewer sees it on the broadcast. The viewer wants the
boards held back by a set number of seconds (30 in the motivating case), so the score, the clock and
the goal ticker line up with the broadcast.

The reads come from `sports_ingest` through the main loop (ADR 0007). Each read is the games as they
were at the moment it was collected. The boards draw from one read at a time, so the score, the clock
and the goals of one game always come from the same read.

## Decision

- **The loop buffers its reads with their collection times.** `NhlScoreboard::DelayedGames` keeps
  each read with the time it was collected. The boards show the newest read that is at least
  `delay` seconds old. A read is first shown at its collection time plus `delay`, so the score, the
  clock and the goals always come from one read and move together.
- **Polling keeps the newest read.** The next read still follows the poll rule on the newest read, so
  the feed is read at its normal cadence, and the delay only changes what the boards show.
- **Finals are timed from when the boards first show them.** A final game holds its board for one
  dwell from the first delayed read that shows it final (ADR 0029), not from the read that
  collected it.
- **The default is 0 seconds.** A delay of 0 shows each read at once, as before.
- **One setting for both paths.** `bin/scoreboard --delay SECONDS` and `bin/replay_night --delay
  SECONDS` pass the same `delay:` to `MainLoop`. A replay's clock is its night clock, so the delay
  works the same on a recording. `bin/replay_night --png` shows the frame a delayed board would show.
- **Reads buffered only as far as the boards need.** Reads older than the one on the boards are
  dropped, so the buffer holds a few reads at a time.

## Alternatives considered

- **Sleep before each read.** Reading the feed and then waiting would stall the scroll clock and the
  dwell timing, which depend on the loop's wake-ups (ADR 0025). It would also hold back the reads
  themselves, not only what the boards show.
- **Delay in the display.** `GameDisplay` could keep its own history. That would put game timing into
  the drawing code, which ADR 0005 keeps to the game state it is given. The loop already owns the
  reads and their times.
- **Delay each game's clock instead of its read.** Shifting the game clock alone would leave the
  score and the goals on the live time, so the boards would disagree with each other. Holding back
  whole reads keeps every part of a game in step.
- **Delay only the scores.** The same problem: the goal ticker would scroll ahead of the score.

## Consequences

- Each read is held in memory until the boards move past it. At most a few reads are held, since
  reads come every 10 to 60 seconds and the delay is in seconds.
- The boards are blank until the first read is `delay` seconds old. For a game that is already
  live when the app starts, the first shown state is the one from `delay` seconds earlier, so
  the boards show what the feed had at the time, not the current score.
- A failed read adds nothing to the buffer, so the last good read stays on the boards, as ADR 0007
  says. Under a delay the boards keep showing the old read until the next good one is due to show.
- `bin/fake_panels --live --delay SECONDS` previews the delay on the Mac, through the same `delay:`
  argument to `MainLoop`.
- Checking a delay against a live game on the panels is for the maintainer.
