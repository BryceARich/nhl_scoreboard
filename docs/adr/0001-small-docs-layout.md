# 0001. Keep docs small, with the README as an index

- **Status:** Proposed
- **Date:** 2026-11-24
- **Issue:** #1

## Context

People and Claude sessions read these docs at the start of every task, so one large file crowds out
the context window. `sports_ingest` had to split its README after it grew.

## Decision

The README is an index. Status, setup and hardware are in `docs/RESUME.md`, structure in
`docs/ARCHITECTURE.md`, decisions in `docs/adr/`, rules in `CLAUDE.md`. Files aim for under 150
lines and split by topic when they pass that. Setup stays in `RESUME.md` (issue #1 asks for it)
until it outgrows it. Changelog entries go straight into `CHANGELOG.md`.

## Alternatives considered

- **`docs/SETUP.md` and `docs/sources/` now, as in `sports_ingest`.** This app has little setup yet,
  and its one data source is documented in that repo.
- **Changelog fragments (`changelog.d/`).** They prevent conflicts between parallel PRs, but the C1
  issues are mostly a chain, so they'd cost tooling for little.
- **One long README.** Simplest at first, and what `sports_ingest` moved away from.

## Consequences

- Readers follow a link for detail. Reviewers have to ask for a split when a file grows.
- If PRs start running in parallel, changelog conflicts may justify fragments later.
