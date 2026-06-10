---
date: 2026-06-10T18:00:00+0200
researcher: Composer
git_commit: 9fe8adf8761d8fe524fd68a1daeebef6831a6678
branch: main
repository: safelog-ai
topic: "Refactor opportunities — which structural problems to fix, in what order"
tags: [research, refactor, technical-debt, intake, redaction, structural-debt]
status: complete
last_updated: 2026-06-10
last_updated_by: Composer (m4l4-2 exploration)
source_analysis: context/changes/case-submission-flow-analysis/research.md
---

# Research: Refactor opportunities

**Date**: 2026-06-10
**Researcher**: Composer (3 sub-agents per structural candidate)
**Git Commit**: `9fe8adf8761d8fe524fd68a1daeebef6831a6678`
**Branch**: main
**Repository**: safelog-ai
**Source analysis**: [`context/changes/case-submission-flow-analysis/research.md`](../case-submission-flow-analysis/research.md)

## Research Question

Which problems documented in the case-submission-flow analysis are **structural refactor candidates** (fix changes code shape, not just tests or docs)? For each candidate: current shape, intentionality verdict, migration feasibility — then rank the 2–3 strongest opportunities with trade-offs for a separate planning session.

**Hard boundary:** exploration only — no code changes, no implementation decisions.

---

## Problem inventory and classification

Every problem from the source analysis, classified as **CANDIDATE** (structural refactor) or **NON-CANDIDATE** (test, documentation, or product-scope gap — input for feasibility/cost only).

| ID | Problem (from source) | Class | Rationale |
|----|------------------------|-------|-----------|
| TD-1 | Transaction rollback tested only on outer `create!` | NON-CANDIDATE | Missing test oracle; transaction structure is correct |
| TD-2 | `findings` hash as implicit DB contract | **CANDIDATE** | Adding mapper/DTO changes persist seam shape |
| TD-3 | No unit spec for `CaseSubmission` | NON-CANDIDATE | Test coverage gap |
| TD-4 | Strong params without mass-assignment test | NON-CANDIDATE | Test coverage gap |
| TD-5 | `\r\n` line endings in `Engine` | **CANDIDATE** | Input normalization changes engine processing shape |
| TD-6 | Known pattern gap without regression spec | NON-CANDIDATE | Test coverage gap |
| TD-7 | Plaintext metadata columns | **CANDIDATE** | `encrypts` on models changes persistence shape — but product-gated |
| TD-8 | E2E covers only happy path | NON-CANDIDATE | Test coverage gap |
| TD-9 | `filter_parameter_logging` checklist | NON-CANDIDATE | Documentation/process gap |
| TD-10 | `Demo::LoadCase` hidden coupling | **CANDIDATE** | Optional `Intake::SubmitCase` facade changes call-site structure |
| IMPL-1 | `ProcessCaseSubmission` mixes orchestration, txn, helper, AR | **CANDIDATE** | Extract persist/redact layers changes class boundaries |
| G-05 | `Source` struct passthrough dead branch | **CANDIDATE** | Removing branch simplifies `normalize_sources` shape |
| G-01 | Rollback when `log_sources.create!` fails | NON-CANDIDATE | Test gap (feeds TD-1) |
| G-02 | Rollback when `redaction_findings.create!` fails | NON-CANDIDATE | Test gap (feeds TD-1) |
| G-03 | `sources: nil` path unverified | NON-CANDIDATE | Test gap |
| G-04 | Mass assignment test | NON-CANDIDATE | Test gap (feeds TD-4) |
| G-06–G-15 | Remaining test gaps | NON-CANDIDATE | Test/documentation gaps |
| OQ-1 | Normalize `\r\n` vs document? | NON-CANDIDATE | Decision input for TD-5 |
| OQ-2 | Encrypt plaintext metadata post-MVP? | NON-CANDIDATE | Product/threat-model input for TD-7 |
| OQ-3 | Limit `pasted_content` size | NON-CANDIDATE | Validation feature, not structural refactor |

