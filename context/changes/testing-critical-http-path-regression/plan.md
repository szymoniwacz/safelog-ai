# Critical HTTP Path Regression — Implementation Plan

## Overview

Rollout Phase 2 of `context/foundation/test-plan.md`: **gap-fill-only** request/integration coverage for risks **#3** (IDOR / authorization matrix), **#6** (demo loader gate), and **#7** (analyze failure after retry exhaustion). Controllers already behave correctly; this change strengthens test oracles, adds the missing HTTP failure path for analyze, documents §6.2 request patterns, and updates §6.6 — without duplicating Phase 1 security guardrails (#1, #2, #4).

Baseline: **119 RSpec examples**, all green. Target: **~126–130 examples** (small delta).

## Current State Analysis

Research (`context/changes/testing-critical-http-path-regression/research.md`) verified:

- **Risk #3** — All `:id` actions scope via `current_user.debugging_cases.find` → 404. `spec/requests/debugging_cases_authorization_spec.rb` covers cross-user show/analyze/archive/export but lacks not-403 oracles, show body-leak checks, export-with-report setup, and analyze side-effect depth. Same 404 behavior duplicated in four per-feature request files.
- **Risk #6** — `Demo::LoadCase.available?` gates dev/test only. `spec/requests/debugging_cases_load_demo_spec.rb:47-57` already proves production-like 404 via `Rails.env` stubs. Service spec asserts `available?` true in test only.
- **Risk #7** — Service retry/failure proven in `spec/services/analysis/analyze_case_spec.rb:62-94`. **No request spec** exercises POST analyze → failed report → safe UI message → export blocked.

### Key Discoveries

- `Analysis::AnalyzeCase.call` accepts optional `client:` but controller uses default `Ai::ClientResolver.current` — request specs stub resolver like `debugging_cases_analyze_security_spec.rb:13`.
- Invalid client stubs live as nested classes in `analyze_case_spec.rb:119-134` — extract to shared support for request reuse.
- Cross-user export with generated report partially covered in `debugging_cases_report_export_security_spec.rb:76-81` — authorization matrix should own the canonical example with explicit leak oracles.
- §6.2 in `test-plan.md:140-142` is still TBD — required Phase 2 deliverable.

## Desired End State

