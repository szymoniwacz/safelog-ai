# Security Guardrail Cookbook — Plan Brief

> Full plan: `context/changes/testing-security-guardrail-cookbook/plan.md`
> Research: `context/changes/testing-security-guardrail-cookbook/research.md`

## What & Why

Phase 1 of the test rollout codifies security spec patterns and closes residual gaps for risks **#1** (raw never persist), **#2** (sanitized-only AI), and **#4** (metadata redaction). Request guardrails already exist; this change adds thin gap-fill examples, extracts a shared DB-scan helper, and ships the test-plan cookbook so future contributors know where and how to prove PRD guardrails.

## Starting Point

116 RSpec examples with strong request-layer coverage (`debugging_cases_security_spec`, `debugging_cases_analyze_security_spec`). Service specs prove log-paste secrets but not metadata-only paths. Duplicate inline DB-scan helpers; cookbook §6 reads "TBD."

## Desired End State

Shared persistence oracle in `spec/support/`, ~4–6 new examples covering metadata-only persist and prompt paths, cookbook §6.1/§6.3/§6.4/§6.5/§6.6 documented, full `bin/ci` green. No duplicate full flows or new encryption model tests.

## Key Decisions Made

| Decision | Choice | Why | Source |
|----------|--------|-----|--------|
| Helper extraction order | Extract before new examples | Single refactor commit; DRY oracle for cookbook | Research |
| `environment` redaction | Out of scope | Not in test plan risk #4 field list | Research |
| Encryption model specs | Document only (§6.4) | Risk #5 already covered | Research |
| Intake service title/description | Include one example | Non-HTTP cookbook reference for #1/#4 | Research / Plan |
| AnalyzeCase vs PromptBuilder | PromptBuilder only for metadata prompt gap | Cheapest layer; AnalyzeCase HTTP path already strong | Plan |
| Rewrite show-only POST in debugging_cases_spec | Document as anti-pattern, don't rewrite | Scope control; security spec is canonical | Plan |

## Scope

**In scope:** Shared helper; PromptBuilder metadata-only example; intake title/description persist example; analyze customer_reference-only request example; test-plan §6 cookbook; ~120–122 examples.

**Out of scope:** E2E, snapshots, view tests; authorization (#3); encryption new examples (#5); export/authorization duplication; environment metadata; exhaustive regex catalog.

## Architecture / Approach

Five phases ordered by cost × signal: (1) extract shared `assert_no_raw_substring_in_persisted_data`, (2) service prompt metadata gap, (3) service intake metadata persist, (4) request analyze isolation, (5) cookbook prose + §3 complete. All new examples use risk-derived oracles, not implementation mirrors.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Shared persistence oracle | `spec/support/security_persistence_helpers.rb` + wired specs | Helper naming `_spec.rb` double-load |
| 2. PromptBuilder metadata | Service proof metadata secrets stay out of AI prompts | Overlap with log-paste oracle |
| 3. Intake metadata persist | Service proof title/description redact on persist | Duplicating HTTP examples verbatim |
| 4. Analyze CR isolation | Request proof customer_reference-only in prompts | Fixture complexity |
| 5. Cookbook §6 | Documentation + Phase 1 complete in test plan | Accidentally editing §1–§2 strategy |

**Prerequisites:** Research complete; 116-example baseline green.

**Estimated effort:** One focused session (~5 small phases).

## Open Risks & Assumptions

- Example count stays modest; if helper extraction touches many files, keep diff minimal (two call sites only).
- Cookbook §6 edits are allowed documentation updates to `context/foundation/test-plan.md` per Phase 5 scope (not a strategy rewrite).

## Success Criteria (Summary)

- Shared DB-scan helper is the documented #1 oracle; show-only tests cited as anti-pattern.
- Metadata-only secrets proven absent from prompts (service + request) and from title/description persist (service).
- §6 cookbook filled; `bin/ci` green.