**Structural candidates (7):** TD-2, TD-5, TD-7, TD-10, IMPL-1, G-05 — plus TD-10 facade variant counted under TD-10.

---

## Candidate analyses

### TD-2: `findings` hash as implicit DB contract

#### Current shape

| Statement | Tag |
|-----------|-----|
| `Engine#redact_line` appends `{ finding_type, line_number, placeholder, risk_level }` per match | **evidence** — `engine.rb:36–41` |
| `Redaction::Result` holds untyped `findings` array | **evidence** — `result.rb:4–10` |
| Sole runtime persist call-site: `log_source.redaction_findings.create!(finding)` | **evidence** — `process_case_submission.rb:45–47` |
| Hash keys match DB columns 1:1; `log_source_id` set by association | **evidence** — `schema.rb:55–63`, `redaction_finding.rb:1–5` |
| No mapper, DTO, or `Data.define` for findings | **evidence** |
| Downstream consumers read AR records, not engine hashes | **evidence** — `summary_counts.rb:14`, `extract_signals.rb:40–41`, `debugging_cases_controller.rb:17–19` |
| Metadata redaction discards findings (`.sanitized_text` only) | **evidence** — `process_case_submission.rb:58–61` |
| Rename/remove hash key → `RecordInvalid` or `UnknownAttributeError` at runtime | **inference** |

#### Intentionality verdict

**Conscious MVP limitation.** S-02 plan (`context/archive/2026-05-27-safe-multi-source-intake/plan.md:81, 136–138`) specified findings as array of hashes with exactly those four keys before implementation. Schema (F-02, commit `0b038ae`) predates engine (`f82913b`) by ~3.5h; persist loop (`6f98f4d`) unchanged across 5 subsequent intake commits. No mapper was planned.

**unknown:** Whether `Data.define` vs hash-at-boundary was explicitly rejected or simply not revisited post-MVP.

#### Migration feasibility

| Factor | Assessment |
|--------|--------------|
| Incremental path | Phase A: `RedactionFinding.build_from_engine_finding(finding)` at persist seam — reversible, ~2–3 files. Phase B (optional): typed `Redaction::Finding` in engine |
| Blast radius | Full intake flow: 31 files. **This change alone: ~4** — `engine.rb`, `process_case_submission.rb`, `redaction_finding.rb`, `engine_spec.rb` |
| Existing safeguards | `engine_spec.rb:20–40` (hash keys, no raw); `process_case_submission_spec.rb:284–300` (persisted `finding_type`); security oracle scans values not key contract |
| Gaps | No `redaction_finding_spec.rb` (G-12); no contract spec pinning keys ⊆ AR attrs; inner-loop rollback untested (G-02) |
| First prerequisite | Boundary factory + contract spec whitelisting exactly four attrs |

---

### IMPL-1: `ProcessCaseSubmission` mixed responsibilities

#### Current shape

| Responsibility | Location | Tag |
|----------------|----------|-----|
| Public API + `Result` | `process_case_submission.rb:5–13, 64–70` | **evidence** |
| Validation gate (no DB/registry on invalid) | `process_case_submission.rb:21` | **evidence** |
| Registry lifecycle (one per submission) | `process_case_submission.rb:23` | **evidence** |
| Sole `DebuggingCase.transaction` in `app/` | `process_case_submission.rb:27–49` | **evidence** |
| Private `redact_metadata` helper | `process_case_submission.rb:58–62` | **evidence** |
| Direct AR `create!` on 3 models | `process_case_submission.rb:28–33, 38–46` | **evidence** |
| `RecordInvalid` → `Result(errors:)` mapping | `process_case_submission.rb:52–53` | **evidence** |
| Controller stays thin (delegates only) | **evidence** — `debugging_cases_controller.rb:28–38` |
| Parallel pattern in `Analysis::AnalyzeCase` (orchestrator owns txn + persist) | **inference** — `analyze_case.rb:22–52` |
| Repo-map lists engine/correlation as safe seams, not intake orchestrator | **evidence** — `artifact-2-structure.md:176` |

