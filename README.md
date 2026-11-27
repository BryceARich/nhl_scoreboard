# nhl_scoreboard

A live NHL scoreboard on LED matrix panels driven by a Raspberry Pi, written in Ruby. Game data
comes from the [sports_ingest](https://github.com/BryceARich/sports_ingest) gem. It replaces the
Python scoreboard in NHL_Apps (`led_scoreboard.py`).

> **Status:** the matrix binding and a panel test (C1-01), and the scoreboard layout on the fake
> canvas (C1-04). There's no main loop yet.
> See [`docs/RESUME.md`](docs/RESUME.md) for current status and the next issues.

## Docs

| Read | For |
|---|---|
| [`docs/RESUME.md`](docs/RESUME.md) | Status, setup, hardware (panels, wiring, librgbmatrix), gotchas. **Start here.** |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | How the pieces fit, and what each issue adds |
| [`docs/adr/`](docs/adr/README.md) | Decisions and why |
| [`CLAUDE.md`](CLAUDE.md) | Project rules: code, docs, branches, licensed data |
| [`docs/BOT_ACCOUNT.md`](docs/BOT_ACCOUNT.md) | Setting up the account Claude contributes as |
| [`CHANGELOG.md`](CHANGELOG.md) | What changed |

## Quick start

With [mise](https://mise.jdx.dev) installed (see [setup](docs/RESUME.md#setup)):

```bash
bin/setup              # Ruby, gems, and the licensed-data pre-commit hook
bundle exec rspec      # tests, offline
bundle exec standardrb # lint
```

Work is tracked in [issues](https://github.com/BryceARich/nhl_scoreboard/issues) titled
`[C1-yy]`, in build order.
