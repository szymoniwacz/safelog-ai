# Critical HTTP Path Regression — Plan Brief

> Full plan: `context/changes/testing-critical-http-path-regression/plan.md`
> Research: `context/changes/testing-critical-http-path-regression/research.md`

## What & Why

Phase 2 of the test rollout closes gap-fill coverage for **authorization (IDOR)**, **demo loader gate**, and **analyze failure/retry** at the HTTP integration layer. Controllers already enforce correct behavior; this change strengthens test oracles and ships the §6.2 request cookbook — without repeating Phase 1 security guardrails.

## Starting Point

119 RSpec examples, all green. Phase 1 shipped §6.1/§6.3–§6.5. Authorization cross-user 404s exist but are fragmented and lack not-403/body-leak oracles. Demo gate has a production-like request test. Analyze retry/failure is proven in service specs only — no HTTP failure path.

## Desired End State

Contributors have a canonical authorization matrix spec, an analyze failure request example, a demo gate service anchor, and a filled §6.2 cookbook. `bin/ci` stays green with ~7–11 new examples.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|------------------|--------|
| IDOR dedup | Strengthen matrix only; keep per-feature cross-user specs | Avoid churn; matrix becomes canonical reference in §6.2 | Research |
| Invalid AI client in requests | Stub `Ai::ClientResolver.current` with shared `AiTestClients::InvalidClient` | Matches existing analyze security pattern; exercises full HTTP stack | Research / Plan |
| OpenAI JSON parse tests | Out of scope | Structural invalid already covered via `AnalyzeCase` + validator | Research |
| Demo gate depth | One service `.available?` example + §6.2 docs; keep existing request spec | Request env-stub test already proves risk #6 | Research |
| Guest auth matrix | Document pointers in §6.2, not duplicated in authorization spec | Guest redirects already in per-feature specs; minimize duplication | Plan |
| Example count target | ~126–130 total | Small delta aligned with Phase 1 gap-fill sizing | Plan |

## Scope

**In scope:**

- Extract `spec/support/ai_test_clients.rb`; refactor `analyze_case_spec.rb` to use it
- Strengthen `debugging_cases_authorization_spec.rb` (not-403, body leak, export-with-report, analyze side effects)
- Add failed analyze HTTP example in `debugging_cases_analyze_spec.rb`
- Add demo `.available?` production example in `load_case_spec.rb`
- Fill `test-plan.md` §6.2 and §6.6; update §3/§5 on completion

**Out of scope:**

- Phase 1 security guardrails (#1, #2, #4)
- E2E/Playwright, UI snapshots, view cosmetic tests
- Controller changes, OpenAI invalid-JSON specs, dedup of per-feature IDOR tests

## Architecture / Approach

Three incremental phases: (1) shared test stubs + authorization matrix gap-fill, (2) analyze failure at HTTP layer via resolver stub, (3) demo service assertion + cookbook prose. All new tests use independent oracles from test-plan risk guidance — 404 obscurity, safe failure message, no partial report export.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Auth matrix + shared clients | Canonical IDOR oracles + reusable invalid AI client | Over-asserting on error page content that varies by Rails version |
| 2. Analyze failure HTTP | POST analyze → retry exhausted → safe UI + no export | Stubbing resolver incorrectly bypasses real orchestration |
| 3. Demo + cookbook | Service production gate + §6.2/§6.6 docs | Over-documenting patterns already proven in Phase 1 |

**Prerequisites:** Phase 1 archived; 119-example baseline green; research complete.

**Estimated effort:** ~1–2 sessions across 3 phases.

## Open Risks & Assumptions

- Export-with-report authorization example depends on FakeClient fixture strings remaining stable — use substring from known fixture, not copied implementation constants.
- If `bin/ci` example count in §5 is updated manually, implementer must match `--dry-run` output exactly.

## Success Criteria (Summary)

- Cross-user show/analyze/archive/export return 404 with strengthened leak oracles (risk #3).
- Failed analyze at HTTP layer shows safe message, `failed` report, no export (risk #7).
- Demo `.available?` false in production stub; §6.2 documents all three patterns (risk #6).
- `bin/ci` green with modest example count increase.
