# 0039. Keep the favorite's final game on its board after a win, and drop it at once after a loss

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #39

## Context

ADR 0029 drops every final game from the rotation once it has held its board for one dwell. For the
favorite team that is the wrong result on a win: a fan who comes back to the panels after a win
should still see the final score on the favorite's board, and after a loss the game should leave.
The issue asks for both, and for other games to keep following the normal rotation.

## Decision

- **A favorite's final game is judged by its result.** `MainLoop` keeps a final game of the favorite
  team on the boards when the favorite scored more goals, and drops it as soon as the read shows it
  final when the favorite lost. It doesn't wait for the dwell.
- **The favorite's winning game stays on board 1.** `GamePicker` already puts the favorite's game
  first whenever it plays today, so a winning final stays up without a refresh and is not replaced
  by the rotation. It leaves when the day's read stops listing it (the day rolls over at local
  midnight, ADR 0029).
- **Other final games keep the ADR 0029 rule:** one dwell after they are first seen final.
- The favorite is identified by the picker's tri-code, as the picker does. Hockey finals have no
  ties (overtime and shootouts decide them), so the score comparison picks a winner.

## Alternatives considered

- **Keep the favorite's final for one dwell, as other finals do.** That is the ADR 0029 rule. It
  drops a win after ten seconds, which is the behaviour the issue asks to change.
- **Keep every favorite's final, win or lose, until the day ends.** Simpler, but a loss would stay
  on the panels all day, which the issue rules out.
- **Drop a winning favorite's final when the rotation would show another game.** The picker never
  moves the favorite off board 1, so this would need a second rule in the picker to hand the board
  over. Left for a later issue if the maintainer wants the favorite's board to rotate after a win.

## Consequences

- The favorite's board after a win holds the final until the day rolls over, so a winning favorite
  keeps one board busy after the game ends. Other boards still rotate.
- The loss rule uses the first read that shows the game final, the same as ADR 0029 does for its
  dwell, so a delayed board (ADR 0030) drops the loss when the delayed feed shows it.
- Specs use synthetic games and never hit the network. A real game on the panels is for the
  maintainer to check.
