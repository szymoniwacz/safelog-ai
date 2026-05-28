---
date: 2026-05-28T19:45:00+02:00
researcher: Cursor Agent
git_commit: c975002d3bc2d07fea92ce098692ddc1107f899b
branch: main
repository: safelog-ai
topic: "Architecture alignment — canonical source vs implementation"
tags: [research, architecture, services, correlation, analysis, ai, cleanup]
status: complete
last_updated: 2026-05-28
last_updated_by: Cursor Agent
---

# Research: Architecture alignment — canonical source vs implementation

**Date**: 2026-05-28  
**Researcher**: Cursor Agent  
**Git Commit**: `c975002d3bc2d07fea92ce098692ddc1107f899b`  
**Branch**: `main`  
**Repository**: safelog-ai

## Research Question

Analyze mismatches between the SafeLog AI canonical project source and the current implementation. Focus on service boundaries, naming consistency, correlation architecture, analysis/AI responsibilities, and cleanup opportunities. Do not propose large rewrites.

## Summary

**Overall: well aligned on the write path; minor read-path and documentation drift.**

The MVP pipeline matches shape-notes and archived plans:

`Intake → Redaction → (on analyze) Correlation::ExtractSignals → Analysis::PromptBuilder → Ai::Client → AiReport`

Controllers delegate mutations to services; models stay thin; security guardrails are implemented and tested. The main gaps are:

1. **Read/display logic** in `DebuggingCasesHelper` (correlation JSON parse, AI structured parse, redaction summary counts, export filename) — conflicts with AGENTS.md “correlation and AI in services.”
2. **Documentation drift** — archived plan diagrams say `ExtractSignals` persists; code persists in `Analysis::AnalyzeCase`. F-03 roadmap change id `ai-adapter-test-harness` vs folder `ai-adapter-foundation`.
3. **Small naming/type nits** — `Ai::Request#case_ref` is integer id, not string; `ResponseValidator` runs twice (planned, but under-documented).
4. **Cleanup opportunities** — unused AI fixture file, stale AGENTS.md line about missing test suite, optional title metadata redaction (description fixed in impl review F1).

No architectural rewrite recommended. Surgical extractions from helper → small service objects would complete boundary alignment.

## Detailed Findings

### 1. Service boundaries — write path ✅

| Domain | Service entry | Called from |
|--------|---------------|-------------|
| Intake | `Intake::ProcessCaseSubmission` | `DebuggingCasesController#create`, `Demo::LoadCase` |
| Redaction | `Redaction::Engine` | `ProcessCaseSubmission` (shared registry) |
| Correlation | `Correlation::ExtractSignals` | `Analysis::AnalyzeCase` only |
| Analysis | `Analysis::AnalyzeCase`, `Analysis::PromptBuilder` | `#analyze` |
| AI | `Ai::ClientResolver`, clients, `Request`, `ResponseValidator` | `AnalyzeCase`, env-gated production |

Matches `context/foundation/shape-notes.md` business logic (lines 147–156) and `AGENTS.md` (line 38).

### 2. Service boundaries — read path ⚠️

`DebuggingCasesController#show` loads records then delegates parsing to helper methods:

```16:24:app/controllers/debugging_cases_controller.rb
  def show
    @debugging_case = current_user.debugging_cases.includes(log_sources: :redaction_findings).find(params[:id])
    @log_sources = @debugging_case.log_sources.order(:position)
    @findings = @log_sources.flat_map(&:redaction_findings)
    @correlation_signal = @debugging_case.correlation_signals.order(:created_at).last
    @correlation_signals = parse_correlation_signals(@correlation_signal)
    @ai_report = @debugging_case.ai_reports.order(:created_at).last
    @ai_report_structured = parse_ai_report_structured(@ai_report)
    @fake_ai_client_active = Ai::ClientResolver.fake_client_active?
```

Helper methods implement domain read logic:

```14:39:app/helpers/debugging_cases_helper.rb
  def redaction_summary_counts(findings)
    findings.group_by { |finding| [ finding.finding_type, finding.risk_level ] }
            .transform_values(&:count)
            ...
  end

  def parse_correlation_signals(correlation_signal)
    ...
    JSON.parse(correlation_signal.payload).fetch("signals", [])
  end

  def parse_ai_report_structured(ai_report)
    ...
    JSON.parse(ai_report.structured_json)
  end

  def report_download_filename(debugging_case)
    ...
  end
```

