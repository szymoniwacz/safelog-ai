<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Safe Multi-Source Intake (S-02)

- **Plan**: `context/changes/safe-multi-source-intake/plan.md`
- **Mode**: Deep
- **Date**: 2026-05-27
- **Verdict**: REVISE
- **Findings**: 0 critical, 2 warnings, 2 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | PASS |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding

Grounding: 5/5 paths ✓; `app/services/intake/` and `DebuggingCasesController` absent as expected; brief↔plan ✓; Progress↔Phase 5/5 ✓, 17/17 success criteria mapped ✓

## Findings

### F1 — Phase 3 before Phase 4 may block manual verification

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 3 manual verification; Phase 4 dependency
- **Detail**: Phase 3 success criteria mention browser create before views land in Phase 4. Controller can render minimal templates, but plan should state Phase 3 manual check is optional until Phase 4 or use scaffold placeholders.
- **Fix**: Phase 3 manual item → "Optional until Phase 4 views exist" OR add minimal `new.html.erb`/`show.html.erb` stubs in Phase 3.
- **Decision**: PENDING

### F2 — `customer_reference` redaction scope underspecified

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 2 — ProcessCaseSubmission; Critical Implementation Details
- **Detail**: Plan says "optionally redact customer_reference through engine" — PRD lists customer_reference as case metadata users paste/type, often sensitive. Leaving it plain while logs are redacted may leak emails/IDs in an encrypted but user-visible field.
- **Fix A ⭐ Recommended**: Require `customer_reference` run through same `Redaction::Engine` with shared registry before `DebuggingCase` assign (metadata may correlate with log placeholders).
  - Strength: Consistent security story; matches PRD diagnostic sensitivity.
  - Tradeoff: User sees placeholders in customer_reference on show — acceptable for MVP.
  - Confidence: HIGH — PRD groups customer_reference with diagnostic text.
  - Blind spot: None significant.
- **Fix B**: Store customer_reference as plain user input without redaction; only log bodies redacted.
  - Strength: Simpler; user sees what they typed.
  - Tradeoff: Sensitive metadata may persist verbatim (encrypted).
  - Confidence: MEDIUM — conflicts with spirit of US-01.
  - Blind spot: PRD intent on customer_reference field.
- **Decision**: PENDING

### F3 — Fixed source slots vs dynamic add

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Lean Execution
- **Location**: Phase 4 — new form
- **Detail**: Plan allows 2–3 fixed indexed slots vs Stimulus "add source". FR-003 requires multiple sources but not unlimited — fixed 3 slots is fine for MVP if at least one required.
- **Fix**: Document decision in plan-brief: start with 3 indexed slots, no dynamic add in S-02.
- **Decision**: PENDING

### F4 — Security DB assertion method not specified

- **Severity**: 💡 OBSERVATION
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Plan Completeness
- **Location**: Phase 5 — security specs
- **Detail**: "Query DB for raw substring" on encrypted columns requires reading decrypted values via AR in test (OK) — but must not use SQL LIKE on ciphertext for false confidence. Plan should say assert via model reload/decrypt in Ruby.
- **Fix**: Phase 5 contract: use `LogSource.pluck` after decrypt via AR attributes, not raw SQL string match on ciphertext.
- **Decision**: PENDING
