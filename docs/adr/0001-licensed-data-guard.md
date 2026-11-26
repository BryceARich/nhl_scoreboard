# 0001. Copy the licensed-data guard from `sports_ingest`

- **Status:** Proposed
- **Date:** 2026-11-24
- **Issue:** #1

## Context

Evolving-Hockey and PuckPedia data must never enter git in any of the maintainer's repos, and
`sports_ingest`'s M1-11 (its ADR 0014) built a guard meant for all of them. It must run in a git
hook, before any bundle is installed and on macOS system Ruby.

## Decision

We will copy the guard (stdlib Ruby script, `core.hooksPath` hook and spec), with
a CI job that runs it over tracked files and every commit in a pull request (#9). The one
change: no path is exempt here, because this app has no fixtures for those sources.

## Alternatives considered

- **Ship it in the `sports_ingest` gem.** One copy, but the hook would need the bundle installed,
  and gem consumers don't need repo tooling.
- **Git submodule or shared Action.** One copy, but more moving parts in every clone; an Action
  alone doesn't block a local commit.
- **Copy it unchanged.** Easier to sync, but leaves an exempt folder nothing here uses.

## Consequences

- Pattern fixes in `sports_ingest` must be copied here by hand.
- It stays a heuristic, and `--no-verify` skips the hook. CI (#9) checks every pull request
  again, so a skipped hook still fails the PR.