**Mismatch:** AGENTS.md assigns correlation and AI to `app/services/<domain>/`. Helpers should remain presentation-only (labels, select options).

**Small fix (no rewrite):** Extract three one-file service objects:

- `Correlation::ParsePayload.call(correlation_signal)` (~10 lines)
- `Analysis::ParseStructuredReport.call(ai_report)` or `AiReport#structured_hash` (~10 lines)
- `Redaction::SummaryCounts.call(findings:)` (~8 lines)

Optional: `Analysis::ReportExport` for `download_report` filename + body lookup (~15 lines).

### 3. Correlation architecture — mostly aligned, doc drift

**When correlation runs:** Only on `POST analyze`, inside `Analysis::AnalyzeCase`, after `AiReport` created as `processing`:

```22:30:app/services/analysis/analyze_case.rb
      ai_report = @debugging_case.ai_reports.create!(status: :processing)
      correlation_payload = Correlation::ExtractSignals.call(debugging_case: @debugging_case)
      persist_correlation_signal!(correlation_payload)
      request = Analysis::PromptBuilder.call(
        debugging_case: @debugging_case,
        correlation_payload: correlation_payload
      )
```

**Who persists:** Orchestrator, not extractor:

```48:51:app/services/analysis/analyze_case.rb
    def persist_correlation_signal!(correlation_payload)
      @debugging_case.correlation_signals.create!(
        payload: JSON.generate(correlation_payload)
      )
```

**Extractor is pure** — scans sanitized placeholders + finding types (`app/services/correlation/extract_signals.rb`). Matches detailed S-03 plan; **conflicts with S-03 plan-brief diagram** that labels “ExtractSignals (persist CorrelationSignal)”.

**Re-analyze behavior:** New `CorrelationSignal` + `AiReport` each run; show uses latest by `created_at`. Not specified in PRD; acceptable for MVP but worth documenting.

**On AI failure:** Correlation row still persisted; only report marked `failed`. Matches synchronous session NFR.

### 4. Analysis vs Ai responsibilities — aligned with planned split

| Concern | Module | Notes |
|---------|--------|-------|
| Case orchestration, retry, DB writes | `Analysis::AnalyzeCase` | Owns lifecycle |
| Prompt assembly from sanitized evidence | `Analysis::PromptBuilder` | Sole producer (documented F4 fix) |
| Provider HTTP, JSON parse | `Ai::OpenAiClient` | Env-gated |
| Request envelope, metadata guard | `Ai::Request` | Content guard deferred to upstream |
| Schema + validation | `Ai::ResponseValidator`, `Ai::ReportSchema` | Shared |
| Test/CI client | `Ai::FakeClient` | Never calls network |

**Double validation:** `ResponseValidator` in clients (`fake_client.rb:13`, `open_ai_client.rb:21`) and orchestrator (`analyze_case.rb:60`). Planned per F-03 handoff + S-03; F-03 brief diagram shows only one validation point — **doc mismatch, not code bug**.

**Client injection:** S-03 plan-brief says resolver in controller; implementation uses default kwarg on `AnalyzeCase.call` (`analyze_case.rb:13`). Specs stub resolver — **acceptable deviation**.

**`case_ref` type:** F-03 plan specifies String; `PromptBuilder` passes integer id (`prompt_builder.rb:22`). Cosmetic.

### 5. Naming consistency ⚠️ (low impact)

| Canonical (roadmap/plan) | Implementation | Impact |
|--------------------------|----------------|--------|
| F-03 change id `ai-adapter-test-harness` | Folder/archive `ai-adapter-foundation` | Navigation only; noted in roadmap Done |
| `CorrelationSignal` model | `Correlation::ExtractSignals` service | Clear naming |
| `AiReport#structured_json` column | Parsed in helper, not `Analysis::` | Boundary smell |
| `Demo::` namespace | Not in original roadmap streams | Fine — S-06 additive |

Roadmap baseline (updated 2026-05-28) now reflects MVP; archived plans remain historical source.

### 6. Metadata redaction — partial vs shape-notes

F1 impl review fixed **description** redaction in `ProcessCaseSubmission`. **Title** still stored plain and included in AI prompts (`prompt_builder.rb:36`). Shape-notes list title as metadata input; F-02 intentionally left title unencrypted. Low risk; optional one-line `redact_metadata` for title if parity with description desired.

