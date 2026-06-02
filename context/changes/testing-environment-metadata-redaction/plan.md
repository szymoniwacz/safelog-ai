# Environment Metadata Redaction — Implementation Plan

## Overview

Close the Phase 1 deferral for `environment` metadata redaction: wire `environment` through the same `redact_metadata` path as title, description, and customer_reference in `Intake::ProcessCaseSubmission`, add gap-fill security specs mirroring existing per-field patterns, and extend test-plan risk #4 documentation. Baseline **122 RSpec examples**; target **126** (+4).

## Current State Analysis

Research (`context/changes/testing-environment-metadata-redaction/research.md`) verified:

- **Implementation gap** — `environment` is the only metadata field passed through raw at intake (`app/services/intake/process_case_submission.rb:31`). Title, description, and customer_reference use `redact_metadata` with the shared `PlaceholderRegistry`.
- **Downstream exposure** — Persisted environment appears on show/index and in AI prompts via `Analysis::PromptBuilder` line 39. No second redaction pass at the AI boundary.
- **Test gap** — Per-field metadata redaction blocks exist for title, description, and customer_reference. No environment-specific examples. All specs use benign `"production"` for environment.
- **Helper ready** — `assert_no_raw_substring_in_persisted_data` already scans the `environment` column (`spec/support/security_persistence_helpers.rb:12`).

### Key Discoveries

- Single redaction boundary at intake — fixing `ProcessCaseSubmission` fixes persist, show, and AI paths together.
- F-02 schema intentionally keeps `environment` as a plain (non-encrypted) column; redaction is the protection mechanism, same as title/description.
- Phase 1 (`testing-security-guardrail-cookbook`) explicitly deferred environment because risk #4 listed only three fields — this slice closes that deferral.

## Desired End State

1. `environment` passes through `redact_metadata(@submission.environment, registry)` at intake with the same shared registry as other metadata and log sources.
2. Service and request specs prove environment-only secrets redact on persist, never appear in DB scan oracles, and never reach analyze prompts (and show response for HTTP parity).
3. Test-plan risk #4 field list includes `environment`; Phase 1 deferral note removed; §6.3 cookbook references the new examples.
4. Full suite and `bin/ci` green; example count **122 → 126**.

### Verification

```bash
mise exec -- bundle exec rspec spec/ --dry-run | tail -1
mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb spec/services/analysis/prompt_builder_spec.rb spec/requests/debugging_cases_security_spec.rb spec/requests/debugging_cases_analyze_security_spec.rb
mise exec -- bin/ci
```

## What We're NOT Doing

- Encrypting `environment` (F-02 intentional plain column).
- Changes to `security_persistence_helpers.rb`, controller, or views.
- Shared-registry cross-field placeholder test for environment + log paste (customer_reference test already covers the pattern).
- Duplicating full POST security flows or rewriting existing title/description/customer_reference blocks.
- E2E, snapshots, or exhaustive redaction regex catalog tests.

## Implementation Approach

**Order:** failing service specs first (cheapest layer), one-line intake fix to green, then request specs, then test-plan doc. Each new example uses an independent oracle — `SecureRandom`-prefixed secret only in `environment`, clean log paste (`Started GET /health`), placeholder present and raw absent.

**Planning decisions** (resolved from research open questions):

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Risk #4 scope | Extend to include `environment` | Parity with F1 metadata-misuse rationale and architecture-alignment title fix |
| HTTP show assertion | Include in `debugging_cases_security_spec.rb` | Low cost; matches title block pattern (persist + show + analyze) |
| Cross-field registry test | Omit | customer_reference shared-registry example already documents the pattern |

## Phase 1: Intake Fix and Service Layer Proofs

### Overview

Wire environment through `redact_metadata` and prove persist + prompt boundaries at the service layer before adding HTTP examples.

### Changes Required

#### 1. Intake redaction parity

**File**: `app/services/intake/process_case_submission.rb`

**Intent**: Apply the same `redact_metadata` helper used for title, description, and customer_reference to `environment`, using the existing shared `PlaceholderRegistry` created at line 23.

**Contract**: The `debugging_case.create!` call at lines 28–33 assigns `environment` via `redact_metadata(@submission.environment, registry)` instead of raw `@submission.environment`. Blank/optional environment must remain unchanged (`redact_metadata` returns early on blank at line 59).

#### 2. ProcessCaseSubmission persist example

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Add one example proving secrets in `environment` metadata redact on persist and pass the shared DB-scan oracle. Mirror the title/description block at lines 106–133.

**Contract**: New example `"redacts secrets in environment metadata on persist"`: `SecureRandom`-prefixed email only in `environment`, clean log paste, field-level `[EMAIL_1]` assertion, `assert_no_raw_substring_in_persisted_data(secret)`.

#### 3. PromptBuilder metadata-only example

**File**: `spec/services/analysis/prompt_builder_spec.rb`

**Intent**: Add one example proving environment-only secrets do not appear in assembled AI prompt content. Mirror the customer_reference block at lines 46–73.

**Contract**: New example `"excludes environment metadata-only secrets from the assembled prompt"`: secret only in `environment`, clean log paste, joined message content includes `[EMAIL_1]` and excludes raw secret.

### Sub-phase rationale

