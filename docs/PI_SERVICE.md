# Running on boot

The Pi service, set up by `script/pi/provision`. Linked from
[`RESUME.md`](RESUME.md).

`script/pi/provision` does the Pi setup in one go: Ruby and gems through `bin/setup`, librgbmatrix at
the pinned commit (if it isn't installed), then a systemd service that starts the scoreboard on boot
and restarts it after a crash. Logs go to `/var/log/nhl-scoreboard/scoreboard.log`, rotated daily.
Run it as your own user, not as root; it calls `sudo` where it needs to:

```bash
script/pi/provision --font ~/rpi-rgb-led-matrix/fonts/5x7.bdf --favorite COL
sudo journalctl -u nhl-scoreboard -f
```

It writes the favorite team to `/etc/nhl-scoreboard.env`; edit that file and run
`sudo systemctl restart nhl-scoreboard` to change it. See [ADR 0008](adr/0008-systemd-service-and-provision-script.md). Setup and the panels are in
[`RESUME.md`](RESUME.md) and [`HARDWARE.md`](HARDWARE.md).


