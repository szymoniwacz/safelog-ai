# Safe Multi-Source Intake (S-02) — Plan Brief

> Full plan: `context/changes/safe-multi-source-intake/plan.md`

## What & Why

Roadmap **S-02** is the product north star: a signed-in user submits a debugging case with metadata and **multiple pasted log sources in one request**; the app redacts sensitive values **in memory**, persists **sanitized evidence + redaction findings only**, and never shows raw content again. This proves the security wedge before S-03 AI analysis.

## Starting Point

F-02 schema + models exist (`DebuggingCase`, `LogSource`, `RedactionFinding` with encryption on diagnostic fields). F-03 RSpec harness and S-01 auth request specs exist. **No** `app/services/` intake/redaction code, **no** case routes/controllers/views. Dashboard placeholder mentions cases coming soon.

## Desired End State

User can `GET /debugging_cases/new`, submit title/description/customer_reference/environment plus ≥1 source (type, optional name, pasted raw text), and land on case detail showing sanitized logs (copyable), redaction summary by type/risk, and consistent cross-source placeholders (e.g. `[REQUEST_1]`). Raw substrings absent from DB, show page, and test assertions. User A cannot open user B's case (request spec). `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Service layout | `app/services/redaction/` + `app/services/intake/` | Matches AGENTS.md domain services | Plan |
| Raw handling | Transient `pasted_content` param → service only | Never touch ActiveRecord with raw fields | Plan |
| Placeholder map | In-memory registry per submission | AGENTS.md forbids persisting raw-to-placeholder maps | Plan |
| Correlation | Same normalized value → same placeholder within one submit | PRD cross-source correlation | Plan |
| HTTP layer | `DebuggingCasesController` `< AuthenticatedController` | F-01/S-01 gating pattern | Plan |
| Authorization | `current_user.debugging_cases.find(id)` | Flat per-user ownership (PRD) | Plan |
| UI | Server-rendered ERB (no React) | PRD MVP non-goals | Plan |
| Nested sources | Dynamic fields in form (Stimulus optional) or fixed max slots | MVP: start with indexed fields `log_sources[0][pasted_content]` — no upload | Plan |
| AI / analyze | Out of scope | S-03 | Plan |
| Demo case FR-011 | Out of scope | S-06 | Plan |

## Scope

**In scope:** Redaction engine (PRD pattern set), intake orchestrator, case new/create/show, sanitized display + copy, redaction summary, param filtering for pasted content, security + authorization request specs.

**Out of scope:** Analyze case, AI, correlation signal extraction (S-03), archive filter (S-05), demo loader (S-06), file upload, adding sources after create, background jobs.

## Architecture / Approach

```
POST /debugging_cases
  → DebuggingCasesController#create
  → Intake::ProcessCaseSubmission (transaction)
       → Redaction::Engine per source (in-memory registry shared)
       → persist DebuggingCase + LogSources + RedactionFindings
  → redirect show (sanitized only)

Redaction::Engine: raw string in → { sanitized_text, findings[] } out
PlaceholderRegistry: discarded after request (not persisted)
```

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Redaction engine | Patterns, placeholders, unit specs | Over/under-redaction; persisting registry by mistake |
| 2. Intake service | Persist sanitized tree in one transaction | Raw leaked via logging or AR assign |
| 3. Controller + routes | new/create/show + ownership scope | Strong params logging raw paste |
| 4. Case UI | Form + detail + copy + summary | Accidentally rendering raw on validation error |
| 5. Security specs | No raw in DB/response; cross-user deny | Flaky string assertions |

**Prerequisites:** F-01, F-02, S-01, F-03 (RSpec). **Estimated effort:** ~3–4 sessions across 5 phases.

## Open Risks & Assumptions

- Regex redaction is MVP-heuristic, not exhaustive DLP — document in service comments.
- Validation re-render on failure must not echo submitted pasted content (re-show empty paste fields).
- `customer_reference` is encrypted diagnostic text — redact if pasted patterns appear there too on intake.

## Success Criteria (Summary)

- End-to-end: create case with 2+ sources → detail shows placeholders, not raw secrets.
- Security specs pass; cross-user request denied.
- `bin/ci` green.
