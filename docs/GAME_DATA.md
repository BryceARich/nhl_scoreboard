# Game data

Game data (play-by-play, scores, replays) never enters git. Keep it in a folder outside the repo.
The convention is `~/nhl-games/<date>`, one folder per day, for example `~/nhl-games/2026-11-25`.
CLAUDE.md's licensed-data rule still applies to Evolving-Hockey and PuckPedia data, which this
repo doesn't use.

## Fetch a day's games

`sports_ingest` reads the NHL. Run its scripts through Bundler, because `bin/` scripts don't load
the gem by themselves:

```bash
SSL_CERT_FILE=/etc/ssl/cert.pem script/claude/run bundle exec ruby <script> <args>
```

`SSL_CERT_FILE` is needed on a Mac whose Ruby lacks CA certificates. Without it the NHL request fails
with `SSLError: certificate verify failed`. On the Pi it's usually not needed.

## Pick a day with games

Check how many games a date has before you fetch. In `sports_ingest`, `SportsIngest::NHL.scores(date:)`
lists the day's games, and `final?` on each tells you which are done. A day with 14 finals makes a
good test; a day with 1 doesn't show layouts.

## Fonts

The fonts for the fake canvas and the panels live in `~/rpi-rgb-led-matrix/fonts/` on both the Mac
and the Pi (see [RESUME](RESUME.md#building-librgbmatrix-pi)). The Mac copy works for the fake
canvas.
