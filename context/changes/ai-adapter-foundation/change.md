---
change_id: ai-adapter-foundation
title: AI adapter foundation (F-03)
status: plan_reviewed
created: 2026-05-27
updated: 2026-05-27
archived_at: null
---

## Notes

Roadmap **F-03** (`context/foundation/roadmap.md` — change id there: `ai-adapter-test-harness`). Provider-agnostic AI adapter interface with fake client for tests/CI; OpenAI as first real provider behind env gate. Prerequisites: F-02 (`encrypted-diagnostic-schema`) complete.

**Phase 1 done:** RSpec + WebMock + `bin/ci` RSpec step. GHA `test` job requires repository secret `RAILS_MASTER_KEY` (decrypts credentials for Rails boot in CI).

**Phase 2 done:** `Ai::Client` contract, `Request`/`CompletionResult`, `FakeClient`, `ClientResolver` under `app/services/ai/` with 7 service specs.

**Phase 3 done:** `ReportSchema`, `ResponseValidator`, `InvalidResponseError`; canonical fixture aligned; FakeClient validates before returning.

**Phase 4 done:** `OpenAiClient` (ruby-openai, env-gated), param filter, security specs. **S-03 handoff:** call `Ai::ClientResolver.current#complete`, validate with `Ai::ResponseValidator`; retry-once + `AiReport` persistence belong in analyze service.