1. `spec/requests/debugging_cases_authorization_spec.rb` is the **canonical authorization matrix** with strengthened oracles: 404 (not 403), no body leak on cross-user show, export blocked when owner has generated report, analyze does not mutate other user's case.
2. `spec/requests/debugging_cases_analyze_spec.rb` includes a **failed analyze HTTP path** after retry exhaustion: alert flash, `failed` report, failure callout in HTML, no hypothesis content, export returns 404, client called twice.
3. `spec/services/demo/load_case_spec.rb` asserts `.available?` is false when `Rails.env.production?` is stubbed true (service-level risk #6 anchor).
4. `context/foundation/test-plan.md` §6.2 documents request/integration patterns for authorization matrix, demo gate, and analyze journeys; §6.6 notes Phase 2 completion.
5. Full suite and `bin/ci` remain green; example count increases modestly.

### Verification

```bash
mise exec -- bundle exec rspec spec/requests/debugging_cases_authorization_spec.rb spec/requests/debugging_cases_analyze_spec.rb spec/requests/debugging_cases_load_demo_spec.rb spec/services/demo/load_case_spec.rb
mise exec -- bundle exec rspec spec/ --dry-run | tail -1
mise exec -- bin/ci
```

## What We're NOT Doing

- Duplicating Phase 1 raw-persist, sanitized-AI, or metadata redaction specs.
- Removing cross-user examples from per-feature request files (strengthen matrix first; dedup deferred unless identical).
- OpenAI invalid-JSON service specs (structural invalid already covered at `AnalyzeCase` layer).
- E2E/Playwright, UI snapshots, view cosmetic tests (test plan §7).
- Controller or authorization implementation changes (behavior already correct).
- Correlation-on-failure service assertion (low signal; optional follow-up).
- Rewriting guest redirect matrix into authorization spec (document pointers to existing feature specs in §6.2).

## Implementation Approach

Order by **cost × signal**: shared AI test client stub first (enables #7 request spec), authorization matrix gap-fill (#3), analyze HTTP failure (#7), demo service assertion + cookbook (#6). Each new example uses **independent oracles** from test-plan risk response guidance — expected 404/failure semantics, not values copied from implementation internals.

## Critical Implementation Details

**Analyze failure request spec** must stub `Ai::ClientResolver.current` to return a client that always returns structurally invalid completions (empty `summary`), triggering validator failure and retry exhaustion through the real controller → `AnalyzeCase` path. Do not call real OpenAI or bypass `ResponseValidator`.

**Authorization export-with-report example** must set up owner analyze success (stub `FakeClient` via resolver) before cross-user download attempt — otherwise 404 could come from missing report rather than IDOR scoping.

## Phase 1: Shared AI Test Clients + Authorization Matrix Gap-Fill

### Overview

Extract reusable invalid AI client stubs and strengthen the canonical IDOR matrix for risk **#3**.

### Changes Required

#### 1. Shared invalid AI client stubs

**File**: `spec/support/ai_test_clients.rb`

**Intent**: Provide `AiTestClients::InvalidClient` (always invalid structured output) and optionally `AiTestClients::InvalidOnceClient` (invalid then FakeClient success) mirroring nested classes in `analyze_case_spec.rb`, so request and service specs share one definition.

**Contract**: Classes include `Ai::Client`; `InvalidClient#complete` returns `Ai::CompletionResult.new(structured: { summary: "" }, markdown: "")` and tracks `complete_calls`. Loaded via `spec/support/` glob (not a `_spec.rb` file).

#### 2. Refactor service spec to use shared stubs

**File**: `spec/services/analysis/analyze_case_spec.rb`

**Intent**: Replace nested `InvalidClient` / `InvalidOnceClient` with `AiTestClients::*` references. No behavior change.

**Contract**: Same example titles and assertions; nested class definitions removed.

#### 3. Strengthen authorization matrix

**File**: `spec/requests/debugging_cases_authorization_spec.rb`

**Intent**: Close risk #3 gap-fill oracles in the canonical matrix file.

**Contract**: Extend existing cross-user examples (or add sibling examples) to assert:

- HTTP status is `:not_found` and **not** `:forbidden` for show, analyze, archive, and download_report.
- Cross-user **show** response body does not include the owner-only case title (`"Owner-only case"`).
- Cross-user **analyze** leaves `correlation_signals.count` unchanged (in addition to `ai_reports.count == 0`).
- New example: owner runs analyze successfully (stub `Ai::ClientResolver.current` → `Ai::FakeClient.new`), then cross-user `GET download_report` returns 404 and response body must not include markdown export content from the generated report (e.g. hypothesis summary substring from FakeClient fixture).

**File**: `spec/support/request_status_helpers.rb` (optional, if matrix grows repetitive)

**Intent**: Single helper `expect_not_found_without_forbidden` wrapping status assertion — only add if three or more call sites need it.

**Contract**: Method asserts `have_http_status(:not_found)` and `not_to have_http_status(:forbidden)`.

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/services/analysis/analyze_case_spec.rb` passes after client extraction (no behavior change).
- `mise exec -- bundle exec rspec spec/requests/debugging_cases_authorization_spec.rb` passes with new/changed examples.
- RuboCop clean on new/edited spec/support and request files.

#### Manual Verification

- Confirm `spec/support/ai_test_clients.rb` is not named `*_spec.rb` (auto-loaded, not double-run).

---

## Phase 2: Analyze Failure HTTP Path

### Overview

Add request-layer proof for risk **#7**: invalid AI output retries then fails safely at the HTTP boundary.

### Changes Required

#### 1. Failed analyze request example

**File**: `spec/requests/debugging_cases_analyze_spec.rb`

**Intent**: Prove POST analyze for owner exhausts retry and surfaces safe failure through controller redirect + show page — independent of service spec duplication at HTTP layer.

**Contract**: Before POST, stub `Ai::ClientResolver.current` → `AiTestClients::InvalidClient.new`. After POST:

- Redirect to case show with `flash[:alert]` equal to `Analysis::AnalyzeCase::FAILURE_MESSAGE`.
- `follow_redirect!` — response body includes failure callout text; does **not** include generated hypothesis content (e.g. FakeClient's default summary string `"Checkout timeout may be caused by downstream payment latency."`).
- `debugging_case.reload.ai_reports.last` is `failed`; `structured_json` and `markdown_body` are nil.
- `AiTestClients::InvalidClient#complete_calls` equals **2** (retry exhausted).
- `GET download_report` returns 404 (no export of partial/invalid report).

#### 2. Optional: retry-then-success HTTP smoke (out of scope if time-constrained)

**Intent**: Not required for risk #7 — service spec already covers retry success. Skip unless implementer wants symmetry.

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_spec.rb` passes including failure example.
- Failure example does not send raw log substrings to stub client prompt (existing sanitized paste fixture is sufficient).

#### Manual Verification

- Failure example uses resolver stub, not direct `AnalyzeCase.call` — exercises full HTTP stack.

---

## Phase 3: Demo Gate Service Anchor + Cookbook (§6.2 / §6.6)

### Overview

Light risk **#6** service assertion plus test-plan cookbook documentation for request/integration patterns.

### Changes Required

#### 1. Demo availability in production (service)

**File**: `spec/services/demo/load_case_spec.rb`

**Intent**: Assert `.available?` is false when `Rails.env.production?` returns true (and development/test false) — complements existing request env-stub test.

**Contract**: One new example under `.available?` describe block; no behavior change to application code.

#### 2. Fill §6.2 request/integration cookbook

**File**: `context/foundation/test-plan.md`

**Intent**: Replace §6.2 TBD with actionable patterns for Phase 2 risks.

**Contract**: §6.2 must document:

- **When to use request vs service** — authorization and demo gate at request layer; analyze retry logic also at service layer (`analyze_case_spec.rb`).
- **Risk #3 — authorization matrix** — canonical file `debugging_cases_authorization_spec.rb`; assert 404 not 403; body leak oracles; per-action side effects; anti-pattern: testing only show while ignoring analyze/export.
- **Risk #6 — demo gate** — canonical file `debugging_cases_load_demo_spec.rb:47-57` (`Rails.env` stub pattern); anti-pattern: happy path only in test env without production-like gate.
- **Risk #7 — analyze journey** — success in `debugging_cases_analyze_spec.rb`; failure after retry via `AiTestClients::InvalidClient` + resolver stub; anti-pattern: FakeClient success alone proves validator/retry paths.
- **Run commands** for the three canonical request files.
- Pointer: guest redirect examples remain in per-feature specs (list them).

#### 3. Update §6.6 Phase 2 notes and §3/§5 metadata

**File**: `context/foundation/test-plan.md`

**Intent**: Record Phase 2 completion, example count delta, and deferrals.

**Contract**:

- §6.6 adds Phase 2 entry with change-id, date, examples added, what was deferred (dedup of per-feature IDOR tests, OpenAI JSON parse specs).
- §3 Phase 2 Status → `complete` when implementation lands.
- §5 RSpec example count updated to final number.

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/services/demo/load_case_spec.rb` passes with new `.available?` example.
- `mise exec -- bin/ci` passes (full suite + lint + security scans).

#### Manual Verification

- §6.2 is self-contained for a contributor adding a new `:id` action authorization test.
- §6.6 Phase 2 entry accurately lists new example count and files touched.

---

## Testing Strategy

### Request / Integration Tests

- Authorization matrix: guest (documented elsewhere), owner happy, other_user 404 with leak oracles.
- Analyze: owner success (existing) + owner failure after retry (new).
- Demo: existing request coverage retained; service production assertion added.

### Service Tests

- `analyze_case_spec.rb` — unchanged behavior after client extraction.
- `load_case_spec.rb` — one new `.available?` example.

### Manual Testing Steps

1. Skim authorization spec — each `:id` action has cross-user 404 with side-effect or body oracle.
2. Run failed analyze example in isolation — confirm flash alert and no hypothesis HTML.
3. Read §6.2 — confirm a new contributor could locate canonical patterns without reading this plan.

## Performance Considerations

None — test-only change; no runtime impact.

## Migration Notes

None.

## References

- Research: `context/changes/testing-critical-http-path-regression/research.md`
- Test plan: `context/foundation/test-plan.md` §2–§3, §6–§7
- Phase 1 cookbook: `context/archive/2026-06-01-testing-security-guardrail-cookbook/plan.md`
- Authorization: `spec/requests/debugging_cases_authorization_spec.rb`
- Analyze orchestration: `app/services/analysis/analyze_case.rb:13-44,55-67`
- Demo gate: `app/services/demo/load_case.rb:7-9`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Shared AI Test Clients + Authorization Matrix Gap-Fill

#### Automated

- [x] 1.1 `mise exec -- bundle exec rspec spec/services/analysis/analyze_case_spec.rb` passes after client extraction
- [x] 1.2 `mise exec -- bundle exec rspec spec/requests/debugging_cases_authorization_spec.rb` passes with strengthened matrix
- [x] 1.3 RuboCop clean on new/edited spec/support and request files

#### Manual

- [ ] 1.4 `spec/support/ai_test_clients.rb` loaded via support glob, not executed as standalone spec

### Phase 2: Analyze Failure HTTP Path

#### Automated

- [ ] 2.1 `mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_spec.rb` passes including failure example

#### Manual

- [ ] 2.2 Failure example exercises controller → AnalyzeCase via resolver stub, not direct service call

### Phase 3: Demo Gate Service Anchor + Cookbook (§6.2 / §6.6)

#### Automated

- [ ] 3.1 `mise exec -- bundle exec rspec spec/services/demo/load_case_spec.rb` passes with production `.available?` example
- [ ] 3.2 `mise exec -- bin/ci` passes

#### Manual

- [ ] 3.3 §6.2 and §6.6 updated; §3 Phase 2 marked complete with final example count
