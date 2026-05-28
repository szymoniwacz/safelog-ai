<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: SafeLog AI MVP (F-01 → S-06)

- **Plan**: Cross-cutting review — `context/changes/{minimal-auth-scaffold,encrypted-diagnostic-schema,ai-adapter-foundation,account-access,safe-multi-source-intake,analyze-hypothesis-report,report-markdown-export,archive-debugging-case,load-demo-case}/plan.md`
- **Scope**: Full MVP — foundations F-01, F-02, F-03 and slices S-01 through S-06
- **Date**: 2026-05-27
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical · 3 warnings · 4 observations
- **CI**: `bin/ci` green — 94 examples, 0 failures

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

## What Looks Solid

- **Raw log intake path:** `Intake::ProcessCaseSubmission` redacts `pasted_content` in memory via case-local `PlaceholderRegistry`; persists only `sanitized_content` + finding metadata; no forbidden `raw_*` columns in schema.
- **AI boundary:** `Analysis::PromptBuilder` uses sanitized logs and redacted `customer_reference`; `Correlation::ExtractSignals` reads placeholders from sanitized content; `Ai::Request` blocks forbidden metadata keys. Security specs prove raw intake secrets do not reach fake client or correlation payload.
- **Authorization:** All case actions scope through `current_user.debugging_cases.find(...)` → 404 for cross-user access; covered across show, analyze, archive, export, index specs.
- **Encryption (F-02):** `encrypts` on diagnostic fields per accepted plan; plain `title`/`description`/`environment` intentional.
- **Scope discipline:** Minimal Devise modules; no background analyze, React/Vite, or upload integrations; demo loader dev/test only with production 404 specs.
- **Architecture:** Thin controllers; domain logic in `app/services/{redaction,intake,correlation,analysis,ai,demo}/`.
- **Parameter filtering:** `:pasted_content` filtered; failed intake does not repopulate pasted fields.

## Security Checklist

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Raw logs never persisted | PASS | Schema; intake + security specs |
| Raw logs not sent to AI | PASS | Analyze security specs; `PromptBuilder` |
| Raw logs filtered from param logging | PASS | `filter_parameter_logging.rb` |
| Placeholder registry in-memory only | PASS | `PlaceholderRegistry`; no persistence path |
| Per-user case isolation | PASS | Controller scoping + cross-user 404 specs |
| Encrypted diagnostic fields | PASS (impl) / gap (tests) | Models correct; F2 test gap |
| Demo dev/test only | PASS | `Demo::LoadCase.available?` + production 404 |
| Fake AI in CI/tests | PASS | `ClientResolver` → `FakeClient` in test |
| No out-of-scope features | PASS | No analyze jobs, no React, minimal Devise |
| Hypothesis-framed reports | PASS | `ResponseValidator`, `ReportSchema`, prompts |

## Findings

### F1 — Description metadata bypasses redaction pipeline

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — realistic operator mistake; small localized fix
- **Dimension**: Safety & Quality
- **Location**: `app/services/intake/process_case_submission.rb:30`, `app/services/analysis/prompt_builder.rb:41`
- **Detail**: Only `customer_reference` passes through `redact_metadata`. `description` (and `title`) are stored and sent to AI as plain text. Secrets pasted into description persist unencrypted and appear in analyze prompts — outside log-intake path but violates spirit of PRD NFR when metadata is misused.
- **Fix**: Run `description` (and optionally `title`) through the same shared-registry `redact_metadata` helper. Add one request spec with secret email in `description` asserting DB + analyze prompt contain `[EMAIL_1]` only.
- **Decision**: FIXED — redacted `description` via shared registry; added request spec in `debugging_cases_security_spec.rb`

### F2 — No test proves encryption-at-rest for diagnostic columns

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — one focused model/spec example
- **Dimension**: Success Criteria / Safety & Quality
- **Location**: `spec/models/` (missing)
- **Detail**: F-02 requires diagnostic text unreadable in SQLite without keys. Suite checks semantic absence of raw secrets but not that encrypted columns store ciphertext (raw SQL read does not contain known plaintext).
- **Fix**: Add one example per encrypted model reading column via `ActiveRecord::Base.connection.select_value` expecting ciphertext, not plaintext.
- **Decision**: FIXED — added `spec/models/encryption_at_rest_spec.rb` covering all encrypted diagnostic columns

### F3 — Authorization coverage is action-scattered, not end-to-end

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — add specs, no code change required
- **Dimension**: Safety & Quality
- **Location**: `spec/requests/debugging_cases_authorization_spec.rb`
- **Detail**: Cross-user 404 tested per feature file but `debugging_cases_authorization_spec.rb` only covers GET show. Regression in one mutating action could slip through if that file's specs are removed.
- **Fix**: Extend authorization spec with POST analyze, POST archive, GET download_report returning 404 for `other_user`.
- **Decision**: FIXED — consolidated cross-user 404 examples in `debugging_cases_authorization_spec.rb`

### F4 — AI request guard is metadata-only

- **Severity**: OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Safety & Quality
- **Location**: `app/services/ai/request.rb`
- **Detail**: `Ai::Request` validates metadata key names but not message content. Upstream services and tests enforce sanitization today; future `PromptBuilder` bug would not be caught at adapter boundary.
- **Fix (optional)**: Lightweight content scan in `Ai::Request` for obvious raw patterns, or document `PromptBuilder` as sole gate.
- **Decision**: FIXED — documented PromptBuilder as sole sanitization gate in `Ai::Request`, `PromptBuilder`, and guard spec

### F5 — Redaction heuristics are intentionally incomplete

- **Severity**: OBSERVATION
- **Impact**: 🔎 MEDIUM — accepted MVP tradeoff; document, don't rewrite
- **Dimension**: Safety & Quality
- **Location**: `app/services/redaction/patterns.rb`
- **Detail**: Regex-heuristic patterns may miss standalone secrets without `token=` / `Authorization:` prefixes. PRD acknowledges MVP detectors; main checkout-timeout patterns covered in tests.
- **Fix**: No engine rewrite. Optionally add pattern for bare `sk-…` API keys if course demos need it.
- **Decision**: FIXED — documented known heuristic gaps in `Redaction::Patterns` (no new regex)

### F6 — Production analyze falls back to FakeClient without API key

- **Severity**: OBSERVATION
- **Impact**: 🔎 MEDIUM — deploy/demo configuration, not a security bug
- **Dimension**: Plan Adherence
- **Location**: `app/services/ai/client_resolver.rb:6-9`
- **Detail**: Without `OPENAI_API_KEY`, production analyze succeeds with canned fake output. Safe for security but misleading for real AI demo.
- **Fix**: Set `OPENAI_API_KEY` in Fly secrets before public demo, or surface UI notice when fake client is active.
- **Decision**: PENDING

### F7 — Roadmap and deploy docs are stale

- **Severity**: OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Plan Adherence
- **Location**: `context/foundation/roadmap.md`, `context/deployment/deploy-plan.md`
- **Detail**: Roadmap marks F-01–S-06 as `proposed`; deploy plan describes empty-schema shell deploy. Does not affect runtime.
- **Fix**: Run `/10x-archive` per completed change; update roadmap Done section and deploy-plan scope.
- **Decision**: PENDING

## Recommended Fix Order

1. F1 — redact `description` through existing registry (~5 lines + 1 spec)
2. F2 — ciphertext-at-rest examples (~15 lines total)
3. F3 — consolidate auth specs (~20 lines)
4. F7 — documentation/archive housekeeping (no app rewrite)
