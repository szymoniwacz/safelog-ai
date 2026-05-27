# Safe Multi-Source Intake (S-02) Implementation Plan

## Overview

Land roadmap **S-02** (north star): signed-in users create a debugging case with metadata and multiple pasted log sources in **one request**; deterministic in-memory redaction assigns case-local placeholders; only sanitized logs and redaction findings persist; case detail displays sanitized evidence and a security summary — raw content never shown again. Server-rendered Rails UI; services own redaction and intake. Unblocks **S-03** analyze flow.

## Current State Analysis

- **Schema:** F-02 complete — `debugging_cases`, `log_sources`, `redaction_findings` with AR Encryption on `customer_reference` and `sanitized_content` (`db/schema.rb`).
- **Models:** `DebuggingCase`, `LogSource` (source_type enum), `RedactionFinding` — no intake validations beyond `title` presence.
- **Auth:** S-01 request specs; `AuthenticatedController` gating; no case routes.
- **Services:** `app/services/ai/` only (F-03); no redaction/intake.
- **UI:** Dashboard placeholder; no case forms or detail pages.
- **Param filter:** Password/token keys filtered; pasted log params not yet filtered (`config/initializers/filter_parameter_logging.rb`).

### Key Discoveries:

- AGENTS.md: raw text transient per request; no raw columns; no persisted placeholder maps; no raw in logs/AI.
- PRD patterns: email, token, IP, session ID, customer ID, request ID, Authorization header, phone, card last4 — case-local placeholders like `[EMAIL_1]`, cross-source correlation within one submission.
- FR-003 requires all sources in initial submission — no post-create source add (Non-Goals).
- US-01 acceptance: user A cannot access user B's case — request spec in this slice.
- `LogSource#position` from F-02 supports stable ordering in UI.

## Desired End State

After this plan:

1. Routes: `resources :debugging_cases, only: [:new, :create, :show]` under authentication.
2. `Redaction::Engine` redacts pasted text using shared in-memory `Redaction::PlaceholderRegistry` per submission.
3. `Intake::ProcessCaseSubmission` builds case + sources + findings in one transaction; raw strings never assigned to AR attributes except transient local variables.
4. Case show renders sanitized log bodies (copy-friendly), findings grouped for summary counts by `finding_type` and `risk_level`.
5. Request/security specs prove raw substrings absent from DB and show response; cross-user `show` returns 404.
6. `bin/ci` green.

### Verification

- Automated: service specs, request specs, full `bin/ci`.
- Manual: browser flow with intentional secrets in paste → detail shows placeholders only.

## What We're NOT Doing

- Analyze case, correlation extraction, AI adapter calls (S-03).
- Markdown export (S-04), archive UX (S-05), demo loader (S-06).
- File upload, live log integrations, background jobs.
- Adding log sources after initial create.
- Persisting raw content, placeholder maps, hashes of raw values.
- React/Vite UI.

## Implementation Approach

Build bottom-up: redaction engine (pure, well-tested) → intake orchestrator (transaction + persistence) → thin controller (params, redirect, render) → ERB views. Keep raw field name `pasted_content` in params only; filter it from logs. On validation failure, re-render form **without** re-populating pasted fields (metadata fields may repopulate).

## Critical Implementation Details

**Validation error UX:** If case metadata invalid or no sources provided, re-render `new` with safe metadata values only — do not put submitted paste back into textareas (prevents accidental shoulder-surf and matches “raw not shown again” spirit).

**Shared registry lifetime:** Instantiate one `Redaction::PlaceholderRegistry` per `Intake::ProcessCaseSubmission` call; pass into each `Redaction::Engine.redact` invocation so identical tokens across sources share placeholders.

**Finding types & risk:** Map detectors to stable `finding_type` strings (e.g. `email`, `authorization_header`, `request_id`) and `risk_level` (`high`, `medium`, `low`) — document mapping in engine; authorization/token/email typically `high`.

## Phase 1: Redaction Engine

### Overview

Pure in-memory redaction: detect PRD patterns, assign correlated placeholders, return sanitized text + finding metadata.

### Changes Required:

#### 1. Placeholder registry

**File:** `app/services/redaction/placeholder_registry.rb`

**Intent:** In-memory class tracking `{ normalized_value => placeholder }` and counters per type prefix (`EMAIL`, `REQUEST`, etc.). `#placeholder_for(type:, value:)` returns existing or allocates `[TYPE_N]`.

**Contract:** No serialization, no DB, no logging of raw values.

#### 2. Pattern detectors / engine

**Files:** `app/services/redaction/engine.rb`, optionally `app/services/redaction/patterns.rb`

**Intent:** `Redaction::Engine.redact(text, registry:)` returns result object with `sanitized_text` and `findings` (array of hashes: `finding_type`, `line_number`, `placeholder`, `risk_level`). Apply regex/heuristics for PRD types; record line numbers from pre-redaction line split.

