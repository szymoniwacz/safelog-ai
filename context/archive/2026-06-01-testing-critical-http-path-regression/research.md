---
date: 2026-06-01T00:00:00+00:00
researcher: Composer
git_commit: a4903586625a3c9652615a924b38cae1965b5637
branch: main
repository: safelog-ai
topic: "Rollout Phase 2 — Critical HTTP path regression (risks #3, #6, #7)"
tags: [research, testing, authorization, demo-gate, analyze-failure, request-specs]
status: complete
last_updated: 2026-06-01
last_updated_by: Composer
---

# Research: Rollout Phase 2 — Critical HTTP path regression

**Date**: 2026-06-01  
**Researcher**: Composer  
**Git Commit**: a4903586625a3c9652615a924b38cae1965b5637  
**Branch**: main  
**Repository**: safelog-ai

## Research Question

Ground rollout Phase 2 of `context/foundation/test-plan.md` for risks **#3** (IDOR), **#6** (demo loader in production), and **#7** (invalid AI output retry/failure). Verify or correct the test-plan response guidance, locate existing tests, identify the cheapest useful test layer, and flag gaps for gap-fill (not duplicating Phase 1 security guardrails).

## Summary

All three risks have **correct application behavior** today. Test coverage is **partially present but uneven**:

| Risk | Implementation | Existing tests | Phase 2 gap-fill focus |
|------|----------------|----------------|------------------------|
| **#3 IDOR** | `current_user.debugging_cases.find` on every `:id` action → 404 | `spec/requests/debugging_cases_authorization_spec.rb` covers cross-user show/analyze/archive/export | Strengthen matrix oracles (not 403, body leak, export-with-report); consolidate §6.2 cookbook; avoid duplicating scattered per-feature specs |
| **#6 Demo gate** | `Demo::LoadCase.available?` → dev/test only; controller `head :not_found` | `spec/requests/debugging_cases_load_demo_spec.rb` includes env-stub production 404 | Minor: service-level `available?` when production; document canonical pattern in §6.2 |
| **#7 AI failure** | `AnalyzeCase#complete_with_retry` — 2 attempts, then `failed` + safe message | Service retry/failure in `analyze_case_spec.rb`; **no request spec** for failed analyze | Add request spec for HTTP failure path (flash, DB status, no partial report); optional OpenAI invalid-JSON service spec |

**Cheapest layer:** Request specs for #3 matrix strengthening and #7 HTTP failure; existing request spec for #6 is already sufficient — plan should treat #6 as document + light assertion hardening, not new coverage from scratch.

**Test-plan correction:** §3 Phase 2 status was pre-marked `change opened` before the folder existed; folder now created. Risk #3 response guidance remains valid; implementation already guards all four actions — Phase 2 is **test depth/consolidation**, not new controller work.

## Detailed Findings

### Risk #3 — Cross-user case access (IDOR)

#### Controller scoping

Every member action scopes through `current_user.debugging_cases.find(params[:id])`:

- `show` — `app/controllers/debugging_cases_controller.rb:17`
- `analyze` — `app/controllers/debugging_cases_controller.rb:42`
- `download_report` — `app/controllers/debugging_cases_controller.rb:53`
- `archive` — `app/controllers/debugging_cases_controller.rb:68`

`index` scopes list via `current_user.debugging_cases.active/archived` (`:8-9`). `create` assigns `user: current_user`; `load_demo` creates for `current_user` only.

Cross-user lookup raises `ActiveRecord::RecordNotFound` → Rails **404**. No `403`/`forbidden` paths exist in controllers.

#### Existing request coverage

**Canonical matrix:** `spec/requests/debugging_cases_authorization_spec.rb`

| Action | Cross-user | Owner happy | Guest |
|--------|------------|-------------|-------|
| show | 404 (`:23-28`) | 200 + sanitized body (`:31-40`) | not in this file |
| analyze | 404 + no ai_reports (`:44-51`) | not in this file | not in this file |
| archive | 404 + not archived (`:55-62`) | not in this file | not in this file |
| download_report | 404 (`:66-72`) | not in this file | not in this file |

**Duplicated cross-user tests** (same 404 behavior): `debugging_cases_analyze_spec.rb:36-42`, `debugging_cases_archive_spec.rb:27-33`, `debugging_cases_report_export_spec.rb:37-42`, `debugging_cases_report_export_security_spec.rb:76-81`.

