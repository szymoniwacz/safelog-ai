<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Encrypted Diagnostic Schema (F-02)

- **Plan**: `context/changes/encrypted-diagnostic-schema/plan.md`
- **Mode**: Deep
- **Date**: 2026-05-25
- **Verdict**: SOUND (after triage fixes)
- **Findings**: 0 critical, 4 warnings, 3 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS |
| Lean Execution | WARNING |
| Architectural Fitness | PASS |
| Blind Spots | WARNING |
| Plan Completeness | WARNING |

## Grounding

Grounding: 6/6 paths ✓, 3/3 symbols ✓ (no AR encryption in app yet — expected), brief↔plan ✓, Progress↔Phase 7/7 phases ✓, 26/26 success criteria mapped ✓

## Findings

### F1 — `db:encryption:init` does not write credentials

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Plan Completeness
- **Location**: Phase 1 — Encryption keys; Progress 1.1
- **Detail**: Plan and Progress 1.1 imply keys are "generated via" `db:encryption:init`. Rails 8.1 task only **prints** a YAML snippet to stdout (`activerecord` `databases.rake` `encryption:init`). Keys land in `config/credentials.yml.enc` only after a manual `credentials:edit` paste. Without that step, 1.2 (`primary_key.present?`) fails.
- **Fix A ⭐ Recommended**: Reword Phase 1 + Progress 1.1/1.4: run `db:encryption:init` → copy snippet → `credentials:edit` → save; add automated check only after edit.
  - Strength: Matches actual Rails behavior; prevents false "done" on init alone.
  - Tradeoff: One extra manual sub-step in Phase 1.
  - Confidence: HIGH — verified in vendored `activerecord-8.1.3` rake task.
  - Blind spot: None significant.
- **Fix B**: Add a custom rake task that writes keys into credentials programmatically.
  - Strength: Fully automates 1.1.
  - Tradeoff: Non-standard; touches credentials API; more code to maintain.
  - Confidence: MEDIUM — not used elsewhere in repo.
  - Blind spot: CI headless credentials edit may need master key.
- **Decision**: FIXED via Fix A

### F2 — Contradictory AR Encryption column guidance

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Critical Implementation Details — Column type for encrypted text
- **Detail**: Same paragraph says ciphertext lives in the migration column **and** "do not add separate `*_ciphertext` columns manually unless Rails generator does so." Default `encrypts` uses the existing column (`EncryptedAttributeType`); extra columns appear only with `ignore_case:`. Wording invites implementer to second-guess migrations.
- **Fix**: Replace with one sentence: "Migrations declare plain `:text`/`:string` columns; `encrypts` in the model encrypts in-place — no manual `*_ciphertext` columns for this plan."
- **Decision**: FIXED

### F3 — Production encryption config underspecified

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Blind Spots
- **Location**: Phase 1 — Application encryption config
- **Detail**: Contract requires ENV overrides for Fly (`RAILS_ACTIVE_RECORD_ENCRYPTION_*` per deploy-plan) but no file names `production.rb` vs initializer, and no success criterion that production loads keys from ENV. Rails can auto-read ENV when set, but implementer may only wire credentials and break first encrypted production deploy.
- **Fix A ⭐ Recommended**: Add Phase 1 contract bullet: "Document in `config/environments/production.rb` comment or encryption initializer that Fly secrets map to Rails encryption ENV vars; verify with `RAILS_ENV=production bin/rails runner` config check when secrets present."
  - Strength: Closes deploy gap called out in change.md Notes.
  - Tradeoff: Slightly expands Phase 1 scope.
  - Confidence: HIGH — deploy-plan already lists env var names.
  - Blind spot: Whether Fly injects vars without explicit `application.rb` wiring (Rails 8 often does).
- **Fix B**: Defer production wiring to deploy change only.
  - Strength: Keeps F-02 dev-focused.
  - Tradeoff: First production migration with encrypted rows risks misconfiguration.
  - Confidence: MEDIUM.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A

### F4 — `log_sources.position` not a recorded planning decision

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Lean Execution
- **Location**: Phase 3 — LogSource migration
- **Detail**: `position` integer added for "stable ordering" but absent from plan-brief Key Decisions and PRD schema language. Harmless for S-02, but unreviewed scope.
- **Fix A ⭐ Recommended**: Add one line to plan-brief decisions table ("source ordering → `position` integer, default 0") OR remove column and order by `created_at` until S-02 needs explicit order.
  - Strength: A documents intent; B minimizes schema.
  - Tradeoff: A is one doc line; B may require S-02 migration if UI needs reorder.
  - Confidence: HIGH for documenting; MEDIUM for removal.
  - Blind spot: S-02 multi-source display order requirements.
- **Fix B**: Keep column; add brief decision row only (no schema change).
  - Strength: Zero implementation churn.
  - Tradeoff: Column remains undocumented in decision log.
  - Confidence: HIGH.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A

### F5 — Phase 7 forbidden-column grep may be over-broad

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 7 — Schema guardrail check
- **Detail**: Grep pattern `raw_` matches substrings (e.g. future `draw_*` unlikely; `straw_*` unlikely). Low risk today; explicit forbidden list is clearer.
- **Fix**: Use fixed patterns: `raw_content`, `original_content`, `encrypted_raw_content`, `original_` prefix on columns — not bare `raw_`.
- **Decision**: FIXED

### F6 — No explicit `foreign_key` on associations

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architectural Fitness
- **Location**: Phases 2–6 migrations
- **Detail**: Plan indexes FK columns but does not require `add_foreign_key`. SQLite MVP often skips DB-level FKs; orphans possible if rows inserted outside AR.
- **Fix**: Optional `add_foreign_key` in migrations (SQLite 3.6.19+ supported) — or accept AR-only integrity and note in Migration Notes.
- **Decision**: FIXED

### F7 — Phase 2.2 association check is intentionally weak mid-plan

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 2 Success Criteria; Progress 2.2
- **Detail**: Runner step allows checking only `User.reflect_on_association(:debugging_cases)` before child models exist. Plan text acknowledges re-run at end; Progress 2.2 title does not say "minimum until Phase 6."
- **Fix**: Rename Progress 2.2 to "User ↔ DebuggingCase association loads in runner (child associations verified in Phase 7)".
- **Decision**: FIXED
