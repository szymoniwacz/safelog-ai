# Invariant Aggregate Refactor Plan — SafeLog AI

DDD plan (no production code implementation in Module 4). Source: `context/domain/02-invariant-aggregate-refactor.md`

---

## Step 1 — Business invariants

| ID | Invariant (MUST hold) | Source |
|----|----------------------|--------|
| **INV-G1** | **No diagnostic content may be persisted until it passed deterministic in-memory redaction; raw pasted content and raw→placeholder mappings are never persisted** | PRD; AGENTS.md; README |
| INV-G2 | Redaction before any AI reasoning — model sees sanitized evidence only | PRD; PromptBuilder |
| INV-G3 | Case-local placeholders: same raw value in one submission → same placeholder cross-source | PRD; PlaceholderRegistry |
| INV-G4 | Redaction findings persisted without original values (type, line, placeholder, risk) | PRD; Engine |
| INV-G5 | Atomic intake: case + all log sources in one transaction | ProcessCaseSubmission |
| INV-G7 | Case belongs to one User; no cross-user access | PRD; controller scope |
| INV-G8 | AI report hypothesis-framed with uncertainty_notes; invalid → retry once → failed | PRD; AnalyzeCase |
| INV-G9 | Diagnostic text encrypted at rest | PRD; model `encrypts` |

## Step 2 — Classification and pick #1

Scale: **Core** (1–5), **Spread** (1–5 layers without central guard), **Enforcement** (E= enforced, D= declared/convention, N= violable without test regression).

| ID | Core | Spread | Enforcement | Notes |
|----|------|--------|-------------|-------|
| **INV-G1** | **5** | **5** | **D→N** | Product insight; rule in orchestrator + no raw columns + oracles; **AR models accept any string** |

### Choice: **INV-G1 — Persistence gate (sanitized-only)**

**Rationale:** Core PRD business logic and shape-notes (“deterministic redaction must gate AI”). Without INV-G1 the product becomes generic “paste logs to AI”. **Structurally weakest enforcement:** security oracles prove the happy path, but **no domain type or aggregate root** prevents `LogSource.create!(sanitized_content: raw_secret)`. Rule lives procedurally in `ProcessCaseSubmission` (5 responsibilities in one class) and negatively in schema (no raw columns), not in a closed domain model.

## Step 4 — Aggregate guardian design (summary)

**Only legal way to materialize DebuggingCase in DB:** in-memory aggregate `Intake::SanitizedCaseDraft` built through redaction, persisted via repository in one transaction. Raw `pasted_content` never leaves intake as a persistable type.

```
Intake::SanitizedCaseDraft          (AGGREGATE ROOT)
  ├── prepare!(submission)         — redact in memory, build draft
  ├── persist!(repository)         — single txn, sanitized-only
  └── RawPersistenceForbiddenError — no silent partial persist
```

**Plan status:** F1–F5 phased roadmap documented for future implementation slice — M4L5 deliverable complete.
