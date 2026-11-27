# 0006. Clip the goal ticker by drawing order, not with a canvas clip

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #6

## Context

The right 64 columns hold a goal ticker that scrolls text from right to left (C1-05). Scrolled text
runs past column 64 into the logo area. The canvas interface has `set_pixel`, `fill` and
`draw_text`, and no clip rectangle. The real canvas is a C call through FFI (ADR 0002), and
adding a clip there would mean new C code that can't be tested off the Pi.

## Decision

- **Draw the ticker first, then the layout.** `GameDisplay#show` fills the canvas black, the
  `GoalTicker` draws the scrolled text, and then `ScoreboardLayout` clears the left 64 columns
  pixel by pixel and draws the logos and text. Any ticker text that ran left of column 64 is
  overwritten by the clear.
- **The layout clears only its own columns.** It used to `fill` the whole canvas, which would have
  erased the ticker. It now clears with `set_pixel`, 64 × 32 calls per frame.
- **Text is measured off the canvas.** The ticker finds the text's width by drawing it at column
  128, past the right edge, where every pixel is clipped. The width sets the scroll cycle.

## Alternatives

- **A clip rectangle in `Canvas`.** This is the clean answer, but it needs a new C call that the
  Mac can't test, and it widens the binding for one caller.
- **Draw the text into a separate buffer and copy it.** The canvas can't be read back, so this
  would mean a second canvas and a copy per frame.
- **Only scroll text that fits.** Long goal descriptions would then never show in full, and the
  ticker would lose its point.

## Consequences

- The ticker and the layout must be drawn in that order. `GameDisplay` owns the order, and its
  spec checks that the ticker lands in the right 64 columns.
- Pixels drawn off the canvas (past column 128) rely on the canvas clipping them. The fake canvas
  does; the real `led_canvas_*` calls should too, but that is unverified until the Pi run.
