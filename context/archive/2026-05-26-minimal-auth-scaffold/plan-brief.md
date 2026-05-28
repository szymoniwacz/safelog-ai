# Minimal Auth Scaffold (F-01) — Plan Brief

> Full plan: `context/changes/minimal-auth-scaffold/plan.md`

## What & Why

Roadmap **F-01** requires a minimal authentication foundation before any debugging-case work: email/password accounts via Devise, session sign-in, and route-level protection so later slices can assume `current_user`. Without this, S-01 and the north-star intake slice cannot enforce per-user ownership.

## Starting Point

Rails 8.1 scaffold with SQLite wired but **no tables**, **no Devise**, **no test suite**, and only a public health route (`GET /up`). Param filtering for passwords already exists in `filter_parameter_logging.rb`.

## Desired End State

Users can register and sign in through generator Devise pages; authenticated users see a placeholder home page with minimal nav (email + sign out); guests cannot access that page; `/up` stays public for Fly. Downstream controllers inherit an `AuthenticatedController` base — not a global `ApplicationController` filter.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ------------------ | ------ |
| Scope vs S-01 | F-01 foundation only | Keeps change small; S-01 owns user-visible polish + tests | Plan |
| Test framework | Defer RSpec to S-01 | No suite today; auth request specs fit account-access slice | Plan |
| Route gating | Per-controller via base class | Avoid global filter; inherit `AuthenticatedController` for app routes | Plan |
| Devise modules | Three allowed modules only | Matches AGENTS.md and PRD minimal auth | Plan |
| Auth UI | Generator default ERB | Fastest path; styling deferred | Plan |
| Root route | Placeholder dashboard when signed in | Proves gating without case UI | Plan |
| Ownership hook | `current_user` only | Case authorization comes with domain models | Plan |
| Layout | Minimal nav (email + sign out) | Enough shell for manual smoke | Plan |
| Health check | `/up` stays public | Fly deployment health dependency | Plan |
| Password policy | Devise default (≥ 6) | PRD does not require stronger rules in F-01 | Plan |
| Verification | Manual smoke + `bin/ci` | No new tests in this change | Plan |

## Scope

**In scope:** Devise gem, `User` + migration, `devise_for :users`, generator views, `AuthenticatedController`, placeholder root, layout nav, branding fix, manual verification.

**Out of scope:** RSpec, case models, ownership specs, global `authenticate_user!`, extra Devise modules, custom passwords, encryption, log intake.

## Architecture / Approach

```
Guest → /users/sign_in (Devise) → session cookie
Signed-in → DashboardController < AuthenticatedController → root placeholder
Public → GET /up (no auth)
Future case controllers → inherit AuthenticatedController
```

Devise owns credential flows; application controllers stay thin per AGENTS.md.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Devise & User model | Gem, initializer, `users` table | Migration mis-configured modules |
| 2. Routes & gating | Devise routes, root placeholder, `/up` public | Accidental global auth breaks health |
| 3. Views & layout | Generator views, minimal nav | Layout omits CSRF/sign-out helpers |
| 4. Verify & handoff | CI green, inheritance contract documented | Skipping manual smoke hides routing bugs |

**Prerequisites:** `mise exec -- bundle install` / `bin/setup` working; empty DB acceptable.

**Estimated effort:** ~1–2 focused sessions across 4 phases.

## Open Risks & Assumptions

- **No automated auth tests until S-01** — regressions rely on manual smoke and careful inheritance discipline.
- **Per-controller gating** — any new controller inheriting `ApplicationController` directly would be unprotected until caught in review.
- Assumes server-rendered MVP (no React auth shell) per PRD Non-Goals.

## Success Criteria (Summary)

- Register, sign in, sign out work via Devise.
- `/` is authenticated-only with a visible placeholder; `/up` works for guests.
- `bin/ci` passes; downstream changes can inherit `AuthenticatedController`.
