# Encrypted Diagnostic Schema (F-02) Implementation Plan

## Overview

Land roadmap **F-02**: the full MVP debugging-case domain schema (cases, log sources, redaction findings, correlation signals, AI reports) with **Active Record Encryption** on PRD-defined diagnostic text only. Models, migrations, and encryption wiring only — no controllers, views, intake, redaction engine, or AI adapter. This unblocks **S-02** (`safe-multi-source-intake`), **F-03**, and later analysis/archive slices without ever adding forbidden raw-content columns.

## Current State Analysis

- **Schema:** `users` only (`db/schema.rb:13-20`); F-01 auth is in place.
- **Domain:** No `DebuggingCase`, `LogSource`, or related models under `app/models/`.
- **Encryption:** No `config.active_record.encryption` wiring; `config/credentials.yml.enc` exists but encryption keys not generated yet.
- **Controllers:** `AuthenticatedController` documents F-02 inheritance contract (`app/controllers/authenticated_controller.rb:1-6`); no case routes.
- **Tests:** No `spec/` tree; RSpec deferred (same as F-01) — verification is `bin/ci` + manual console/schema checks.
- **Deploy:** `context/deployment/deploy-plan.md` documents `bin/rails db:encryption:init` and Fly secret names for production keys.

### Key Discoveries:

- PRD NFR requires encrypted diagnostic text: `customer_reference`, sanitized logs, correlation payloads, AI report bodies — **not** title, environment, or description (`context/foundation/prd.md` guardrails).
- AGENTS.md forbids `raw_content`, `original_content`, `encrypted_raw_content`, or equivalents — schema review must grep for these patterns.
- Shape notes list source types: `rails_log`, `aws_cloudwatch`, `new_relic`, `browser_console`, `customer_report`, `other` (`context/foundation/prd.md` journey step 3).
- FR-007 / acceptance criteria imply `AiReport` needs a **status** lifecycle (`failed` after invalid AI response).
- F-01 handoff: domain controllers inherit `AuthenticatedController` later; F-02 does not add routes.

## Desired End State

After this plan:

1. Five domain tables exist with correct foreign keys and `dependent: :destroy` from `DebuggingCase`.
2. Encrypted columns use non-deterministic AR Encryption; plaintext diagnostic fields are unreadable in SQLite without keys.
3. Plain metadata columns (`title`, `description`, `environment`, finding metadata, enums) stay unencrypted per planning decision.
4. No forbidden raw/original columns anywhere in `db/schema.rb` or models.
5. `bin/ci` passes; manual console proves encrypt/decrypt round-trip on at least one model per encrypted table family.

### Verification

- Automated: migrations apply; `bin/ci` green; runner loads all models and associations.
- Manual: `rails console` create/destroy tree; inspect DB bytes for ciphertext on encrypted columns; confirm grep guardrails.

## What We're NOT Doing

- Controllers, routes, views, or Stimulus/React UI for cases.
- In-memory redaction, intake services, correlation extraction, or AI adapter (S-02, F-03, S-03).
- RSpec or security specs (S-01 / later slices).
- Authorization scopes (`user` ownership enforced in controllers/specs later — only `belongs_to :user` on case here).
- Archive list/filter behavior (S-05) — only `archived_at` column now.
- Deterministic encryption or DB lookup on ciphertext.
- Demo case seed data (FR-011 / later slice).

## Implementation Approach

Configure AR Encryption once (credentials in dev/test; credentials + documented Fly env in production). Add **one migration per table** in dependency order: `debugging_cases` → `log_sources` → `redaction_findings` → `correlation_signals` → `ai_reports`. Each migration creates only the columns needed for that table; models declare `encrypts` on diagnostic fields immediately. Use Rails `enum` for `LogSource#source_type` and `AiReport#status`. Cascade deletes from `DebuggingCase` via `has_many ..., dependent: :destroy`.

## Critical Implementation Details

**Encryption before first encrypted row:** Run `mise exec -- bin/rails db:encryption:init` and wire keys in `config/application.rb` (or environment-specific config) **before** creating records in Phase 2+. Without keys, encrypted attributes raise at runtime.

**Column type for encrypted text:** Migrations declare plain `:text` columns for `customer_reference`, `sanitized_content`, `payload`, `structured_json`, and `markdown_body`; models add `encrypts` so ciphertext is stored in those same columns (in-place). Do not add manual `*_ciphertext` columns in this change.

**Forbidden columns:** Migrations and models must never introduce `raw_content`, `original_content`, `encrypted_raw_content`, `raw_*`, or mapping tables for raw-to-placeholder values.

