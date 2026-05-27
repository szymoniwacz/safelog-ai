# Analyze Hypothesis Report (S-03) Implementation Plan

## Overview

Land roadmap **S-03**: signed-in users run **Analyze case** on an existing sanitized debugging case; deterministic correlation extraction builds placeholder-based signals; the F-03 AI adapter receives sanitized evidence only; validated hypothesis-framed structured JSON + Markdown persist on `AiReport`; case show displays correlation signals and report. Synchronous session-only flow (no background jobs). Unblocks **S-04** Markdown export.

## Current State Analysis

- **Intake (S-02):** `Redaction::Engine`, `Intake::ProcessCaseSubmission`, `DebuggingCasesController` new/create/show, sanitized logs + redaction summary UI.
- **AI adapter (F-03):** `Ai::Client`, `FakeClient`, `OpenAiClient`, `Request`, `CompletionResult`, `ResponseValidator`, `ReportSchema`; test env uses `FakeClient`; WebMock blocks external HTTP.
- **Schema (F-02):** `correlation_signals.payload` (encrypted text), `ai_reports.structured_json` + `markdown_body` (encrypted), `status` enum `pending`/`processing`/`generated`/`failed`.
- **Models:** `CorrelationSignal`, `AiReport` belong to `DebuggingCase`; no service logic yet.
- **Routes:** `resources :debugging_cases, only: [:new, :create, :show]` — no analyze action.

### Key Discoveries:

- AGENTS.md: AI receives sanitized evidence only; never raw logs, mappings, or originals; persist validated AI reports only.
- PRD US-01: invalid AI JSON retried once; then `failed` with safe user message.
- PRD: analyze completes in same browser session (sync POST → redirect).
- F-03 deferred retry to S-03 orchestrator (`Analysis::AnalyzeCase`).
- S-02 cross-source correlation already uses shared placeholders (e.g. `[REQUEST_1]` in multiple sources) — correlation extractor can derive signals from shared placeholders without raw values.
- `Ai::Request` rejects metadata keys matching `/raw|original|mapping/i`.

## Desired End State

After this plan:

1. `POST /debugging_cases/:id/analyze` runs synchronously for case owner.
2. `Correlation::ExtractSignals` produces sanitized signal hashes and persists one `CorrelationSignal` per analyze run.
3. `Analysis::PromptBuilder` builds `Ai::Request` from sanitized log bodies, case metadata, and correlation payload — no raw intake secrets.
4. `Analysis::AnalyzeCase` orchestrates extract → prompt → `client.complete` → validate → persist `AiReport`; retries once on `Ai::InvalidResponseError`.
5. Case show renders Analyze button, correlation signals section, and hypothesis report (summary, hypotheses, uncertainty notes); safe failure message when status `failed`.
6. Service + request specs prove sanitized-only AI prompts and cross-user analyze denial.
7. `bin/ci` green.

### Verification

- Automated: correlation specs, analysis specs, analyze request specs, security specs, full `bin/ci`.
- Manual: browser flow on case with shared `[REQUEST_1]` → analyze → signals + report visible.

## What We're NOT Doing

- Markdown copy/download (S-04), archive UX (S-05), demo loader (S-06).
- Background jobs, ActionCable progress, or async analyze by case ID.
- Prompt persistence tables or logging full AI request bodies.
- Sending raw log text, redaction originals, or placeholder-to-raw maps to AI.
- New schema migrations (use existing F-02 tables).
- React/Vite UI.

## Implementation Approach

Build bottom-up: correlation extractor (pure + persistence) → prompt builder → analyze orchestrator (retry + AiReport) → thin controller member action → show UI partials. Inject `client:` into analyze service for specs. Controller stays HTTP-only; no AI logic in views.

## Critical Implementation Details

**Correlation payload shape (MVP):** JSON object with `signals` array. Each signal: `placeholder` (String, e.g. `[REQUEST_1]`), `finding_types` (Array of String from redaction findings), `source_types` (Array of String — log source types where placeholder appears), `occurrence_count` (Integer). No original values, no raw substrings, no placeholder maps.

**Re-analyze:** Each analyze run creates a new `CorrelationSignal` and new `AiReport`. Show page displays latest `AiReport` by `created_at` desc and latest correlation signal similarly.

**Retry-once:** On first `Ai::InvalidResponseError` from validator, call `client.complete` a second time with the same request. Second failure → `AiReport` status `failed`, no structured/markdown body persisted (or persist nil), user sees generic safe message.

**Prompt content:** Include case `title`, `environment`, sanitized `customer_reference`, ordered log sources (type, optional name, sanitized body), and serialized correlation signals. Use clearly labeled sections in a single user message (or system + user) — content must be placeholder-safe only.

## Phase 1: Correlation Signal Extractor

### Overview

