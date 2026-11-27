# 0029. Follow the local day's games in the main loop, and drop a final game after one dwell

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #29

## Context

The main loop (ADR 0007) reads whatever `SportsIngest::NHL.scores` returns and keeps every game in
the rotation. Two things go wrong on a real day of games:

- `scores` with no date asks for the NHL's current date (Eastern time), not the day the app's clock is
  on, so an evening in a time zone behind Eastern can show the next day's games or miss today's.
- A final game stays in the rotation for the rest of the day, so the boards keep showing a finished
  game. When no game is left to show, the loop skips the draw, so the last frame stays on the panels.

The issue asks the loop to follow today's games as they start and finish, poll the live ones, drop
a final game after its dwell, and show an idle state on a day with no games.

## Decision

- **The day is the local calendar day.** `NhlScoreboard::DayScores` asks `sports_ingest` for the
  games of `Date.today` (the app's time zone) on every read, so the loop rolls over at local
  midnight. `bin/scoreboard` passes the gem's `scores(date:)`; the gem is still the only NHL reader.
- **A final game holds its board for one dwell, then leaves.** `MainLoop` records the first read
  that sees a game final, and leaves it out of the rotation once `dwell` has passed. A game is
  identified by its two teams' tri-codes, since each read returns new objects. Games the day's read
  no longer lists are forgotten, so a later game between the same teams starts its dwell afresh.
- **No games means blank boards.** When nothing is left to show, `MainLoop` draws an empty frame
  instead of skipping the draw, so the panels go dark rather than keep a finished game.
- **Polling is unchanged.** Each read gives every game the gem's poll interval; a game that starts
  mid-run joins the rotation on the next read.

## Alternatives considered

- **Use the NHL's date (`scores` with no date).** It is what the gem does by default and needs no
  date logic, but it isn't the app's day, so the boards disagree with the local calendar the issue
  asks for. We take the local day.
- **Drop finals in the picker.** `GamePicker` could skip final games. It has no clock and no memory
  of when a game ended, so the dwell would need a second clock inside it. The loop already owns the
  clock and the dwell, so the loop keeps the rule.
- **Keep finals until the day ends.** That is the old behaviour: a final game stays on the boards all
  day, and a night of replay shows finished games the same way. The issue asks for them to leave.
- **Key finals by a game ID.** `sports_ingest` games have IDs, but the replay's game states and the
  specs' fakes don't. The tri-code pair works for all three and a single day never repeats it.
- **Keep the last frame when no game is left.** The old behaviour; it leaves a finished game on
  the panels after its dwell, which is the bug this ADR fixes.

## Consequences

- The night replay (ADR 0019) now drops a finished game after one dwell, as a live day does. Its
  spec was updated to match. Replays show the same boards a live day would.
- A day that rolls over at midnight local time drops any game still live past midnight: its next
  read is for the new date. That is the rule the issue asks for; a game running past midnight
  leaves the panels.
- The loop reads the NHL once per poll interval as before, and one final game costs one dwell of
  board time, so no extra requests are added.
- A real day on the panels is for the maintainer to check. Specs drive the loop with a fake feed
  and never hit the network.