**Index isolation:** `debugging_cases_index_spec.rb:52-73` — other user's cases absent from active/archived lists.

#### Gaps vs test-plan intent

Test plan requires: *404 (not 403 leak)* and *challenge signed-in user implies only own cases reachable*.

| Gap | Priority | Cheapest fix |
|-----|----------|--------------|
| No explicit `not_to eq(403)` or status exclusion | Medium | Shared example or one matrix row per action |
| Cross-user show does not assert body excludes `"Owner-only case"` | Medium | `expect(response.body).not_to include(...)` on 404 |
| Cross-user export when owner **has** generated report | Low | Setup owner analyze + cross-user download (partially in `report_export_security_spec.rb`) |
| Analyze cross-user: no correlation_signals mutation check | Low | Assert count unchanged |
| Matrix fragmented across 5+ files | Medium | Extend `debugging_cases_authorization_spec.rb`; trim duplicates only if plan explicitly scopes dedup |
| §6.2 cookbook TBD | Required deliverable | Document authorization matrix pattern after gap-fill |

**Anti-pattern avoided:** Not testing only show while leaving analyze/export unguarded — all four already have cross-user specs.

### Risk #6 — Demo loader in production

#### Gate mechanism

```ruby
# app/services/demo/load_case.rb:7-9
def self.available?
  Rails.env.development? || Rails.env.test?
end
```

Controller gate (`debugging_cases_controller.rb:75-77`): `head :not_found` when unavailable. Service raises `Demo::LoadCase::UnavailableError` if called when unavailable (`load_case.rb:20`).

Route `POST /debugging_cases/load_demo` is registered in all environments (`config/routes.rb:15`); protection is runtime-only.

#### Existing request coverage

`spec/requests/debugging_cases_load_demo_spec.rb`:

- Guest redirect (`:9-14`)
- Happy path in test env (`:16-34`)
- Stub `available?` → false → 404 (`:36-45`)
- **Production-like:** stub `Rails.env.development?` and `test?` → false → 404 (`:47-57`) — **primary risk #6 proof**

Dashboard UI: `spec/requests/dashboard_spec.rb:24-39` — button visibility tied to `available?`.

Service: `spec/services/demo/load_case_spec.rb:8-11` — `available?` true in test; `:32-38` — raises when stubbed unavailable.

#### Gaps vs test-plan intent

Test plan requires: *404 outside development/test*; challenge *happy path only in development*.

| Gap | Priority | Notes |
|-----|----------|-------|
| Service spec never asserts `available?` false when `production?` stubbed | Low | One-line service example |
| Staging/custom env untested | Low | Same logic as production stub |
| Controller gate removal → `UnavailableError` unrescued | Low | Document only; out of Phase 2 scope unless regression feared |
| §6.2 cookbook | Required | Canonical demo-gate request pattern |

**Verdict:** Risk #6 is **largely proven**; Phase 2 should not duplicate happy-path demo tests. Focus on cookbook documentation and optional service-level production assertion.

### Risk #7 — Invalid AI output, retry, safe failure

#### Orchestration

`Analysis::AnalyzeCase` (`app/services/analysis/analyze_case.rb`):

1. Create `AiReport` status `processing`
2. Extract/persist correlation signals
3. Build prompt via `PromptBuilder`
4. `complete_with_retry` — max **2 attempts** (`attempts >= 2` re-raises)
5. Success → `generated` with structured JSON + markdown
6. `rescue Ai::InvalidResponseError` → `failed`, nil encrypted fields, `FAILURE_MESSAGE`

#### Validator rules (`app/services/ai/response_validator.rb`)

Required: `summary` (non-empty string), `hypotheses` (non-empty array of hashes with title+description), `uncertainty_notes` (non-empty array of non-empty strings). Raises `Ai::InvalidResponseError` on violation.

Prompt instructs hypothesis-framed output (`prompt_builder.rb:28-33`); structure enforced post-hoc.

#### Existing spec coverage

**Service — strong:**

- Retry then success: `analyze_case_spec.rb:62-75` (`InvalidOnceClient`, 2 calls)
- Retry exhausted → failure: `analyze_case_spec.rb:77-94` (`InvalidClient`, `be_failed`, nil fields, `FAILURE_MESSAGE`, 2 calls)
- Validator invalid payloads: `response_validator_spec.rb:26-79`