#### Intentionality verdict

**Conscious MVP limitation.** S-02 plan specified single service creating full case tree in one transaction with shared registry. Monolith was the spec, not an oversight. Five commits since initial (`6f98f4d`) only added metadata fields through existing `redact_metadata` path — structure never split.

#### Migration feasibility

| Extraction target | Feasibility | Notes |
|-------------------|-------------|-------|
| `redact_metadata` → `Intake::RedactMetadata` or module | **High** | 4 call sites in one class; registry injection unchanged |
| Persist object (`Intake::PersistRedactedCase`) | **Medium** | Must preserve atomicity; enables easier inner-loop rollback specs (TD-1) |
| Thin coordinator `ProcessCaseSubmission` | **Medium** | Public `.call`/`Result` unchanged → 2 runtime callers unaffected |
| Full repository layer | **Low value** | No existing pattern in `app/services/`; YAGNI |

**Suggested order:** (1) inner-loop rollback specs, (2) extract `redact_metadata`, (3) extract persist inside same transaction block.

**Blocker:** Security oracles treat this file as the only raw-contact boundary. Split must keep "one registry per submission" and "no sanitized write outside transaction" obvious in review.

| Factor | Assessment |
|--------|--------------|
| Blast radius | ~31 files if intake contract changes; extraction-only touches `process_case_submission.rb` + new file(s) + existing specs |
| First prerequisite | Add G-01/G-02 rollback specs **before** moving transaction block |

---

### TD-5: `\r\n` line endings in `Redaction::Engine`

#### Current shape

| Statement | Tag |
|-----------|-----|
| Split: `text.to_s.split(/\n/, -1)` | **evidence** — `engine.rb:15` |
| Rejoin: `sanitized_lines.join("\n")` (LF only) | **evidence** — `engine.rb:20` |
| CRLF paste → lines retain trailing `\r` | **inference** (standard Ruby `\n`-only split; no `\r` handling in `app/`) |
| Patterns use `\S`, `\b` — likely still match before trailing `\r` | **inference** — not verified by spec |
| Zero `\r`/`\r\n` examples in `spec/` | **evidence** |
| Sole runtime callers: `process_case_submission.rb:36, 61` | **evidence** (source analysis V-01) |

#### Intentionality verdict

**No documented decision.** Engine unchanged since initial commit `f82913b` (2026-05-27, S-02 phase 1). `-1` preserve trailing empty lines looks intentional; CRLF handling never specified in PRD, F-02, or patterns docs.

#### Migration feasibility

| Factor | Assessment |
|--------|--------------|
| Fix options | (a) `gsub(/\r\n?/, "\n")` before split; (b) `chomp("\r")` per line; (c) document + regression spec only |
| Blast radius | **Low** — primary: `engine.rb` + `engine_spec.rb`; optionally one integration spec |
| Existing safeguards | Security oracles may pass even with `\r` in output if patterns match; gap is correctness not raw-leak |
| First prerequisite | **Behavior decision** (source OQ-1): normalize vs accept-and-document; write characterization spec either way |

---

### TD-7: Plaintext metadata columns

#### Current shape

| Statement | Tag |
|-----------|-----|
| `encrypts :customer_reference` only on `DebuggingCase` | **evidence** — `debugging_case.rb:5` |
| `encrypts :sanitized_content` only on `LogSource` | **evidence** — `log_source.rb:6` |
| `title`, `description`, `environment`, `name` — plain columns, redacted via `redact_metadata` | **evidence** — `process_case_submission.rb:29–32, 40` |
| `encryption_at_rest_spec.rb` audits encrypted columns only | **evidence** — no examples for metadata columns |
| Security oracle scans metadata for raw substrings at AR layer | **evidence** — `security_persistence_helpers.rb:26–37` |
| Index UI reads plain `title`, `environment` | **evidence** — `index.html.erb:27–28` |
| `PromptBuilder`, `report_filename.rb` read plain metadata | **evidence** |

