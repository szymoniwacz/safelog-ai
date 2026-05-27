# Analyze Hypothesis Report (S-03) — Plan Brief

> Full plan: `context/changes/analyze-hypothesis-report/plan.md`

## What & Why

Roadmap **S-03** completes the core debugging loop after S-02 intake: a signed-in user clicks **Analyze case** on a sanitized debugging case; the app extracts **correlation signals** from placeholder-linked evidence, calls the **F-03 AI adapter** with sanitized content only, validates a **hypothesis-framed** report (retry once on invalid JSON), and displays correlation signals plus structured + Markdown report on the case detail page. Raw logs and original sensitive values never reach AI or persistence beyond what S-02 already sanitized.

## Starting Point

**S-02** delivers case new/create/show with `Redaction::Engine`, `Intake::ProcessCaseSubmission`, sanitized `LogSource` rows, and redaction findings. **F-03** delivers `app/services/ai/` (`Client`, `FakeClient`, `Request`, `ResponseValidator`, `ReportSchema`). F-02 models include `CorrelationSignal` (encrypted `payload`) and `AiReport` (encrypted `structured_json`, `markdown_body`; status enum). No correlation or analyze services, no analyze route, no report UI. 53 RSpec examples; `bin/ci` green.

## Desired End State

User on case show clicks **Analyze case** → same browser session completes (sync, no background job) → page shows correlation signals (placeholder-based, no originals) and hypothesis report (summary, hypotheses, uncertainty notes). Failed validation after one retry shows safe failure message; `AiReport` status `failed`. Request/service specs prove AI prompts contain placeholders only, not raw submission secrets; cross-user analyze denied. `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Service layout | `app/services/correlation/` + `app/services/analysis/` | Matches AGENTS.md domain boundaries | Plan |
| Correlation input | Sanitized log bodies + redaction findings (placeholders only) | No raw values; reuses S-02 redaction metadata | Plan |
| Correlation output | One `CorrelationSignal` row per analyze with JSON payload array | F-02 schema; encrypted diagnostic text | Plan |
| AI prompt source | `LogSource#sanitized_content`, case metadata, correlation payload | AGENTS.md sanitized-only AI boundary | Plan |
| Client injection | `client:` keyword on analyze service; resolver in controller | Testability without stubbing globals | Plan |
| Invalid AI response | Retry `#complete` once; then `AiReport` `failed` | PRD US-01 acceptance criteria | Plan |
| Report storage | New `AiReport` per analyze; UI shows latest by `created_at` | Simple audit trail; no schema change | Plan |
| HTTP | `POST analyze` member route on `debugging_cases` | Thin controller; sync redirect back to show | Plan |
| Markdown export | Out of scope | S-04 | Plan |
| Background jobs | Out of scope | PRD non-goals | Plan |

## Scope

**In scope:** Correlation extractor, prompt builder, analyze orchestrator, analyze route/action, show UI for signals + report + analyze button, service + request specs (sanitized prompts, retry-once, authorization).

**Out of scope:** Markdown copy/download (S-04), archive (S-05), demo loader (S-06), prompt persistence columns, new providers, background jobs, re-intake/editing sources.

## Architecture / Approach

```
POST /debugging_cases/:id/analyze
  → DebuggingCasesController#analyze
  → Analysis::AnalyzeCase.call(debugging_case:, client:)
       → Correlation::ExtractSignals (persist CorrelationSignal)
       → Analysis::PromptBuilder (Ai::Request messages)
       → client.complete → Ai::ResponseValidator
       → retry once on InvalidResponseError
       → persist AiReport (generated | failed)
  → redirect show

Prompt contains [REQUEST_1] etc. only — never raw email/token from intake.
```

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Correlation extractor | Placeholder cross-source signals + unit specs | Leaking original values into payload |
| 2. Analyze orchestrator | Prompt builder + AnalyzeCase + retry + specs | Raw text in prompt; missing retry |
| 3. Analyze route | POST member action + request skeleton | Authorization bypass |
| 4. Report UI | Analyze button, signals + hypothesis report on show | Rendering failed state unsafely |
| 5. Security specs | AGENTS.md prompt guard + cross-user analyze deny | FakeClient instance not captured in request spec |

**Prerequisites:** S-02, F-03. **Estimated effort:** ~3 sessions across 5 phases.

## Open Risks & Assumptions

- Correlation heuristics are MVP-simple (shared placeholders across sources); not full log parsing.
- `FakeClient` returns canonical fixture — analyze specs focus on prompt content and persistence, not report prose quality.
- Re-analyze creates additional `AiReport` rows; UI shows latest — acceptable for MVP.
- OpenAI path untested in CI; production uses same orchestrator with env-gated client.

## Success Criteria (Summary)

- End-to-end: create case → analyze → show displays correlation signals and hypothesis report.
- Specs prove no raw secrets in AI request messages or correlation payload.
- Invalid response retried once; persistent failure surfaces safe message.
- `bin/ci` green.
