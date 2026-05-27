# Encrypted Diagnostic Schema (F-02) — Plan Brief

> Full plan: `context/changes/encrypted-diagnostic-schema/plan.md`

## What & Why

Roadmap **F-02** adds the MVP persistence layer for debugging cases: cases, log sources, redaction findings, correlation signals, and AI reports. Diagnostic text must be unreadable at rest (Active Record Encryption) before **S-02** can safely store sanitized evidence. This change is schema and models only — no intake UI or redaction pipeline.

## Starting Point

Rails 8.1 with **`users`** table and Devise auth (F-01). No domain models, no AR Encryption config, no forbidden-column guardrails in schema yet. `AuthenticatedController` exists for future case routes.

## Desired End State

Five related tables exist with correct associations and `dependent: :destroy` from `DebuggingCase`. Encrypted fields (`customer_reference`, `sanitized_content`, correlation `payload`, `structured_json`, `markdown_body`) round-trip through AR Encryption; metadata (`title`, `description`, `environment`, finding fields) stays plain. `bin/ci` passes; implementers can build S-02 services on these models without adding `raw_*` columns.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ------------------ | ------ |
| Schema scope | Full MVP domain (5 tables) | Unblocks S-02, F-03, S-03+ without another schema pass | Plan |
| Encrypted fields | PRD-strict diagnostic text only | Matches NFR; title/env/description stay queryable plain text | Plan |
| Key storage | Rails credentials + Fly env | Dev parity; production aligns with deploy-plan | Plan |
| Tests | Defer RSpec | No suite yet; same speed bias as F-01 | Plan |
| `description` | Plain `text` | Not listed as diagnostic ciphertext in PRD | Plan |
| `archived_at` | On case now | Column ready; archive UX in S-05 | Plan |
| AiReport bodies | `structured_json` + `markdown_body` encrypted | Matches PRD JSON + Markdown outputs | Plan |
| `source_type` | Rails `enum` on `LogSource` | PRD-fixed source type set | Plan |
| UI / HTTP | None in F-02 | Foundation slice — services/controllers later | Plan |
| RedactionFinding | Metadata only, no originals | FR-004 — never persist original sensitive values | Plan |
| CorrelationSignal | Encrypted `payload` per row | Diagnostic correlation JSON at rest | Plan |
| Migrations | One migration per table | Easier review and rollback | Plan |
| Source ordering | `log_sources.position` (integer, default 0) | Stable multi-source display order for S-02 | Plan review |
| AiReport status | `pending` / `completed` / `failed` | FR-007 invalid-response path | Plan |
| Deletes | `dependent: :destroy` from case | Clean tree when case removed | Plan |
| Deterministic encryption | None | No DB lookup on ciphertext in MVP | Plan |

## Scope

**In scope:** `db:encryption:init`, encryption config, five migrations, five models, `User has_many :debugging_cases`, encrypt declarations, enums, handoff notes, manual encryption smoke, `bin/ci`.

**Out of scope:** Controllers/routes/views, redaction/intake/AI services, RSpec, authorization specs, demo seed, archive filtering behavior, deterministic encryption.

## Architecture / Approach

```
User ──< DebuggingCase ──< LogSource ──< RedactionFinding
              ├──< CorrelationSignal (encrypts payload)
              └──< AiReport (encrypts structured_json, markdown_body)

DebuggingCase encrypts customer_reference
LogSource encrypts sanitized_content
```

Configure encryption once, then add tables in FK order with `encrypts` on each diagnostic column. Verify with console + grep for forbidden `raw_*` / `original_*` names.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. AR Encryption setup | Keys + app config + CI | Missing keys break all encrypted writes |
| 2. DebuggingCase | Root table + `customer_reference` encrypt | Accidental plain-text sensitive column |
| 3. LogSource | Sanitized log storage + source enum | Introducing `raw_content` by mistake |
| 4. RedactionFinding | Finding metadata without originals | Storing original values in schema |
| 5. CorrelationSignal | Encrypted JSON payload | Plaintext payload column left alongside |
| 6. AiReport | Status enum + two encrypted bodies | Wrong status values for FR-007 |
| 7. Verify & handoff | Cascade, guardrails, docs | Skipping DB ciphertext check |

**Prerequisites:** F-01 complete (`users`, Devise). **Estimated effort:** ~2–3 focused sessions across 7 phases.

## Open Risks & Assumptions

- **No automated encryption tests until later slices** — rely on manual console and schema review.
- **Fly secrets** must be set before production writes encrypted data.
- **`has_many :ai_reports`** assumed for retry/history; S-03 may constrain to one active report in app logic.
- Assumes SQLite text columns are sufficient for MVP log size; intake slice may add length validation.

## Success Criteria (Summary)

- All five domain tables migrate cleanly with correct FKs and destroy cascade.
- Encrypted diagnostic fields are ciphertext in SQLite; forbidden column names absent.
- `bin/ci` green; S-02 can add intake services without schema rework.
