---
archived_from: context/changes/case-submission-flow-analysis/research.md
archived_date: 2026-06-24
original_git_commit: ac9793d4f33f588f2fdaae5fe81c7817cfe4ba1c
note: |
  Archived research for submission/package; original file moved from
  `context/changes/case-submission-flow-analysis/research.md` into this path.
  See repo history for prior versions.
---

# Research (ARCHIVE): Case submission flow analysis

This file is an archive copy of the research document moved into `10x-archive`.

<!-- BEGIN ARCHIVED CONTENT -->

---
date: 2026-06-10T12:00:00+0200
researcher: Composer
git_commit: ac9793d4f33f588f2fdaae5fe81c7817cfe4ba1c
branch: main
repository: safelog-ai
topic: "Case submission flow — POST create → Intake → Redaction → persist"
tags: [research, codebase, intake, redaction, debugging-cases, security-oracles, repo-map]
status: complete
last_updated: 2026-06-24
last_updated_by: Composer (English translation; Phase 7 gap refresh)
ast_grep_version: 0.43.0
---

# Research: Case submission flow analysis

**Date**: 2026-06-10
**Researcher**: Composer (3 sub-agents: e2e trace, test gaps, blast radius)
**Git Commit**: `ac9793d4f33f588f2fdaae5fe81c7817cfe4ba1c`
**Branch**: main
**Repository**: safelog-ai
**Territory map**: [`context/map/repo-map.md`](../../map/repo-map.md)

> **Phase 7 update (2026-06-24):** Documented test gaps G-01–G-04, G-06–G-15 and related TD items were closed in Phase 7 (228 → 240 RSpec examples): transaction rollback specs (`persist_redacted_case_spec.rb`), `sources: nil` and multi invalid types (`case_submission_spec.rb`), mass-assignment request spec, CRLF normalization in `Engine`, standalone `sk-` regression (`patterns_spec.rb`), position/multi-pattern/nil-empty engine coverage, plaintext metadata baseline (`encryption_at_rest_spec.rb`), E2E validation + single-source paths. **Still open:** G-05 (Source struct passthrough), TD-9 (filter_parameter_logging checklist), TD-10 (demo coupling). TD-2 partially addressed via `RedactionFinding.build_from_engine_finding`.

## Research Question

How does the debugging case creation flow work from `POST /debugging_cases` through `Intake::ProcessCaseSubmission` and `Redaction::Engine` to SQLite persistence? What are the transaction boundaries, security guardrails, test coverage, and change blast radius — in the context of risk zones from repo-map?

**Scope:** intake + persist only. **Out of scope:** `Analysis::AnalyzeCase`, AI, correlation.

## Summary

The flow is a thin HTTP slice (`DebuggingCasesController#create`) delegating to a single domain orchestrator (`Intake::ProcessCaseSubmission`), which is the **only runtime caller** of `Redaction::Engine`. Raw `pasted_content` exists only in process memory for the duration of the request; only sanitized fields reach the DB (`sanitized_content`, post-redaction metadata, `redaction_findings` without raw values). A shared `PlaceholderRegistry` deduplicates placeholders across metadata and all sources.

Security oracles (`spec/requests/debugging_cases_security_spec.rb`) are strong for the main path. At research time (2026-06-10), the largest gaps were missing transaction rollback tests for `log_sources.create!` / `redaction_findings.create!` failures in the loop, unverified `sources: nil` handling, and no strong-params (mass assignment) test. **Most of these were closed in Phase 7 (2026-06-24)** — see note above.

Blast radius: **31 files** across runtime + tests (excluding 3 migrations); in git history `process_case_submission.rb` has 5 commits — **3** of them also touch `debugging_cases_security_spec.rb` in the same commit.

---

## AST-grep verification (m4l3-2)

Structural claims from the report verified (ast-grep 0.43.0, `-l ruby`, scope `app/` / `spec/` unless noted).

