# Intake Persist Extraction Implementation Plan

## Overview

Extract `redact_metadata` and the AR persist layer from
`Intake::ProcessCaseSubmission` into dedicated services
(`Intake::RedactMetadata`, `Intake::PersistRedactedCase`), leaving a thin
coordinator that validates input, owns the shared placeholder registry, runs
`Redaction::Engine` per source, and maps errors to the existing `Result` type.
Public `.call(user:, submission:)` / `Result` contract stays unchanged for
`DebuggingCasesController` and `Demo::LoadCase`.

## Current State Analysis

`ProcessCaseSubmission` (~74 lines) mixes validation gating, registry
lifecycle, metadata redaction, per-source engine redaction, a sole
`DebuggingCase.transaction`, and direct AR `create!` on three models. TD-2
(finding persist contract) is done — `RedactionFinding.build_from_engine_finding`
already sits at the persist seam. G-01/G-02 rollback oracles exist in
`process_case_submission_spec.rb:256–301`.

### Key Discoveries:

- Sole intake orchestrator: `app/services/intake/process_case_submission.rb:20–56`
- Private `redact_metadata` helper (5 call sites): `process_case_submission.rb:58–64`
- Sole `DebuggingCase.transaction` in `app/`: `process_case_submission.rb:27–51`
- Two runtime callers unchanged: `debugging_cases_controller.rb`, `demo/load_case.rb:23`
- Security oracles scan persisted AR values — split must preserve one registry per
  submission and no sanitized writes outside the transaction
- Upstream ranking and incremental path:
  `context/changes/refactor-opportunities/research.md` (IMPL-1)

## Desired End State

After this plan:

1. `Intake::RedactMetadata.call(text, registry:)` is the only metadata redaction
   entry point; blank/nil text returns unchanged (nil or blank).
2. `Intake::PersistRedactedCase` accepts an explicit DTO payload (no
   `CaseSubmission` dependency), owns `DebuggingCase.transaction`, and performs
   all AR creates including finding mapper calls.
3. `ProcessCaseSubmission` validates, creates one registry, redacts metadata and
   sources, builds the persist payload, delegates to persist, and maps
   `RecordInvalid` → `Result(errors:)`.
4. Rollback oracles G-01/G-02 live in `persist_redacted_case_spec.rb`.
5. `CaseSubmission.normalize_sources` no longer accepts pre-built `Source`
   structs (G-05 dead branch removed) with a minimal unit spec.
6. `bin/ci` green; security persistence oracles unchanged.

### Verification

- Automated: targeted RSpec per phase + `mise exec -- bin/ci`
- Manual: optional demo-case intake via UI — case, sources, and findings still
  appear on case show

## What We're NOT Doing

- Schema or migration changes
- Metadata column encryption (TD-7 — product decision)
- CRLF normalization in `Engine` (TD-5 — separate change)
- `Intake::SubmitCase` demo facade (TD-10)
- Full `CaseSubmission` unit spec beyond G-05 branch removal (TD-3 backlog)
- Strong-params / mass-assignment tests (TD-4)
- Persisting metadata redaction findings (current behavior: metadata redaction
  discards engine findings — unchanged)
- Changing public `ProcessCaseSubmission.call` signature or `Result` shape

## Implementation Approach

Incremental bottom-up matching refactor-opportunities IMPL-1 path: extract the
smallest seam first (`RedactMetadata`), then move transaction + AR writes into
`PersistRedactedCase` with an explicit DTO, then bundle G-05 cleanup. Each
phase ends with targeted specs and full suite green before the next phase.

## Critical Implementation Details

**Registry lifecycle:** The coordinator creates exactly one
`Redaction::PlaceholderRegistry` per successful validation path and passes it
to `RedactMetadata` and `Engine.redact`. Persist receives only already-redacted
strings and typed `Redaction::Finding` arrays — never raw submission text.

**Transaction boundary:** After Phase 2, no AR `create!` for intake models
remains in `ProcessCaseSubmission`. All sanitized writes happen inside
`PersistRedactedCase` within its transaction.