**Contract:** Deterministic for same input+registry state; never mutate registry into persistence layer.

#### 3. Result object

**File:** `app/services/redaction/result.rb`

**Intent:** Simple struct/value object holding sanitized text and findings array for one source.

**Contract:** Findings contain no original values.

#### 4. Unit specs

**Files:** `spec/services/redaction/engine_spec.rb`, `spec/services/redaction/placeholder_registry_spec.rb`

**Intent:** Cover email/token/request ID redaction; cross-call placeholder reuse via shared registry; line numbers; no original in findings.

**Contract:** Table-driven examples with known raw snippets (use obviously fake secrets in specs).

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/redaction/`
- `mise exec -- bin/ci`

#### Manual Verification:

- `rails runner` quick redact of sample multiline string (optional; no persistence)

**Implementation Note:** Pause for human confirmation before Phase 2.

---

## Phase 2: Intake Orchestration Service

### Overview

Wire redaction into a transactional service that creates the full case tree from one submission payload.

### Changes Required:

#### 1. Submission value object

**File:** `app/services/intake/case_submission.rb`

**Intent:** Holds case metadata (`title`, `description`, `customer_reference`, `environment`) and array of source hashes (`source_type`, `name`, `pasted_content`) — `pasted_content` is raw and transient.

**Contract:** No ActiveRecord; validates at least one source with non-blank paste.

#### 2. Process service

**File:** `app/services/intake/process_case_submission.rb`

**Intent:** `Intake::ProcessCaseSubmission.call(user:, submission:)` creates `DebuggingCase`, iterates sources with shared `PlaceholderRegistry`, runs engine, creates `LogSource` + `RedactionFinding` rows, returns case or raises/returns errors object.

**Contract:** Single DB transaction; `sanitized_content` only on `LogSource`; findings metadata only; discard registry after call; optionally redact `customer_reference` through engine before assign.

#### 3. Service specs

**File:** `spec/services/intake/process_case_submission_spec.rb`

**Intent:** Two sources with same request ID → same placeholder in both sanitized bodies; raw secret absent from `LogSource#sanitized_content` and DB; findings persisted count > 0.

**Contract:** Use test DB; assert no column contains raw substring via reload + decrypt.

#### 4. Model tweaks (minimal)

**Files:** `app/models/debugging_case.rb`, `app/models/log_source.rb` (if needed)

**Intent:** Accept nested persistence via service only — add validations (`environment` optional, source presence enforced in service). Do **not** add `accepts_nested_attributes_for` with raw fields.

**Contract:** No new forbidden columns.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: run service with fake multi-source submission; inspect sanitized content in memory/DB

**Implementation Note:** Pause for human confirmation before Phase 3.

---

## Phase 3: Controller, Routes, Authorization

### Overview

HTTP entry points for new/create/show scoped to `current_user`.

### Changes Required:

#### 1. Routes

**File:** `config/routes.rb`

**Intent:** `resources :debugging_cases, only: [:new, :create, :show]`; optional `root` remains dashboard or add nav link to new case (dashboard link only — no root change required).

**Contract:** Routes require authentication via controller inheritance.

#### 2. Controller

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `< AuthenticatedController`; `new` builds empty form context; `create` builds `CaseSubmission`, calls process service, redirects to show on success; `show` loads `@debugging_case` via `current_user.debugging_cases.find(params[:id])` with sources/findings.

**Contract:** Strong params permit metadata + sources array with `source_type`, `name`, `pasted_content`; never log submission; rescue `RecordNotFound` → 404.

#### 3. Param filtering

**File:** `config/initializers/filter_parameter_logging.rb`

**Intent:** Add filters for `:pasted_content`, `:content`, `:raw`, `:log`, `:body` (partial match safe list).

**Contract:** Filter list updated; restart note in change.md only.

#### 4. Request specs (happy path skeleton)

**File:** `spec/requests/debugging_cases_spec.rb` (partial — expanded Phase 5)

**Intent:** Signed-in user can `GET new`, `POST create` with sanitized outcome redirect, `GET show` success.

**Contract:** Use fake paste with known secret substring; assert show body excludes raw secret.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: create case (may wait for Phase 4 views if minimal — controller can work with bare templates temporarily)

**Implementation Note:** Pause for human confirmation before Phase 4.

---

## Phase 4: Case UI (New + Show)

### Overview

Server-rendered forms and detail page: multi-source paste, sanitized display, copy, redaction summary.

### Changes Required:

#### 1. New case form

**File:** `app/views/debugging_cases/new.html.erb`

**Intent:** Case metadata fields + at least two source field groups (type select from enum, optional name, pasted textarea). Submit creates all sources in one POST. Use Stimulus only if needed for “add source” — MVP may use 2–3 fixed slots.

**Contract:** Field name `log_sources[][pasted_content]` or indexed; label clarifies paste is processed once.

#### 2. Show template

