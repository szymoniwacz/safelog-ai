# Environment Metadata Redaction — Plan Brief

> Full plan: `context/changes/testing-environment-metadata-redaction/plan.md`
> Research: `context/changes/testing-environment-metadata-redaction/research.md`

## What & Why

Phase 1 of the test rollout deferred `environment` metadata redaction because risk #4 listed only title, description, and customer_reference. `environment` is the last metadata field that bypasses `redact_metadata` at intake — secrets pasted there persist plain, appear on show/index, and reach AI prompts unchanged. This slice closes that gap with a one-line intake fix and gap-fill security specs mirroring existing per-field patterns.

## Starting Point

`Intake::ProcessCaseSubmission` redacts title, description, and customer_reference via a shared `PlaceholderRegistry` but passes `environment` through raw (`process_case_submission.rb:31`). Per-field metadata redaction tests exist for the other three fields; the DB-scan helper already scans `environment` but no spec injects secrets into that column. Baseline: **122 RSpec examples**, all green.

## Desired End State

`environment` redacts at intake like other metadata fields. Service and request specs prove environment-only secrets never persist raw, never appear in show responses, and never reach analyze prompts. Test-plan risk #4 includes `environment`; Phase 1 deferral note removed. Suite at **126 examples**, `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|------------------|--------|
| Implementation scope | Fix intake + tests | Test-only would leave production gap; single redaction boundary at intake | Research |
| Risk #4 expansion | Include `environment` | Parity with F1 metadata-misuse rationale and title redaction fix | Research / Plan |
| HTTP show assertion | Add to security request spec | Low cost; matches title block (persist + show + analyze) | Research / Plan |
| Cross-field registry test | Omit | customer_reference example already covers shared-placeholder pattern | Research / Plan |
| Example count target | 122 → 126 (+4) | One service persist, one prompt, one analyze request, one security show | Plan |

## Scope

**In scope:** One-line `redact_metadata` for environment in `ProcessCaseSubmission`; four new spec examples; surgical test-plan §2/§6.3/§6.6 updates; AGENTS.md example count if cited.

**Out of scope:** Encryption of environment; helper/controller/view changes; shared-registry cross-field test; duplicating existing metadata blocks or full POST security flows.

## Architecture / Approach

All metadata sanitization happens once at intake via the shared `PlaceholderRegistry`. Wiring `environment` through `redact_metadata` automatically fixes persist, show UI, and `PromptBuilder` AI prompts — no downstream changes needed. Tests follow the established per-field isolation pattern: `SecureRandom` secret only in target field, clean log paste, field + DB-scan + prompt oracles.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Intake fix + service proofs | `redact_metadata` for environment; intake + prompt_builder specs | Forgetting intake fix leaves tests green only after revert check |
| 2. Request proofs + test-plan | HTTP security/analyze blocks; risk #4 doc update | Over-editing test-plan beyond surgical field-list changes |

**Prerequisites:** Phase 1 test rollout complete (122-example baseline); research artifact on disk.
**Estimated effort:** ~1 session, 2 phases.

## Open Risks & Assumptions

- Assumes environment should follow same redaction path as title/description (consistent with F1 spirit; not explicitly named in PRD guardrails).
- Blank/optional environment behavior unchanged — `redact_metadata` early-return on blank is sufficient.
- No migration or backfill needed — existing cases with plain environment values are acceptable (no raw secrets in production data assumed).

## Success Criteria (Summary)

- Secrets in `environment` redact to placeholders on persist and never reach AI prompts or show responses.
- New specs fail if intake fix is reverted.
- Test-plan risk #4 and §6.3 document environment alongside other metadata fields.
- `bin/ci` green at 126 examples.
