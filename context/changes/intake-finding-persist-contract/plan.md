# Intake Finding Persist Contract Implementation Plan

## Overview

Replace the implicit hash contract between `Redaction::Engine` findings and
`redaction_findings.create!` with a typed `Redaction::Finding` value object,
an explicit `RedactionFinding.build_from_engine_finding` mapper at the sole
persist seam, and inner-loop transaction rollback oracles (G-01, G-02). No
schema changes; behavior and persisted data shape stay the same.

## Current State Analysis

`Engine#redact_line` appends plain hashes with four keys (`finding_type`,
`line_number`, `placeholder`, `risk_level`) directly into `Result#findings`.
`Intake::ProcessCaseSubmission` passes each hash unchanged to
`log_source.redaction_findings.create!(finding)` — the hash key set is the
only contract between redaction and persistence.

### Key Discoveries:

- Sole runtime persist call-site: `app/services/intake/process_case_submission.rb:45–47`
- Engine hash shape: `app/services/redaction/engine.rb:36–41`
- AR columns match hash keys 1:1: `db/schema.rb:55–63`, `app/models/redaction_finding.rb:1–5`
- `engine_spec.rb` uses `hash_including` matchers but does not pin exact key set
- No `spec/models/redaction_finding_spec.rb` (G-12 gap)
- Outer rollback tested (`debugging_cases.create!` failure); inner-loop rollback
  for `log_sources` / `redaction_findings` untested (G-01, G-02)
- Downstream consumers read AR records, not engine hashes — unaffected by typing

## Desired End State

After this plan:

1. `Redaction::Finding` is the only engine output type for findings; unknown
   kwargs rejected at construction; all four attributes required.
2. `RedactionFinding.build_from_engine_finding(finding)` accepts
   `Redaction::Finding` only and returns explicit persistence attributes.
3. `ProcessCaseSubmission` calls the mapper — no direct hash splat to `create!`.
4. Contract and mapper behavior covered in `spec/models/redaction_finding_spec.rb`;
   `engine_spec` expects `Redaction::Finding` instances.
5. G-01 and G-02 examples prove full transaction rollback on inner `create!`
   failures (zero persisted `DebuggingCase` rows).
6. `bin/ci` green; security oracles unchanged.

### Verification

- Automated: `bundle exec rspec spec/services/redaction/ spec/models/redaction_finding_spec.rb spec/services/intake/process_case_submission_spec.rb`; `bin/ci`
- Manual: optional demo-case intake via UI — findings still appear on case show

## What We're NOT Doing

- Schema or migration changes
- `Intake::ProcessCaseSubmission` service extraction (IMPL-1)
- Typed metadata finding persistence (metadata redaction still discards findings)
- `Redaction::Finding` Phase B in engine only without full Result typing (full typing is in scope)
- CRLF normalization (TD-5)
- Strong-params / mass-assignment tests (TD-4)
- Hash input path on the mapper (Finding-only)

## Implementation Approach

Bottom-up: introduce typed value object and migrate engine output first (keeps
redaction layer testable in isolation), then add AR mapper and swap persist
seam, then add rollback oracles last (depends on stable persist path). Each
phase ends with targeted RSpec + full suite green.

## Critical Implementation Details

**Finding validation timing:** Strict contract enforcement runs at
`Redaction::Finding` construction — `Data.define` rejects unknown kwargs;
add explicit presence validation for all four attributes before the struct is
returned. The AR mapper assumes a valid Finding and maps fields explicitly
(no second whitelist pass needed).

**Rollback stub target:** G-01/G-02 follow the existing outer-rollback pattern
(`process_case_submission_spec.rb:240–254`) but stub `create!` on the
`log_sources` or `redaction_findings` association after the case row would
exist. Assert `DebuggingCase.count` unchanged, not only `result.debugging_case.nil?`.

## Phase 1: Typed Finding in Redaction Layer

### Overview

Introduce `Redaction::Finding`, migrate the engine to emit typed findings,
type `Result#findings`, and update engine specs.

### Changes Required:

#### 1. Finding value object

**File**: `app/services/redaction/finding.rb`

**Intent**: Define `Redaction::Finding` as a `Data.define` struct with exactly
four members (`finding_type`, `line_number`, `placeholder`, `risk_level`).
Reject unknown keyword arguments (native `Data.define` behavior). Validate all
four attributes are present/non-blank at construction.

**Contract**: Public constructor accepts only the four named fields; no
`original`, `raw`, or extension keys. Line number is Integer; others are String.

#### 2. Engine migration

**File**: `app/services/redaction/engine.rb`

**Intent**: Replace hash literals in `findings << { ... }` with
`Redaction::Finding.new(...)` (or equivalent factory) so `Result#findings`
is an array of Finding instances.

**Contract**: Same semantic output as today — one Finding per pattern match,
same field values; no change to sanitized text or placeholder behavior.

#### 3. Result typing

**File**: `app/services/redaction/result.rb`

**Intent**: Document and enforce that `@findings` holds `Redaction::Finding`
instances (YARD comment or private validation optional; array element type is
the contract).

**Contract**: `Result#findings` returns `Array<Redaction::Finding>`.

#### 4. Engine specs

**File**: `spec/services/redaction/engine_spec.rb`