#### Intentionality verdict

**Conscious foundational decision (F-02).** `context/archive/2026-05-27-encrypted-diagnostic-schema/plan-brief.md:22`: *"PRD-strict diagnostic text only; title/env/description stay queryable plain text."* PRD NFR lists encrypted fields without metadata. Reviews (`mvp-impl-review.md:29`, `m1-m3-builder-readiness-review.md:259`) accept this tradeoff. Redaction is the protection mechanism.

#### Migration feasibility

| Factor | Assessment |
|--------|--------------|
| If encrypting | **Medium–high** blast radius: models, `encryption_at_rest_spec`, index UI (queryability), `report_filename.rb`, production backfill |
| Queryability | Non-deterministic `encrypts` breaks naive `WHERE`/`ORDER BY` on title/env unless schema strategy changes |
| Lower-effort alternative | Negative baseline spec documenting intentional plaintext (not structural refactor) |
| First prerequisite | **Product/threat-model decision** (source OQ-2) — PRD does not require metadata encryption today |

**Note:** True fix is a **product/security concept change**, not code-structure cleanup. Structural refactor only applies after that decision.

---

### TD-10: `Demo::LoadCase` as hidden coupling

#### Current shape

| Statement | Tag |
|-----------|-----|
| Two runtime callers of `ProcessCaseSubmission.call` | **evidence** — `debugging_cases_controller.rb:30`, `demo/load_case.rb:23` |
| Demo: env gate → `CaseFixture.submission_attributes` → same pipeline | **evidence** — `load_case.rb:19–24`, `case_fixture.rb:9–38` |
| Fixture keys mirror strong params | **evidence** — `debugging_cases_controller.rb:91–98` |
| S-06 plan: reuse intake, demo exercises real code | **evidence** — `context/archive/2026-05-27-load-demo-case/plan-brief.md:21` |
| Zero git co-change between proc and demo files | **evidence** — proc: 5 commits; demo: 1 commit (`77b0291`) |
| Demo not listed as second intake caller in repo-map zone #4 | **evidence** — appears only as zone #6 (Fly vs local demo) |
| Spec coverage: `load_case_spec.rb`, `debugging_cases_load_demo_spec.rb` | **evidence** |

#### Intentionality verdict

**Conscious limitation — intentional reuse, under-documented visibility.** FR-011 requires demo in dev/test. Coupling is by design; "hidden" refers to map/visibility, not accidental architecture.

#### Migration feasibility

| Option | Effort | Risk |
|--------|--------|------|
| A. Document in repo-map intake table | Low | Low |
| B. `Intake::SubmitCase` facade (wraps `CaseSubmission.new` + `ProcessCaseSubmission.call`) | Medium | Medium — reduces duplicate two-liner |
| C. Demo bypasses intake | High | **High** — violates "exercises real code" |
| D. Demo via internal HTTP POST | High | Medium — unnecessary indirection |

| Factor | Assessment |
|--------|--------------|
| Blast radius | Any `CaseSubmission` contract change hits fixture + demo specs (~4 files) regardless of facade |
| First prerequisite | Document demo as second intake caller in repo-map (Option A) before any structural change |

---

### G-05: `Source` struct passthrough in `normalize_sources`

#### Current shape

| Statement | Tag |
|-----------|-----|
| `Source = Data.define(:source_type, :name, :pasted_content)` | **evidence** — `case_submission.rb:8` |
| Passthrough branch: `if source.is_a?(Source)` → return unchanged | **evidence** — `case_submission.rb:29–30` |
| All runtime callers pass hashes, never `Source` | **evidence** — controller params, `case_fixture.rb`, all specs |
| Passthrough branch never exercised in tests | **evidence** — grep: no `Source.new` in `spec/` |
| `sources: nil` → `Array(nil)` → `[]` → validation error | **inference** — untested (G-03) |
| File unchanged since single commit `6f98f4d` | **evidence** |

