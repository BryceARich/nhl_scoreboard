# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Goal ticker scrolls (C1-10): `MainLoop` keeps a scroll clock and draws the goal ticker one column
  every 0.1 s (`SCROLL_SECONDS`), the way `bin/fake_panels --demo ticker` does, so `bin/scoreboard` and
  `bin/replay_night` show the latest goal sliding across each row's band. Before, the step was never
  advanced, so the text stayed off the edge. Reads and rotation keep their own times (ADR 0025).
  `FakeCanvas#to_png` now appends whole rows instead of bytes, so a frame at the browser's scale is
  about ten times faster, with the same PNG bytes. `bin/replay_night --serve` retries a frame that
  fails to encode (`Zlib::DataError`, seen once on the preview thread) and skips it if the retry
  fails, so the preview keeps going. Build order: C1-10.

### Added

- Goal ticker text (C1-10): each goal scrolls as "Goal (TRI) scorer clock Pn". A goal by the
  favorite team (`--favorite`, `NHL_FAVORITE_TEAM`) scrolls as "{Team name} GOAL!!!", for example
  "Avalanche GOAL!!! scorer clock Pn" (`TeamNames`). `GoalTicker` takes `favorite:`.
- Goal queue (C1-10): each goal scrolls once across its row's band, in its team's colour, then is
  dropped. Each starts as soon as it's scored, so goals can overlap. A game's goals already there when it
  first shows are history and don't scroll; `GameDisplay` takes `scroll_history:` to replay them (the
  ticker demo does). `GoalTicker#span` and `#draw_once` draw one scroll.
- Replay length (C1-10): `bin/replay_night --serve` plays each layout for the whole night by default;
  `--hold SECONDS` now limits it.
- Replay start (C1-10): `bin/replay_night --from-period 2` starts the night when the favorite's game
  reaches that period (`NightReplay#seconds_into_period`). It needs `--serve` and a favorite.
- Board grid (C1-06): `BoardGrid` places boards on a grid of any size, with
  `columns` to a row, and each row of boards gets its own goal ticker under it, sized to that row
  (ADR 0007, which supersedes ADR 0006's band across the whole canvas). `ScoreboardLayout#draw`
  takes `y:`, and `GoalTicker#draw` takes a band's rectangle. `bin/scoreboard --boards N --columns N`
  lays out a grid other than the panels' full one. Build order: C1-06.
- Goal ticker (C1-05): `GoalTicker` scrolls the latest goal across a band under the boards (rows
  24 to 31, the full canvas width) in the scoring team's colour (`TeamColors`, one primary colour
  per team), so the text can slide from one board to the next (ADR 0006). Each board is 64 × 24
  for its scoreboard; `ScoreboardLayout#draw` takes `x:` for the board's column. `GameDisplay#show`
  takes a list of states, one board each, and `step:` and `ticker:`. `bin/fake_panels --demo ticker`
  shows games with the ticker across the boards.
- Main loop (C1-06): `GamePicker` puts the favorite team's game on the first board while it plays today
  (`--favorite`, or `NHL_FAVORITE_TEAM`), and rotates the other games through the remaining boards
  for `--dwell` seconds, live ones first. The board count comes from the matrix width, so it
  follows the panels. With no more games than boards, nothing rotates, and no two boards show the
  same game. `MainLoop` reads the day's games through `sports_ingest` with the gem's poll interval,
  keeps the last games on the panels when a read fails, and `bin/scoreboard` runs it on the panels.
  `sports_ingest` is a git gem pinned to a commit (ADR 0007, both). Build order: C1-06.
- Hardware replay (C1-09): `bin/replay_night --hardware` plays the night on the real panels, one layout sized to
  them, as `bin/scoreboard` does. Not run on a Pi yet.
- Real-game replay (C1-09): `bin/fetch_night DATE DIR` saves a day's final games as play-by-play JSON
  through `sports_ingest`, outside the repo. `bin/replay_night --pace events` steps each game one play
  at a time, `--step` seconds apart (default 1). `PlayByPlay` takes `pace:` and `step:`.
- Night replay (C1-09): `NightReplay` plays several recorded games on one clock, each starting at its
  recorded time and holding its final state after its last read. `bin/replay_night` runs a night
  through the main loop on the fake panels. `--panels` (boards) and `--columns` (boards per row) take
  lists, and each layout that fits is a variation. `PlayByPlay` takes a `start:` time, and
  `GameState#live?` tells the game picker which games are under way. See ADR 0019 (night).
- Backfill (C1-09): `PlayByPlay` turns a finished game's play-by-play into a state a second, with the
  clock interpolated between plays, so a past game can be replayed. See ADR 0019 (backfill).
- Replay (C1-09): `GameRecording` reads and writes a game's reads as JSON Lines, each state with
  its read time; `GameSequence.replay` plays them one frame a second, each showing the newest read
  at or before that second. `bin/fake_panels --state RECORDING --demo replay` plays one in the
  browser. `GameState#as_hash` writes a state back out. See ADR 0019. The recorder doesn't yet read
  from `sports_ingest`; that waits on the gem decision in #19.
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
