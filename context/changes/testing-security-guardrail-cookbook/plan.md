# Security Guardrail Cookbook — Implementation Plan

## Overview

Rollout Phase 1 of `context/foundation/test-plan.md`: close **gap-fill-only** test coverage for risks **#1** (raw never persist), **#2** (sanitized-only AI), and **#4** (metadata redaction on persist + in prompts). Request-layer guardrails already exist; this change extracts shared patterns, adds thin service/request examples where research found holes, and ships cookbook sections §6.1, §6.3, §6.4, §6.5, and §6.6.

Baseline: **116 RSpec examples**, all green. Target: **~120–122 examples** (small delta — no duplicate full flows).

## Current State Analysis

Research (`context/changes/testing-security-guardrail-cookbook/research.md`) verified:

- **Risk #1** — `spec/requests/debugging_cases_security_spec.rb` already scans `DebuggingCase`, `LogSource`, and `RedactionFinding` after POST intake. Anti-pattern: `spec/requests/debugging_cases_spec.rb` POST example asserts show body only (no DB scan).
- **Risk #2** — `spec/requests/debugging_cases_analyze_security_spec.rb` inspects `FakeClient#last_request` and correlation payload. Service specs prove log-paste secrets only; `PromptBuilder` / `AnalyzeCase` do not cover metadata-only secrets.
- **Risk #4** — HTTP blocks exist for title and description (`debugging_cases_security_spec.rb`). `customer_reference` in analyze security overlaps log-paste secrets — metadata-only isolation missing. Intake service spec covers `customer_reference` persist but not title/description.

**Duplicate helpers:** `assert_no_raw_substring_in_persisted_data` is inlined in the security request spec; intake service spec duplicates a narrower inline scan.

### Key Discoveries