**Request — gap:**

- `debugging_cases_analyze_spec.rb:45-68` — owner success only (`"Analysis complete."`, `be_generated`)
- **No request spec** for failed analyze: alert flash, `failed` status in DB, failure UI, no export

**OpenAI client — gap:**

- `open_ai_client_spec.rb` — success only; no invalid JSON / missing keys

#### Gaps vs test-plan intent

Test plan requires: *invalid JSON retries then fails safely with hypothesis framing required*; challenge *first successful analyze proves validator exists, not retry/failure path*.

| Gap | Priority | Cheapest fix |
|-----|----------|--------------|
| HTTP failure path after retry exhaustion | **High** | Request spec stubbing invalid client via test helper or dependency injection at controller boundary |
| Request asserts no partial report in response/export | Medium | Follow-on in same spec |
| Invalid JSON parse through retry (OpenAI path) | Low | Service spec on `OpenAiClient` — optional if request + AnalyzeCase service already cover structural invalid |
| Correlation persisted on failure | Low | Service assertion — behavior exists, untested |

**Verdict:** Service layer proves retry/failure logic. Phase 2 **must add request-layer failure path** to satisfy risk #7 at the HTTP integration layer test plan specifies.

## Code References

- `app/controllers/debugging_cases_controller.rb:17,42,53,68,75-77` — scoped finds and demo gate
- `app/services/demo/load_case.rb:7-9,20` — demo availability
- `app/services/analysis/analyze_case.rb:32-44,55-67` — analyze orchestration and retry
- `app/services/ai/response_validator.rb:18-94` — schema validation
- `spec/requests/debugging_cases_authorization_spec.rb` — IDOR matrix (partial)
- `spec/requests/debugging_cases_load_demo_spec.rb:47-57` — production-like demo 404
- `spec/services/analysis/analyze_case_spec.rb:62-94` — retry success/failure
- `spec/requests/debugging_cases_analyze_spec.rb:45-68` — analyze success only (HTTP)

## Architecture Insights

1. **404-as-obscurity** is consistent for IDOR and demo gate — tests should assert `:not_found`, optionally assert status is not `:forbidden`.
2. **Authorization is inline scoping**, not Pundit — tests target controller find pattern, not policy objects.
3. **Analyze failure is service-rescued** — controller only checks `result.success?`; request failure spec needs invalid AI client wired through the full POST analyze path.
4. **Phase 1 deferred authorization matrix** (`test-plan.md:217`) — this phase completes that deferral plus §6.2 cookbook.

## Historical Context

- `context/archive/2026-06-01-testing-security-guardrail-cookbook/change.md` — Phase 1 explicitly deferred risk #3 authorization matrix to Phase 2.
- `context/archive/2026-05-27-analyze-hypothesis-report/plan.md` — original retry-once design for `AnalyzeCase`.
- `context/archive/2026-05-27-load-demo-case/plan.md` — demo loader scoped to dev/test.

## Related Research

- `context/archive/2026-06-01-testing-security-guardrail-cookbook/research.md` — Phase 1 security gaps (#1, #2, #4)

## Recommended Phase 2 Scope (for `/10x-plan`)

1. **Extend** `debugging_cases_authorization_spec.rb` — full guest/owner/other matrix oracles; explicit not-403; body leak checks; export with generated report.
2. **Document** demo gate pattern in `test-plan.md` §6.2; optional service `available?` production example.
3. **Add** request spec for analyze failure after retry exhaustion (inject invalid client or stub resolver).
4. **Write** §6.2 "Adding a request/integration test" cookbook referencing authorization matrix, demo gate, and analyze journey specs.
5. **Do not duplicate** Phase 1 raw-persist / sanitized-AI / metadata redaction specs.

## Open Questions

- Should Phase 2 deduplicate cross-user tests from per-feature request files, or only strengthen the matrix file and leave duplicates? (Recommend: strengthen matrix first; dedup only if examples are identical and maintenance cost is called out in plan.)
- How to inject invalid AI client in request specs — check whether `Ai::ClientResolver` supports test doubles without violating FakeClient-only CI rule.
