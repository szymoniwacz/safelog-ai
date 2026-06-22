# Intake Persist Extraction — Plan Brief

> Full plan: `context/changes/intake-persist-extraction/plan.md`
> Research: `context/changes/refactor-opportunities/research.md`

## What & Why

Split `Intake::ProcessCaseSubmission` into a thin coordinator plus
`Intake::RedactMetadata` and `Intake::PersistRedactedCase` so metadata redaction,
transactional persistence, and orchestration have explicit seams. Motivation:
IMPL-1 ranked refactor — mixed responsibilities in a ~74-line intake boundary
block clean extraction and targeted rollback testing now that TD-2 and G-01/G-02
prerequisites are done.

## Starting Point

`ProcessCaseSubmission` validates a `CaseSubmission`, creates one shared
placeholder registry, redacts metadata inline via a private helper, runs
`Redaction::Engine` per source, and persists the full case tree in the sole
`DebuggingCase.transaction` in `app/`. Finding persist already uses
`RedactionFinding.build_from_engine_finding`. Two callers
(`DebuggingCasesController`, `Demo::LoadCase`) depend only on public `.call` /
`Result`.

## Desired End State

Coordinator validates, redacts (metadata + sources), builds an explicit persist
DTO, and delegates. `PersistRedactedCase` owns the transaction and all AR
creates. Rollback oracles live at the persist seam. `CaseSubmission` no longer
has a dead `Source` passthrough branch. Public API and persisted data shape are
unchanged; `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Transaction owner | `PersistRedactedCase` | Persist layer should wrap atomic AR writes | Plan |
| Source redaction owner | Coordinator runs `Engine.redact` | Persist stays AR-only; security boundary stays visible in orchestrator | Plan |
| Persist input | Explicit DTO / keywords (no `CaseSubmission`) | Decouple persist from form object shape | Plan |
| Phase split | Three phases: RedactMetadata → Persist → G-05 | Incremental reviewable diffs | Research / Plan |
| Rollback oracles | Dedicated `persist_redacted_case_spec` (G-01/G-02) | Rollback behavior tested at persist seam | Plan |
| RedactMetadata testing | Dedicated unit spec + submission integration oracle | Pin helper contract without duplicating full flow | Plan |
| Scope | IMPL-1 extraction + G-05 cleanup | Bundle trivial dead branch while touching intake | Plan |

## Scope

**In scope:** `RedactMetadata` extract, `PersistRedactedCase` extract with DTO,
coordinator slim-down, persist + redact unit specs, G-01/G-02 migration,
`CaseSubmission` G-05 branch removal + minimal unit spec.

**Out of scope:** Schema changes, metadata encryption (TD-7), CRLF normalization
(TD-5), demo facade (TD-10), full `CaseSubmission` spec (TD-3), strong-params
tests (TD-4).

## Architecture / Approach

```
CaseSubmission params
        ↓
ProcessCaseSubmission (validate → registry → RedactMetadata + Engine.redact)
        ↓
PersistRedactedCase (transaction → DebuggingCase + LogSource + RedactionFinding)
        ↓
Result(debugging_case, errors)
```

One registry per submission; persist never sees raw paste text.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. RedactMetadata | Callable metadata redaction + unit spec | Trivial wiring miss on one of five call sites |
| 2. PersistRedactedCase | Transaction + AR creates moved; G-01/G-02 migrated | DTO shape drift vs current AR attributes |
| 3. G-05 cleanup | Remove dead Source passthrough + form spec | None — no production callers used branch |

**Prerequisites:** TD-2 finding contract and G-01/G-02 on main (done, PR #14)
**Estimated effort:** ~2–3 focused sessions across 3 phases

## Open Risks & Assumptions

- Security reviewers must still see one registry per submission and no sanitized
  writes outside `PersistRedactedCase`'s transaction — document in PR note.
- `AnalyzeCase` also owns its transaction; this change does not establish a
  repo-wide orchestrator pattern — intake-only.
- G-05 removal assumes zero callers pass pre-built `Source` structs (verified in
  research).

## Success Criteria (Summary)

- Public `ProcessCaseSubmission.call` / `Result` unchanged for both callers
- All existing intake integration examples pass; G-01/G-02 live on persist spec
- No raw secrets in persisted AR columns (existing security oracles green)
- `bin/ci` green after each phase
