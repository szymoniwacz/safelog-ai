---
date: 2026-06-20T22:30:07+02:00
researcher: Cursor Agent
git_commit: 005b6cb46641255118b27af451f40350e1682d83
branch: e2e-tests-verification
repository: safelog-ai
topic: "Playwright E2E gaps vs MVP edge cases"
tags: [research, e2e, playwright, capybara, test-plan, mvp]
status: complete
last_updated: 2026-06-20
last_updated_by: Cursor Agent
---

# Research: Playwright E2E gaps vs MVP edge cases

**Date**: 2026-06-20T22:30:07+02:00  
**Researcher**: Cursor Agent  
**Git Commit**: `005b6cb46641255118b27af451f40350e1682d83`  
**Branch**: `e2e-tests-verification`  
**Repository**: [szymoniwacz/safelog-ai](https://github.com/szymoniwacz/safelog-ai)

## Research Question

Compare existing test coverage and identify browser E2E gaps for MVP edge cases. For each user-visible edge case, classify coverage by layer (request/service, Capybara, Playwright), flag Playwright candidates, and respect cost×signal — do not duplicate RSpec security oracles in Playwright.

## Summary

The MVP is well defended at the **RSpec request/service layer** (66 request examples + service/model specs). **Capybara** (`spec/system/`, 8 examples, `rack_test`) covers browser-visible happy paths plus validation and user-isolation UX. **Playwright** (`e2e/`, 5 tests excluding four `capture-*` screenshot specs) mirrors the core certification path: auth, full happy-path case journey (including real file download), and demo loader.

**Playwright gaps worth closing** (risk-driven, cost×signal):

| Priority | Gap | Risk / signal | Recommendation |
|----------|-----|---------------|----------------|
| P1 | Form validation UX (no sources, metadata preserved on error) | User-visible MVP constraint; Capybara already proves it | **Playwright E2E candidate** — port Capybara scenarios |
| P1 | Cross-user case show → public 404 | Risk #3 user-visible half; Capybara covered, Playwright not | **Playwright E2E candidate** — assert 404 page, no sanitized content |
| P2 | Invalid sign-in (wrong password) | Auth UX; request-only today | **Optional Playwright candidate** — low cost, moderate signal |
| P2 | Cases index status badges / empty states | List UX; request-only detail | **Defer** — lower signal than validation/isolation |
| P3 | Analyze failure flash after retry exhaustion | Risk #7 user message; request + service proven | **Playwright candidate blocked** — `e2e-server` runs `RAILS_ENV=test`; `ClientResolver` always returns success; needs test harness hook before browser spec |

**Do not add Playwright specs for:** DB persistence oracles, AI prompt inspection, encryption-at-rest checks, log-file guards, demo production env gate, or the full IDOR matrix (analyze/archive/export). Those remain cheapest and strongest in RSpec per `context/foundation/test-plan.md` §2 and §6.9.

## Test stack baseline

| Layer | Location | Count | CI gate | Role |
|-------|----------|-------|---------|------|
| Request/integration | `spec/requests/` | 66 examples / 13 files | `bin/ci` | Auth, HTTP journeys, IDOR matrix, security oracles |
| Service/model | `spec/services/`, `spec/models/` | ~70+ examples | `bin/ci` | Redaction, intake, analyze retry/validator, encryption |
| Capybara system | `spec/system/` | 8 examples / 5 files | `bin/ci` (via RSpec) | Browser-visible flows, `rack_test` driver |
| Playwright E2E | `e2e/*.spec.ts` (excl. `capture-*`) | 5 tests / 3 files | optional `bin/e2e` | Real Chromium; download events; demo certification |

Playwright runs against `bin/e2e-server` with `RAILS_ENV=test` ([`bin/e2e-server`](https://github.com/szymoniwacz/safelog-ai/blob/005b6cb46641255118b27af451f40350e1682d83/bin/e2e-server)).

## MVP edge case coverage matrix

Legend: **Covered** = layer has meaningful assertions for the edge case. **Partial** = related path covered but not this specific assertion. **—** = no coverage at that layer.

### Authentication & session (FR-001)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Guest redirected from `/` and protected routes | Covered (`dashboard_spec`, per-route specs) | — | Covered (`authentication_spec.rb`) | Covered (`authentication.spec.ts`) | **Already covered** — all UI layers |
| Sign up with valid credentials → dashboard | Covered (`devise/registrations_spec.rb`) | — | Covered | Covered | **Already covered** |
| Sign in with valid credentials | Covered (`devise/sessions_spec.rb`) | — | Covered | Covered | **Already covered** |
| Sign out → guest blocked from dashboard | Covered | — | Covered | Covered | **Already covered** |
| Invalid password on sign-in (422, password not echoed) | Covered (`devise/sessions_spec.rb`) | — | — | — | **Stay in RSpec** (request proves status + no leak). Optional P2 Playwright for form error UX only — do not assert security oracles in browser |

### Case creation & validation (FR-002, FR-003, FR-004)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Multi-source create with in-memory redaction | Covered (`debugging_cases_spec`, `debugging_cases_security_spec`) | Covered (`process_case_submission_spec`) | Covered (`debugging_case_flow_spec.rb`) | Covered (`debugging-case-flow.spec.ts`) | **Already covered** |
| Show page: sanitized logs, placeholders, no raw secrets in HTML | Covered | — | Covered | Covered (UI text absence) | **Already covered**. UI raw-absence in Playwright is UX signal only — not a substitute for DB oracles |
| Redaction summary visible | Covered (response body) | Covered (`summary_counts_spec`) | Covered | Covered | **Already covered** |
| Cross-source `[REQUEST_N]` correlation visible | Covered | Covered | Covered | Covered | **Already covered** |
| Validation: no log sources → errors, form re-rendered | Covered (`debugging_cases_spec.rb`) | Covered | Covered (`debugging_case_validation_spec.rb`) | — | **Playwright E2E candidate (P1)** — Capybara parity |
| Validation: blank title → 422 | Covered | Covered | — | — | **Stay in RSpec** — non-UI validation; no Playwright value |
| Validation: invalid `source_type` → 422 | Covered | Covered | — | — | **Stay in RSpec** |
| Validation: metadata fields preserved on error | Covered | — | Covered (`debugging_case_validation_spec.rb`) | — | **Playwright E2E candidate (P1)** |
| Validation: pasted secrets not re-rendered on error | Covered (`debugging_cases_security_spec.rb`) | — | — | — | **Stay in RSpec** — security oracle (raw must not reappear) |
| Intake transaction rollback on partial failure | — | Covered (`process_case_submission_spec` G-01/G-02) | — | — | **Stay in RSpec** — non-UI, failure injection |
| All log sources must be submitted at create (MVP constraint) | Partial (validation) | Covered | Partial | Partial | Enforced by validation specs; no post-create source UI exists |

### Sanitized log copy (FR-006)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| User can copy sanitized log text | — | — | — | — | **No automated layer** — UI uses read-only textareas + hint ("Select all and copy"). Not a Playwright priority (no copy button; clipboard APIs add flake). Manual smoke sufficient per test-plan §7 |

### Analyze & reports (FR-007, FR-008, FR-009)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Analyze success → hypothesis report + correlation signals | Covered (`debugging_cases_analyze_spec.rb`) | Covered (`analyze_case_spec.rb`) | Covered | Covered | **Already covered** |
| Report markdown visible on show page | Covered | — | Covered | Covered | **Already covered** |
| Download report as `.md` (sanitized) | Covered (`debugging_cases_report_export_spec.rb`) | — | Partial (direct URL visit) | Covered (Playwright `download` event) | **Already covered** — Playwright adds real download signal Capybara lacks |
| Export blocked when no generated report | Covered | — | — | — | **Stay in RSpec** |
| Export/download cross-user → 404 | Covered (`authorization_spec`, export specs) | — | — | — | **Stay in RSpec** — IDOR matrix |
| Analyze cross-user → 404, no side effects | Covered | — | — | — | **Stay in RSpec** |
| Analyze failure after retry → safe alert, no report body, export 404 | Covered (`debugging_cases_analyze_spec.rb`) | Covered (`analyze_case_spec.rb`, `response_validator_spec.rb`) | — | — | **Stay in RSpec** for oracles. **Playwright candidate (P3, blocked)** for flash UX — requires harness to inject `InvalidClient` because test env always uses `FakeClient` ([`app/services/ai/client_resolver.rb`](https://github.com/szymoniwacz/safelog-ai/blob/005b6cb46641255118b27af451f40350e1682d83/app/services/ai/client_resolver.rb)) |
| Invalid AI response retried once | — | Covered (`InvalidOnceClient`) | — | — | **Stay in RSpec** — orchestration logic |
| Hypothesis framing / uncertainty in structured output | Covered (response includes fixture text) | Covered (`response_validator_spec.rb`) | Partial (heading visible) | Partial | **Stay in RSpec** for validator rules; browser asserts presence only |

### Archive & case list (FR-010)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Owner archives case → redirect, flash, archived_at set | Covered (`debugging_cases_archive_spec.rb`) | — | Covered (in flow) | Covered (in flow) | **Already covered** |
| Archived / Active filter tabs | Covered (`debugging_cases_index_spec.rb`) | — | Covered (in flow) | Covered (in flow) | **Already covered** in journey specs |
| Index: other user's cases never listed | Covered | — | — | — | **Stay in RSpec** — scoping oracle |
| Index: analysis status badges ("Analyzed", "Not analyzed") | Covered | — | — | — | **Defer** — low browser signal |
| Archive cross-user → 404 | Covered | — | — | — | **Stay in RSpec** |

### Demo loader (FR-011)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Load demo in test/dev → sanitized case | Covered (`debugging_cases_load_demo_spec.rb`) | Covered (`demo/load_case_spec.rb`) | Covered (`demo_case_spec.rb`) | Covered (`demo-case.spec.ts`) | **Already covered** |
| Demo secrets absent from UI | Covered | Covered | Covered | Covered | **Already covered** (UI layer) |
| Demo unavailable in production → 404 | Covered (env stub) | Covered (`.available?`) | — | — | **Stay in RSpec** — env gate via stub; Playwright runs test env only |
| "Load demo case" button hidden when unavailable | Covered (`dashboard_spec.rb`) | — | — | — | **Stay in RSpec** — HTML conditional |

### Access control & isolation (PRD Access Control, risk #3)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Cross-user show → 404, no sanitized content leak | Covered (`debugging_cases_authorization_spec.rb`) | — | Covered (`user_isolation_spec.rb`) | — | **Playwright E2E candidate (P1)** — certification-visible security UX |
| Cross-user analyze / archive / export matrix | Covered (`authorization_spec` + per-action specs) | — | — | — | **Stay in RSpec** — full matrix cheaper than 4+ browser tests |
| Guest gates on all mutating routes | Covered (per-route) | — | Partial (auth spec routes) | Partial (auth spec routes) | **Already covered** at HTTP layer |

### Security guardrails (risks #1–#5 — non-UI)

| Edge case | Request | Service | Capybara | Playwright | Classification |
|-----------|---------|---------|----------|------------|----------------|
| Raw substrings never persist after intake (DB scan) | Covered (`debugging_cases_security_spec.rb` + `assert_no_raw_substring_in_persisted_data`) | Covered | — | — | **Stay in RSpec only** — do not duplicate in Playwright |
| Raw substrings never in `log/test.log` after intake | Covered | — | — | — | **Stay in RSpec only** |
| Analyze prompts contain placeholders only | Covered (`debugging_cases_analyze_security_spec.rb`) | Covered (`prompt_builder_spec`, `analyze_case_spec`) | — | — | **Stay in RSpec only** |
| Metadata fields redacted on persist and in prompts | Covered | Covered | — | — | **Stay in RSpec only** |
| Export markdown contains no raw secrets | Covered (`report_export_security_spec`) | — | — | — | **Stay in RSpec only** |
| Diagnostic text encrypted at rest (ciphertext in SQLite) | — | Covered (`encryption_at_rest_spec.rb`) | — | — | **Stay in RSpec only** |
| Redaction findings never store original values | — | Covered (`engine_spec`, `redaction_finding` model) | — | — | **Stay in RSpec only** |

## Playwright inventory (gap analysis scope)

Excluded from gap analysis per scope: `capture-architect-screenshots.spec.ts`, `capture-champion-screenshots.spec.ts`, `capture-m5l4-screenshots.spec.ts`, `capture-submission-screenshots.spec.ts` (screenshot/demo artifacts, not regression guards).

| File | Tests | MVP paths exercised |
|------|-------|---------------------|
| `e2e/authentication.spec.ts` | 3 | Guest redirect; sign up; sign in after sign out |
| `e2e/debugging-case-flow.spec.ts` | 1 | Multi-source create → sanitized UI → analyze → report → **browser download** → archive → Active/Archived filters |
| `e2e/demo-case.spec.ts` | 1 | Load demo → sanitized evidence, fixture secrets absent |

Shared helpers: `e2e/helpers.ts` (`signUp`, `signIn`, `fillLogSourceSlot`).

## Capybara inventory (comparison baseline)

| File | Examples | MVP paths |
|------|----------|-----------|
| `spec/system/authentication_spec.rb` | 3 | Guest redirect; sign up; sign in/out |
| `spec/system/debugging_case_flow_spec.rb` | 1 | Full happy path (download via direct URL, not browser download event) |
| `spec/system/debugging_case_validation_spec.rb` | 2 | No sources validation; metadata preserved |
| `spec/system/demo_case_spec.rb` | 1 | Load demo |
| `spec/system/user_isolation_spec.rb` | 1 | Cross-user show → 404 |

**Capybara-only today:** validation (2), user isolation (1). These are the primary Playwright parity gaps.

## Recommended Playwright additions (plan input — not implemented)

Ordered by cost×signal. None duplicate RSpec security oracles.

### P1 — Add now (no harness changes)

1. **`e2e/debugging-case-validation.spec.ts`** (or examples in existing file)
   - Submit case with title but no log sources → error copy, form stays on new case, title preserved
   - Submit with metadata filled, no sources → description, customer reference, environment preserved
   - Mirror: `spec/system/debugging_case_validation_spec.rb`

2. **`e2e/user-isolation.spec.ts`**
   - Seed case via factory/API helper or pre-create via owner session in setup
   - Second user navigates to case URL → 404 page, no case title, no `[REQUEST_1]`
   - Mirror: `spec/system/user_isolation_spec.rb`
   - Do **not** assert HTTP status codes alone; assert visible public 404 copy

### P2 — Optional

3. **Invalid sign-in** — wrong password shows error, stays on sign-in page, password field not populated with secret (mirror request spec behavior at UI level)

### P3 — Blocked on test harness

4. **Analyze failure UX** — only after `ClientResolver` (or equivalent) accepts a test-only override (e.g. `ENV["E2E_AI_CLIENT"]=invalid`) when serving Playwright. Until then, risk #7 failure UX remains request-spec proven.

### Explicit non-candidates

- DB scans after form submit
- Prompt content inspection after analyze
- Raw SQL encryption checks
- Production demo gate
- Cross-user analyze/archive/export (keep authorization matrix in request specs)
- Clipboard/copy button tests for sanitized logs or report markdown

## Capybara vs Playwright overlap

| Concern | Capybara | Playwright | Notes |
|---------|----------|------------|-------|
| Driver | `rack_test` (no layout engine) | Chromium | Playwright catches real layout/rendering regressions |
| Download | Visits export URL directly | Native `download` event | Playwright already stronger here |
| CI | Required (`bin/ci`) | Optional (`bin/e2e`) | Per test-plan §5, §6.9 |
| Security oracles | Explicitly excluded | UI absence checks only | test-plan §6.8, §6.9 |

Adding P1 Playwright specs mostly **certification parity** with Capybara, not new risk coverage — value is real-browser confidence before Demo Day, not replacing RSpec.

## Code References

- `e2e/authentication.spec.ts` — Playwright auth smoke
- `e2e/debugging-case-flow.spec.ts` — Playwright full MVP journey + download
- `e2e/demo-case.spec.ts` — Playwright demo loader
- `spec/system/debugging_case_validation_spec.rb` — Capybara validation gaps for Playwright
- `spec/system/user_isolation_spec.rb` — Capybara isolation gap for Playwright
- `spec/requests/debugging_cases_security_spec.rb` — canonical raw-never-persist oracle (request)
- `spec/requests/debugging_cases_authorization_spec.rb` — IDOR matrix (request)
- `spec/requests/debugging_cases_analyze_spec.rb` — analyze success/failure HTTP paths
- `spec/support/security_persistence_helpers.rb` — `assert_no_raw_substring_in_persisted_data`
- `spec/models/encryption_at_rest_spec.rb` — ciphertext-at-rest oracle
- `app/services/ai/client_resolver.rb` — test env always `FakeClient` (blocks failure E2E)
- `context/foundation/test-plan.md` — cost×signal, layer guidance §6.8–§6.9
- `context/foundation/prd.md` — MVP success criteria and FR list

## Architecture Insights

1. **Three-tier test pyramid is intentional.** Request specs own security and authorization oracles; Capybara owns rack-level user flows in CI; Playwright owns optional Chromium certification (`test-plan.md` §6.9, §7).

2. **Playwright UI secret-absence checks are not security tests.** `debugging-case-flow.spec.ts` asserts `rawEmail`/`rawToken` not visible — acceptable UX regression signal, but test-plan explicitly keeps DB/prompt oracles in RSpec.

3. **E2E server = test environment.** `bin/e2e-server` sets `RAILS_ENV=test`, so analyze always succeeds unless a resolver hook is added. Plan phase must address harness before analyze-failure browser spec.

4. **No copy-button automation target.** FR-006 is satisfied by read-only textareas + hints in `app/views/debugging_cases/show.html.erb` and `_ai_report.html.erb`; automated copy tests would be high flake for low signal.

## Historical Context (from prior changes)

- `context/archive/2026-06-01-testing-security-guardrail-cookbook/` — Closed risks #1, #2, #4 at request/service layer; deferred IDOR to Phase 2
- `context/archive/2026-06-01-testing-critical-http-path-regression/` — Authorization matrix, analyze failure HTTP path, demo production gate
- `context/foundation/test-plan.md` Phase 5 (2026-06-09) — Added Capybara system specs; security oracles remain in request specs
- `context/foundation/test-plan.md` Phase 6 (2026-06-09) — Added Playwright; optional gate, 5 tests, not in `bin/ci`
- `context/foundation/test-plan.md` §7 — Deliberate exclusions: Playwright in CI, UI snapshots, Selenium, vision-based review

## Related Research

- `context/changes/case-submission-flow-analysis/research.md` — intake flow analysis (if planning overlaps submission UX)
- `context/archive/2026-06-01-testing-critical-http-path-regression/research.md` — HTTP path regression scope

## Open Questions

1. **Analyze failure in Playwright:** Should plan add `ENV`-driven client override in `ClientResolver` for e2e only, or accept request-spec-only coverage for risk #7 failure UX?
2. **User isolation seeding in Playwright:** Pre-create case via UI (two sessions) vs test API/fixture helper — affects spec complexity and runtime.
3. **Playwright in CI:** Out of scope for this change per test-plan §7, but P1 additions increase local `bin/e2e` time (~3 tests → ~8). Acceptable for Demo Day prep?