- `app/services/intake/process_case_submission.rb:27-47` — shared `PlaceholderRegistry` redacts sources + metadata fields.
- `app/services/analysis/prompt_builder.rb:36-52` — prompt reads **persisted** case fields; safety depends on upstream redaction, not `Ai::Request` re-scan.
- `environment` is passed through without `redact_metadata` — **out of Phase 1 scope** (test plan #4 lists title, description, customer_reference only).
- `spec/models/encryption_at_rest_spec.rb` already covers risk **#5** — cookbook reference only, no new model examples.

## Desired End State

1. Shared `spec/support/security_persistence_helpers.rb` is the canonical DB-scan oracle for raw-substring absence after intake.
2. Service specs prove metadata-only secrets never reach AI prompts (`PromptBuilder`) and never persist in title/description (`ProcessCaseSubmission`).
3. One request example isolates `customer_reference`-only secrets in analyze prompts (clean log paste, no overlapping secrets in sources).
4. `context/foundation/test-plan.md` §6.1, §6.3, §6.4, §6.5, and §6.6 document patterns with file references and anti-patterns.
5. Full suite and `bin/ci` remain green; example count increases modestly (~4–6 new examples).

### Verification

```bash
mise exec -- bundle exec rspec spec/ --dry-run | tail -1   # example count
mise exec -- bundle exec rspec spec/support/security_persistence_helpers.rb spec/requests/debugging_cases_security_spec.rb spec/requests/debugging_cases_analyze_security_spec.rb spec/services/intake/process_case_submission_spec.rb spec/services/analysis/prompt_builder_spec.rb
mise exec -- bin/ci
```

## What We're NOT Doing

- Duplicating full POST security flows or export/authorization specs (already adequate).
- New encryption-at-rest model examples (risk #5 — document existing `encryption_at_rest_spec.rb` only).
- E2E/Playwright, UI snapshots, view cosmetic tests (test plan §7).
- `environment` metadata redaction tests (deferred — not in risk #4 field list).
- Rewriting `debugging_cases_spec.rb` POST example to add DB scan (document as anti-pattern instead).
- Exhaustive redaction regex catalog tests.

## Implementation Approach

Order by **cost × signal**: extract shared helper first (enables DRY + cookbook anchor), then cheapest service examples (no HTTP), then one targeted request example (metadata isolation), finally cookbook prose (no runtime change). Each new example must use an **independent oracle** — expected behavior from PRD/risk wording, not values copied from implementation.

## Phase 1: Extract Shared Persistence Oracle

### Overview

Centralize the multi-table DB scan helper so request and service specs share one canonical #1 oracle. Document the show-page-only anti-pattern in comments pointing to this helper.

### Changes Required

#### 1. Shared helper module

**File**: `spec/support/security_persistence_helpers.rb`

**Intent**: Provide `assert_no_raw_substring_in_persisted_data(raw_substring)` scanning `DebuggingCase` diagnostic columns (title, description, environment, customer_reference), all `LogSource#sanitized_content`, and all `RedactionFinding` attribute values — matching the existing security request spec behavior.

**Contract**: Module `SecurityPersistenceHelpers` with the method above; included in RSpec via `config.include SecurityPersistenceHelpers` in `spec/rails_helper.rb` (or module function required by specs — pick one pattern and use consistently).

#### 2. Wire existing specs to helper

**File**: `spec/requests/debugging_cases_security_spec.rb`

**Intent**: Remove inline helper definition; call shared helper. No behavior change.

**Contract**: Delete local `assert_no_raw_substring_in_persisted_data`; rely on support module.

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Replace inline `DebuggingCase.find_each` / `LogSource.find_each` / `RedactionFinding.find_each` block in `"does not persist raw secrets in encrypted diagnostic fields"` with shared helper.

**Contract**: Same example title and secrets; helper call only.

### Sub-phase rationale

| Field | Value |
|-------|-------|
| **Behavior asserted** | Known raw substring absent from all intake-persisted diagnostic tables |
| **Regression caught** | Raw email/token written to SQLite after redaction bypass or regression |
| **Research source** | `research.md` — Risk #1; `debugging_cases_security_spec.rb:42-61` |
| **Edge/boundary** | Scans encrypted (`customer_reference`) and plaintext (`title`, `description`) columns via AR — correct per schema |
| **Anti-pattern avoided** | Show-response-only oracle (`debugging_cases_spec.rb:52-64`) |

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb spec/services/intake/process_case_submission_spec.rb` passes with zero behavior change.
- RuboCop clean on new/edited spec files.

#### Manual Verification

- Confirm helper file name ends without `_spec.rb` (auto-loaded by `rails_helper.rb:27`, not double-run as spec).

---

## Phase 2: Service Layer — Metadata in AI Prompts

### Overview

Close risk **#2** / **#4** service gap: secret appears **only** in persisted metadata (`customer_reference` and/or `title`), with benign log paste — assert `PromptBuilder` joined message content excludes raw and includes placeholder.

### Changes Required

#### 1. PromptBuilder metadata-only example

**File**: `spec/services/analysis/prompt_builder_spec.rb`

**Intent**: Add one example where `secret_email` appears only in `customer_reference` (and optionally a second variant or combined example for `title`), log paste is clean (`"Started GET /health"`), case created via `ProcessCaseSubmission`, correlation extracted, then `PromptBuilder.call` — joined content must include `[EMAIL_1]` and exclude raw email.

**Contract**: New `it` block under `.call`; uses existing `create_case_from_submission` helper; oracle is risk #2 wording (raw never in AI-bound content), not copied from `prompt_builder.rb` string literals.

### Sub-phase rationale

| Field | Value |
|-------|-------|
| **Behavior asserted** | Metadata-only secret never appears in assembled AI user message |
| **Regression caught** | `PromptBuilder` reads persisted metadata without placeholder substitution |
| **Research source** | `research.md` — Risk #2 gaps; `prompt_builder_spec.rb:14-43` (log-only today) |
| **Edge/boundary** | Clean log paste — isolates metadata path without log-paste overlap |
| **Anti-pattern avoided** | FakeClient/analyze success without inspecting prompt text |

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/services/analysis/prompt_builder_spec.rb` passes.

#### Manual Verification

- Example fails if raw email is concatenated into prompt sections for case metadata lines.

---

## Phase 3: Service Layer — Metadata Persist on Intake

### Overview

Close risk **#1** / **#4** intake service gap: prove title and description redact on persist at the service layer (HTTP spec owns this today; cookbook needs a non-HTTP reference).

### Changes Required

#### 1. ProcessCaseSubmission title/description example

**File**: `spec/services/intake/process_case_submission_spec.rb`

**Intent**: Add one example: secret email in `title` and/or `description`, benign sources, call `ProcessCaseSubmission`, assert persisted fields contain `[EMAIL_1]` and shared helper confirms raw absent.

**Contract**: New `it` under `.call`; uses `assert_no_raw_substring_in_persisted_data` from Phase 1.

### Sub-phase rationale

| Field | Value |
|-------|-------|
| **Behavior asserted** | Title/description metadata redact before persist |
| **Regression caught** | `redact_metadata` skipped or bypassed for non-log fields |
| **Research source** | `research.md` — intake service gap; `process_case_submission_spec.rb:87-114` (customer_reference only) |
| **Edge/boundary** | Secret in metadata only, not in pasted_content |
| **Anti-pattern avoided** | Testing description only while assuming title is safe |

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb` passes.

---

## Phase 4: Request Layer — Customer Reference Isolation in Analyze

### Overview

Close risk **#2** / **#4** overlap gap: analyze security fixture puts `secret_email` in both `customer_reference` and rails log — add example where secret is **only** in `customer_reference`, log paste benign, assert persist + analyze prompt via shared patterns.

### Changes Required

#### 1. Analyze security — metadata-only block

**File**: `spec/requests/debugging_cases_analyze_security_spec.rb`

**Intent**: Add `describe "customer_reference metadata redaction"` (or equivalent) with isolated secret in `customer_reference`, clean `pasted_content`, POST intake, optional DB scan via helper, POST analyze, inspect `fake_client.last_request` — raw absent, placeholder present.

**Contract**: Mirrors structure of title/description blocks in `debugging_cases_security_spec.rb:124-157` but scoped to analyze-security file for #2 prompt + correlation assertions if valuable (prompt minimum; correlation payload optional if clean logs produce empty/minimal payload).

### Sub-phase rationale

| Field | Value |
|-------|-------|
| **Behavior asserted** | Analyze prompt excludes raw when secret lived only in customer_reference |
| **Regression caught** | Metadata leak in prompt when log sources contain no matching secret |
| **Research source** | `research.md` — overlapping oracle in `debugging_cases_analyze_security_spec.rb:20-27` |
| **Edge/boundary** | Benign log line only — no duplicate secret in sources |
| **Anti-pattern avoided** | Relying on log-paste redaction failure to catch metadata prompt leak |

### Success Criteria

#### Automated Verification

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_security_spec.rb` passes.

---

## Phase 5: Cookbook Documentation (§6)

### Overview

Replace TBD placeholders in `context/foundation/test-plan.md` §6 with shipped patterns. No new test examples in this phase — documentation only.

### Changes Required

#### 1. §6.1 Adding a service unit test

**File**: `context/foundation/test-plan.md`

**Intent**: Document when to use service specs vs request specs; reference `spec/services/intake/process_case_submission_spec.rb` and `spec/services/analysis/prompt_builder_spec.rb`; run command.

#### 2. §6.3 Adding a security guardrail test

**Intent**: Document canonical files, shared helper, FakeClient prompt inspection, DB scan oracle; cite anti-pattern `debugging_cases_spec.rb` show-only POST.

#### 3. §6.4 Adding an encryption-at-rest check

**Intent**: Reference `spec/models/encryption_at_rest_spec.rb` raw SQL pattern; note Phase 1 adds no new model examples.

#### 4. §6.5 Adding tests for new intake or redaction behavior

**Intent**: Require shared helper after intake; reference intake service + security request specs.

#### 5. §6.6 Per-rollout-phase notes

**Intent**: One short Phase 1 note: gaps closed, example count delta, deferred items (environment, #3/#5/#6).

**Contract**: Update §3 Phase 1 Status to `complete` when Phase 5 lands and full `bin/ci` green.

### Success Criteria

#### Automated Verification

- `mise exec -- bin/ci` passes (full gate).

#### Manual Verification

- §6 sections no longer read "TBD — see §3 Phase 1."
- Cookbook anti-patterns section names show-only oracle explicitly.

---

## Testing Strategy

### Unit / service tests

- Phase 2–3 additions only; reuse `ProcessCaseSubmission` + `PromptBuilder` patterns from existing specs.
- FakeClient for analyze paths; no real AI.

### Request / integration tests

- Phase 4 one new block; Phases 1–3 refactor/wire only in request spec for helper extraction.

### Manual testing steps

1. Deliberately break `redact_metadata` in a local branch — confirm new examples fail for the right reason (raw in DB or prompt).
2. Skim §6 cookbook as a new contributor — can locate where to add a security spec without reading the whole codebase.

## Performance Considerations

Negligible — a handful of RSpec examples; no CI time budget change expected.

## Migration Notes

None — test-only change.

## References

- Research: `context/changes/testing-security-guardrail-cookbook/research.md`
- Test plan: `context/foundation/test-plan.md` §2–§3, §6–§7
- Canonical request patterns: `spec/requests/debugging_cases_security_spec.rb`, `spec/requests/debugging_cases_analyze_security_spec.rb`
- Encryption pattern: `spec/models/encryption_at_rest_spec.rb:9-23`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Extract Shared Persistence Oracle

#### Automated

- [x] 1.1 `mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb spec/services/intake/process_case_submission_spec.rb` passes after helper extraction — 5019c31
- [x] 1.2 RuboCop clean on `spec/support/security_persistence_helpers.rb` and edited specs — 5019c31

#### Manual

- [x] 1.3 Helper loaded via support glob, not executed as standalone spec file — 5019c31

### Phase 2: Service Layer — Metadata in AI Prompts

#### Automated

- [x] 2.1 `mise exec -- bundle exec rspec spec/services/analysis/prompt_builder_spec.rb` passes with metadata-only example — 8e5c53a

### Phase 3: Service Layer — Metadata Persist on Intake

#### Automated

- [x] 3.1 `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb` passes with title/description example — 56376ab

### Phase 4: Request Layer — Customer Reference Isolation in Analyze

#### Automated

- [x] 4.1 `mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_security_spec.rb` passes with customer_reference-only block

### Phase 5: Cookbook Documentation (§6)

#### Automated

- [ ] 5.1 `mise exec -- bin/ci` passes (full suite + lint + security scans)

#### Manual

- [ ] 5.2 §6.1, §6.3, §6.4, §6.5, §6.6 filled; §3 Phase 1 marked complete
