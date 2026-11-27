# Architecture

How the scoreboard is put together. Decisions are in [`adr/`](adr/README.md).

> **Status:** written in C1-00. C1-01 added the matrix layer and its `lib/` paths, and C1-02 the
> fake canvas for the Mac; the rest is still plan. When code lands and differs, update this file in the same PR.

## Data flow

```mermaid
flowchart LR
    ingest["sports_ingest/nhl<br/>scores, live state, goals,<br/>poll interval, cache"] --> loop["Main loop (C1-06)<br/>game picker, polling,<br/>offline tolerance"]
    loop --> layout["Scoreboard layout (C1-04)<br/>Goal ticker (C1-05)"]
    logos["PPM logos (C1-03)"] --> layout
    layout --> canvas{{"Canvas interface"}}
    canvas --> real["Matrix canvas (C1-01)<br/>FFI to librgbmatrix, on the Pi"]
    canvas --> fake["Fake canvas (C1-02)<br/>terminal cells, PNG and a browser page, on the Mac"]
```

| Layer | Responsibility | Must not |
|---|---|---|
| **sports_ingest** | Fetch, parse and cache NHL data (its [repo](https://github.com/BryceARich/sports_ingest)) | — |
| **Main loop** | Choose the game, poll at an adaptive rate, survive network loss | Draw pixels |
| **Layout and ticker** | Turn game state into draw calls | Fetch data, or know which canvas it has |
| **Canvas** | Set pixel, fill, draw text in a BDF font, swap on vsync | Know about hockey |
| **Assets** | Read P6 PPM logos, pre-sized to 20×20 | Need a native image library |

## Display

Boards sit on a grid of any size, `columns` to a row, filled row by row (`BoardGrid`, ADR 0007). A
board is 64×24: its scoreboard (logos, period, clock and score) takes rows 0 to 23 of its
rectangle. Each row of boards is 32 rows tall, with its own goal ticker in the 8 rows under its
boards, sized to the boards in that row. The grid's size comes from the panels or from configuration,
and a row's ticker only shows that row's games. Panels and matrix options are in
[`HARDWARE.md`](HARDWARE.md).

## What exists now

| Path | Contents |
|---|---|
| `script/licensed-data-guard`, `script/lib/`, `.githooks/` | Licensed-data guard and its pre-commit hook |
| `.claude/commands/`, `script/claude/` | `/spawn_unblocked`, `/work_issue` and their helpers |
| `spec/` | RSpec specs |
| `bin/setup` | Ruby, gems and hook |
| `bin/hello_panels` | Draws "hello" on the panels (C1-01) |
| `bin/fake_panels` | Draws "hello" or the scoreboard frame on the fake canvas: terminal, PNG, or a browser page with `--serve` (C1-02) |
| `lib/nhl_scoreboard/scoreboard_layout.rb`, `team_logos.rb` | `ScoreboardLayout` draws one 64-column board from a game's state by its methods ([ADR 0005](adr/0005-layout-reads-game-state-by-duck-type.md)); `TeamLogos` maps tri-codes to logos (C1-04) |
| `lib/nhl_scoreboard/game_state.rb`, `game_display.rb`, `game_sequence.rb` | `GameState` (JSON in, same readers as `GameScore`), `GameDisplay` (shows one or more states on a matrix, one board each), `GameSequence` (demos that play a state out: `countdown`, `cycle_home_logos`) (C1-04) |
| `lib/nhl_scoreboard/goal_ticker.rb`, `team_colors.rb` | `GoalTicker` scrolls the latest goal across a band under a row of boards, in the scoring team's colour ([ADR 0007](adr/0007-board-grid-and-row-tickers.md), superseding [ADR 0006](adr/0006-ticker-band-below-the-boards.md)); `BoardGrid` places each board and row band on any grid (ADR 0007); `TeamColors` maps tri-codes to colours (C1-05) |
| `lib/nhl_scoreboard/game_picker.rb`, `main_loop.rb`, `day_scores.rb`, `bin/scoreboard` | `GamePicker` chooses the games for every board (the favorite on the first board, live games preferred on the rest, no game on two boards; the board count comes from the grid); `MainLoop` reads through `sports_ingest` with adaptive polling, keeps the last games when a read fails, drops a final game after one dwell, and blanks the boards with no games; `DayScores` reads the local day's games; `bin/scoreboard` runs it on the panels (C1-06, C1-11, ADRs 0007 and 0029) |
| `lib/nhl_scoreboard/scoreboard_layout.rb`, `team_logos.rb` | `ScoreboardLayout` draws the left 64 columns from a game's state by its methods ([ADR 0005](adr/0005-layout-reads-game-state-by-duck-type.md)); `TeamLogos` maps tri-codes to logos (C1-04) |
| `lib/nhl_scoreboard/game_state.rb`, `game_display.rb`, `game_sequence.rb` | `GameState` (JSON in, same readers as `GameScore`), `GameDisplay` (shows any state on a matrix), `GameSequence` (demos that play a state out: `countdown`, `cycle_home_logos`) (C1-04) |
| `lib/nhl_scoreboard/game_recording.rb` | `GameRecording`: a game's reads as JSON Lines with their times, read back for replay; `GameSequence.replay` plays them one frame a second ([ADR 0019](adr/0019-replay-recordings-one-frame-a-second.md)) (C1-09) |
| `lib/nhl_scoreboard/night_replay.rb`, `bin/replay_night` | `NightReplay` plays a night of recorded games on one clock, through the main loop's picker and grid, on the fake panels ([ADR 0019 (night)](adr/0019-night-replay-through-the-main-loop.md)) (C1-09) |
| `lib/nhl_scoreboard/play_by_play.rb` | `PlayByPlay` turns one finished game's play-by-play into a state a second, with the clock interpolated between plays ([ADR 0019 (backfill)](adr/0019-backfill-recordings-from-play-by-play.md)) (C1-09) |
| `assets/logos/` | 34 team logos, 20×20 PPM, made by `script/import_logos` ([ADR 0004](adr/0004-ppm-logos-presized.md)) (C1-03) |
| `lib/nhl_scoreboard/` | `Matrix`, `Canvas`, `Font`, `MatrixSettings` (C1-01); `native.rb` and `native/` are the only C binding ([ADR 0002](adr/0002-ffi-to-librgbmatrix.md)) |
| `lib/nhl_scoreboard/` (fake) | `FakeMatrix`, `FakeCanvas`, `BdfFont`, `PngEncoder`, `PreviewServer`: pure Ruby, no C ([ADR 0003](adr/0003-pure-ruby-fake-canvas.md)) (C1-02) |
| `.github/` | Issue and PR templates; `workflows/ci.yml` (licensed-data guard, specs and lint) |

App paths are added here by the issues that create them.