| Field | Value |
|-------|-------|
| **Behavior asserted** | Environment metadata redacts at intake; sanitized value persists; prompt excludes raw |
| **Regression caught** | `redact_metadata` skipped or bypassed for `environment` |
| **Research source** | `research.md` — intake gap at `process_case_submission.rb:31`; patterns at `process_case_submission_spec.rb:106-133`, `prompt_builder_spec.rb:46-73` |
| **Edge/boundary** | Blank environment unchanged; optional field stays optional |
| **Anti-pattern avoided** | Test-only slice without fixing intake (would leave production gap) |

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb spec/services/analysis/prompt_builder_spec.rb` passes.
- New environment service examples fail if intake fix is reverted (spot-check locally).

#### Manual Verification

- Confirm no new columns, migrations, or encryption changes.

---

## Phase 2: Request Layer Proofs and Test-Plan Update

### Overview

Add HTTP-level guardrails for environment metadata (persist, show, analyze prompt) and update test-plan documentation to close the Phase 1 deferral.

### Changes Required

#### 1. Analyze request — environment metadata redaction

**File**: `spec/requests/debugging_cases_analyze_security_spec.rb`

**Intent**: Add isolated `"environment metadata redaction"` block proving persist + DB scan + analyze prompt exclusion. Mirror `customer_reference metadata redaction` at lines 89–122.

**Contract**: Nested `describe` with `environment_secret_email` only in `environment`, clean log paste, field persist assertions, `assert_no_raw_substring_in_persisted_data`, `fake_client.last_request` prompt join.

#### 2. Security request — environment show parity

**File**: `spec/requests/debugging_cases_security_spec.rb`

**Intent**: Add `"environment metadata redaction"` block with persist, show response, and analyze prompt assertions. Mirror title block at lines 103–136.

**Contract**: Nested `describe` with secret only in `environment`; assert persisted redaction, `response.body` excludes raw secret after intake redirect, analyze prompt excludes raw secret.

#### 3. Test-plan cookbook and risk map

**File**: `context/foundation/test-plan.md`

**Intent**: Extend risk #4 to include `environment`; document new canonical examples; remove Phase 1 deferral note. Surgical edits only — do not rewrite unrelated sections (per `lessons.md`).

**Contract**:
- §2 risk map row #4 (line 46): add `environment` to metadata field list.
- §2 risk response guidance row #4 (line 58): add `environment` to redaction field list.
- §6.3 Risk #4 heading and bullets (lines 230–236): add `environment` to field list; note HTTP blocks in both security request specs; add environment analyze example reference.
- §6.6 Phase 1 deferred list (lines 327–328): remove `environment` metadata redaction from deferred items; add brief note under a new Phase 4 row or append to §6.6 that this slice closed the environment deferral (example count 122 → 126).

**File**: `AGENTS.md` (if example count is cited)

**Intent**: Update RSpec example count from 122 to 126 if AGENTS.md references the current count.

**Contract**: Single-line count update only; no other AGENTS.md edits.

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb spec/requests/debugging_cases_analyze_security_spec.rb` passes.
- `mise exec -- bundle exec rspec spec/` — **126 examples**, 0 failures.
- `mise exec -- bin/ci` green (RuboCop, audits, Brakeman, full RSpec).

#### Manual Verification

- Deliberately revert intake fix locally — confirm new environment examples fail for persist or prompt reasons.
- Skim test-plan §6.3 — environment appears alongside other metadata fields with file references.

---

## Testing Strategy

### Unit / Service Tests

- Environment secret only in `environment` field; log paste clean.
- Placeholder `[EMAIL_1]` present; raw `SecureRandom`-prefixed email absent from field, DB scan, and prompt content.

### Request Tests

- Full HTTP intake → show → analyze path for environment metadata.
- `fake_client.last_request` prompt inspection (risk #2 oracle).
- Show response body excludes raw secret (parity with title block).

### Manual Testing Steps

1. Revert `process_case_submission.rb` line 31 — run new specs; confirm failures.
2. Restore fix — full `bin/ci` green.
3. Read updated test-plan §6.3 — environment documented as risk #4 field.

## References

- Research: `context/changes/testing-environment-metadata-redaction/research.md`
- Prior Phase 1 plan: `context/archive/2026-06-01-testing-security-guardrail-cookbook/plan.md`
- Intake service: `app/services/intake/process_case_submission.rb:28-33`
- Canonical customer_reference pattern: `spec/requests/debugging_cases_analyze_security_spec.rb:89-122`
- Canonical title pattern: `spec/requests/debugging_cases_security_spec.rb:103-136`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Intake Fix and Service Layer Proofs

#### Automated

- [x] 1.1 `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb spec/services/analysis/prompt_builder_spec.rb` passes
- [x] 1.2 New environment service examples fail if intake fix is reverted (spot-check locally)

#### Manual

- [ ] 1.3 Confirm no new columns, migrations, or encryption changes

### Phase 2: Request Layer Proofs and Test-Plan Update

#### Automated

- [ ] 2.1 `mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb spec/requests/debugging_cases_analyze_security_spec.rb` passes
- [ ] 2.2 `mise exec -- bundle exec rspec spec/` — 126 examples, 0 failures
- [ ] 2.3 `mise exec -- bin/ci` green

#### Manual

- [ ] 2.4 Revert intake fix locally — confirm new environment examples fail for persist or prompt reasons
- [ ] 2.5 Skim test-plan §6.3 — environment appears alongside other metadata fields with file references
