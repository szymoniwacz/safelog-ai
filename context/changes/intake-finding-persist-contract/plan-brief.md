# Intake Finding Persist Contract — Plan Brief

> Full plan: `context/changes/intake-finding-persist-contract/plan.md`
> Research: `context/changes/refactor-opportunities/research.md`

## What & Why

Engine findings reach the database as untyped hashes with no enforced contract
between `Redaction::Engine` and `RedactionFinding` persistence. This change
introduces a typed `Redaction::Finding`, an explicit AR mapper at the sole
persist seam, and inner-loop rollback tests — so future finding extensions
cannot silently break persistence.

## Starting Point

Today `Engine#redact_line` appends `{ finding_type, line_number, placeholder,
risk_level }` hashes and `ProcessCaseSubmission` passes them directly to
`create!`. Specs check finding values but not the key contract; G-01/G-02
rollback paths are untested.

## Desired End State

Findings are `Redaction::Finding` objects end-to-end through the engine;
`RedactionFinding.build_from_engine_finding` is the only persist adapter;
contract violations fail at construction or mapper type-check; G-01/G-02 prove
full transaction rollback. Persisted data and user-visible behavior unchanged.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Mapper location | `RedactionFinding.build_from_engine_finding` | Single explicit seam at AR boundary; matches refactor research recommendation | Research / Plan |
| Contract strictness | Strict — unknown kwargs rejected at Finding construction | Fail fast before persist; Data.define enforces shape | Plan |
| Engine typing | Full — `Redaction::Finding` in dedicated file, typed `Result#findings` | Eliminates implicit hash contract in redaction layer, not just at persist | Plan |
| Mapper input | `Redaction::Finding` only | No transitional hash path; one type through the seam | Plan |
| Rollback specs | Include G-01 + G-02 with stubbed `create!` | Closes highest-risk test gap bundled with persist contract work | Plan |
| Service extraction | None — keep `ProcessCaseSubmission` structure | Scope stays surgical; IMPL-1 deferred | Plan |
| Test surface | `redaction_finding_spec` + updated `engine_spec` | Model spec owns mapper contract; engine spec owns typed output | Plan |

## Scope

**In scope:** `Redaction::Finding` value object; engine + result migration;
`RedactionFinding.build_from_engine_finding`; persist seam swap; model spec;
engine spec matcher updates; G-01/G-02 rollback examples.

**Out of scope:** Schema changes; IMPL-1 extraction; CRLF (TD-5); metadata
finding persistence; hash-input mapper path.

## Architecture / Approach

```
Engine#redact_line → Redaction::Finding (typed)
       ↓
Result#findings: Array<Finding>
       ↓
ProcessCaseSubmission loop
       ↓
RedactionFinding.build_from_engine_finding(finding) → Hash
       ↓
log_source.redaction_findings.create!(attrs)
```

Validation runs at Finding construction; mapper maps fields explicitly;
rollback specs stub inner association `create!` failures.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Typed finding in redaction layer | `Redaction::Finding`, engine + result + engine_spec | Over-strict validation breaks valid engine output |
| 2. Persist mapper + seam swap | AR mapper, model spec, wired call-site | Missing a secondary `create!` call-site (verify with grep) |
| 3. Inner-loop rollback oracles | G-01, G-02 stub specs | Stub targets wrong association object |

**Prerequisites:** Green `bin/ci` on main; no open intake schema work.

**Estimated effort:** ~1–2 sessions across 3 phases.

## Open Risks & Assumptions

- Assumes no hidden callers pass engine hashes to persistence outside `ProcessCaseSubmission` (verified in refactor research; re-grep before Phase 2).
- `Data.define` presence validation must not reject valid engine output (e.g. line_number 0 if ever emitted — today 1-based).
- Stub-based G-01/G-02 prove rollback behavior with test doubles, not production failure modes.

## Success Criteria (Summary)

- Engine emits only `Redaction::Finding` instances; specs enforce type.
- Persist seam uses mapper exclusively; contract spec pins attribute whitelist.
- G-01/G-02 pass; `bin/ci` green; security oracles unchanged.
