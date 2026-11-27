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

The canvas is 128×32 for two boards side by side (a grid is more). Each board is 64×32: its
scoreboard (logos, period, clock and score) takes rows 0 to 23. The goal ticker is a band across the
whole canvas in rows 24 to 31, so its text can slide from one board to the next
([ADR 0006](adr/0006-ticker-band-below-the-boards.md)). Panels and matrix options are in
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
| `lib/nhl_scoreboard/goal_ticker.rb`, `team_colors.rb` | `GoalTicker` scrolls the latest goal across a band under the boards, in the scoring team's colour ([ADR 0006](adr/0006-ticker-band-below-the-boards.md)); `TeamColors` maps tri-codes to colours (C1-05) |
| `lib/nhl_scoreboard/game_picker.rb`, `main_loop.rb`, `bin/scoreboard` | `GamePicker` chooses the game (a live favorite first, else a rotation); `MainLoop` reads through `sports_ingest` with adaptive polling and keeps the last games when a read fails; `bin/scoreboard` runs it on the panels (C1-06, ADR 0007) |
| `assets/logos/` | 34 team logos, 20×20 PPM, made by `script/import_logos` ([ADR 0004](adr/0004-ppm-logos-presized.md)) (C1-03) |
| `lib/nhl_scoreboard/` | `Matrix`, `Canvas`, `Font`, `MatrixSettings` (C1-01); `native.rb` and `native/` are the only C binding ([ADR 0002](adr/0002-ffi-to-librgbmatrix.md)) |
| `lib/nhl_scoreboard/` (fake) | `FakeMatrix`, `FakeCanvas`, `BdfFont`, `PngEncoder`, `PreviewServer`: pure Ruby, no C ([ADR 0003](adr/0003-pure-ruby-fake-canvas.md)) (C1-02) |
| `.github/` | Issue and PR templates; `workflows/ci.yml` (licensed-data guard, specs and lint) |

App paths are added here by the issues that create them.