**Rollback stub migration:** G-01/G-02 examples move from
`process_case_submission_spec.rb` to `persist_redacted_case_spec.rb`, stubbing
`create!` on the relevant association (`log_sources` / `redaction_findings`).
Keep one thin integration example in `process_case_submission_spec.rb` proving
the coordinator still maps `RecordInvalid` to `Result` (outer `create!` failure
example at `:240–254` stays).

## Phase 1: Extract RedactMetadata

### Overview

Move the private `redact_metadata` helper into `Intake::RedactMetadata` and wire
all five call sites through the new service without changing behavior.

### Changes Required:

#### 1. RedactMetadata service

**File**: `app/services/intake/redact_metadata.rb`

**Intent**: Provide a single callable that redacts optional metadata text through
the shared registry, returning nil/blank unchanged and otherwise returning
`sanitized_text` from `Redaction::Engine.redact`.

**Contract**: `Intake::RedactMetadata.call(text, registry:)` — class method
only; `registry` required; no persistence side effects.

#### 2. Wire ProcessCaseSubmission

**File**: `app/services/intake/process_case_submission.rb`

**Intent**: Replace private `redact_metadata` calls with
`Intake::RedactMetadata.call(...)`; delete the private method.

**Contract**: Same five fields redacted (title, description, environment,
customer_reference, source name); registry still created once before use.

#### 3. Unit spec

**File**: `spec/services/intake/redact_metadata_spec.rb`

**Intent**: Pin blank/nil passthrough, redaction of secrets, and registry
placeholder reuse independent of the full submission flow.

**Contract**: Cover at minimum: `nil` → nil, `""` → blank, secret email →
placeholder, two calls with same registry reuse placeholder index.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/redact_metadata_spec.rb`
- `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- No behavior change visible in case create flow (metadata still redacted on persist)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Extract PersistRedactedCase

### Overview

Introduce `Intake::PersistRedactedCase` with an explicit DTO input, move the
transaction and all AR creates into it, slim the coordinator to payload
assembly + error mapping, and migrate G-01/G-02 rollback oracles to a dedicated
persist spec.

### Changes Required:

#### 1. Source payload value object

**File**: `app/services/intake/persist_redacted_case.rb` (or sibling file if
prefer split)

**Intent**: Define `PersistRedactedCase::SourcePayload` as `Data.define` with
`:source_type`, `:name`, `:position`, `:sanitized_content`, and `:findings`
(array of `Redaction::Finding`).

**Contract**: Findings are typed engine output only; no raw paste content on
the struct.

#### 2. PersistRedactedCase service

**File**: `app/services/intake/persist_redacted_case.rb`

**Intent**: Accept `user:`, `case_attributes:` (Hash with title, description,
environment, customer_reference — all already redacted), and `sources:`
(array of `SourcePayload`). Wrap AR creates in `DebuggingCase.transaction`.
Create case, log sources with positions, and findings via
`RedactionFinding.build_from_engine_finding`. Return the persisted
`DebuggingCase`.

**Contract**: `Intake::PersistRedactedCase.call(user:, case_attributes:, sources:)`
raises `ActiveRecord::RecordInvalid` on failure (same as today). No
`CaseSubmission` parameter. Sole owner of `DebuggingCase.transaction` for intake.

#### 3. Slim ProcessCaseSubmission

**File**: `app/services/intake/process_case_submission.rb`

**Intent**: After validation and registry creation, redact metadata fields via
`RedactMetadata`, run `Redaction::Engine.redact` per
`submission.sources_with_content`, build `SourcePayload` array and
`case_attributes` hash, call `PersistRedactedCase.call`, return
`success(debugging_case)`. Keep `rescue ActiveRecord::RecordInvalid`.

**Contract**: No AR `create!` calls remain in this file. Public `.call` / `Result`
unchanged.

#### 4. Persist spec with rollback oracles

**File**: `spec/services/intake/persist_redacted_case_spec.rb`

**Intent**: Happy-path persist (case + sources + findings), G-01 rollback when
`log_sources.create!` fails, G-02 rollback when `redaction_findings.create!`
fails — assert `DebuggingCase.count` unchanged.

**Contract**: Build DTO payloads directly (no `CaseSubmission` required for
persist tests). Use same stub patterns as current G-01/G-02 examples.

#### 5. Trim submission spec

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Remove migrated G-01/G-02 examples; keep full integration coverage
(redaction, registry reuse, security oracles, outer rollback at `:240–254`).