**Intent**: Replace `hash_including(...)` matchers with expectations on
`Redaction::Finding` attribute values. Keep existing security assertions
(no raw values in finding fields).

**Contract**: Examples assert `finding.is_a?(Redaction::Finding)` and compare
`.finding_type`, `.line_number`, `.placeholder`, `.risk_level`.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/redaction/`
- `mise exec -- bin/ci`

#### Manual Verification:

- None required for this phase

**Implementation Note**: After automated verification passes, pause for human
confirmation before Phase 2.

---

## Phase 2: Persist Mapper and Seam Swap

### Overview

Add explicit AR mapper on `RedactionFinding`, wire it at the sole persist
call-site, and cover mapper behavior in a new model spec.

### Changes Required:

#### 1. AR mapper

**File**: `app/models/redaction_finding.rb`

**Intent**: Add `RedactionFinding.build_from_engine_finding(finding)` class
method that accepts `Redaction::Finding` only (raise `ArgumentError` for other
types) and returns a Hash of the four persistence attributes suitable for
`create!`.

**Contract**: Return keys exactly `{ finding_type:, line_number:, placeholder:, risk_level: }` — no `log_source_id` (association sets it).

#### 2. Persist seam swap

**File**: `app/services/intake/process_case_submission.rb`

**Intent**: Replace `log_source.redaction_findings.create!(finding)` with
`log_source.redaction_findings.create!(RedactionFinding.build_from_engine_finding(finding))`.

**Contract**: Sole runtime call-site for finding persist; no other direct hash
splat to `redaction_findings.create!` in `app/`.

#### 3. Model spec

**File**: `spec/models/redaction_finding_spec.rb` (new)

**Intent**: Cover mapper happy path (Finding → correct attribute hash),
`ArgumentError` when passed a Hash or wrong type, and that returned hash keys
match assignable AR attributes exactly.

**Contract**: Whitelist assertion — returned hash keys ⊆
`%i[finding_type line_number placeholder risk_level]` and all four present.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/models/redaction_finding_spec.rb spec/services/intake/process_case_submission_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- None required for this phase

**Implementation Note**: After automated verification passes, pause for human
confirmation before Phase 3.

---

## Phase 3: Inner-Loop Rollback Oracles (G-01, G-02)

### Overview

Add transaction rollback specs for failures inside the source/finding persist
loop — closing the test gap documented in case-submission-flow analysis.

### Changes Required:

#### 1. G-01 — log_sources.create! failure

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Add example stubbing `log_sources` association `create!` to raise
`ActiveRecord::RecordInvalid` after a valid submission is processed far enough
that the case row would be created. Assert `DebuggingCase.count` unchanged,
result not successful, no partial case visible via count query.

**Contract**: Mirrors outer rollback example pattern at lines 240–254; targets
inner loop failure point.

#### 2. G-02 — redaction_findings.create! failure

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Add example stubbing `redaction_findings` association `create!` to
raise `ActiveRecord::RecordInvalid` when findings are persisted. Assert full
rollback — zero new `DebuggingCase` rows.

**Contract**: Proves atomicity of the single `DebuggingCase.transaction` block
through the finding persist step.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- None required

**Implementation Note**: Phase 3 completes the change; no further phases.

---

## Testing Strategy

### Unit Tests:

- `Redaction::Finding` — unknown kwargs rejected, blank attribute rejected
- `RedactionFinding.build_from_engine_finding` — type guard, attribute mapping
- `Redaction::Engine` — typed findings, line numbers, no raw in fields
- G-01/G-02 — stubbed inner `create!` failures, count-based rollback oracle

### Integration Tests:

- Existing `process_case_submission_spec` happy paths remain green
- `debugging_cases_security_spec` — no changes expected; run as regression gate

### Manual Testing Steps:

1. Load demo case or submit paste with known secrets
2. Confirm case show still lists findings by type and risk level

## Performance Considerations

Negligible — one small value object allocation per pattern match replaces one
hash allocation; same count as today.

## Migration Notes

No data migration. Deploy is code-only; existing persisted findings unchanged.

## References

- Related research: `context/changes/refactor-opportunities/research.md` (TD-2)
- Source flow analysis: `context/changes/case-submission-flow-analysis/research.md`
- Engine: `app/services/redaction/engine.rb:36–41`
- Persist seam: `app/services/intake/process_case_submission.rb:45–47`
- Opportunity map: `context/team/opportunity-map.md` (I-1)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Typed Finding in Redaction Layer

#### Automated

- [x] 1.1 `mise exec -- bundle exec rspec spec/services/redaction/`
- [x] 1.2 `mise exec -- bin/ci`

#### Manual

- [ ] 1.3 No manual verification required for Phase 1

### Phase 2: Persist Mapper and Seam Swap

#### Automated

- [ ] 2.1 `mise exec -- bundle exec rspec spec/models/redaction_finding_spec.rb spec/services/intake/process_case_submission_spec.rb`
- [ ] 2.2 `mise exec -- bin/ci`

#### Manual

- [ ] 2.3 No manual verification required for Phase 2

### Phase 3: Inner-Loop Rollback Oracles (G-01, G-02)

#### Automated

- [ ] 3.1 `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb`
- [ ] 3.2 `mise exec -- bin/ci`

#### Manual

- [ ] 3.3 No manual verification required for Phase 3
