# Load Demo Case (S-06) — Plan Brief

> Full plan: `context/changes/load-demo-case/plan.md`

## What & Why

Roadmap **S-06** (FR-011): one-click **Load demo case** for course demos and README walkthrough. Reuses `Intake::ProcessCaseSubmission` with a fixed checkout-timeout multi-source fixture. **Not available in production.**

## Starting Point

Full intake/analyze/export/archive flows exist. No demo loader; users must paste logs manually.

## Desired End State

Signed-in user in dev/test clicks **Load demo case** → new case with sanitized multi-source logs (shared request_id placeholders) → redirect to show. Production returns 404. Specs prove intake path and env guard. `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Intake path | Reuse `Intake::ProcessCaseSubmission` | Demo exercises real code (PRD) | Plan |
| Fixture location | `app/services/demo/case_fixture.rb` | Constants only; raw strings transient in service | Plan |
| Env guard | `development? \|\| test?` | FR-011 explicit; production 404 | Plan |
| HTTP | `POST load_demo` collection route | Mutates state; CSRF protected | Plan |
| UI visibility | Dashboard link when demo available | Minimal; no production UI leak | Plan |

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Demo fixture + service | `Demo::LoadCase` + specs | Raw fixture strings in specs only |
| 2. Route + controller | POST load_demo + env guard + request specs | Production accidentally enabled |
| 3. UI + production spec | Dashboard button; prod 404 test | — |

**Prerequisites:** S-02. **Estimated effort:** ~1–2 sessions across 3 phases.

## Success Criteria (Summary)

- Dev/test: load demo → case show with placeholders, no raw secrets persisted.
- Production: route returns 404.
- Demo reuses intake/redaction, not bypass.
