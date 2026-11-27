# 0019. Build a finished game's recording from its play-by-play, one read a second, in this repo

- **Status:** Proposed
- **Date:** 2026-11-26
- **Issue:** #19

## Context

Recording a game as it's played (ADR 0019 in this repo, the first draft of #19) needs the recorder
running during the game. A game that's already over can't be recorded, and the live score endpoint
keeps no history. The play-by-play endpoint does keep every event with its game time, and
`sports_ingest` already reads it for goals (ADR 0020 there).

Turning those events into scoreboard states is interpretation, not fetching. It's a scoreboard
concern, so it belongs here.

## Decision

- **`PlayByPlay` in this repo turns a play-by-play payload into snapshots.** It takes the parsed
  JSON, the same shape `sports_ingest` fetches, and returns one `GameRecording::Snapshot` a second of
  game time. Recordings written from it replay through the existing `GameSequence.replay`.
- **The clock is interpolated linearly between two plays in the same period.** A play with no next
  play in its period runs down at the same rate until the period's end.
- **The fetch stays in `sports_ingest`.** This class takes data; it doesn't call the NHL.

## Alternatives considered

- **Put the converter in `sports_ingest`.** It would turn events into scoreboard states inside the
  data gem, which has no scoreboard concepts. The gem would also grow a view it has no other use for.
- **Hold the clock still between plays.** Simpler, but the clock would sit at 20:00 for two minutes
  before a goal, which doesn't look like a game.
- **Interpolate across stoppages as if play ran through them.** This is what the linear rule does.
  A real clock stops at whistles, so a replay runs slow in stoppages. Recording the stoppage times
  from the play-by-play would fix this but needs a rule for each whistle; deferred.

## Consequences

- A finished game can be replayed on the fake panels without the recorder running during the game.
- Replay of a backfill drifts from the real clock by each stoppage's length. The goals, scores and
  periods are exact.
- The `at` of a backfill snapshot is game time, not a read time. Replay only uses the differences
  between reads, so it works either way; [`GameRecording`](../../lib/nhl_scoreboard/game_recording.rb)
  documents both.
- Reading the play-by-play from the NHL still needs the `sports_ingest` gem in this repo. That
  decision is the open question on #19.
