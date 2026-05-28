<!-- PLAN-REVIEW-REPORT -->
# Plan Review: AI Adapter Foundation (F-03)

- **Plan**: `context/changes/ai-adapter-foundation/plan.md`
- **Mode**: Deep
- **Date**: 2026-05-27
- **Verdict**: REVISE
- **Findings**: 0 critical, 3 warnings, 2 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding

Grounding: 5/5 paths ✓ (Gemfile, config/ci.rb, .github/workflows/ci.yml, app/models/ai_report.rb, filter_parameter_logging.rb); `app/services/` absent as expected ✓; 0/3 planned gems present yet (rspec/webmock/ruby-openai — expected pre-implementation); brief↔plan ✓; Progress↔Phase 4/4 phases ✓, 14/14 success criteria mapped ✓

## Findings

### F1 — GitHub Actions needs `RAILS_MASTER_KEY` for RSpec boot

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 1 — GitHub Actions job; Progress 1.4
- **Detail**: Plan claims the GHA test job needs "no secrets" (`plan.md` Phase 1 contract). `rspec-rails` via `rails_helper` loads full Rails, which decrypts `config/credentials.yml.enc` for Devise `secret_key_base` and F-02 `active_record_encryption` keys. `.github/workflows/ci.yml` has no `RAILS_MASTER_KEY` env today. Local dev works because `config/master.key` exists (gitignored); CI clone will fail on boot without a repo secret or alternate test credentials strategy.
- **Fix A ⭐ Recommended**: Add Phase 1 contract bullet: GHA `test` job sets `RAILS_MASTER_KEY` from repository secret; document in change Notes that F-02 credentials must be present in encrypted credentials (already true locally).
  - Strength: Standard Rails CI pattern; one secret unlocks Devise + encryption config.
  - Tradeoff: Requires configuring GitHub repo secret before CI goes green.
  - Confidence: HIGH — verified boot fails with invalid master key; workflow has no key today.
  - Blind spot: Whether course/Fly deploy uses same credentials file (likely yes).
- **Fix B**: Use `config/credentials/test.yml.enc` with committed test-only master key for CI.
  - Strength: No GitHub secret for students cloning repo.
  - Tradeoff: Non-standard split; must not leak production keys into test credentials.
  - Confidence: MEDIUM — not used elsewhere in repo.
  - Blind spot: Credential rotation story.
- **Decision**: PENDING

### F2 — OpenAI client response shape underspecified

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Plan Completeness
- **Location**: Phase 4 — OpenAiClient
- **Detail**: Plan says OpenAI adapter "parses JSON from assistant content into structured hash + markdown" with "prefer provider returns JSON matching schema and separate markdown field." Chat Completions return a single string — dual outputs (`structured_json` + `markdown_body` on `AiReport`) need an explicit contract: e.g. require assistant JSON with `structured` and `markdown` keys, or generate markdown from structured in Ruby. Without this, Phase 4 implementer may diverge from S-03 persistence expectations.
- **Fix A ⭐ Recommended**: Add Critical Implementation Details sentence: "OpenAI adapter expects assistant message to be JSON with top-level `structured` (object matching ReportSchema) and `markdown` (string); FakeClient returns the same shape."
  - Strength: Aligns adapter output with F-02 two-column storage; one parse path.
  - Tradeoff: Prompt engineering in S-03 must enforce JSON shape from model.
  - Confidence: HIGH — matches `AiReport` columns and validator flow.
  - Blind spot: Model compliance rate (S-03 retry handles invalid).
- **Fix B**: Adapter returns structured only; markdown derived via `Ai::MarkdownRenderer` from structured hash.
  - Strength: Single source of truth; smaller model output.
  - Tradeoff: New renderer class; markdown may not match model prose quality.
  - Confidence: MEDIUM — PRD allows both fields stored separately.
  - Blind spot: FR-008 display expectations for markdown-specific formatting.
- **Decision**: PENDING

### F3 — Report schema fields inferred, not PRD-enumerated

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: End-State Alignment
- **Location**: Phase 3 — ReportSchema
- **Detail**: PRD requires "validated structure with uncertainty notes" and hypothesis language but does not list exact JSON keys. Plan proposes `summary`, `hypotheses[]`, `uncertainty_notes[]`, optional `correlation_highlights`. S-03 UI may need different fields — low rework risk if schema is versioned in structured JSON, but plan should record this as an explicit planning assumption.
- **Fix**: Add one row to plan-brief Key Decisions: "Report JSON keys → summary, hypotheses, uncertainty_notes (MVP inferred from PRD guardrails; S-03 may extend display without adapter break if keys stable)."
- **Decision**: PENDING

### F4 — Change-id differs from roadmap slug

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: change.md Notes; roadmap F-03 row
- **Detail**: Roadmap lists change id `ai-adapter-test-harness`; this change folder is `ai-adapter-foundation`. Notes cross-reference both — fine for traceability, but backlog/issue titles may diverge.
- **Fix**: Keep `ai-adapter-foundation` as working folder; note roadmap alias in change.md (already done) or align roadmap row on next roadmap edit (out of scope for F-03 implement).
- **Decision**: PENDING

### F5 — Phase 1 optional smoke spec adds throwaway work

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Lean Execution
- **Location**: Phase 1 — RSpec install
- **Detail**: Plan suggests temporary `spec/smoke_spec.rb` then remove when Phase 2 adds real specs. Zero-example `rspec` already exits 0; smoke file is unnecessary churn.
- **Fix**: Drop smoke spec mention; rely on `rspec` with 0 examples or wait until Phase 2 for first committed spec.
- **Decision**: PENDING
