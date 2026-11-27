# 0025. Scroll the goal ticker from the main loop's clock, redrawing ten times a second

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #25

## Context

The goal ticker never showed on the boards. `GoalTicker#draw` starts the text at the band's right
edge for step 0, and nothing advanced the step: `MainLoop#tick` drew with no step and slept for the
rotation's dwell (10 s). `bin/fake_panels --demo ticker` advanced the step itself, every 0.1 s, so the
ticker worked only there. The scroll needs its own clock, ten steps a second, and the picker's
rotation and the reads must keep their own, slower, times.

## Decision

- **The main loop owns the scroll clock.** `MainLoop` starts the clock on its first tick and passes
  `step:` to `display.show(boards, step:)`. The step is the number of {SCROLL_SECONDS} (0.1 s)
  since then, so the ticker moves one column per draw, the same rate as `--demo ticker`.
- **The loop wakes every `SCROLL_SECONDS`** and redraws. Reads still happen only when due, and the
  picker still rotates on its own dwell, from the time it started, so neither follows the wake-ups.
- **Callers pass the step through.** `GameDisplay#show` already takes `step:`. The replay's
  `BrowserDisplay` passes it on too, so `bin/replay_night` scrolls the same way, and its game clock is
  unchanged.

## Alternatives considered

- **A ticker thread in `GameDisplay`.** The display would draw on its own timer while the loop
  reads and rotates. That needs a lock around the boards it draws and two clocks to keep in step.
  Rejected: one loop with one clock is simpler to test.
- **Keep the dwell sleep and step the ticker by the dwell.** The text would jump a whole band every
  10 s, not scroll. Rejected; the issue asks for smooth scrolling.
- **Scroll only in `bin/scoreboard`.** The replay would stay broken for the maintainer's test case,
  and the two entry points would drift apart. Rejected.

## Consequences

- The loop draws the full frame ten times a second, the cost `--demo ticker` already pays on the Mac.
  The Pi has less CPU; the maintainer should check the frame rate on the panels, and the rate is one
  constant (`MainLoop::SCROLL_SECONDS`) to change.
- A read or a rotation no longer waits for the dwell sleep, but both are checked against their own
  times on each wake-up, so they happen on time to within 0.1 s.
- The specs run the loop on its own clock: the scroll step, the read and rotation timing, and a goal
  crossing a real display's band.