#### Intentionality verdict

**Likely forward-compatibility, never adopted.** S-02 plan describes "array of source hashes" — passthrough not mentioned. No caller uses `Source` structs after 2+ weeks.

**unknown:** Whether passthrough was planned for programmatic callers or defensive coding.

#### Migration feasibility

| Option | Effort | Risk |
|--------|--------|------|
| A. Add `case_submission_spec.rb` (covers passthrough + `sources: nil`) | Low | Low — addresses TD-3/G-03 too |
| B. Remove passthrough branch (hash-only path) | Low | Very low — zero callers use `Source` |

| Factor | Assessment |
|--------|--------------|
| Blast radius | **1 file** (`case_submission.rb`); no caller changes for Option B |
| First prerequisite | Unit spec documenting current behavior before removal (Option A) |

---

## Refactor opportunities (ranked)

Proposal for planning session. **Not a decision** — ranking based on evidence: cost of debt vs cost of change, blast radius, incremental path.

### 1. TD-2 — Explicit finding persist boundary

| Dimension | Assessment |
|-----------|------------|
| **Current → target** | Engine hash passed directly to `create!(finding)` → explicit mapper (`RedactionFinding.build_from_engine_finding`) or typed `Redaction::Finding` + `#to_persistence_attrs` at sole call-site |
| **Why #1** | Only structural seam between redaction domain and persistence with **zero code-level contract enforcement**. Debt cost rises with every findings extension (new columns, pattern metadata). Change cost is **lowest** among candidates (~4 files, reversible). Unblocks safe evolution without touching 31-file blast radius. |
| **Blast radius** | ~4 files minimum; downstream (correlation, summary, views) reads AR attrs — unaffected if schema unchanged |
| **Incremental path** | (1) Factory + contract spec → (2) swap `create!(finding)` for `create!(factory(finding))` → (3) optional typed object in engine |
| **First prerequisite** | Contract spec asserting engine output keys ⊆ `{ finding_type, line_number, placeholder, risk_level }` and all four present |

**Trade-off:** Adds one indirection line at the persist seam. Acceptable — documents contract that today exists only by naming convention.

---

### 2. IMPL-1 — Extract `redact_metadata`, then persist object

| Dimension | Assessment |
|-----------|------------|
| **Current → target** | Monolithic `ProcessCaseSubmission` (~72 lines, 4 responsibilities) → thin coordinator + `Intake::RedactMetadata` + `Intake::PersistRedactedCase` (transaction stays in coordinator or persist object) |
| **Why #2** | Debt cost: mixed responsibilities make TD-1 rollback tests harder to write (must stub inside monolith). Change cost: **medium** — but public `.call`/`Result` API unchanged, 2 runtime callers unaffected. Aligns with future metadata/source field additions (5 commits so far all touched this file). Composes with TD-2 (persist object is natural home for finding mapper). |
| **Blast radius** | Extraction-only: `process_case_submission.rb` + 1–2 new files + existing specs. Full intake blast radius (31 files) only if contract changes. |
| **Incremental path** | (1) G-01/G-02 rollback specs → (2) extract `redact_metadata` → (3) extract persist inside same transaction → (4) optional TD-2 mapper in persist object |
| **First prerequisite** | Inner-loop rollback specs (G-01, G-02) **before** moving transaction block |

**Trade-off:** More files for a ~72-line class. Justified if TD-1 tests or new intake fields are planned soon; optional hygiene if MVP is stable.

---

### 3. TD-5 — CRLF normalization in `Engine`

