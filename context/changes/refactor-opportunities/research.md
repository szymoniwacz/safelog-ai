---
date: 2026-06-10T18:00:00+0200
researcher: Composer
git_commit: e96dc9277c67648f03543b3291eb2d62a2edf0bb
branch: main
repository: safelog-ai
topic: "Refactor opportunities — which structural problems to fix, in what order"
tags: [research, refactor, technical-debt, intake, redaction, structural-debt, verified]
status: complete
last_updated: 2026-06-22
last_updated_by: Composer (main re-verification)
last_updated_note: "Re-verified TD-1–TD-10, G-01–G-15, IMPL-1 against main; disposition for active changes"
verification_commit: e96dc9277c67648f03543b3291eb2d62a2edf0bb
ast_grep_version: 0.43.0
source_analysis: context/changes/case-submission-flow-analysis/research.md
---

# Research: Refactor opportunities

**Date**: 2026-06-10
**Researcher**: Composer (3 sub-agents per structural candidate)
**Git Commit**: `e96dc9277c67648f03543b3291eb2d62a2edf0bb` (re-verified 2026-06-22) · original research `9fe8adf`
**Branch**: main
**Repository**: safelog-ai
**Source analysis**: [`context/changes/case-submission-flow-analysis/research.md`](../case-submission-flow-analysis/research.md)

## Research Question

Which problems documented in the case-submission-flow analysis are **structural refactor candidates** (fix changes code shape, not just tests or docs)? For each candidate: current shape, intentionality verdict, migration feasibility — then rank the 2–3 strongest opportunities with trade-offs for a separate planning session.

**Hard boundary:** exploration only — no code changes, no implementation decisions.

## Summary

Source analysis [`case-submission-flow-analysis/research.md`](../case-submission-flow-analysis/research.md) documents 10 technical-debt items (TD-1–TD-10), 15 test gaps (G-01–G-15), and 3 open questions on the intake→redaction→persist path. Of **27 distinct problems**, **6 were structural refactor candidates** (TD-2, TD-5, TD-7, TD-10, IMPL-1, G-05); the rest are test, documentation, or product-scope gaps.

