# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Team logos (C1-03): `PpmImage` reads and writes binary PPM (P6) in pure Ruby, with `resize_box`
  and `draw`; `LogoLibrary` loads `assets/logos/`, the 32 NHL_Apps logos pre-sized to 20×20 by
  `script/import_logos`, plus `kraken` and `mammoth` (34 in all). `bin/fake_panels --logo avalanche` draws one on the Mac.
  See ADR 0004.
- Fake canvas for the Mac: `FakeMatrix` and `FakeCanvas` with the same methods as `Matrix` and
  `Canvas`, drawing in memory. `FakeCanvas` shows a frame as terminal cells, one per LED, or a PNG
  with a grid, and `BdfFont` and `PngEncoder` are pure Ruby, so no librgbmatrix is needed.
  `PreviewServer` serves the frame to a browser window, with no gems. `bin/fake_panels` runs it,
  with `--frame scoreboard` for the old layout and `--countdown` for a clock that counts down. See
  ADR 0003 (C1-02).
- FFI binding to librgbmatrix's C API: `Matrix` (open, canvas, offscreen canvas, swap on vsync),
  `Canvas` (set pixel, fill, clear, draw text), `Font` (BDF), and `MatrixSettings` with the
  RESUME defaults (32 rows, 4 × 32 columns, `regular` mapping, GPIO slowdown 2). Plus
  `bin/hello_panels` for the panel check. See ADR 0002 (C1-01).
- Docs and conventions scaffold: README, `CLAUDE.md`, `docs/RESUME.md` (with hardware setup),
  `docs/ARCHITECTURE.md`, `docs/adr/`, and issue and PR templates (C1-00).
- Licensed-data guard from `sports_ingest`, as a pre-commit hook, with its spec and
  `bin/setup`. Its CI check is a separate issue, #9 (C1-00).
- Claude contributes as BryceAIRich: rules in `CLAUDE.md`, setup in `docs/BOT_ACCOUNT.md` (C1-00).
- `/spawn_unblocked` and `/work_issue` commands with `script/claude/` helpers, adapted from
  `sports_ingest`, for C1 issues only, checking blockers in other repos too (tooling).
- CI workflow (`.github/workflows/ci.yml`): the licensed-data guard over tracked files and every
  commit in a pull request, and specs and `standardrb` on Ubuntu ARM64 with the Ruby from
  `.ruby-version`, on pull requests and on `main` (C1-08).
