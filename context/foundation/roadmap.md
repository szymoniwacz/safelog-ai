---
project: SafeLog AI
version: 1
status: active
created: 2026-05-25
updated: 2026-06-09
prd_version: 1
main_goal: speed
top_blocker: time
---

# Roadmap: SafeLog AI

> Derived from `context/foundation/prd.md` (v1) + auto-researched codebase baseline.
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Vision recap

When debugging production incidents, engineers paste multi-source logs into AI tools — exposing tokens, emails, IDs, and other sensitive values while correlating signals by hand. SafeLog AI’s distinguishing trait — the one that, if removed, makes it a generic “paste logs into ChatGPT” workflow — is that deterministic backend logic redacts and pseudonymizes evidence in memory before any AI runs; the model only ever sees sanitized, hypothesis-framed output.

## North star

**S-02: Safe multi-source intake** — user can submit a debugging case with metadata and multiple pasted sources, then see only sanitized logs and a redaction/security summary with consistent case-local placeholders.

> **North star** here means the smallest end-to-end flow that proves the core product hypothesis — that raw logs never persist and cross-source correlation survives redaction — placed as early as prerequisites allow. Analysis and export matter only after this wedge works.

## At a glance

| ID | Change ID | Outcome (user can …) | Prerequisites | PRD refs | Status |
|---|---|---|---|---|---|
| F-01 | minimal-auth-scaffold | (foundation) Devise email/password; routes gated; User model | — | Access Control, FR-001 | done |
| F-02 | encrypted-diagnostic-schema | (foundation) Domain schema + Active Record Encryption on diagnostic text | F-01 | NFR (encryption), FR-002 | done |
| F-03 | ai-adapter-test-harness | (foundation) Provider-agnostic AI adapter + fake client for tests/CI | F-02 | Success Criteria guardrails, FR-007 | done |
| S-01 | account-access | sign up and sign in with email and password | F-01 | FR-001, US-01 | done |
| S-02 | safe-multi-source-intake | submit a case with multiple pasted sources and view/copy sanitized logs plus redaction summary | F-01, F-02, S-01 | FR-002, FR-003, FR-004, FR-005, FR-006, US-01 | done |
| S-03 | analyze-hypothesis-report | run Analyze case and view a structured, hypothesis-framed AI debugging report | S-02, F-03 | FR-007, FR-008, US-01 | done |
| S-04 | report-markdown-export | copy and download the report as Markdown | S-03 | FR-009, US-01 | done |
| S-05 | archive-debugging-case | archive a case; default list hides it; Archived filter shows it | S-02 | FR-010 | done |
| S-06 | load-demo-case | load a pre-built demo case in development and test only | S-02 | FR-011 | done |

## Streams

Navigation aid — groups items that share a Prerequisites chain. Canonical ordering still lives in the dependency graph below; this table is the proposed reading order across parallel tracks.

| Stream | Theme | Chain | Note |
|---|---|---|---|
| A | Account & security wedge | `F-01` → `S-01` → `F-02` → `S-02` | North star; speed bias — must-have path first |
| B | Analysis & share | `F-03` → `S-03` → `S-04` | Joins Stream A at `S-02` |
| C | Case lifecycle | `S-05` | Parallel with Stream B after `S-02` |
| D | Demo polish | `S-06` | Parallel with Streams B/C after `S-02`; course demo |

## Baseline

What's in place as of **2026-06-09** (MVP feature slices F-01–S-06 implemented; Fly.io production deploy verified).

- **Frontend:** server-rendered Rails views (Hotwire, Propshaft, importmap); dashboard, case CRUD, analyze, export, archive UI
- **Backend:** Rails 8.1 services under `app/services/{redaction,intake,correlation,analysis,ai,demo}/`; authenticated case flows
- **Data:** SQLite domain schema with Active Record Encryption on diagnostic text; 135 RSpec examples
- **Auth:** Devise email/password; `AuthenticatedController` gates app routes
- **Deploy / infra:** Fly.io production at https://safelog-ai.fly.dev/; `Dockerfile`, `fly.toml` (fra, always-on, `HTTP_PORT=8080`); SQLite on volume `data`; manual deploy; CI in `.github/workflows/ci.yml`
- **Observability:** Rails default logging; `/up` health check (passing on Fly)

