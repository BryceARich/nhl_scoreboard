# 0005. Draw the scoreboard from the game state by its methods, without the sports_ingest gem

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #5

## Context

The scoreboard's left 64 columns (logos, period, clock and score) must show live state (C1-04).
The state comes from `SportsIngest::NHL::GameScore` in the `sports_ingest` gem. The layout is the
only code here that reads it, and it must run unchanged on the Mac and the Pi (CLAUDE.md). This
repo's Gemfile has no app gems yet, and CLAUDE.md says every gem must install on a Pi.

Two decisions had real alternatives: how the layout gets the game, and whether this repo depends
on `sports_ingest`.

## Decision

- **The layout reads the game by its methods.** `ScoreboardLayout#draw` takes any object that
  answers `phase`, `period`, `period_type`, `clock`, and `home_team` and `away_team` (each with
  `score`). A `GameScore` answers all of them. The specs use a small struct with the same shape.
- **No `sports_ingest` dependency yet.** The Gemfile doesn't list the gem. The main loop (C1-06)
  is the first code that fetches scores, and it can add the dependency then, with the source the
  Pi can reach.

## Alternatives considered

- **Add `sports_ingest` to the Gemfile now.** The gem's own dependencies (nflverse, HTTP) would
  install on the Pi for a layout that only reads five methods. Its source isn't on rubygems yet,
  so a `git:` or `path:` entry would need the Pi to reach GitHub or a sibling checkout.
- **Copy a value object for the state into this repo.** That duplicates the gem's state model and
  drifts from it. The duck type gets the same checks with no copy.
- **Pass the layout plain values instead of the game.** The caller would unpack the game into a
  dozen arguments, and every change to the state would touch the caller too.

## Consequences

- The layout doesn't break when the gem gains fields, and the specs run offline with no gem.
- A method renamed in `GameScore` breaks the layout at run time, not at load time. The specs use
  the same names, so a rename shows up in review only if someone compares them. C1-06 should run
  the layout on a real `GameScore` once, in a spec that is skipped when the gem is absent.
- When C1-06 adds the gem, this ADR gets a follow-up, not an edit.

## Follow-up (C1-06)

The gem is now in the Gemfile for `bin/scoreboard` only; see [0007](0007-sports-ingest-as-git-gem.md).
The layout still reads games by duck type and doesn't require the gem. The spec that draws a real
`SportsIngest::NHL::GameScore` is in `spec/nhl_scoreboard/game_score_spec.rb`, skipped when the gem
is absent.