## Phase 1: Active Record Encryption Setup

### Overview

Generate encryption keys, configure the app to read them from credentials (with production override via env per deploy doc), and prove the stack boots with encryption enabled.

### Changes Required:

#### 1. Encryption keys

**Files:** `config/credentials.yml.enc` (via editor after init), optionally `config/credentials/development.yml.enc` if project splits env credentials

**Intent:** Run `db:encryption:init` (prints a credentials YAML snippet to stdout), copy the `active_record_encryption` block into credentials via `mise exec -- bin/rails credentials:edit`, and save. Deterministic key is required by Rails even though no attributes use deterministic encryption.

**Contract:** `db:encryption:init` prints keys; after `credentials:edit`, encrypted credentials contain `primary_key`, `deterministic_key`, and `key_derivation_salt` (never paste keys into chat/logs).

#### 2. Application encryption config

**File:** `config/application.rb` (or `config/initializers/active_record_encryption.rb` if generator creates one)

**Intent:** Point `config.active_record.encryption.*` at credentials in development/test. In production, rely on Fly-injected `RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and `RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (Rails reads these ENV vars when set — document the mapping in a short comment in `config/environments/production.rb` or the encryption initializer).

**Contract:** App boots in development; production config comment names the three Fly secret env vars from `context/deployment/deploy-plan.md`; no hardcoded secrets in source. Optional local check: `RAILS_ENV=production mise exec -- bin/rails runner 'puts ActiveRecord::Encryption.config.primary_key.present?'` when env vars are exported.

#### 3. Documentation touchpoint

**File:** `context/changes/encrypted-diagnostic-schema/change.md` (Notes section only)

**Intent:** Note that Fly production must set the three encryption env vars when this change deploys; link mentally to deploy-plan — no edits to `context/deployment/` required in F-02 unless implementer finds deploy-plan stale.

