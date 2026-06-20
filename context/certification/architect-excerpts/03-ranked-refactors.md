# Refactor opportunities — ranked (M4L4)

Source: `context/changes/refactor-opportunities/research.md` (exploration only — no code changes in Module 4)

## Summary

Of **27 distinct problems** from case-submission flow analysis, **6 are structural refactor candidates** (TD-2, TD-5, TD-7, TD-10, IMPL-1, G-05); the rest are test, documentation, or product-scope gaps.

**Ranked refactor opportunities (proposal for planning):**

1. **TD-2** — explicit finding persist boundary (lowest change cost, highest leverage before extending findings)
2. **IMPL-1** — extract `redact_metadata` + persist object from `ProcessCaseSubmission` (composes with TD-2; enables rollback specs)
3. **TD-5** — CRLF normalization in `Engine` (low blast radius; real-world paste correctness)

Rejected for refactor ranking: TD-7 (product decision), TD-10 facade (doc-only suffices), G-05 (trivial dead code).

## Problem inventory (structural candidates)

| ID | Problem | Class | Rationale |
|----|---------|-------|-----------|
| TD-2 | Findings metadata not explicitly bounded at persist | **CANDIDATE** | Shape change — extract persist boundary |
| IMPL-1 | `ProcessCaseSubmission` mixes orchestration + redact + persist | **CANDIDATE** | God-object; 5 responsibilities in one class |
| TD-5 | CRLF not normalized before redaction | **CANDIDATE** | Engine behavior change; cross-platform paste |
| TD-7 | Multi-step intake UX | NON-CANDIDATE | Product scope |
| TD-10 | Missing facade naming | NON-CANDIDATE | Documentation suffices |
| G-05 | Dead code in helper | NON-CANDIDATE | Trivial cleanup |

**Hard boundary:** exploration only — no implementation decisions in M4L4 research.

## Verification

Ranking claims verified with **ast-grep** at pinned commit (`verification_commit: 2ce9993`). See the ast-grep verification section in the full research doc.

**Links forward:** TD-2 + IMPL-1 compose with M4L5 `SanitizedCaseDraft` aggregate plan (`context/domain/02-invariant-aggregate-refactor.md`).
