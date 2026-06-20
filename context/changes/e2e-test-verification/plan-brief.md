# E2E Test Verification — Plan Brief

> Full plan: `context/changes/e2e-test-verification/plan.md`
> Research: `context/changes/e2e-test-verification/research.md`

## What & Why

Playwright E2E covers the MVP happy path (auth, full case journey, demo) but
misses three user-visible edge cases already proven in Capybara: form validation
UX, cross-user case isolation (404), and invalid sign-in. This change adds
risk-driven browser specs for Demo Day certification without duplicating RSpec
security oracles.

## Starting Point

Five Playwright regression tests in three files; eight Capybara system examples
include validation and isolation coverage Playwright lacks. Request/service
layers (135 RSpec examples) own all security and IDOR oracles.

## Desired End State

Nine Playwright regression tests (excluding `capture-*`): new
`debugging-case-validation.spec.ts` (2 tests), new `user-isolation.spec.ts` (1
test), plus one invalid sign-in test in `authentication.spec.ts`. Helpers gain
`storageState` auth reuse. Full `bin/e2e` and `bin/ci` green; no RSpec changes.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|------------------|--------|
| Spec granularity | One new/edited spec per phase | Matches research P1/P2 gaps; reviewable increments | Research |
| Security oracles | RSpec only | cost×signal — DB/prompt checks cheapest in request specs | Research / Test plan |
| Isolation seeding | Owner creates case via UI in `beforeAll` | No Rails factory access from TypeScript; no new test API | Plan |
| Auth reuse | Introduce `storageState` in helpers | User constraint; reduces flaky repeated sign-ups | Plan |
| Analyze failure UX | Out of scope | `ClientResolver` always succeeds in test env — needs harness | Research |
| Invalid sign-in | Include as Phase 3 | Low-cost auth UX parity with request spec | Research P2 |
| CI policy | Playwright stays optional | Per test-plan §7 — local `bin/e2e` only | Test plan |

## Scope

**In scope:**

- `e2e/debugging-case-validation.spec.ts` (new, 2 tests)
- `e2e/user-isolation.spec.ts` (new, 1 test)
- `e2e/authentication.spec.ts` (add 1 test)
- `e2e/helpers.ts` (`storageState` helpers)
- `.gitignore` entry for `e2e/.auth/`

**Out of scope:**

- Analyze failure browser spec, production demo gate, IDOR matrix in browser
- RSpec security oracle duplication, Playwright in CI, `capture-*` changes
- test-plan.md updates (optional follow-up)

## Architecture / Approach

Three additive Playwright specs mirroring Capybara assertions with `getByRole`
selectors. Phase 1 introduces `storageState` auth helpers. Phase 2 uses owner
UI session to seed a case URL, then a fresh other-user session asserts public 404.
Phase 3 adds invalid sign-in to existing auth spec. Each phase gates on
targeted Playwright → full `bin/e2e` → `bin/ci`.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Validation spec | Form error UX + metadata preservation in Chromium | URL/path mismatch vs Capybara after failed POST |
| 2. User isolation spec | Cross-user show → 404, no content leak | Owner UI seeding flakiness / case URL capture |
| 3. Invalid sign-in | Wrong password error UX in browser | Must not weaken existing auth tests |

**Prerequisites:** Node deps + Chromium (`mise exec -- npm run test:e2e:install`);
local `bin/e2e-server` via `playwright.config.ts`  
**Estimated effort:** ~1 session, 3 phases

## Open Risks & Assumptions

- Failed create may redirect to `/debugging_cases` or re-render `/debugging_cases/new` — assert form + errors, not URL alone
- Serial `beforeAll` owner setup adds ~10–15s to isolation spec; acceptable for certification path
- Optional headed smoke (Phase 3 manual) catches layout issues rack_test cannot

## Success Criteria (Summary)

- Playwright regression count 5 → 9 (excl. `capture-*`); all green via `bin/e2e`
- Capybara and request security specs unchanged and passing via `bin/ci`
- No DB scan, prompt inspection, or IDOR matrix duplication in Playwright
