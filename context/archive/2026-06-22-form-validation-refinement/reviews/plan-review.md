<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Form Validation Refinement

- **Plan**: `context/changes/form-validation-refinement/plan.md`
- **Mode**: Deep
- **Date**: 2026-06-22
- **Verdict**: SOUND (after triage fixes)
- **Findings**: 1 critical, 3 warnings, 1 observation

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS ✅ |
| Lean Execution | PASS ✅ |
| Architectural Fitness | PASS ✅ |
| Blind Spots | PASS ✅ |
| Plan Completeness | PASS ✅ |

## Grounding

Grounding: 9/9 paths ✓, 3/3 symbols ✓, brief↔plan ✓ (Progress↔Phase mechanical match ✓)

## Findings

### F1 — E2E paste oracle contradicts “What We're NOT Doing”

- **Severity**: ❌ CRITICAL
- **Impact**: 🔎 MEDIUM
- **Dimension**: Lean Execution
- **Location**: What We're NOT Doing vs Phase 3 — E2E specs
- **Detail**: Plan excluded paste-not-rerendered oracle in Playwright (TD-8) but Phase 3 E2E added “no secret in page content”.
- **Fix A ⭐ Recommended**: Remove paste-echo assertion from E2E; keep security in RSpec only.
- **Decision**: FIXED via Fix A — E2E UX only; paste oracle stays RSpec-only

### F2 — AR persist failure path lacks field-error mapping

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM
- **Dimension**: Blind Spots
- **Location**: Critical Implementation Details
- **Detail**: AR errors (e.g. `:sanitized_content`) won’t match `:sources` slot parsers.
- **Fix A ⭐ Recommended**: Document AR path as banner + repopulate only.
- **Decision**: FIXED via Fix A — documented in Critical Implementation Details

### F3 — Helper spec marked optional but Progress step is mandatory

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW
- **Dimension**: Plan Completeness
- **Location**: Phase 2 item 4; Progress 2.1
- **Detail**: Optional helper spec left Progress 2.1 ambiguous.
- **Fix**: Require helper spec; concrete rspec command in Progress.
- **Decision**: FIXED — helper spec required; Progress 2.1 concrete

### F4 — `name` repopulation is unredacted echo on 422

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW
- **Dimension**: Blind Spots
- **Location**: Phase 1 / Phase 2 — `@source_slots` name repopulation
- **Detail**: Name echo on 422 mirrors metadata policy; not covered by paste security spec.
- **Fix**: Document intentional scope in Critical Implementation Details.
- **Decision**: FIXED — documented in Critical Implementation Details

### F5 — Slot-index bug claim verified

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: End-State Alignment
- **Location**: Phase 1 — CaseSubmission fix
- **Detail**: Bug confirmed at `case_submission.rb:44`; existing specs won’t break.
- **Fix**: No plan change needed.
- **Decision**: DISMISSED — observation only; plan already correct
