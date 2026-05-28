# Architecture Alignment Implementation Plan

## Overview

Small post-MVP cleanup aligning the **read/display path** with canonical service boundaries (`AGENTS.md`, `context/foundation/shape-notes.md`). Relocate helper-held domain logic into `app/services/{correlation,redaction,analysis}/`, fix minor naming/doc drift, and remove dead artifacts — **no new product features or schema changes**.

## Current State Analysis

Research (`context/changes/architecture-alignment/research.md`) confirms:

- **Write path aligned:** `Intake → Redaction → Analysis::AnalyzeCase → Correlation::ExtractSignals → PromptBuilder → Ai::Client`
- **Read path drift:** `DebuggingCasesHelper` parses correlation payloads, AI structured JSON, aggregates redaction counts, and builds export filenames (`app/helpers/debugging_cases_helper.rb:14-39`)
- **Doc drift:** AGENTS.md line 34 stale; F-03 `case_ref` typed as integer; unused `spec/support/fixtures/ai/valid_report.json`

### Key Discoveries:

- `#show` sets ivars via helper parsers (`app/controllers/debugging_cases_controller.rb:16-24`); views consume ivars/locals — controller can wire services directly
- `_redaction_summary.html.erb` alone calls `redaction_summary_counts(findings)` in views
- `Analysis::AnalyzeCase#persist_correlation_signal!` owns DB write — intentional per detailed S-03 plan, not extractor

## Desired End State

1. Four small read-path services exist with `.call` entry points and focused specs
2. `DebuggingCasesHelper` contains only presentation helpers (`log_source_type_options`, `finding_type_label`, `SOURCE_SLOT_COUNT`)
3. `#show` assigns `@correlation_signals`, `@ai_report_structured`, `@redaction_summary` via services; `#download_report` uses `Analysis::ReportFilename`
4. `title` metadata redacted like `description` in intake; `PromptBuilder` passes string `case_ref`
5. Orchestrator persistence documented; AGENTS.md and review doc updated; unused AI fixture removed
6. `bin/ci` green; no behavior change visible to users

## What We're NOT Doing

- New routes, models, migrations, or UI features
- Moving `CorrelationSignal` persistence into `Correlation::ExtractSignals`
- Removing orchestrator `ResponseValidator` call (keep defense-in-depth)
- Renaming archived change folders or rewriting archived plan diagrams
- Full export service / presenter layer
- Changing re-analyze append semantics
- Expanding redaction pattern coverage

## Implementation Approach

Extract logic verbatim from helper into namespaced service objects matching write-path domains. Update controller and one partial; delete helper domain methods. Phase 2 handles naming/intake parity and inline comments. Phase 3 is doc-only + fixture deletion.

## Critical Implementation Details

**Correlation persistence ownership:** Do not move `correlation_signals.create!` out of `Analysis::AnalyzeCase`. Add a brief comment on `#persist_correlation_signal!` noting S-03 intentional split (pure extractor, orchestrator persists).

**Parser error handling:** Preserve helper behavior — invalid JSON returns `[]` for correlation signals and `nil` for structured report.

---

## Phase 1: Read-Path Service Extraction

### Overview

Move domain read logic from helper to services; wire controller and redaction partial.

### Changes Required:

#### 1. Correlation payload parser

**File:** `app/services/correlation/parse_payload.rb`

**Intent:** Parse encrypted `CorrelationSignal#payload` into the `signals` array for display.

**Contract:** `Correlation::ParsePayload.call(correlation_signal:)` → `Array` (empty when blank/invalid JSON).

#### 2. Redaction summary counts

**File:** `app/services/redaction/summary_counts.rb`

**Intent:** Group findings by `[finding_type, risk_level]` and count for FR-005 summary display.

**Contract:** `Redaction::SummaryCounts.call(findings:)` → sorted Hash keyed by `[finding_type, risk_level]`.

#### 3. Structured report parser

**File:** `app/services/analysis/parse_structured_report.rb`

**Intent:** Parse `AiReport#structured_json` for show partial rendering.

**Contract:** `Analysis::ParseStructuredReport.call(ai_report:)` → `Hash` or `nil`.

#### 4. Report download filename

**File:** `app/services/analysis/report_filename.rb`

**Intent:** Build parameterized `.md` filename for export (same rules as current helper).

**Contract:** `Analysis::ReportFilename.call(debugging_case:)` → String ending in `-report.md`.

#### 5. Controller wiring

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `#show` calls the three parsers/summary services for ivars; `#download_report` uses `Analysis::ReportFilename`.

**Contract:** Replace helper parser calls; assign `@redaction_summary` for partial.

#### 6. View partial

**File:** `app/views/debugging_cases/_redaction_summary.html.erb`

**Intent:** Use `@redaction_summary` (or local `summary`) instead of calling helper aggregator.

**Contract:** No direct service calls from views.

#### 7. Helper cleanup

**File:** `app/helpers/debugging_cases_helper.rb`

**Intent:** Remove `redaction_summary_counts`, `parse_correlation_signals`, `parse_ai_report_structured`, `report_download_filename`.

