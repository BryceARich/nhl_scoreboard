# 0008. Run the scoreboard as a systemd service, set up by one provision script

- **Status:** Proposed
- **Date:** 2026-11-27
- **Issue:** #8

## Context

On the Pi, `bin/scoreboard` has to start on boot, come back after a crash, and keep its logs from
filling the SD card. Setup today is a list of manual steps in [`RESUME.md`](../RESUME.md): mise,
librgbmatrix, bundle, then a command. Each one can go wrong on a fresh Pi, and the maintainer
should not have to repeat them by hand.

The acceptance criterion is that it starts on boot and survives a network drop. The network part
is already handled by the main loop, which keeps the last games on the panels when a read fails
(ADR 0007). The service only has to cover a dead process and a slow network at boot.

## Decision

We will run `bin/scoreboard` as a **systemd** unit, `deploy/nhl-scoreboard.service`, with
`Restart=always`, ordered after `network-online.target`, and logging to
`/var/log/nhl-scoreboard/scoreboard.log`. Logs are rotated by a logrotate config,
`deploy/nhl-scoreboard.logrotate`, that uses `copytruncate` because the service keeps the file open.

`script/pi/provision` does the setup: it runs `bin/setup` (Ruby through mise, then the gems),
builds librgbmatrix at the commit pinned in [`HARDWARE.md`](../HARDWARE.md) if the library isn't
installed, fills the placeholders in the unit, installs the unit and the logrotate config, writes
the favorite team to `/etc/nhl-scoreboard.env`, and enables the service. It runs as the checkout's
owner and calls `sudo` for the system steps. The service runs as root, since the library needs GPIO
access.

## Alternatives considered

- **cron `@reboot` with a loop script.** Simpler, but nothing restarts a crashed process, and
  logging and rotation are left to the script. We'd rebuild what systemd gives us.
- **Supervisord or a Ruby process manager.** Another dependency to install on the Pi, with no
  benefit over systemd, which Raspberry Pi OS already runs.
- **Run as a non-root user with GPIO group access.** The library's own docs say to run as root,
  because it sets up the GPIO and drops privileges only after that (RESUME's gotchas). Changing
  that is a separate decision for hardware testing.
- **A journald-only log, no logrotate.** `journalctl` already caps its size, but the README points
  to a plain log file for `tail -f`, and logrotate is the usual way to bound one. Both are kept:
  journald gets the unit's stderr, and the log file gets stdout.
- **Pin librgbmatrix in two places.** The provision script repeats the commit from `HARDWARE.md`
  so it can build unattended; the two must be kept in step when the pin moves.

## Consequences

- The Pi setup is one command, and the same unit file is what runs in production.
- The service keeps retrying after a crash, with no start limit, so the panels come back by
  themselves. A broken config therefore retries every five seconds and fills the log until someone
  fixes it; logrotate keeps that bounded.
- The unit's behaviour is checked offline in `spec/pi_provisioning_spec.rb`. Starting the service on
  a real Pi, a network drop and a reboot are for the maintainer to check.
- A future change to the librgbmatrix pin needs both `HARDWARE.md` and `script/pi/provision`.
