# 0007. Read the NHL through sports_ingest, from its git repo and pinned to a commit

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #7

## Context

The main loop (C1-06) must read live games. CLAUDE.md says game data comes through
`sports_ingest` and this repo never calls NHL endpoints itself. ADR 0005 left the gem out of the
Gemfile until the first code fetched scores, so this is where it's added. `sports_ingest` is not
published to RubyGems, and the Pi has to install everything the Gemfile lists (CLAUDE.md).

## Decision

- The Gemfile lists `sports_ingest` with `git:` from `github.com/BryceARich/sports_ingest` and a
  `ref:` set to one commit (`c48c4ce` at the time of this ADR). Bundler records the commit in
  `Gemfile.lock`, so every install gets the same code.
- It's in the default group, because `bin/scoreboard` needs it at run time, not only in tests.
- Only `bin/scoreboard` requires it, through `require "sports_ingest/nhl"` (the gem's own advice,
  so no ESPN, nflverse or CSV code loads). The library under `lib/nhl_scoreboard/` still reads
  games by duck type and doesn't require the gem (ADR 0005).
- Bumping the pin is a one-line change in the Gemfile followed by `bundle lock`, reviewed in its
  own PR.

## Alternatives considered

- **`path:` to a sibling checkout.** Works on the Mac, but the Pi has no sibling checkout, and the
  path would differ per machine. Rejected.
- **Publish `sports_ingest` to RubyGems first.** The cleanest long-term source, but it's a
  separate release process in another repo, and it would hold up this issue. Revisit once the
  gem is released; the change is one Gemfile line.
- **Track `branch: "main"` without a `ref:`.** Installs would drift each time the gem changed.
  A pin means the Pi runs what was tested here.
- **Vendor the needed files into this repo.** Copies would drift from the gem, and the gem's
  polling rules (its ADR 0025) would be duplicated. Rejected.

## Consequences

- Installing needs network access to GitHub, both for `bin/setup` on the Pi and in CI, which
  already checks out a public repo. The gem's own dependencies (`zeitwerk`, `csv`) are pure Ruby
  and install on the Pi.
- The specs don't touch the network: the scoreboard specs use fake games, and the one spec that
  uses a real `GameScore` builds it in place.
- When the gem moves to RubyGems or its API changes, the pin and the readers
  `ScoreboardLayout` uses are the two things to check.