Deterministic extraction of cross-source correlation from sanitized evidence already persisted by S-02.

### Changes Required:

#### 1. Extractor service

**File:** `app/services/correlation/extract_signals.rb`

**Intent:** `Correlation::ExtractSignals.call(debugging_case:)` loads `log_sources` + `redaction_findings`, scans sanitized content for placeholder tokens matching `/\[[A-Z]+_\d+\]/`, groups by placeholder across sources, enriches with finding types from `RedactionFinding` rows, returns `{ signals: [...] }` hash suitable for JSON serialization.

**Contract:** No reads of raw params; no original values in output; deterministic for same case data.

#### 2. Persist helper (optional inline in Phase 2)

**File:** same or called from analyze orchestrator in Phase 2

**Intent:** Create `CorrelationSignal` with `payload` = JSON.generate(result) (Rails encryption on model).

**Contract:** Payload contains placeholders only.

#### 3. Unit specs

**File:** `spec/services/correlation/extract_signals_spec.rb`

**Intent:** Case with two sources sharing `[REQUEST_1]` → one signal with `occurrence_count >= 2` and both source types listed; single-source placeholder → signal with count 1; no raw secret strings from factory intake in payload.

**Contract:** Build case via `Intake::ProcessCaseSubmission` in specs.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/correlation/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: run extractor on existing case; inspect signal hash contains placeholders only

**Implementation Note:** Pause for human confirmation before Phase 2.

---

## Phase 2: Analyze Orchestration Service

### Overview

Wire correlation extraction, prompt building, AI call, validation, retry, and `AiReport` persistence.

### Changes Required:

#### 1. Prompt builder

**File:** `app/services/analysis/prompt_builder.rb`

**Intent:** `Analysis::PromptBuilder.call(debugging_case:, correlation_payload:)` returns `Ai::Request` with messages built from sanitized fields only and optional `case_ref: debugging_case.id`.

**Contract:** Message content must not include keys forbidden by `Ai::Request`; use only persisted sanitized text.

#### 2. Analyze orchestrator

**File:** `app/services/analysis/analyze_case.rb`

**Intent:** `Analysis::AnalyzeCase.call(debugging_case:, client: Ai::ClientResolver.current)` runs: create `AiReport` status `processing`; extract signals + persist `CorrelationSignal`; build request; `client.complete`; `ResponseValidator.call`; on success update `AiReport` to `generated` with structured + markdown; on `InvalidResponseError` retry once; on second failure set `failed`. Return result object with `success?`, `ai_report`, `user_message`.

**Contract:** Single synchronous call chain; no logging of prompt content; injectable `client` for tests.

#### 3. Service specs

**Files:** `spec/services/analysis/prompt_builder_spec.rb`, `spec/services/analysis/analyze_case_spec.rb`

**Intent:** Prompt excludes raw secret used at intake; includes `[EMAIL_1]` or `[REQUEST_1]` as appropriate. AnalyzeCase with `FakeClient` persists `generated` report. Invalid-first-response double triggers exactly two `complete` calls then `failed` status.

**Contract:** Use unique fake secrets in intake submission setup.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/analysis/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: `Analysis::AnalyzeCase.call(debugging_case:, client: Ai::FakeClient.new)` on fixture case

**Implementation Note:** Pause for human confirmation before Phase 3.

---

## Phase 3: Analyze Route and Controller Action

### Overview

HTTP entry point for synchronous analyze scoped to case owner.

### Changes Required:

#### 1. Route

**File:** `config/routes.rb`

**Intent:** Add member route `post :analyze` on `debugging_cases`.

**Contract:** Route nested under authenticated controller.

#### 2. Controller action

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `#analyze` loads case via `current_user.debugging_cases.find(params[:id])`, calls `Analysis::AnalyzeCase`, redirects to `show` with flash notice or alert from result.

**Contract:** No params beyond id; no logging of case content.

#### 3. Request specs (happy path)

**File:** `spec/requests/debugging_cases_analyze_spec.rb`

**Intent:** Signed-in owner POST analyze → redirect to show → body includes report summary or hypothesis heading; guest/other user denied.

**Contract:** Case created via intake with sanitized content.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- Optional until Phase 4: routes listed for analyze member

**Implementation Note:** Pause for human confirmation before Phase 4.

---

## Phase 4: Analyze UI on Case Show

### Overview

Analyze button and display sections for correlation signals and AI report on case detail.

### Changes Required:

#### 1. Show controller ivars

**File:** `app/controllers/debugging_cases_controller.rb` (`#show`)

**Intent:** Load `@correlation_signal` (latest), `@ai_report` (latest), parse correlation payload for view if needed.

**Contract:** Render only persisted sanitized/validated data.

#### 2. Analyze button

**File:** `app/views/debugging_cases/show.html.erb`