## Foundations

### F-01: Minimal auth scaffold

- **Outcome:** (foundation) Devise email/password sign-up and sign-in work; application routes require authentication where needed.
- **Change ID:** minimal-auth-scaffold
- **PRD refs:** Access Control, FR-001
- **Unlocks:** S-01, S-02, S-03, S-04, S-05, S-06 (all case flows require a signed-in user)
- **Prerequisites:** —
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Auth is absent in baseline but gates every user story; sequencing it first avoids rework on case ownership and authorization specs.
- **Status:** done

### F-02: Encrypted diagnostic schema

- **Outcome:** (foundation) Debugging-case domain tables exist; diagnostic text fields use Active Record Encryption at rest.
- **Change ID:** encrypted-diagnostic-schema
- **PRD refs:** NFR (stored diagnostic text encrypted), FR-002
- **Unlocks:** S-02 (north star), S-03, S-04, S-05, S-06
- **Prerequisites:** F-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Empty `db/schema.rb` blocks all persistence; doing schema + encryption before intake prevents migrating sensitive columns later under time pressure.
- **Status:** done

### F-03: AI adapter test harness

- **Outcome:** (foundation) Provider-agnostic AI adapter interface exists with a fake implementation used in tests and CI (no real provider calls).
- **Change ID:** ai-adapter-test-harness
- **PRD refs:** Success Criteria guardrails, FR-007
- **Unlocks:** S-03, security tests proving sanitized-only prompts
- **Prerequisites:** F-02
- **Parallel with:** S-05 (after S-02), S-06 (after S-02)
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Analyze case is on the critical path but untestable without a fake client; landing the harness before S-03 keeps the ~3-week schedule from stalling on CI/provider wiring.
- **Status:** done

## Slices

### S-01: Account access

- **Outcome:** user can sign up and sign in with email and password.
- **Change ID:** account-access
- **PRD refs:** FR-001, US-01
- **Prerequisites:** F-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Thin vertical proof that F-01 works in the browser before investing in the heavier intake slice.
- **Status:** done

### S-02: Safe multi-source intake

- **Outcome:** user can create a debugging case with title, description, customer_reference, and environment, submit multiple pasted log sources in one request, and view/copy sanitized logs plus a redaction/security summary (no raw content shown again).
- **Change ID:** safe-multi-source-intake
- **PRD refs:** FR-002, FR-003, FR-004, FR-005, FR-006, US-01
- **Prerequisites:** F-01, F-02, S-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** North star — proves the security wedge (in-memory redaction, no raw persistence) before AI spend; largest single slice under a time budget.
- **Status:** done

### S-03: Analyze hypothesis report

- **Outcome:** user can run Analyze case and view correlation signals plus a structured, hypothesis-framed AI debugging report from sanitized evidence only.
- **Change ID:** analyze-hypothesis-report
- **PRD refs:** FR-007, FR-008, US-01
- **Prerequisites:** S-02, F-03
- **Parallel with:** S-05, S-06
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Depends on sanitized evidence quality from S-02; synchronous session-only analysis per PRD NFR.
- **Status:** done

### S-04: Report Markdown export

- **Outcome:** user can copy and download the AI debugging report as Markdown (`.md`).
- **Change ID:** report-markdown-export
- **PRD refs:** FR-009, US-01
- **Prerequisites:** S-03
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Small follow-on once report structure exists; completes US-01 sharing path.
- **Status:** done

### S-05: Archive debugging case

- **Outcome:** user can archive a debugging case; archived cases are hidden from the default list and visible via an Archived filter.
- **Change ID:** archive-debugging-case
- **PRD refs:** FR-010
- **Prerequisites:** S-02
- **Parallel with:** S-03, S-06
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Independent of AI path — good parallel work after north star when time is tight.
- **Status:** done

