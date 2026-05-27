# Archive Debugging Case (S-05) — Plan Brief

> Full plan: `context/changes/archive-debugging-case/plan.md`

## What & Why

Roadmap **S-05** (FR-010): users archive debugging cases they no longer need in the active list. Archived cases are hidden from the default index and visible via an **Archived** filter. Uses existing `archived_at` on `DebuggingCase` — no schema migration.

## Starting Point

Cases are created and viewed individually (`new`, `create`, `show`, `analyze`, export). No case index/list exists. Dashboard links only to new case. `archived_at` column present but unused.

## Desired End State

`GET /debugging_cases` lists active cases by default; `?filter=archived` shows archived cases. Case show has **Archive case** button. `POST archive` sets `archived_at`. Owner-only; cross-user archive/index denied. `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Archive field | Set `archived_at` timestamp | F-02 column; no soft-delete gem | Plan |
| Unarchive | Out of scope for MVP | FR-010 only mentions archive + filter | Plan |
| List route | `index` on `debugging_cases` | Standard REST; filter via query param | Plan |
| Filter UX | Links: Active \| Archived | Simple server-rendered toggle | Plan |
| Archived access | Owner can still open show by id from archived list | Reachable via filter per PRD | Plan |

## Scope

**In scope:** Model scopes, archive action, index + filter UI, dashboard link, request specs.

**Out of scope:** Unarchive, bulk archive, demo loader (S-06).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Archive action | Scopes + POST archive + specs | Redirect before index exists |
| 2. Case index + filter | List UI, dashboard link | Filter state in URLs |
| 3. Authorization specs | Cross-user archive/index 404 | — |

**Prerequisites:** S-02. **Estimated effort:** ~2 sessions across 3 phases.

## Success Criteria (Summary)

- Active cases on default index; archived only with filter.
- Archive button sets `archived_at` and removes case from active list.
- Cross-user archive/index blocked.
