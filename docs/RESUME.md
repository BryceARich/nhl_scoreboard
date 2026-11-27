# Picking back up

Start here after time away. Update this file when status or setup changes.

_Last updated: 2026-11-26 (C1-06)._

## Current status

Milestone C1 Scoreboard: **C1-00** (scaffold) and **C1-08** (CI, `.github/workflows/ci.yml`) are
done. **C1-01** (#2) adds the FFI binding and `bin/hello_panels`; its specs pass offline, and the
panel check is waiting for the maintainer on the Pi. **C1-02** (#3) adds the fake canvas for the
Mac; its specs pass, and `bin/fake_panels` is for a human to look at. **C1-03** (#4) adds the
logo loader; its 34 logos are pre-sized to 20×20 in `assets/logos/`. **C1-04** (#5) adds
`ScoreboardLayout`, which draws the left 64 columns from a game's live state (ADR 0005); its specs
pass, and `bin/fake_panels --frame scoreboard` is for a human to look at. **C1-05** (#6) adds the goal ticker, a band under the boards in rows 24 to 31 that scrolls the latest goal in the scoring team's colours across the whole grid (ADR 0006); its specs pass, and `--demo ticker` is for a human to look at. **C1-06** (#7) adds the main loop and
`bin/scoreboard` (ADR 0007): the game picker, adaptive polling, and offline tolerance. Its specs pass
offline; a run on the panels and through a full game are for the maintainer. Next, in order: **C1-07**.
**C1-09** (#19) adds the replays: `GameRecording` reads a recording, `PlayByPlay` builds one from a finished game's
play-by-play, `NightReplay` plays several games on one clock, and `bin/replay_night` runs a night through
the main loop on the fake panels. Its specs pass on synthetic data. The gem is in the Gemfile (ADR 0007), but nothing in C1-09 fetches
from the NHL yet: the recorder for live games is still to come. A run on a real night is for the maintainer.
CI runs the licensed-data guard and the specs and lint on every pull request and on `main`. Check each issue's
"Blocked by", which can name `sports_ingest` issues. `script/claude/ready-issues --all` does that
for you, and `/spawn_unblocked` starts sessions for the ready ones.

## Setup

On a Mac:

```bash
xcode-select --install        # skip if already installed
brew install mise libyaml openssl@3 git
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc && exec zsh
```

On a Pi (64-bit Raspberry Pi OS or Ubuntu):

```bash
sudo apt update
sudo apt install -y curl git build-essential libssl-dev libyaml-dev zlib1g-dev libffi-dev libreadline-dev
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc && exec bash
```

Then on both (building Ruby on a Pi can take 15+ minutes):

```bash
git clone https://github.com/BryceARich/nhl_scoreboard.git
cd nhl_scoreboard
bin/setup                 # Ruby, gems, pre-commit hook
bundle exec rspec         # should be green
bundle exec standardrb    # should be clean
```

### Running the app

On the Pi, as root, with the panels wired and librgbmatrix built ([`HARDWARE.md`](HARDWARE.md)).
It puts the favorite team's game on the first board while it plays today, and rotates the other games
through the remaining boards, live ones first. The board count comes from the grid:

```bash
sudo NHL_FAVORITE_TEAM=COL "$(mise which ruby)" bin/scoreboard ~/rpi-rgb-led-matrix/fonts/5x7.bdf
```

`--favorite TRI` does the same as `NHL_FAVORITE_TEAM`, and `--dwell SECONDS` sets how long each
game holds its board (10 by default). The boards default to a full grid of the panels;
`--boards N --columns N` lays out another grid, such as 7 boards in 4 columns, if it fits the panels. It reads the NHL through `sports_ingest`, which the Pi
must reach over the network. C1-07 (#8) adds the Pi service that starts it on boot.

### Fake canvas on the Mac

`FakeMatrix` and `FakeCanvas` draw in memory with the same methods as the real ones, and show the
frame in a terminal, as a PNG, or in a browser page. No panels, librgbmatrix or root needed. Give it a BDF font from
the repo above (the Mac copy works too):

```bash
script/claude/run bin/fake_panels ~/rpi-rgb-led-matrix/fonts/7x13.bdf --png preview.png
```

For a live window, serve the frame and open it in a browser (Ctrl-C stops it):

```bash
script/claude/run bin/fake_panels ~/rpi-rgb-led-matrix/fonts/5x7.bdf --cols 64 --chain 1 --frame scoreboard --serve 8080
```

Then open http://127.0.0.1:8080. The frame is the game state in `--state FILE` (JSON, default
`assets/demo_game.json`; the teams' logos come from their tri-codes). Give a different state to draw
it:

```bash
script/claude/run bin/fake_panels ~/rpi-rgb-led-matrix/fonts/5x7.bdf --cols 64 --chain 1 --frame scoreboard --state my_game.json --serve 8080
```

Add `--demo countdown` to play the state out in the browser, one second per frame: the clock counts
down to 00:00. `--demo home-logos` cycles the home team through every logo. `--demo ticker` scrolls
the latest goal across the band under the boards, a column every tenth of a second. All need `--serve` and
`--frame scoreboard`:

```bash
script/claude/run bin/fake_panels ~/rpi-rgb-led-matrix/fonts/5x7.bdf --cols 64 --chain 1 --frame scoreboard --serve 8080 --demo countdown
```

`--demo replay` plays a recording back, one frame a second. A recording is a JSON Lines file of reads
from a live game, kept outside the repo; `--state` names it. The repo's synthetic one is in
`spec/fixtures/replay_game.jsonl`:

```bash
script/claude/run bin/fake_panels ~/rpi-rgb-led-matrix/fonts/5x7.bdf --cols 64 --chain 1 --frame scoreboard --state spec/fixtures/replay_game.jsonl --serve 8080 --demo replay
```

The format and the frame rule are in [ADR 0019](adr/0019-replay-recordings-one-frame-a-second.md).

A whole night goes through the main loop with `bin/replay_night`. Put one recording (`.jsonl`) or play-by-play
payload (`.json`) per game in a directory outside the repo. `--panels` sets the boards, `--columns` the boards per
row. Give lists (`--panels 2,4 --columns 1,2`) to try every layout that fits: `--png` writes one frame per layout at
`--at` seconds, and `--serve` plays the layouts in turn, each for `--hold` seconds:

```bash
script/claude/run bin/replay_night ~/rpi-rgb-led-matrix/fonts/5x7.bdf ~/games/2026-11-25 --panels 6 --columns 3 --serve 8080
script/claude/run bin/replay_night ~/rpi-rgb-led-matrix/fonts/5x7.bdf ~/games/2026-11-25 --panels 2,4 --columns 1,2 --png night.png --at 2400
```

Fetch a day's final games first (outside the repo; on a Mac set `SSL_CERT_FILE`), then replay them one
play a second:

```bash
SSL_CERT_FILE=/etc/ssl/cert.pem script/claude/run bundle exec ruby bin/fetch_night 2026-11-25 ~/nhl-games/2026-11-25
script/claude/run bin/replay_night ~/rpi-rgb-led-matrix/fonts/5x7.bdf ~/nhl-games/2026-11-25 --panels 4,8,12 --columns 4 --pace events --serve 8080
```

On the Pi, add `--hardware` (as root, with one `--panels` and one `--columns` that match the panels) to play the night
on the real panels. It isn't run on a Pi yet.

The night is in [ADR 0019 (night)](adr/0019-night-replay-through-the-main-loop.md).

The terminal view needs 24-bit colour. Text uses `BdfFont`, a pure-Ruby reader, because `Font`
needs librgbmatrix ([ADR 0003](adr/0003-pure-ruby-fake-canvas.md)).

## Hardware

Panels, wiring, matrix options and the librgbmatrix build are in [`HARDWARE.md`](HARDWARE.md).

## Known gotchas

- **macOS system Ruby (2.6) is too old.** If `which ruby` isn't mise's, use `mise exec -- <command>`.
- **On-board sound conflicts with the matrix.** Put `blacklist snd_bcm2835` in a file under
  `/etc/modprobe.d/`, run `sudo update-initramfs -u`, and reboot.
- **Run matrix programs as root**; the library drops privileges after it sets up the GPIO, so files
  opened later must be readable by that user.
- **Pi 5:** upstream's support statements conflict. Prefer an older model until tested.
- **GPIO slowdown is a runtime option** in the C API (`RGBLedRuntimeOptions`); rows, chain and
  mapping are in `RGBLedMatrixOptions`.
- **A ticket's branch lives in one worktree.** `git switch` refuses a branch checked out elsewhere;
  see [WORKTREES](WORKTREES.md).
- **Game data goes outside the repo, and a Mac needs `SSL_CERT_FILE` to fetch it.** See
  [GAME_DATA](GAME_DATA.md).