### S-06: Load demo case

- **Outcome:** user can load a pre-built checkout/payment-timeout demo case in development and test environments only.
- **Change ID:** load-demo-case
- **PRD refs:** FR-011
- **Prerequisites:** S-02
- **Parallel with:** S-03, S-05
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Course demo and README walkthrough; sequenced after real intake so demo reuses production code paths.
- **Status:** done

## Backlog Handoff

MVP slices and first Fly.io deploy complete (2026-06-09). Next work is post-MVP (observability, Postgres scale, CI auto-deploy) — pick from Parked or open a new change via `/10x-new`.

## Open Roadmap Questions

_Resolved: MVP uses server-rendered Rails views per PRD Non-Goals (2026-05-28)._

## Parked

- **Real observability API integrations** — Why parked: PRD §Non-Goals; manual paste only in MVP.
- **Log management / incident-command platform scope** — Why parked: PRD §Non-Goals.
- **Raw log retention in any form** — Why parked: PRD §Non-Goals and guardrails.
- **Adding log sources after initial submission** — Why parked: PRD §Non-Goals; all sources in one request for MVP.
- **Background jobs for analysis** — Why parked: PRD §Non-Goals; synchronous Analyze only.
- **Multi-tenancy and role models** — Why parked: PRD §Non-Goals.
- **Container packaging as MVP gate** — Why parked: PRD §Non-Goals; Fly deploy completed 2026-06-09 without blocking feature work.
- **Separate rich client UI framework** — Why parked: PRD §Non-Goals for MVP (pending Open Roadmap Question above).
- **Production observability stack (Sentry, metrics, OTel)** — Why parked: speed bias + baseline partial logging sufficient for MVP; invest lightly in infra.

## Done

- **F-01: (foundation) Devise email/password sign-up and sign-in work; application routes require authentication where needed.** — Archived 2026-05-28 → `context/archive/2026-05-26-minimal-auth-scaffold/`. Lesson: —.
- **F-02: (foundation) Debugging-case domain tables exist; diagnostic text fields use Active Record Encryption at rest.** — Archived 2026-05-28 → `context/archive/2026-05-27-encrypted-diagnostic-schema/`. Lesson: —.
- **F-03: (foundation) Provider-agnostic AI adapter interface exists with a fake implementation used in tests and CI (no real provider calls).** — Archived 2026-05-28 → `context/archive/2026-05-27-ai-adapter-foundation/` (change id `ai-adapter-foundation`). Lesson: —.
- **S-01: user can sign up and sign in with email and password.** — Archived 2026-05-28 → `context/archive/2026-05-27-account-access/`. Lesson: —.
- **S-02: user can create a debugging case with title, description, customer_reference, and environment, submit multiple pasted log sources in one request, and view/copy sanitized logs plus a redaction/security summary (no raw content shown again).** — Archived 2026-05-28 → `context/archive/2026-05-27-safe-multi-source-intake/`. Lesson: —.
- **S-03: user can run Analyze case and view correlation signals plus a structured, hypothesis-framed AI debugging report from sanitized evidence only.** — Archived 2026-05-28 → `context/archive/2026-05-27-analyze-hypothesis-report/`. Lesson: —.
- **S-04: user can copy and download the AI debugging report as Markdown (`.md`).** — Archived 2026-05-28 → `context/archive/2026-05-27-report-markdown-export/`. Lesson: —.
- **S-05: user can archive a debugging case; archived cases are hidden from the default list and visible via an Archived filter.** — Archived 2026-05-28 → `context/archive/2026-05-27-archive-debugging-case/`. Lesson: —.
- **S-06: user can load a pre-built checkout/payment-timeout demo case in development and test environments only.** — Archived 2026-05-28 → `context/archive/2026-05-27-load-demo-case/`. Lesson: —.