**Contract:** Remaining methods are presentation-only.

#### 8. Service specs

**Files:** `spec/services/correlation/parse_payload_spec.rb`, `spec/services/redaction/summary_counts_spec.rb`, `spec/services/analysis/parse_structured_report_spec.rb`, `spec/services/analysis/report_filename_spec.rb`

**Intent:** Cover happy path, blank input, invalid JSON where applicable; mirror current helper behavior.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/correlation/parse_payload_spec.rb spec/services/redaction/summary_counts_spec.rb spec/services/analysis/parse_structured_report_spec.rb spec/services/analysis/report_filename_spec.rb`
- `mise exec -- bundle exec rspec spec/requests/debugging_cases_spec.rb spec/requests/debugging_cases_report_export_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- Case show page still renders redaction summary, correlation signals, and AI report after analyze
- Download report filename unchanged for a sample case

**Implementation Note:** Pause before Phase 2.

---

## Phase 2: Naming & Intake Parity

### Overview

Minor contract alignment and metadata redaction consistency; document orchestrator ownership.

### Changes Required:

#### 1. Title metadata redaction

**File:** `app/services/intake/process_case_submission.rb`

**Intent:** Run `title` through `redact_metadata` with the shared registry (same as `description` and `customer_reference`).

**Contract:** Secrets in title become placeholders; shared registry with log sources.

#### 2. Intake spec extension

**File:** `spec/services/intake/process_case_submission_spec.rb` or `spec/requests/debugging_cases_security_spec.rb`

**Intent:** Assert secret in title does not persist raw or appear in show body.

**Contract:** One focused example; no new security surface.

#### 3. F-03 case_ref type

**File:** `app/services/analysis/prompt_builder.rb`

**Intent:** Pass `case_ref: debugging_case.id.to_s` to `Ai::Request`.

**Contract:** Update `spec/services/analysis/prompt_builder_spec.rb` expectation if present.

#### 4. Orchestrator comment

**File:** `app/services/analysis/analyze_case.rb`

**Intent:** Comment on `#persist_correlation_signal!` — extractor is pure; orchestrator owns persistence (S-03).

**Contract:** Comment only; no logic change.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/ spec/services/analysis/prompt_builder_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- None required — behavior-preserving metadata hardening

**Implementation Note:** Pause before Phase 3.

---

## Phase 3: Documentation & Dead-Code Cleanup

### Overview

Sync agent onboarding docs and remove unused test fixture; update impl-review artifact.

### Changes Required:

#### 1. AGENTS.md

**File:** `AGENTS.md`

**Intent:** Replace “No test suite yet” with current RSpec/`bin/ci` guidance (~105+ examples).

**Contract:** One paragraph; no duplicate PRD content.

#### 2. Remove unused AI fixture

**File:** `spec/support/fixtures/ai/valid_report.json` (delete)

**Intent:** `FakeClient` uses `ReportSchema` canonical constants — fixture is unused.

**Contract:** Confirm no references via grep before delete.

#### 3. Impl review doc sync

**File:** `context/reviews/mvp-impl-review.md`

**Intent:** Update Security checklist row for encryption tests and verdict table Safety row to PASS (doc hygiene only).

**Contract:** No code changes.

#### 4. Change handoff

**File:** `context/changes/architecture-alignment/change.md`

**Intent:** Set `status: implemented` when all phases complete.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bin/ci`

#### Manual Verification:

- Grep confirms no references to deleted fixture path

**Implementation Note:** Final phase.

---

## Testing Strategy

### Unit Tests:

- Each new service: blank input, valid payload, malformed JSON (where applicable)
- Title redaction: one example with email in title

### Integration Tests:

- Existing request specs must pass without modification (behavior unchanged)
- Export and show flows covered by existing specs

### Manual Testing Steps:

1. Create case → show displays redaction summary
2. Analyze → correlation + report render
3. Download report → correct filename

## Performance Considerations

None — pure in-memory parsing/aggregation; no new queries.

## Migration Notes

None — no schema or data migration.

## References

- Research: `context/changes/architecture-alignment/research.md`
- Canonical boundaries: `AGENTS.md:38`, `context/foundation/shape-notes.md:147-174`
- Helper source: `app/helpers/debugging_cases_helper.rb:14-39`
- S-03 orchestrator: `app/services/analysis/analyze_case.rb:48-51`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Read-Path Service Extraction

#### Automated

- [x] 1.1 Service specs pass for correlation/redaction/analysis read-path
- [x] 1.2 Relevant request specs pass
- [x] 1.3 `bin/ci` passes

#### Manual

- [ ] 1.4 Case show + download verified in browser

### Phase 2: Naming & Intake Parity

#### Automated

- [x] 2.1 Intake/analysis specs pass
- [x] 2.2 `bin/ci` passes

### Phase 3: Documentation & Dead-Code Cleanup

#### Automated

- [x] 3.1 `bin/ci` passes after fixture removal

#### Manual

- [x] 3.2 No dangling references to deleted fixture