**Contract**: Example count drops by 2; no loss of end-to-end intake coverage.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/persist_redacted_case_spec.rb`
- `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb`
- `mise exec -- bundle exec rspec spec/` (full suite)
- `mise exec -- bin/ci`

#### Manual Verification:

- Demo case load (`Demo::LoadCase`) still creates a full case tree in dev/test
- New case via UI still shows redacted metadata and findings on show page

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 3: Bundle G-05 — Remove Source passthrough

### Overview

Remove the dead `Source` struct passthrough branch in
`CaseSubmission.normalize_sources` and add a minimal unit spec proving hash
inputs still normalize correctly.

### Changes Required:

#### 1. Simplify normalize_sources

**File**: `app/services/intake/case_submission.rb`

**Intent**: Delete the `if source.is_a?(Source)` branch; always build `Source`
from hash-like input.

**Contract**: `sources_with_content` and validation behavior unchanged for
controller-permitted params shape.

#### 2. CaseSubmission unit spec

**File**: `spec/services/intake/case_submission_spec.rb`

**Intent**: Cover hash normalization (symbol and string keys), blank source
filtering via validations, and invalid source type error — no pre-built `Source`
input path.

**Contract**: Does not duplicate full `ProcessCaseSubmission` integration;
focuses on form object behavior only.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/case_submission_spec.rb`
- `mise exec -- bundle exec rspec spec/services/intake/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Case create form still accepts multi-source paste payload (no regression)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Testing Strategy

### Unit Tests:

- `redact_metadata_spec.rb` — blank/nil, redaction, registry reuse
- `persist_redacted_case_spec.rb` — happy path, G-01, G-02 rollback
- `case_submission_spec.rb` — normalization and validation (Phase 3)

### Integration Tests:

- `process_case_submission_spec.rb` — full intake flow, security oracles,
  outer rollback, metadata/source redaction (remains primary end-to-end oracle)

### Manual Testing Steps:

1. Start dev server: `mise exec -- bin/dev`
2. Create a case with secrets in title, metadata fields, and pasted logs
3. Confirm placeholders on show page; no raw secrets in DB (spot-check or rely on
   existing security helpers)
4. Load demo case in development if available

## Performance Considerations

No expected performance change — same number of engine passes and AR inserts;
only class boundary moves.

## Migration Notes

No data migration. Deploy is code-only; behavior and persisted shape unchanged.

## References

- Upstream ranking: `context/changes/refactor-opportunities/research.md` (IMPL-1)
- Prior persist contract work: `context/archive/2026-06-20-intake-finding-persist-contract/plan.md`
- Orchestrator: `app/services/intake/process_case_submission.rb`
- Integration oracle: `spec/services/intake/process_case_submission_spec.rb`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Extract RedactMetadata

#### Automated

- [x] 1.1 `mise exec -- bundle exec rspec spec/services/intake/redact_metadata_spec.rb` — 8abeb9e
- [x] 1.2 `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb` — 8abeb9e
- [x] 1.3 `mise exec -- bin/ci` — 8abeb9e

#### Manual

- [x] 1.4 No behavior change visible in case create flow (metadata still redacted on persist)

### Phase 2: Extract PersistRedactedCase

#### Automated

- [x] 2.1 `mise exec -- bundle exec rspec spec/services/intake/persist_redacted_case_spec.rb` — 8abeb9e
- [x] 2.2 `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb` — 8abeb9e
- [x] 2.3 `mise exec -- bundle exec rspec spec/` — 8abeb9e
- [x] 2.4 `mise exec -- bin/ci` — 8abeb9e

#### Manual

- [x] 2.5 Demo case load still creates a full case tree in dev/test
- [x] 2.6 New case via UI still shows redacted metadata and findings on show page

### Phase 3: Bundle G-05 — Remove Source passthrough

#### Automated

- [x] 3.1 `mise exec -- bundle exec rspec spec/services/intake/case_submission_spec.rb` — 8abeb9e
- [x] 3.2 `mise exec -- bundle exec rspec spec/services/intake/` — 8abeb9e
- [x] 3.3 `mise exec -- bin/ci` — 8abeb9e

#### Manual

- [x] 3.4 Case create form still accepts multi-source paste payload (no regression)
