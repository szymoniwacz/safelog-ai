# Account Access (S-01) — Plan Brief

> Full plan: `context/changes/account-access/plan.md`

## What & Why

Roadmap **S-01** proves FR-001 end-to-end: a visitor can sign up, sign in, and sign out with email/password, and protected pages stay gated. F-01 landed Devise scaffold and manual-only verification; this slice adds **request specs** and light UX polish so S-02 can trust auth before building the north-star intake flow.

## Starting Point

F-01 delivered: `devise_for :users`, generator Devise views, `AuthenticatedController`, `DashboardController` root, layout nav with email + sign out (`app/views/layouts/application.html.erb`). RSpec exists from F-03 but has **no auth/request specs** yet. No case routes — cross-user case isolation specs wait for S-02.

## Desired End State

User completes sign-up → lands signed in → visits `/` → sees dashboard; sign out → guest redirected from `/` to login; invalid credentials show safe errors. Request specs cover registration, session create/destroy, and root gating. `bin/ci` green with new specs. No debugging-case features.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Test layer | Request specs only (no Capybara/system) | Fast CI; F-01 already manual browser proof; system tests add deps for thin slice | Plan |
| User fixtures | `FactoryBot` + `User` factory | Standard Rails pattern; F-03 established RSpec | Plan |
| Devise helpers | `Devise::Test::IntegrationHelpers` in request specs | Official Devise integration test support | Plan |
| UI scope | Minimal copy/nav polish only | PRD speed bias; no custom auth design system | Plan |
| Case isolation | Defer to S-02 | No case routes/models exposure yet | Plan |
| Password policy | Devise default (≥ 6 chars) | Matches F-01 / AGENTS.md | Plan |
| Extra Devise modules | None | AGENTS.md hard rule | Plan |

## Scope

**In scope:** FactoryBot, Devise request helpers, registration/session/dashboard request specs, optional light Devise view copy, `bin/ci` green.

**Out of scope:** Debugging cases, intake, authorization across users' cases (S-02), OAuth, password recovery, confirmable, custom styled auth chrome, system/Capybara specs.

## Architecture / Approach

```
Guest → Devise registration/session → signed-in session → DashboardController (AuthenticatedController)
                                                              ↑
                                         request specs assert redirect when guest
```

Specs hit Devise routes and `GET /` directly; no new controllers beyond polish.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Test harness | FactoryBot, Devise helpers, User factory | Missing helper include breaks sign_in in specs |
| 2. Request specs | Register, login, logout, root gating | Devise mapping / flash assertions brittle |
| 3. UX polish | SafeLog-branded auth copy, nav consistency | Scope creep into full UI |

**Prerequisites:** F-01. **Estimated effort:** ~1 session across 3 phases.

## Open Risks & Assumptions

- Assumes stock Devise Turbo compatibility with `button_to` sign out (already in layout).
- GHA test job needs `RAILS_MASTER_KEY` (from F-03 Phase 1).
- Cross-user authorization tests land with case routes in S-02.

## Success Criteria (Summary)

- Request specs prove sign-up, sign-in, sign-out, and guest blocked from `/`.
- `bin/ci` passes including new specs.
- Manual smoke: same flows work in browser (quick confirm).
