# Picking back up

Start here after time away. Update this file when status or setup changes.

_Last updated: 2026-11-24 (C1-00)._

## Current status

Milestone C1 Scoreboard: **C1-00** (this scaffold) is done; no app code yet. Next, in order:
**C1-01** FFI binding (#2), **C1-02** fake canvas (#3), **C1-03** logos (#4). CI is **C1-08** (#9),
not started; until then run specs and lint by hand. Check each issue's
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

There is no app to run yet. C1-06 (#7) adds the main loop and must put its command here;
C1-07 (#8) adds the Pi service. Until then, the panel test below is the end-to-end hardware check.

### Fake canvas on the Mac

Not built yet. C1-02 (#3) adds it (terminal blocks and PNG, no hardware or librgbmatrix needed)
and must put its command here.

## Hardware setup

### Panels

Two P4 panels (4 mm pitch), each 64 wide by 32 high, **1/16 scan**, HUB75, chained into 128×32.
The pair is inferred from the old layout (128 columns, split at 64); check it against the hardware.

### Wiring

Pi header to the first panel's **input** connector, for the library's `regular` mapping, chain 1
([upstream diagram](https://github.com/hzeller/rpi-rgb-led-matrix/blob/master/wiring.md)):

| Signal | Pin | GPIO | | Signal | Pin | GPIO |
|---|---|---|---|---|---|---|
| R1 | 23 | 11 | | A | 15 | 22 |
| G1 | 13 | 27 | | B | 16 | 23 |
| B1 | 26 | 7 | | C | 18 | 24 |
| R2 | 24 | 8 | | D | 22 | 25 |
| G2 | 21 | 9 | | CLK | 11 | 17 |
| B2 | 19 | 10 | | LAT / STB | 7 | 4 |
| GND | 6 | — | | OE | 12 | 18 |

- 1/16 scan uses address lines A–D. **E stays unconnected**; it's for 64-row panels.
- Ribbon from the first panel's **output** to the second's input.
- Power panels from their own 5 V supply, sized from the panel's rating, with correct polarity and
  a ground shared with the Pi. Don't power them from the Pi's header.
- The Pi's signals are 3.3 V. Keep cables short; if pixels glitch, add a 5 V level shifter (74HCT245).

### Matrix options

As in `led_scoreboard.py`, which C1-01 carries over:

| Option | Value | Flag |
|---|---|---|
| rows | 32 | `--led-rows=32` |
| cols | 32 (library default) | `--led-cols=32` |
| chain length | 4 | `--led-chain=4` |
| parallel | 1 | `--led-parallel=1` |
| hardware mapping | `regular` | `--led-gpio-mapping=regular` |
| GPIO slowdown | 2 | `--led-slowdown-gpio=2` |

Chain 4 counts 32-column units: 4 × 32 = 128 columns. Two 64-wide panels can also be described as
cols 64, chain 2. Don't mix them (cols 64 with chain 4 is 256). A faster Pi may need more slowdown.

### Building librgbmatrix (Pi)

[rpi-rgb-led-matrix](https://github.com/hzeller/rpi-rgb-led-matrix) is C++, built from source.
Targets checked against upstream commit `a8dd685` on 2026-11-24; not yet run on this project's Pi.

```bash
git clone https://github.com/hzeller/rpi-rgb-led-matrix.git ~/rpi-rgb-led-matrix
cd ~/rpi-rgb-led-matrix
git checkout a8dd6854580b7e2b18d0f697cec94415dd8824cd
make                  # lib/librgbmatrix.a, lib/librgbmatrix.so.1 and the demo
sudo make install     # /usr/local/lib/librgbmatrix.so, headers, ldconfig
```

Panel test; a rotating square should cover both panels:

```bash
sudo examples-api-use/demo -D0 --led-rows=32 --led-cols=32 --led-chain=4 --led-parallel=1 --led-gpio-mapping=regular --led-slowdown-gpio=2
```

## Known gotchas

- **macOS system Ruby (2.6) is too old.** If `which ruby` isn't mise's, use `mise exec -- <command>`.
- **On-board sound conflicts with the matrix.** Put `blacklist snd_bcm2835` in a file under
  `/etc/modprobe.d/`, run `sudo update-initramfs -u`, and reboot.
- **Run matrix programs as root**; the library drops privileges after it sets up the GPIO, so files
  opened later must be readable by that user.
- **Pi 5:** upstream's support statements conflict. Prefer an older model until tested.
- **GPIO slowdown is a runtime option** in the C API (`RGBLedRuntimeOptions`); rows, chain and
  mapping are in `RGBLedMatrixOptions`.