| Dimension | Assessment |
|-----------|------------|
| **Current → target** | `split(/\n/, -1)` on raw paste (trailing `\r` retained) → normalize `\r\n`/`\r` to `\n` before split (or per-line chomp) |
| **Why #3** | Real-world Windows paste is plausible for log debugging tool. Debt cost: unknown `line_number`/pattern behavior on CRLF input. Change cost: **low** (2 files: engine + spec). Sole runtime callers (2 call-sites in `process_case_submission.rb`). |
| **Blast radius** | **Low** — `engine.rb`, `engine_spec.rb`; optionally one line in `process_case_submission_spec.rb` |
| **Incremental path** | (1) Characterization spec with `"line\r\nsecret"` input documenting current behavior → (2) normalize + update spec → (3) verify security oracles still green |
| **First prerequisite** | Behavior decision (source OQ-1): normalize (recommended) vs accept-and-document |

**Trade-off:** Normalization changes persisted `sanitized_content` for existing CRLF pastes (removes `\r`). Low risk — `\r` in stored content has no known consumer dependency.

---

## Considered and rejected

| Candidate | Why rejected for refactor ranking |
|-----------|-----------------------------------|
| **TD-7** (encrypt metadata) | **Product decision, not structural debt.** F-02/PRD intentionally keep title/env/description queryable plaintext; redaction is the control. Encrypting requires threat-model sign-off, index UI impact, backfill — out of scope for code-shape cleanup. Baseline negative spec is test work, not refactor. |
| **TD-10** (demo facade) | **Intentional reuse by design** (FR-011, S-06). Facade (`Intake::SubmitCase`) adds indirection without solving fixture↔params contract sync. Doc-only fix (repo-map) addresses the "hidden" part at near-zero cost. |
| **G-05** (remove `Source` passthrough) | **Trivial dead-code cleanup** (~3 lines), not a meaningful structural refactor. Better bundled with TD-3 unit spec work. Zero production callers use the branch. |
| **OQ-3** (paste size limit) | Validation feature, not code-structure change. Belongs in a separate change if product requires it. |

---

## Non-candidate backlog (feeds planning cost estimates)

These items from the source analysis are **not structural refactors** but should inform sequencing — several are prerequisites or natural companions to ranked opportunities:

| Priority (source) | ID | Companion to ranked opportunity |
|-------------------|-----|--------------------------------|
| P0 | TD-1 / G-01, G-02 | Prerequisite for IMPL-1 (#2) |
| P0 | G-03 (`sources: nil`) | Companion to G-05 unit spec (TD-3) |
| P1 | TD-4 / G-04 | Independent test slice |
| P1 | TD-3 | Companion to G-05; no refactor required |
| P2 | TD-6, TD-8 | Independent test/E2E slices |
| P3 | TD-9 | Process/docs only |

---

## Code References

- `app/services/redaction/engine.rb:15–21, 36–41` — line split + findings hash construction
- `app/services/intake/process_case_submission.rb:27–49, 58–62` — transaction, persist, `redact_metadata`
- `app/services/intake/case_submission.rb:27–38` — `normalize_sources` + `Source` passthrough
- `app/services/demo/load_case.rb:22–23` — second intake caller
- `app/models/redaction_finding.rb:1–5` — AR validations matching hash keys
- `context/changes/case-submission-flow-analysis/research.md` — source analysis (TD-1–TD-10, G-01–G-15, blast radius)

## Related Research

- `context/changes/case-submission-flow-analysis/research.md` — intake flow analysis (input evidence)
- `context/archive/2026-05-27-safe-multi-source-intake/plan.md` — S-02 original intake design
- `context/archive/2026-05-27-encrypted-diagnostic-schema/plan-brief.md` — F-02 encryption scope (TD-7)
- `context/archive/2026-05-27-load-demo-case/plan-brief.md` — S-06 demo reuse decision (TD-10)
- `context/foundation/prd.md` — guardrails and encryption NFR

## Open Questions (for planning, not exploration)

1. Should IMPL-1 (#2) proceed only if new intake fields are planned, or proactively for test ergonomics?
2. TD-5 (#3): normalize vs document — product preference on Windows paste fidelity?
3. Should G-05 branch removal be bundled with ranked #2 or handled as test-only work (TD-3)?
