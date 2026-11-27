# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Goal ticker (C1-05): `GoalTicker` scrolls the latest goal across a band under the boards (rows
  24 to 31, the full canvas width) in the scoring team's colour (`TeamColors`, one primary colour
  per team), so the text can slide from one board to the next (ADR 0006). Each board is 64 × 24
  for its scoreboard; `ScoreboardLayout#draw` takes `x:` for the board's column. `GameDisplay#show`
  takes a list of states, one board each, and `step:` and `ticker:`. `bin/fake_panels --demo ticker`
  shows two games with the ticker across both.
- Main loop (C1-06): `GamePicker` shows a live game with the favorite team (`--favorite`, or
  `NHL_FAVORITE_TEAM`), else takes turns through today's games for `--dwell` seconds. `MainLoop`
  reads the day's games through `sports_ingest` with the gem's poll interval, so a live game is read
  every 10 s and an idle day every 300 s, and it keeps the last games on the panels when a read
  fails, retrying with backoff. `bin/scoreboard` runs it on the panels. `sports_ingest` is a git
  gem pinned to a commit (ADRs 0007, both). Build order: C1-06.
- Scoreboard layout (C1-04): `ScoreboardLayout` draws the left 64 columns from a game's live
  state, with the home and away logos, the period, the clock and the score at the old
  `led_scoreboard.py` positions. It reads the game by its methods, so no new gem is needed; see ADR
  0005. `TeamLogos` maps each of the 32 current teams' tri-codes to its logo.
  `GameState` is one game's state (teams, scores, period, clock, goals), read from JSON.
  `GameDisplay` shows any state on a matrix, and `GameSequence` plays a state out over time
  (`countdown`, `cycle_home_logos`). `bin/fake_panels --state FILE --demo NAME` drives them, with
  `assets/demo_game.json` as the default state.
- Team logos (C1-03): `PpmImage` reads and writes binary PPM (P6) in pure Ruby, with `resize_box`
  and `draw`; `LogoLibrary` loads `assets/logos/`, the 32 NHL_Apps logos pre-sized to 20×20 by
  `script/import_logos`, plus `kraken` and `mammoth` (34 in all, with `wings` dropped as a duplicate of `redwings`). `bin/fake_panels --logo avalanche` drew one on the Mac (`--state` since C1-04).
  See ADR 0004.
- Fake canvas for the Mac: `FakeMatrix` and `FakeCanvas` with the same methods as `Matrix` and
  `Canvas`, drawing in memory. `FakeCanvas` shows a frame as terminal cells, one per LED, or a PNG
  with a grid, and `BdfFont` and `PngEncoder` are pure Ruby, so no librgbmatrix is needed.
  `PreviewServer` serves the frame to a browser window, with no gems. `bin/fake_panels` runs it,
  with `--frame scoreboard` for the old layout and a clock that counts down (`--demo countdown` since C1-04). See
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