**Contract:** Notes mention Fly secrets alignment; no overwrite of `context/` foundation files.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bin/rails db:encryption:init` prints snippet; credentials edited and saved with `active_record_encryption` keys
- `mise exec -- bin/rails runner 'puts ActiveRecord::Encryption.config.primary_key.present?'` (or equivalent config check)
- `mise exec -- bin/ci`

#### Manual Verification:

- After `credentials:edit`, developer confirms `active_record_encryption` keys exist (without pasting keys into chat/logs)

**Implementation Note**: Pause for human confirmation after automated checks before Phase 2.

---

## Phase 2: DebuggingCase

### Overview

Create the root domain table owned by `User`, with plain metadata, encrypted `customer_reference`, and `archived_at` for later S-05.

### Changes Required:

#### 1. Migration

**File:** `db/migrate/*_create_debugging_cases.rb`

**Intent:** Table `debugging_cases` with `user_id` (null: false, indexed), `title` (string, null: false), `description` (text), `customer_reference` (text — encrypted at model layer), `environment` (string), `archived_at` (datetime, null: true), timestamps.

**Contract:** No raw/original columns; `user_id` references `users`; migration is standalone file.

#### 2. Model

**Files:** `app/models/debugging_case.rb`, `app/models/user.rb`

**Intent:** `DebuggingCase` `belongs_to :user`; `encrypts :customer_reference`; `has_many` children with `dependent: :destroy` (stubs for associations added as models land). `User` `has_many :debugging_cases`.

**Contract:** `encrypts :customer_reference` only; title/description/environment are plain Active Record attributes.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bin/rails db:migrate`
- `mise exec -- bin/rails runner 'DebuggingCase.reflect_on_all_associations(:has_many).map(&:name)'` includes expected children after later phases (re-run at end) or at minimum `User.reflect_on_association(:debugging_cases)`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: create `DebuggingCase` for a `User` with `customer_reference` set; reload shows decrypted value in Ruby; raw SQL shows non-plaintext for that column

**Implementation Note**: Pause for human confirmation before Phase 3.

---

## Phase 3: LogSource

### Overview

Persist sanitized log text per source on a case; `source_type` as Rails enum matching PRD types.

### Changes Required:

#### 1. Migration

**File:** `db/migrate/*_create_log_sources.rb`

**Intent:** `log_sources` with `debugging_case_id` (null: false, indexed), `source_type` (string, null: false), optional `name` (string), `sanitized_content` (text), `position` (integer, default 0 — stable ordering for multi-source UI later), timestamps.

**Contract:** Only sanitized content column for log body — no `raw_*` fields.

#### 2. Model

**File:** `app/models/log_source.rb`

**Intent:** `belongs_to :debugging_case`; `encrypts :sanitized_content`; `enum :source_type` with values `rails_log`, `aws_cloudwatch`, `new_relic`, `browser_console`, `customer_report`, `other`.

**Contract:** Enum keys match PRD; encrypted field is `sanitized_content` only.

**Update:** `DebuggingCase` `has_many :log_sources, dependent: :destroy`.

### Success Criteria:

#### Automated Verification:

- Migration applies
- `mise exec -- bin/rails runner 'LogSource.source_types.keys.sort'` matches PRD set
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: attach `LogSource` to case with multiline `sanitized_content`; ciphertext visible in DB

**Implementation Note**: Pause for human confirmation before Phase 4.

---

## Phase 4: RedactionFinding

### Overview

Store redaction metadata per log source without ever persisting original sensitive values.

### Changes Required:

#### 1. Migration

**File:** `db/migrate/*_create_redaction_findings.rb`

**Intent:** `redaction_findings` with `log_source_id` (null: false, indexed), `finding_type` (string, null: false), `line_number` (integer, null: false), `placeholder` (string, null: false), `risk_level` (string, null: false), timestamps.

**Contract:** Columns are exactly finding metadata — no `original_*` or `raw_*` columns.

#### 2. Model

**File:** `app/models/redaction_finding.rb`

**Intent:** `belongs_to :log_source`; validations for presence on metadata fields; no `encrypts` (placeholders are already pseudonymized).

**Contract:** `LogSource` `has_many :redaction_findings, dependent: :destroy`.

### Success Criteria:

#### Automated Verification:

- Migration applies
- `mise exec -- bin/rails runner 'RedactionFinding.new.respond_to?(:placeholder)'`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: create finding linked to a log source; no encrypted columns on this table

**Implementation Note**: Pause for human confirmation before Phase 5.

---

## Phase 5: CorrelationSignal

### Overview

One row per signal with an encrypted JSON payload column (serialized JSON string, not a separate ciphertext table).

### Changes Required:

#### 1. Migration

**File:** `db/migrate/*_create_correlation_signals.rb`

**Intent:** `correlation_signals` with `debugging_case_id` (null: false, indexed), `payload` (text), timestamps.

**Contract:** Single encrypted diagnostic column `payload`; no parallel plaintext JSON column.

#### 2. Model

**File:** `app/models/correlation_signal.rb`

**Intent:** `belongs_to :debugging_case`; `encrypts :payload`; optional convenience for JSON serialize/deserialize in later slices (not required in F-02 beyond storing string).

**Contract:** `DebuggingCase` `has_many :correlation_signals, dependent: :destroy`.

### Success Criteria:

#### Automated Verification:

- Migration applies
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: save JSON string to `payload`; DB shows encrypted blob

**Implementation Note**: Pause for human confirmation before Phase 6.

---

## Phase 6: AiReport

### Overview

AI report storage with status enum and two encrypted text columns for structured JSON and Markdown body.

### Changes Required:

#### 1. Migration

**File:** `db/migrate/*_create_ai_reports.rb`

**Intent:** `ai_reports` with `debugging_case_id` (null: false, indexed), `status` (string, null: false, default `"pending"`), `structured_json` (text), `markdown_body` (text), timestamps.

**Contract:** No separate raw AI prompt columns; status defaults to pending.

#### 2. Model

**File:** `app/models/ai_report.rb`

**Intent:** `belongs_to :debugging_case`; `encrypts :structured_json, :markdown_body`; `enum :status` with `pending`, `processing`, `generated`, `failed` (align FR-007 failure path).

**Contract:** `DebuggingCase` `has_many :ai_reports, dependent: :destroy` (or `has_one` if product expects single report — use `has_many` for retry/history flexibility unless PRD mandates one; **default `has_many`** for failed retry rows).

### Success Criteria:

#### Automated Verification:

- Migration applies
- `mise exec -- bin/rails runner 'AiReport.statuses.keys'` includes `pending`, `processing`, `generated`, `failed`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: set both encrypted fields; verify decryption on reload

**Implementation Note**: Pause for human confirmation before Phase 7.

---

## Phase 7: Verify & Handoff

### Overview

Prove schema integrity, guardrails, cascade deletes, and document handoff for S-02 implementers.

### Changes Required:

#### 1. Schema guardrail check

**Intent:** Script or one-off grep proving `db/schema.rb` and `app/models/` contain none of the forbidden identifiers: `raw_content`, `original_content`, `encrypted_raw_content`, and column names prefixed `original_` (redaction originals).

**Contract:** Zero forbidden identifiers in schema and models (use explicit patterns — not a broad `raw_` substring grep).

#### 2. Association cascade smoke

**Intent:** Runner destroys a `DebuggingCase` and asserts child counts go to zero for all four child tables.

**Contract:** `dependent: :destroy` works tree-wide.

#### 3. Handoff notes

**Files:** `context/changes/encrypted-diagnostic-schema/change.md` (Notes), optional one-line comment on `DebuggingCase` if useful

**Intent:** State S-02 owns intake/redaction services; F-03 owns AI adapter; controllers must inherit `AuthenticatedController`.

**Contract:** Notes list next slices; no case routes added in F-02.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bin/rails db:migrate:status` all up
- `mise exec -- bin/rails runner` cascade destroy script (document inline in plan progress step)
- Forbidden-column grep clean
- `mise exec -- bin/ci`

#### Manual Verification:

- Review `db/schema.rb` — five new tables, encryption columns present, no forbidden names
- Confirm encryption keys documented for Fly deploy

**Implementation Note**: Final phase — epilogue after all manual steps confirmed per implement skill.

---

## Testing Strategy

### Unit Tests:

- Deferred to **S-01** / security slices per planning decision.

### Integration Tests:

- None in F-02.

### Manual Testing Steps:

1. Create user → case → two log sources with findings → signal → ai report.
2. `destroy` case; verify children removed.
3. SQLite CLI or `rails dbconsole` — encrypted columns not equal to plaintext.
4. Grep guardrails for forbidden column names.

## Performance Considerations

- SQLite + AR Encryption is acceptable for MVP case volume; no extra indexes beyond foreign keys in F-02.
- Large pasted logs will live in `log_sources.sanitized_content` (text); size limits enforced in S-02 intake, not F-02.

## Migration Notes

- Greenfield DB: linear migrations only.
- Referential integrity: `belongs_to` + indexes in F-02; DB-level `add_foreign_key` optional on SQLite (AR-only integrity acceptable for MVP if omitted).
- If encryption keys rotate later, follow Rails encryption key rotation guides — out of F-02 scope.
- Production: set Fly secrets before first encrypted write in production.

## References

- Roadmap F-02: `context/foundation/roadmap.md`
- PRD guardrails & FR-002: `context/foundation/prd.md`
- Deploy encryption secrets: `context/deployment/deploy-plan.md`
- F-01 gating contract: `app/controllers/authenticated_controller.rb`
- Change identity: `context/changes/encrypted-diagnostic-schema/change.md`
- Prior plan pattern: `context/changes/minimal-auth-scaffold/plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Active Record Encryption Setup

#### Automated

- [x] 1.1 Init prints keys; pasted into credentials via `credentials:edit` — 898131b
- [x] 1.2 App boots with encryption config: `mise exec -- bin/rails runner` config check — 898131b
- [x] 1.3 CI passes: `mise exec -- bin/ci` — 898131b

#### Manual

- [x] 1.4 Credentials contain `active_record_encryption` keys after edit (not logged) — 898131b

### Phase 2: DebuggingCase

#### Automated

- [x] 2.1 Migration applies: `mise exec -- bin/rails db:migrate`
- [x] 2.2 User ↔ DebuggingCase association loads in runner (full child tree in Phase 7)
- [x] 2.3 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 2.4 Console encrypt/decrypt round-trip on `customer_reference`

### Phase 3: LogSource

#### Automated

- [x] 3.1 Log sources migration applies
- [x] 3.2 `LogSource.source_types` matches PRD set in runner
- [x] 3.3 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 3.4 Console: `sanitized_content` ciphertext in DB

### Phase 4: RedactionFinding

#### Automated

- [x] 4.1 Redaction findings migration applies
- [x] 4.2 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 4.3 Console: finding row has no encrypted columns

### Phase 5: CorrelationSignal

#### Automated

- [x] 5.1 Correlation signals migration applies
- [x] 5.2 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 5.3 Console: `payload` ciphertext in DB

### Phase 6: AiReport

#### Automated

- [x] 6.1 AI reports migration applies
- [x] 6.2 `AiReport.statuses` includes pending, processing, generated, failed
- [x] 6.3 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 6.4 Console: both encrypted report fields round-trip

### Phase 7: Verify & Handoff

#### Automated

- [x] 7.1 All migrations up: `db:migrate:status`
- [x] 7.2 Cascade destroy runner succeeds
- [x] 7.3 Forbidden raw-column grep clean
- [x] 7.4 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 7.5 Schema review: five tables, no forbidden columns
- [ ] 7.6 Fly encryption secrets noted for deploy
