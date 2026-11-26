# 0003. Draw the Mac preview in pure Ruby, with no new gems

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #3

## Context

Layout code must run unchanged on the Mac and the Pi (C1-02, CLAUDE.md "Layout code talks to the
canvas interface only"). On the Mac there is no librgbmatrix, so the fake canvas must draw text
and write PNG files without it. The fake also has to install on a Raspberry Pi, as every gem does
(CLAUDE.md), because the Pi runs the same specs.

Two things need a decision: how the fake reads BDF fonts, which `Font` can't do without the
library, and how it writes PNG.

## Decision

- **BDF:** `BdfFont` is a small pure-Ruby parser. It reads the bounding box and each encoded
  glyph's bitmap, and skips the rest.
- **PNG:** `PngEncoder` writes the header, one `IDAT` chunk from `Zlib::Deflate` (standard
  library) and the CRCs from `Zlib.crc32`. Every row uses filter type 0.
- **Terminal:** half-block characters with 24-bit colour, two pixel rows per text line.

No gem is added. `zlib` is part of Ruby.

## Alternatives considered

- **`chunky_png` gem.** Pure Ruby and well known, so it would also install on the Pi. Rejected: a
  runtime dependency to write a PNG that needs about 30 lines of code here, and nothing else in the
  app needs images.
- **ImageMagick or `ruby-vips` for the PNG.** Rejected: native libraries, the opposite of what
  CLAUDE.md asks for on the Pi.
- **Drawing text with `Font` and librgbmatrix on the Mac.** Rejected: the library builds only on
  Linux with the Pi's GPIO code, so it can't run on a Mac.
- **Shipping the glyphs as a Ruby table.** Rejected: it copies font data into the repo, which the
  project avoids, and a BDF reader is smaller than the generated table.

## Consequences

- `bin/fake_panels` and the fake canvas need only Ruby. The Pi's `bin/setup` doesn't change.
- `BdfFont` and `Font` are separate classes with the same `height` and `baseline`. Code that draws
  text takes a font from whichever canvas it draws on. C1-04 (layout) must pick a font for each
  canvas; this ADR doesn't decide how.
- The PNG is uncompressed-filtered RGB, which is fine for a 128×32 frame. Larger images would need
  a different filter choice.
- The `y` argument of `draw_text` is a baseline in the Ruby docs. The fake follows those docs. The
  library's own placement isn't checked here, since its source isn't in the repo; the panel check
  on the Pi is the one that settles it (see the PR).