**Re-verification against main (`e96dc92`, 2026-06-22):** Two ranked refactors and several test gaps are **done** via merged changes [`intake-finding-persist-contract`](../intake-finding-persist-contract/plan.md) (PR #14) and [`e2e-test-verification`](../e2e-test-verification/plan.md) (PR #15). [`ci-cd-code-review`](../ci-cd-code-review/requirements.md) is unrelated to intake ranking but **implemented** on main.

| Outcome | Count | IDs |
|---------|-------|-----|
| **Done** | 6 | TD-1, TD-2, G-01, G-02, G-12, G-14 |
| **Partially done** | 2 | TD-8 (validation E2E; paste-on-error still RSpec-only), G-15 (1-slot in `seed.spec.ts` / `user-isolation.spec.ts`; no dedicated minimum-source spec) |
| **Still open** | 16 | TD-3–TD-6, TD-9, G-03–G-04, G-05–G-07, G-09–G-11, G-13, IMPL-1, OQ-1, OQ-3 |
| **Rejected** (refactor ranking) | 3 | TD-7, TD-10, OQ-2 |

**Updated ranked refactor opportunities (open work only):**

1. ~~**TD-2** — explicit finding persist boundary~~ → **DONE** (`Redaction::Finding` + `RedactionFinding.build_from_engine_finding`, PR #14)
2. **IMPL-1** — extract `redact_metadata` + persist object from `ProcessCaseSubmission` (now **#1 open**; rollback specs prerequisite met)
3. **TD-5** — CRLF normalization in `Engine` (still **#2 open**; low blast radius)

Rejected for refactor ranking (unchanged): TD-7 (product decision), TD-10 facade (doc-only suffices), G-05 as standalone ranked item (trivial dead code — bundle with TD-3), OQ-3 (validation feature).

---

## Re-verification against main (2026-06-22)

**Commit:** `e96dc9277c67648f03543b3291eb2d62a2edf0bb` · **Branch:** main  
**Method:** live code + git history (`git log --oneline` on key paths); ast-grep re-run on changed claims; cross-check merged PRs #14 and #15.

### Full problem inventory — current status

| ID | Problem (from source) | Jun-10 class | **Status (Jun-22)** | Evidence |
|----|------------------------|--------------|---------------------|----------|
| TD-1 | Transaction rollback tested only on outer `create!` | NON-CANDIDATE | **DONE** | G-01/G-02 in `process_case_submission_spec.rb:256–300` (PR #14) |
| TD-2 | `findings` hash as implicit DB contract | CANDIDATE | **DONE** | `Redaction::Finding` (`finding.rb:4–16`); `build_from_engine_finding` (`redaction_finding.rb:8–18`); persist seam `process_case_submission.rb:46–47` |
| TD-3 | No unit spec for `CaseSubmission` | NON-CANDIDATE | **STILL OPEN** | No `spec/**/case_submission_spec.rb` |
| TD-4 | Strong params without mass-assignment test | NON-CANDIDATE | **STILL OPEN** | No dedicated mass-assignment example |
| TD-5 | `\r\n` line endings in `Engine` | CANDIDATE | **STILL OPEN** | `engine.rb:15–20` — `split(/\n/, -1)` only; zero `\r` in `spec/` |
| TD-6 | Known pattern gap without regression spec | NON-CANDIDATE | **STILL OPEN** | `patterns.rb:7–10` gap; `engine_spec.rb` tests Bearer context only |
| TD-7 | Plaintext metadata columns | CANDIDATE | **REJECTED** | Unchanged product decision (F-02); `encrypts` still only on diagnostic fields |
| TD-8 | E2E covers only happy path | NON-CANDIDATE | **PARTIAL** | Validation E2E done (G-14); analyze-failure E2E added post-plan; paste-not-rerendered on 422 still RSpec-only |
| TD-9 | `filter_parameter_logging` checklist | NON-CANDIDATE | **STILL OPEN** | Comment in `security_persistence_helpers.rb:10`; no checklist artifact |
| TD-10 | `Demo::LoadCase` hidden coupling | CANDIDATE | **REJECTED** | No `Intake::SubmitCase`; 2 callers unchanged |
| IMPL-1 | `ProcessCaseSubmission` mixed responsibilities | CANDIDATE | **STILL OPEN** | 74-line monolith; no `RedactMetadata` / `PersistRedactedCase` |
| G-01 | Rollback when `log_sources.create!` fails | NON-CANDIDATE | **DONE** | `process_case_submission_spec.rb:256–274` |
| G-02 | Rollback when `redaction_findings.create!` fails | NON-CANDIDATE | **DONE** | `process_case_submission_spec.rb:276–300` |
| G-03 | `sources: nil` path unverified | NON-CANDIDATE | **STILL OPEN** | No dedicated example |
| G-04 | Mass assignment test | NON-CANDIDATE | **STILL OPEN** | Same as TD-4 |
| G-05 | `Source` struct passthrough dead branch | CANDIDATE | **STILL OPEN** (code) / **REJECTED** (rank) | Branch at `case_submission.rb:29–30`; zero `Source.new` in `spec/` |
| G-06 | Multiple invalid source types | NON-CANDIDATE | **STILL OPEN** | No dedicated example |
| G-07 | Windows `\r\n` in `Engine` | NON-CANDIDATE | **STILL OPEN** | Same as TD-5 |
| G-08 | No regression spec for standalone `sk-xxx` | NON-CANDIDATE | **STILL OPEN** | Bearer-only coverage in `engine_spec.rb:10` |
| G-09 | `position` values not asserted explicitly | NON-CANDIDATE | **STILL OPEN** | `position: index` at `process_case_submission.rb:41`; no explicit assertion in intake specs |
| G-10 | Plaintext columns — no baseline encryption audit | NON-CANDIDATE | **STILL OPEN** | `encryption_at_rest_spec.rb` unchanged scope |
| G-11 | Multiple patterns on one line — not tested | NON-CANDIDATE | **STILL OPEN** | `engine_spec.rb` — 4 examples, none multi-match per line |
| G-12 | No `redaction_finding_spec.rb` | NON-CANDIDATE | **DONE** | `spec/models/redaction_finding_spec.rb` — 4 examples |
| G-13 | Empty/nil input to `Engine.redact` | NON-CANDIDATE | **STILL OPEN** | No nil/empty examples in `engine_spec.rb` |
| G-14 | E2E: no validation-failure path | NON-CANDIDATE | **DONE** | `e2e/debugging-case-validation.spec.ts` — 2 tests (PR #15) |
| G-15 | E2E: always 3 slots, no single-source | NON-CANDIDATE | **PARTIAL** | `debugging-case-flow.spec.ts` still 3 slots; `seed.spec.ts` + `user-isolation.spec.ts` use 1 slot |
| OQ-1 | Normalize `\r\n` vs document? | NON-CANDIDATE | **STILL OPEN** | Prerequisite for TD-5 |
| OQ-2 | Encrypt plaintext metadata post-MVP? | NON-CANDIDATE | **REJECTED** (refactor) | Product/threat-model input only |
| OQ-3 | Limit `pasted_content` size | NON-CANDIDATE | **STILL OPEN** | Validation feature, not refactor |

### Merged changes verified on main

#### intake-finding-persist-contract (PR #14, `005b6cb`)

All substantive plan phases **done**:

- Typed `Redaction::Finding` with validation (`app/services/redaction/finding.rb`)
- Engine emits `Finding.new(...)` not hashes (`engine.rb:36–41`)
- `RedactionFinding.build_from_engine_finding` with type guard (`redaction_finding.rb:8–18`)
- Sole `redaction_findings.create!` uses mapper (`process_case_submission.rb:46–47`)
- Contract spec + G-12 (`spec/models/redaction_finding_spec.rb`)
- G-01/G-02 rollback oracles (`process_case_submission_spec.rb:256–300`)
- Explicitly out of scope and correctly omitted: IMPL-1, TD-5

#### e2e-test-verification (PR #15, `4073546`)

Plan phases 1–3 **done**; E2E still **not** in `bin/ci` (by design):

| Planned | Status | Evidence |
|---------|--------|----------|
| `debugging-case-validation.spec.ts` (2 tests) | **DONE** | Closes G-14 / TD-8 validation slice |
| `user-isolation.spec.ts` (1 test) | **DONE** | Cross-user 404 in browser |
| Invalid sign-in in `authentication.spec.ts` | **DONE** | Test 4 |
| `storageState` helpers + `.auth/` gitignore | **DONE** | `e2e/helpers.ts`, `.gitignore:47` |
| Wire Playwright into CI | **N/A (intentional skip)** | `config/ci.rb` — RSpec only |
| Analyze failure E2E | **Superseded** | `e2e/analyze-failure.spec.ts` added post-plan (plan marked blocked) |

**Regression count (excl. `capture-*`):** 11 tests / 7 files (plan target was 9 / 6).

#### ci-cd-code-review (`79a7314` + follow-ups)

Unrelated to intake ranking; **implemented** on main:

- `.github/workflows/ai-code-review.yml` — PR to `main` + `ai-cr:review` label
- `.github/actions/code-review/` — diff → `packages/code-reviewer` → comment + labels
- 6-criterion schema includes `documentation` (`review-schema.ts`)
- Advisory only — not in `ci.yml`

**Minor gaps vs requirements (do not block archive):** fork PRs skip silently (no neutral comment); API failure exits before `post-review.sh`; `requirements.md` header still `status: draft`.

### Active changes disposition

| Change folder | `change.md` status | Recommendation | Rationale |
|---------------|-------------------|----------------|-----------|
| `refactor-opportunities` | research | **Stay open** | Living backlog for IMPL-1, TD-5, and test-gap companions; this doc is the ranking source |
| `intake-finding-persist-contract` | implemented | **Archive** | All plan phases done on main; no open code work |
| `e2e-test-verification` | implemented | **Archive** | Plan complete; residual G-15/TD-8 gaps are test backlog items, not this change |
| `ci-cd-code-review` | implemented | **Archive** | Workflow shipped; minor req/doc drift can be a follow-up ticket |
| `case-submission-flow-analysis` | *(no change.md)* | **Archive** (merge context into refactor-opportunities) | Source analysis superseded by this re-verification; keep as historical input only |

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
| G-06 | Multiple invalid source types in one submission | NON-CANDIDATE | Test gap |
| G-07 | Windows `\r\n` line endings in `Engine` | NON-CANDIDATE | Test gap (same underlying issue as TD-5 candidate) |
| G-08 | No regression spec for standalone `sk-xxx` pattern gap | NON-CANDIDATE | Test gap (feeds TD-6) |
| G-09 | `position` values (0, 1, …) not asserted explicitly | NON-CANDIDATE | Test gap |
| G-10 | Plaintext columns — no baseline encryption audit | NON-CANDIDATE | Test gap (feeds TD-7 product question) |
| G-11 | Multiple patterns on one line — not tested in `Engine` | NON-CANDIDATE | Test gap |
| G-12 | No `spec/models/redaction_finding_spec.rb` | NON-CANDIDATE | Test gap (feeds TD-2 contract spec) |
| G-13 | Empty/nil input to `Engine.redact` | NON-CANDIDATE | Test gap |
| G-14 | E2E: no validation-failure path | NON-CANDIDATE | Test gap (feeds TD-8) |
| G-15 | E2E: always 3 slots, no single-source | NON-CANDIDATE | Test gap (feeds TD-8) |
| OQ-1 | Normalize `\r\n` vs document? | NON-CANDIDATE | Decision input for TD-5 |
| OQ-2 | Encrypt plaintext metadata post-MVP? | NON-CANDIDATE | Product/threat-model input for TD-7 |
| OQ-3 | Limit `pasted_content` size | NON-CANDIDATE | Validation feature, not structural refactor |

**Structural candidates (6):** TD-2, TD-5, TD-7, TD-10, IMPL-1, G-05.

### CI safeguards (refactor regression gates)

All ranked opportunities must stay green through `bin/ci` (`config/ci.rb`, mirrored in `.github/workflows/ci.yml`):

| Gate | Command | Relevance to candidates |
|------|---------|---------------------------|
| Style | `bin/rubocop` | New service files (IMPL-1, TD-2 mapper) |
| Gem audit | `bin/bundler-audit` | No new deps expected |
| Importmap audit | `bin/importmap audit` | N/A — backend-only refactors |
| Brakeman | `bin/brakeman --exit-on-warn` | Mass-assignment / strong-params unchanged unless TD-4 addressed separately |
| RSpec full suite | `bundle exec rspec` | Primary safety net — `process_case_submission_spec.rb` (12 ex.), `debugging_cases_security_spec.rb` (10 ex.), `engine_spec.rb`, `encryption_at_rest_spec.rb`, `load_case_spec.rb` |

E2E (`bin/e2e`) is **not** in `bin/ci` — TD-5/IMPL-1 changes unlikely to need Playwright unless form locators change. Security oracles in request/service specs are the mandatory pre-merge gate for intake refactors.

---

## Candidate analyses

### TD-2: `findings` hash as implicit DB contract

#### Current shape

| Statement | Tag |
|-----------|-----|
| `Engine#redact_line` appends `{ finding_type, line_number, placeholder, risk_level }` per match | **evidence** — `engine.rb:36–41` |
| `Redaction::Result` holds untyped `findings` array | **evidence** — `result.rb:4–10` |
| Sole runtime persist call-site: `log_source.redaction_findings.create!(finding)` | **evidence** — `process_case_submission.rb:46` (raport: 45–47) |
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
| `redact_metadata` → `Intake::RedactMetadata` or module | **High** | 5 call sites in one class (raport: 4); registry injection unchanged |
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

Proposal for planning session. **Not a decision** — ranking based on evidence at `e96dc92`.

### ~~1. TD-2 — Explicit finding persist boundary~~ **DONE**

Implemented in PR #14 (`intake-finding-persist-contract`). Engine typed VO + AR mapper at sole persist seam. Rollback specs (G-01/G-02) shipped in same change.

---

### 1. IMPL-1 — Extract `redact_metadata`, then persist object *(was #2)*

| Dimension | Assessment |
|-----------|------------|
| **Current → target** | Monolithic `ProcessCaseSubmission` (~72 lines, 4 responsibilities) → thin coordinator + `Intake::RedactMetadata` + `Intake::PersistRedactedCase` (transaction stays in coordinator or persist object) |
| **Why #1 (open)** | TD-2 prerequisite met (rollback specs exist). Debt cost: mixed responsibilities still block clean extraction. Change cost: **medium** — public `.call`/`Result` unchanged. Persist object is natural home for finding mapper (already in place). |
| **Blast radius** | Extraction-only: `process_case_submission.rb` + 1–2 new files + existing specs |
| **Incremental path** | (1) ~~G-01/G-02 rollback specs~~ **done** → (2) extract `redact_metadata` → (3) extract persist inside same transaction |
| **First prerequisite** | ~~Inner-loop rollback specs~~ **done** — can proceed to `redact_metadata` extract |

**Trade-off:** More files for a ~72-line class. Justified if TD-1 tests or new intake fields are planned soon; optional hygiene if MVP is stable.

---

### 2. TD-5 — CRLF normalization in `Engine` *(was #3)*

| Dimension | Assessment |
|-----------|------------|
| **Current → target** | `split(/\n/, -1)` on raw paste (trailing `\r` retained) → normalize `\r\n`/`\r` to `\n` before split (or per-line chomp) |
| **Why #2 (open)** | Real-world Windows paste still plausible. Debt cost unchanged. Change cost: **low** (2 files). |
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
| P0 | ~~TD-1 / G-01, G-02~~ | **DONE** (PR #14) |
| P0 | G-03 (`sources: nil`) | Companion to G-05 unit spec (TD-3) — **still open** |
| P1 | TD-4 / G-04 | Independent test slice |
| P1 | TD-3 | Companion to G-05; no refactor required |
| P2 | TD-6, ~~TD-8~~ | TD-8 partial (validation E2E done); TD-6 still open |
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

- `context/changes/case-submission-flow-analysis/research.md` — intake flow analysis (input evidence; **archive candidate**)
- `context/changes/intake-finding-persist-contract/plan.md` — TD-2 implementation (**done**, PR #14)
- `context/changes/e2e-test-verification/plan.md` — G-14/TD-8 validation E2E (**done**, PR #15)
- `context/changes/ci-cd-code-review/requirements.md` — AI PR review workflow (**done**, unrelated to intake ranking)
- `context/archive/2026-05-27-safe-multi-source-intake/plan.md` — S-02 original intake design
- `context/archive/2026-05-27-encrypted-diagnostic-schema/plan-brief.md` — F-02 encryption scope (TD-7)
- `context/archive/2026-05-27-load-demo-case/plan-brief.md` — S-06 demo reuse decision (TD-10)
- `context/foundation/prd.md` — guardrails and encryption NFR

## Claim verification (ast-grep)

Initial verification: ast-grep 0.43.0, commit `2ce9993`. **Re-run 2026-06-22** at `e96dc92` — delta rows marked **changed**. **Re-run 2026-06-24:** V-16 superseded (CRLF spec added); V-19 example count 13+ in `process_case_submission_spec.rb`.

| # | Claim | Jun-10 | **Jun-22** | Evidence |
|---|-------|--------|------------|----------|
| V-01 | Only runtime call-site `redaction_findings.create!` in `app/` | Confirmed | **Confirmed** | `process_case_submission.rb:46` |
| V-02 | No mapper/DTO/`Data.define` for findings | Confirmed | **Changed → mapper + VO exist** | `finding.rb:4`; `build_from_engine_finding` at `:8–18` |
| V-03 | Findings hash has 4 keys | Confirmed | **Changed → typed Finding, not hash** | `engine.rb:36–41` emits `Finding.new(...)` |
| V-04 | 2 runtime callers `ProcessCaseSubmission.call` | Confirmed | **Confirmed** | controller + `load_case.rb:23` |
| V-05 | 2 runtime call-sites `Redaction::Engine.redact` | Confirmed | **Confirmed** | `process_case_submission.rb:36`, `:63` |
| V-06 | Only `DebuggingCase.transaction` in `app/` | Confirmed | **Confirmed** | `process_case_submission.rb:27` |
| V-07 | 3× `create!` on 3 models | Confirmed | **Confirmed** | `:28`, `:38`, `:46` |
| V-08 | `redact_metadata` — 5 call-sites | Confirmed | **Confirmed** | `:29–32`, `:40` |
| V-09 | `ProcessCaseSubmission` ~72 lines | Confirmed | **Confirmed (74 lines)** | `wc -l` |
| V-17 | No `redaction_finding_spec.rb` | Confirmed | **Changed → file exists** | `spec/models/redaction_finding_spec.rb` |
| V-19 | `process_case_submission_spec.rb` — 12 examples | Confirmed | **Changed → 14 examples** | +G-01/G-02 |
| V-16 | Zero `\r`/CRLF examples in `spec/` | Confirmed | **Changed → CRLF spec in `engine_spec.rb` (Phase 7)** | `patterns_spec`, CRLF normalization |

**Ranking impact:** TD-2 done — IMPL-1 becomes top open refactor. V-02/V-03/V-17 supersede original "implicit contract" claims. TD-5 closed in Phase 7 (CRLF normalization). Remaining open candidates unchanged in shape (IMPL-1 monolith, G-05 passthrough).

*(Full Jun-10 table below — historical; rows V-02, V-03, V-17, V-19 superseded by re-run above.)*

| # | Claim | Verdict | Evidence | Method |
|---|-------|---------|----------|--------|
| V-01 | Only runtime call-site `redaction_findings.create!` in `app/` | **Confirmed** | `process_case_submission.rb:46` | `ast-grep -p 'log_source.redaction_findings.create!($ARG)' app/` → 1 match |
| V-02 | No mapper/DTO/`Data.define` for findings in redaction domain | **Confirmed** | No match in `app/services/redaction/`; grep `RedactionFinding.(new\|build\|from)` → 0 | `ast-grep -p 'Data.define($$$)' app/services/redaction/` → 0; `rg RedactionFinding\.(new\|build\|from) app/` → 0 |
| V-03 | Findings hash has 4 keys: `finding_type`, `line_number`, `placeholder`, `risk_level` | **Confirmed** | `engine.rb:36–41` | `ast-grep -p 'findings << { finding_type: $A, line_number: $B, placeholder: $C, risk_level: $D }' app/` |
| V-04 | 2 runtime callers `ProcessCaseSubmission.call` | **Confirmed** | `debugging_cases_controller.rb:30`, `load_case.rb:23` | `ast-grep -p 'Intake::ProcessCaseSubmission.call($$$)' app/` → 2 |
| V-05 | 2 runtime call-sites `Redaction::Engine.redact` in `app/` | **Confirmed** | `process_case_submission.rb:36`, `:61` | `ast-grep -p 'Redaction::Engine.redact($$$)' app/` → 2 |
| V-06 | Only `DebuggingCase.transaction` in `app/` | **Confirmed** | `process_case_submission.rb:27` | `ast-grep -p 'DebuggingCase.transaction' app/` → 1; `rg '\.transaction' app/` → 1 |
| V-07 | 3× `create!` on 3 models in `ProcessCaseSubmission` | **Confirmed** | `:28` (`DebuggingCase`), `:38` (`LogSource`), `:46` (`RedactionFinding`) | `rg '\.create!' process_case_submission.rb` → 3 |
| V-08 | `redact_metadata` — N call-sites in one class | **Refined → 5** | `:29`, `:30`, `:31`, `:32`, `:40` (report: 4) | `ast-grep -p 'redact_metadata($$$)' app/` → 5 |
| V-09 | `ProcessCaseSubmission` ~72 lines | **Confirmed** | 72 file lines | `wc -l process_case_submission.rb` |
| V-10 | 5 commits touching `process_case_submission.rb` | **Confirmed** | 5 commits in history | `git log --oneline -- process_case_submission.rb \| wc -l` → 5 |
| V-11 | Zero same-commit co-change proc ↔ demo | **Confirmed** | No shared commits | `git log` + `git show --name-only` per proc commit → no `load_case.rb` |
| V-12 | `load_case.rb` — 1 commit in history | **Confirmed** | `77b0291` | `git log --oneline -- load_case.rb \| wc -l` → 1 |
| V-13 | `encrypts` only `customer_reference` / `sanitized_content`; metadata plain | **Confirmed** | `debugging_case.rb:5`, `log_source.rb:6`; no `encrypts` on title/description/environment/name | `ast-grep -p 'encrypts $_' app/models/` → 4 rows (2 submission-path) |
| V-14 | `source.is_a?(Source)` branch in `normalize_sources` | **Confirmed** | `case_submission.rb:29` | `ast-grep -p 'source.is_a?(Source)' app/` → 1 |
| V-15 | Zero `Source.new` / `CaseSubmission::Source` in `spec/` | **Confirmed** | No match | `rg 'Source\.new\|CaseSubmission::Source' spec/` → 0 |
| V-16 | Zero `\r`/CRLF examples in `spec/` | **Confirmed (Jun-10 snapshot)** | No match at time of scan | `rg '\\r\|/\\\\r' spec/` → 0 |
| V-17 | No `spec/models/redaction_finding_spec.rb` | **Confirmed (Jun-10 snapshot)** | File did not exist | `glob redaction_finding_spec.rb` → 0 |
| V-18 | `split(/\n/, -1)` in `Engine#redact` | **Confirmed** | `engine.rb:15` | `ast-grep -p 'split($$$)' engine.rb` → 0 (regex literal); `rg 'split\(/\\\\n/, -1\)' engine.rb` → 1 |
| V-19 | `process_case_submission_spec.rb` — 12 examples | **Confirmed (Jun-10 snapshot)** | 12 `it` blocks | `rg '^\s+it ' process_case_submission_spec.rb` → 12 |
| V-20 | `debugging_cases_security_spec.rb` — 10 examples | **Confirmed** | 10 `it` blocks | `rg '^\s+it ' debugging_cases_security_spec.rb` → 10 |
| V-21 | 2 runtime callers `CaseSubmission.new` | **Confirmed** | `debugging_cases_controller.rb:29`, `load_case.rb:22` | `ast-grep -p 'Intake::CaseSubmission.new($$$)' app/` → 2 |

**Ranking impact:** No verdict undermines candidates #1–#3. V-08 (5 vs 4 `redact_metadata` call-sites) strengthens the argument for IMPL-1 (#2), not weakens it — planning decision: whether extraction covers all 5 calls with one helper.

---

## Open Questions (for planning, not exploration)

1. Should IMPL-1 (#1 open) proceed only if new intake fields are planned, or proactively now that rollback specs exist?
2. TD-5 (#2 open): normalize vs document — product preference on Windows paste fidelity?
3. Should G-05 branch removal be bundled with IMPL-1 or handled as test-only work (TD-3)?
4. Should residual G-15 / paste-on-error-422 gaps get a new E2E change or stay in refactor-opportunities test backlog?