**File:** `app/views/debugging_cases/show.html.erb`

**Intent:** Title, metadata (sanitized customer_reference display), each source sanitized body in `<pre>` or textarea readonly with copy button (native `navigator.clipboard` optional — MVP: “select all” instruction or `button` + Stimulus-free `<textarea readonly>` for copy per FR-006).

**Contract:** Render only `@debugging_case` sanitized associations — never flash raw params.

#### 3. Redaction summary partial

**File:** `app/views/debugging_cases/_redaction_summary.html.erb`

**Intent:** Aggregate `@findings` counts grouped by `finding_type` and `risk_level` (Ruby helper or controller ivar `@redaction_summary`).

**Contract:** No original values displayed.

#### 4. Navigation

**Files:** `app/views/dashboard/show.html.erb`, `app/views/layouts/application.html.erb` (optional)

**Intent:** Link “New debugging case” for signed-in users.

**Contract:** Minimal markup.

#### 5. Helper (optional)

**File:** `app/helpers/debugging_cases_helper.rb`

**Intent:** Format source type labels; summary grouping helper.

**Contract:** No raw content handling.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: multi-source submit → detail shows placeholders, summary counts, copy works

**Implementation Note:** Pause for human confirmation before Phase 5.

---

## Phase 5: Security & Authorization Request Specs

### Overview

Prove guardrails: no raw persistence/exposure; cross-user access denied.

### Changes Required:

#### 1. Security examples

**File:** `spec/requests/debugging_cases_security_spec.rb`

**Intent:** After create, query DB for known raw email/token substring from submission — expect zero matches in `log_sources`, `redaction_findings`, `debugging_cases` text columns. Show response body must not include raw secret.

**Contract:** Spec names reference AGENTS.md; use unique fake secrets.

#### 2. Authorization examples

**File:** `spec/requests/debugging_cases_authorization_spec.rb` (or merge into main request spec)

**Intent:** User B `GET` user A case id → 404; user A success.

**Contract:** Two factories `:user` records.

#### 3. Cross-source correlation spec

**File:** `spec/services/redaction/engine_spec.rb` or intake spec (if not done)

**Intent:** Explicit example: two sources, same request id → identical placeholder in both sanitized outputs.

**Contract:** Already may exist from Phase 1/2 — add request-level example if missing.

#### 4. Handoff note

**File:** `context/changes/safe-multi-source-intake/change.md`

**Intent:** S-03 consumes sanitized cases; analyze button/UI deferred.

**Contract:** Notes only.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Optional: tail log during create — confirm filtered params for paste fields

**Implementation Note:** Final phase for S-02.

---

## Testing Strategy

### Unit Tests:

- Redaction engine patterns, registry correlation, line numbers
- Intake service transaction and persistence shape

### Request Tests:

- CRUD path new/create/show
- Security: no raw in DB/response
- Authorization: cross-user 404

### Manual Testing Steps:

1. Submit case with email + Bearer token in two sources sharing a request id.
2. Confirm placeholders and matching `[REQUEST_N]` across sources.
3. Sign in as other user — case URL not accessible.

## Performance Considerations

Synchronous in-request redaction OK for MVP paste size; no background queue. Avoid O(n²) re-scans if paste large — single-pass per line acceptable for MVP.

## Migration Notes

None — schema exists from F-02.

## References

- Roadmap S-02: `context/foundation/roadmap.md`
- PRD FR-002–FR-006, US-01: `context/foundation/prd.md`
- F-02 schema: `context/changes/encrypted-diagnostic-schema/change.md`
- S-01 auth: `context/changes/account-access/change.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Redaction Engine

#### Automated

- [ ] 1.1 `bundle exec rspec spec/services/redaction/` passes
- [ ] 1.2 `bin/ci` passes

#### Manual

- [ ] 1.3 Optional runner smoke on sample string

### Phase 2: Intake Orchestration Service

#### Automated

- [ ] 2.1 `bundle exec rspec spec/services/intake/` passes
- [ ] 2.2 `bin/ci` passes

#### Manual

- [ ] 2.3 Console/service spot-check multi-source create

### Phase 3: Controller, Routes, Authorization

#### Automated

- [ ] 3.1 `bundle exec rspec spec/requests/debugging_cases_spec.rb` passes
- [ ] 3.2 `bin/ci` passes

#### Manual

- [ ] 3.3 Routes listed for debugging_cases

### Phase 4: Case UI (New + Show)

#### Automated

- [ ] 4.1 Full `bundle exec rspec` passes
- [ ] 4.2 `bin/ci` passes

#### Manual

- [ ] 4.3 Browser end-to-end intake flow

### Phase 5: Security & Authorization Request Specs

#### Automated

- [ ] 5.1 Security + authorization request specs pass
- [ ] 5.2 `bin/ci` passes

#### Manual

- [ ] 5.3 Log review confirms pasted params filtered
