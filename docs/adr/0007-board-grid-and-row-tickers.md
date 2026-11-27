# 0007. Lay boards out on a grid of any size, with each row of boards owning its own goal ticker

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #7

## Context

ADR 0006 put one goal ticker in a band across the whole canvas, under every board. That assumes the
boards form one row. The panels may be wired for other layouts (1×1, 1×4, 4 on top with 3 below,
or 4×4 with one missing), and the layout code only places boards horizontally (`ScoreboardLayout#draw`
took `x:` and no `y:`). A single full-width band can't serve a grid whose rows differ in width, and
text sliding from one row into the next makes little sense when the rows are different games.

## Decision

- **A board is a rectangle.** It is 64 columns by 24 rows, and its scoreboard is drawn inside that
  rectangle only, at an origin `(x, y)` (`ScoreboardLayout#draw` takes `x:` and `y:`).
- **`BoardGrid` places boards.** `BoardGrid.new(boards:, columns:)` fills the grid row by row, with
  `columns` boards to a row, so a short last row leaves its right-hand cells empty. `origin(index)`
  gives a board's `(x, y)`. `for_canvas(width:, height:)` makes a full grid of a canvas. Rows and
  columns are not limited, so the grid grows with the number of boards.
- **A row is 32 rows tall:** its boards, then its own ticker band, 8 rows high, under them. This is
  one panel's height. The band is as wide as the boards in its row.
- **Each row's ticker shows that row's latest goal**, from that row's games only. Pixels outside a
  band's columns are cleared, so the text can't leave the band.
- **The picker takes its board count from the grid** (`GamePicker#board_count`), so the choice of
  games follows the layout.

## Alternatives considered

- **One band across the whole canvas (ADR 0006).** It only works for a single row, and text would
  slide from one row's game into another's, which mixes unrelated games. Rejected, and ADR 0006 is
  superseded by this decision.
- **A ticker per board.** Each board would need 32 rows, which doesn't fit a 24-row board on the
  current panels without shrinking the scoreboard. It also gives a short ticker to a board that
  scrolls text from its neighbour. A band per row fits the existing panel height instead.
- **Describe the layout as panels and columns.** A panel is a hardware unit and a board is a
  logical slot, and boards don't always align with panels. Keeping the grid in boards, and the
  chain in `MatrixSettings`, keeps each layer about one thing.
- **Lay the grid out from a config file.** Left for later. `bin/scoreboard --boards N --columns N`
  is enough until the real layout is known.

## Consequences

- The hardware (two boards, one row, 128 × 32 panels) is the default: `BoardGrid.for_canvas` gives
  two boards in one row, with the same ticker band it has now.
- A grid that doesn't fit the panels is refused with a message, not drawn clipped.
- Orientation (rotated panels) isn't handled. A rotation would be a transform applied to the
  rectangle, which the grid can take later without changing how a board is drawn.
- The goal ticker on the Pi now draws only when the display is given a ticker. `bin/scoreboard`
  passes one, so each row's band shows its goals.
