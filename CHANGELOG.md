# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Docs and conventions scaffold: README, `CLAUDE.md`, `docs/RESUME.md` (with hardware setup),
  `docs/ARCHITECTURE.md`, `docs/adr/`, and issue and PR templates (C1-00).
- Licensed-data guard from `sports_ingest`, as a pre-commit hook, with its spec and
  `bin/setup`. Its CI check is a separate issue, #9 (C1-00).
- Claude contributes as BryceAIRich: rules in `CLAUDE.md`, setup in `docs/BOT_ACCOUNT.md` (C1-00).
- `/spawn_unblocked` and `/work_issue` commands with `script/claude/` helpers, adapted from
  `sports_ingest`, for C1 issues only, checking blockers in other repos too (tooling).
