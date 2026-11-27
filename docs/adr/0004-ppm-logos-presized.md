# 0004. Pre-size the team logos to 20×20 and read P6 PPM in pure Ruby

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #4

## Context

The scoreboard draws each team's logo in a 20×20 box (C1-03). The logos come from NHL_Apps as
`tsn_pixelated_logos`: 32 binary PPM (P6) files, 128×128 each. The scoreboard must read them the
same way on the Mac and the Pi, and every gem must install on a Pi (CLAUDE.md), so an image gem
is ruled out for the same reason as in [ADR 0003](0003-pure-ruby-fake-canvas.md).

Two decisions had real alternatives: where the resize to 20×20 happens, and which format the
committed assets use.

## Decision

- **Resize once, at import.** `script/import_logos` box-averages each 128×128 logo to 20×20 and
  writes it to `assets/logos/`. The committed files are already 20×20, so the app never resizes.
- **Read P6 in pure Ruby.** `PpmImage` parses the header (with `#` comments) and the pixel bytes
  with the standard library only. It writes P6 too, for the import script.
- **Keep PPM.** The files stay in the format the source uses, so the import needs no decoder.

## Alternatives considered

- **Resize at runtime.** Rejected: every run would repeat the same work for 32 logos, and the
  result would depend on the resize code on each machine. Pre-sized files are the same everywhere.
- **Store PNG.** Rejected: reading PNG needs a decoder (zlib filters, interlacing), which is more
  code than PPM, and nothing in the scoreboard needs PNG input. `PngEncoder` only writes previews.
- **`mini_magick` or `ruby-vips`.** Rejected: native dependencies, which the Pi install rules
  exclude, to do a resize once.
- **Keep the 128×128 files and let the layout scale them.** Rejected: the layout works on
  whole pixels, and scaling 20 pixels to 128 loses the detail the 20×20 art was made for.

## Consequences

- The logos are trademarks of their teams and the NHL. This repo commits them as NHL_Apps did;
  they are not Evolving-Hockey or PuckPedia data, so the licensed-data guard does not cover them.
- **Transparency.** P6 has no alpha channel. A logo marks its transparent pixels with magenta
  (255, 0, 255), `PpmImage::TRANSPARENT`, and `draw` skips them. No existing logo uses that colour.
  `kraken` and `mammoth` were keyed from their RGBA sources, with alpha below 128 keyed out.
- To change a logo, run `script/import_logos` again on the new 128×128 source and commit the output.
