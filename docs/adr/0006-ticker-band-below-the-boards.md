# 0006. Put the goal ticker in a band below the boards, across the whole canvas

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #6

## Context

Each board is 64 columns by 32 rows and shows one game (ADR 0005, C1-04). A grid of boards is
built from these (for example 4 × 4 of 32 × 64). The goal ticker (C1-05) should announce events
across the grid, so text slides from one board into the next, while each board still shows its own
game. The first version put the ticker in the right half of a 128-wide canvas, which meant the text
had to be clipped at column 64 and drawn in an order that hid the overflow. That was fragile, and
it did not work across a grid.

The canvas interface has `set_pixel`, `fill`, `draw_text` and `width`, and no clip rectangle. The
real canvas is a C call through FFI (ADR 0002), and a clip there would mean new C code that can't be
tested off the Pi.

## Decision

- **Each board's scoreboard uses rows 0 to 23.** Its logos, period, clock and score fit there
  (`ScoreboardLayout::BOARD_HEIGHT`).
- **The ticker uses rows 24 to 31**, the full width of the canvas (`GoalTicker::DEFAULT_TOP`,
  `DEFAULT_HEIGHT`). The text scrolls right to left across every board, and the canvas clips it at
  the grid's outer edges.
- **The layout clears only its own board's rows.** It no longer clears the whole canvas, so it
  can't erase the band. Nothing overlaps, so the draw order no longer matters for clipping.
- **One scroll offset drives the band** for the whole grid, from the main loop. Each board gets its
  own game.

## Alternatives

- **A ticker in the right half of one board, with the text clipped at column 64.** This was the
  first version. It needed the draw-order trick, and it can't span boards.
- **A canvas clip rectangle.** It would fix the clipping, but it needs new C code that can't be
  tested off the Pi, and it still doesn't span boards.
- **A separate ticker per board.** Each board would scroll its own text, so no announcement
  crosses a board edge.

## Consequences

- A board needs 24 rows for its scoreboard and 8 for the band. A 5×7 font fits in the band, with a
  row to spare; a larger font would need the split moved.
- The band draws in a single pass, and the scroll is measured by drawing the text off the right
  edge (where every pixel is clipped) to get its width.
- Whether the real canvas clips draw calls at its edges is still unverified until the Pi run; the
  fake canvas does.