### 7. Cleanup opportunities (small, local)

| Item | Location | Suggestion |
|------|----------|------------|
| Unused fixture | `spec/support/fixtures/ai/valid_report.json` | Wire `FakeClient` to load it **or** delete file + note inline canonical in `ReportSchema` |
| Stale AGENTS.md | `AGENTS.md:34` “No test suite yet” | Update to “105 RSpec examples; extend when adding features” |
| Default Rails job | `app/jobs/application_job.rb` | Leave (harmless scaffold) or delete if team prefers minimal tree |
| Duplicate `ResponseValidator` call | `analyze_case.rb:60` | Keep for defense-in-depth; **or** remove orchestrator call and rely on clients only (~1 line + spec tweak) |
| `mvp-impl-review.md` verdict table | Still shows Safety WARNING | Update to PASS after F1–F7 fixes (doc hygiene) |

### 8. What matches canonical source well ✅

- No raw persistence columns; encrypted diagnostic fields per F-02 plan
- Devise modules per shape-notes (`user.rb:2`)
- Synchronous analyze, no background jobs
- Demo loader dev/test only (`Demo::LoadCase.available?`)
- Fake AI in test via `ClientResolver` (`client_resolver.rb:6`)
- Security specs for intake, analyze, export
- Server-rendered Rails UI (no React)

## Code References

- `app/services/intake/process_case_submission.rb` — intake + redaction orchestration
- `app/services/correlation/extract_signals.rb` — pure correlation extraction
- `app/services/analysis/analyze_case.rb` — analyze orchestrator + persistence
- `app/services/analysis/prompt_builder.rb` — sanitized AI prompt builder
- `app/services/ai/client_resolver.rb` — env-gated client selection
- `app/helpers/debugging_cases_helper.rb:14-39` — read-path logic to relocate
- `app/controllers/debugging_cases_controller.rb` — mostly thin HTTP layer
- `context/foundation/shape-notes.md:147-174` — canonical business logic + boundaries
- `AGENTS.md:38` — controller vs service rule

## Architecture Insights

1. **Two-speed architecture:** Write pipeline is cleanly service-bound; read pipeline still uses helpers as ad-hoc service layer. This is the highest-value alignment gap and fixable in ~4 small extractions.
2. **Analysis owns persistence boundaries:** Correlation extraction stays pure; orchestrator writes both `CorrelationSignal` and `AiReport`. Prefer updating archived plan diagrams over moving persistence into `ExtractSignals`.
3. **Ai layer is provider-portable:** No case knowledge below `Analysis::PromptBuilder` — good for future provider swap.
4. **Documentation lags code in places:** Roadmap/deploy-plan recently refreshed; archived plan briefs and AGENTS.md still have pre-MVP statements.

## Historical Context (from prior changes)

- `context/archive/2026-05-27-safe-multi-source-intake/plan.md` — established `app/services/{redaction,intake}/` layout
- `context/archive/2026-05-27-analyze-hypothesis-report/plan-brief.md` — defined Analysis/Correlation split (diagram persistence wording differs from code)
- `context/archive/2026-05-27-ai-adapter-foundation/plan.md` — F-03 Ai adapter contract; some items deferred (content guard → documented in F4 triage)
- `context/reviews/mvp-impl-review.md` — post-MVP fixes; architecture sound, minor gaps addressed

## Recommended next steps (minimal scope)

**Priority 1 — boundary cleanup (~1 session, no behavior change):**

1. Move helper parsers/aggregators to `Correlation::`, `Analysis::`/`Redaction::` service objects
2. Update helper to delegate or remove moved methods

**Priority 2 — doc hygiene (~30 min):**

1. Fix AGENTS.md test suite line
2. Add one-line comment on `AnalyzeCase#persist_correlation_signal!` pointing to S-03 ownership decision
3. Optionally redact `title` like `description` if metadata parity desired

**Priority 3 — optional polish:**

1. Delete or wire `valid_report.json`
2. Pass `case_ref` as string in `PromptBuilder` for F-03 contract alignment

## Open Questions

1. Should re-analyze append or replace correlation/report rows? (Current: append; show uses latest.)
2. Is helper→service extraction worth a dedicated change (`read-path-services`) or folded into next feature slice?

## Related Research

- `context/reviews/mvp-impl-review.md` — security/behavior review (APPROVED)
- `context/changes/architecture-alignment/research.md` — this document