| # | Claim | Verdict | Evidence |
|---|-------------|---------|-------|
| V-01 | `Redaction::Engine.redact` — only runtime caller is `ProcessCaseSubmission` | **Confirmed** (`app/`) | `process_case_submission.rb:36`, `:61` — only 2 call sites in `app/` |
| V-02 | `ProcessCaseSubmission.call` — 2 runtime callers | **Confirmed** | `debugging_cases_controller.rb:30`, `demo/load_case.rb:23` |
| V-03 | `CaseSubmission.new` — 2 runtime callers | **Confirmed** | `debugging_cases_controller.rb:29`, `demo/load_case.rb:22` |
| V-04 | `PlaceholderRegistry.new` — prod path only `process_case_submission.rb:23` | **Refined** | Explicit prod: `:23`. Also `engine.rb:5` — default arg `registry: PlaceholderRegistry.new` (used when `redact` called without registry; in submission registry is always passed). Spec: `engine_spec.rb:61`, `:71` |
| V-05 | `DebuggingCase.transaction` — one block in application | **Confirmed** | `process_case_submission.rb:27–49` |
| V-06 | `redaction_findings.create!(finding)` — one call site | **Confirmed** | `process_case_submission.rb:46` |
| V-07 | `redact_metadata` — 4× case metadata + 1× per source in loop | **Confirmed** | `:29–32` (4×), `:40` (1× in loop; N× per source) |
| V-08 | `Patterns::ALL` — 9 MVP patterns | **Confirmed** | `patterns.rb:11–66` — 9 hashes in `ALL` array |
| V-09 | `Patterns::ALL` used only in `Engine` | **Confirmed** | `engine.rb:28` — only reference in `app/` |
| V-10 | No `raw_content` / `pasted_content` / `original_content` columns in schema | **Confirmed** | `db/schema.rb` — no matches |
| V-11 | `encrypts` on submission path — `customer_reference`, `sanitized_content` | **Confirmed** | `debugging_case.rb:5`, `log_source.rb:6` |
| V-12 | `process_case_submission_spec.rb` — 12 examples | **Confirmed** (at research time; **13** post–Phase 7) | 12 `it` blocks at research commit |
| V-13 | `debugging_cases_security_spec.rb` — 9 POST→show contexts | **Refuted → 10** | 10 `it` blocks; all use POST create, some also test analyze prompts |
| V-14 | `assert_no_raw_substring_in_persisted_data` — 10+ uses on submission path | **Refined → 15** | 6× `debugging_cases_security_spec.rb` + 9× `process_case_submission_spec.rb` (outside submission scope: 2× `analyze_security_spec.rb`) |
| V-15 | `SOURCE_SLOT_COUNT = 3` | **Confirmed** | `debugging_cases_helper.rb:4`; used in `new.html.erb:42` |
| V-16 | Blast radius ~27 files | **Refined → 31** | List in § Blast radius (excluding 3 migrations) |
| V-17 | Git co-change proc ↔ security spec: 8 commits | **Refuted → 3** | `process_case_submission.rb` has 5 commits in history; 3 commits touch both files in one diff |
| V-18 | Git co-change proc ↔ service spec: 7 commits | **Refuted → 3** | Same as V-17 |
| V-19 | `e2e/helpers.ts` fan-in 4 | **Confirmed** (import) | 4 specs import `./helpers`: `authentication`, `debugging-case-flow`, `capture-submission-screenshots`, `demo-case` |
| V-20 | `fillLogSourceSlot` fan-in 4 | **Refuted → 2** | Used only in `debugging-case-flow.spec.ts`, `capture-submission-screenshots.spec.ts` (+ definition in `helpers.ts`) |
| V-21 | `Engine.redact` in specs via `described_class.redact` | **Refined** | 6 calls in `engine_spec.rb:13,49,62,63,73,77` — do not match pattern `Redaction::Engine.redact` |

---

## Feature overview

### Product goal

The user pastes logs in the form (`new.html.erb`), submits `POST /debugging_cases`. The backend redacts in memory, persists only sanitized evidence and metadata, then redirects to `show`. Raw logs **never** reach the DB, HTML (after validation error), Rails logs, or AI.

### HTTP input

| Element | Location | Description |
|---------|-------------|------|
| Route | `config/routes.rb:13` | `resources :debugging_cases, only: [:index, :new, :create, :show]` |
| Auth | `app/controllers/authenticated_controller.rb:5` | `before_action :authenticate_user!` — guest gets 302 → sign_in |
| Strong params | `debugging_cases_controller.rb:91–99` | `title`, `description`, `customer_reference`, `environment`, `sources: [source_type, name, pasted_content]` |
| Filter params | `config/initializers/filter_parameter_logging.rb:6–12` | All intake fields filtered in logs |

<!-- Truncated for brevity in archive -->

<!-- END ARCHIVED CONTENT -->