**Intent:** `button_to "Analyze case", analyze_debugging_case_path(@debugging_case), method: :post` when no generated report or allow re-analyze (MVP: always show button).

**Contract:** POST only; CSRF via Rails helper.

#### 3. Correlation signals partial

**File:** `app/views/debugging_cases/_correlation_signals.html.erb`

**Intent:** List signals with placeholder, finding types, source types, counts. Empty state when none.

**Contract:** No original values.

#### 4. Report partial

**File:** `app/views/debugging_cases/_ai_report.html.erb`

**Intent:** When `generated`: summary, hypotheses list (title + description), uncertainty notes. When `failed`: safe message. When `processing`: optional brief note (unlikely on sync redirect).

**Contract:** Hypothesis language from stored JSON only; escape HTML via ERB default.

#### 5. Helper (optional)

**File:** `app/helpers/debugging_cases_helper.rb`

**Intent:** Parse correlation JSON safely; format report sections.

**Contract:** Rescues JSON parse errors to empty state.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: analyze case → signals + report sections visible; failure path shows safe message (simulate with invalid client in dev if needed)

**Implementation Note:** Pause for human confirmation before Phase 5.

---

## Phase 5: Security and Authorization Specs

### Overview

Prove AGENTS.md AI guardrails and analyze authorization at request/service layer.

### Changes Required:

#### 1. Sanitized prompt security spec

**File:** `spec/requests/debugging_cases_analyze_security_spec.rb` (or extend analyze spec)

**Intent:** After intake with known raw secret, POST analyze with injectable `FakeClient` (stub resolver or pass via test hook) — assert `last_request` message content excludes raw secret and includes placeholder.

**Contract:** Spec description references AGENTS.md; use AR reload for DB assertions on correlation payload.

#### 2. Authorization spec

**File:** `spec/requests/debugging_cases_analyze_spec.rb` (or separate)

**Intent:** User B POST analyze on user A case → 404.

**Contract:** Two user factories.

#### 3. Handoff note

**File:** `context/changes/analyze-hypothesis-report/change.md`

**Intent:** S-04 consumes `AiReport#markdown_body` for copy/download.

**Contract:** Notes only.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Optional: confirm no pasted_content in logs during analyze (already filtered from S-02)

**Implementation Note:** Final phase for S-03.

---

## Testing Strategy

### Unit Tests:

- Correlation extractor: shared placeholders, finding type enrichment, empty case edge
- Prompt builder: sanitized-only content, forbidden metadata rejection
- AnalyzeCase: success path, retry-once, failed persistence

### Integration / Request Tests:

- Owner analyze happy path
- Cross-user analyze 404
- Security: no raw in AI request after intake

### Manual Testing Steps:

1. Create case with two sources sharing request id placeholder
2. Analyze → verify correlation signals list shared placeholder
3. Verify report shows summary, hypotheses, uncertainty section
4. Sign in as other user → analyze returns 404

## Performance Considerations

Synchronous OpenAI call may take several seconds — acceptable for MVP per PRD. No timeout customization required in S-03 unless Puma defaults cause issues; document in change notes if encountered.

## Migration Notes

None — uses existing F-02 tables.

## References

- PRD FR-007, FR-008, US-01: `context/foundation/prd.md`
- F-03 adapter: `context/changes/ai-adapter-foundation/plan.md`
- S-02 intake: `context/changes/safe-multi-source-intake/change.md`
- `app/services/ai/report_schema.rb`, `app/models/ai_report.rb`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Correlation Signal Extractor

#### Automated

- [x] 1.1 `bundle exec rspec spec/services/correlation/` passes
- [x] 1.2 `bin/ci` passes

#### Manual

- [ ] 1.3 Console extractor returns placeholder-only signals

### Phase 2: Analyze Orchestration Service

#### Automated

- [x] 2.1 `bundle exec rspec spec/services/analysis/` passes
- [x] 2.2 `bin/ci` passes

#### Manual

- [ ] 2.3 Console AnalyzeCase with FakeClient succeeds

### Phase 3: Analyze Route and Controller Action

#### Automated

- [ ] 3.1 `bundle exec rspec spec/requests/debugging_cases_analyze_spec.rb` passes
- [ ] 3.2 `bin/ci` passes

#### Manual

- [ ] 3.3 Routes include analyze member action

### Phase 4: Analyze UI on Case Show

#### Automated

- [ ] 4.1 Full `bundle exec rspec` passes
- [ ] 4.2 `bin/ci` passes

#### Manual

- [ ] 4.3 Browser analyze flow shows signals and report

### Phase 5: Security and Authorization Specs

#### Automated

- [ ] 5.1 Security + authorization analyze specs pass
- [ ] 5.2 `bin/ci` passes

#### Manual

- [ ] 5.3 Optional log review during analyze
