---
starter_id: rails
package_manager: bundle
project_name: safelog-ai
hints:
  language_family: ruby
  team_size: solo
  deployment_target: fly
  ci_provider: github-actions
  ci_default_flow: ci-only-manual-deploy
  bootstrapper_confidence: verified
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: false
  has_ai: true
  has_background_jobs: false
---

## Shipped stack (MVP)

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Ruby 3.4 | via mise locally; pinned in `Dockerfile` for Fly |
| Framework | Rails 8.1 | Server-rendered ERB views — **no React/Vite in MVP** |
| Database | SQLite | `storage/*.sqlite3`; Active Record Encryption on diagnostic text |
| Auth | Devise | `database_authenticatable`, `registerable`, `validatable` only |
| AI | Provider-agnostic adapter | `Ai::FakeClient` in test/CI; OpenAI optional via `OPENAI_API_KEY` |
| Tests | RSpec | 240 examples + SimpleCov 100% line/branch in `bin/ci`; 13 functional Playwright via `bin/e2e` |
| CI | GitHub Actions + `bin/ci` | Lint, security audits, RSpec — **no auto-deploy** (manual `fly deploy`) |
| Hosting | Fly.io + Docker | Deployed at https://safelog-ai.fly.dev/ (verified 2026-06-09; suspended when idle); SQLite on Fly volume |

PostgreSQL is a **future scale option only** — not used in the shipped MVP.

## Why this stack

SafeLog AI is a solo, after-hours web MVP with email/password auth, encrypted diagnostic storage, in-memory redaction, and hypothesis-framed AI reports. The standard `(web-app, ruby)` path applies: **Rails** with convention-heavy structure agents handle well.

**UI:** Server-rendered Rails views (ERB) for the full MVP flow — dashboard, case intake, analyze, export, archive. React/Vite was considered early in bootstrap notes but **not implemented**; service boundaries in `app/services/` keep a future UI swap possible without rewriting domain logic.

**Database:** **SQLite** for MVP — simpler local and Fly.io deploy, sufficient for course/demo scale, compatible with Active Record Encryption. Bootstrap initially scaffolded with `--database postgresql`; app config was switched to SQLite before feature work (see `config/database.yml`, `storage/`).

**Operations:** GitHub Actions runs CI gates on push/PR. Production deploy is **manual** `fly deploy` per `context/deployment/deploy-plan.md` — first deploy completed 2026-06-09; auto-deploy on merge not configured yet (Architect/Champion may extend).

Auth, AI, and encryption flags are set; background jobs, payments, realtime, and external log integrations stay out of scope per the PRD.

## Bootstrap history (informational)

- Starter: `rails new` (subdir-then-move merge); initial scaffold used PostgreSQL adapter — **shipped app uses SQLite**.
- Local toolchain: mise (Ruby + Node for Playwright MCP only); production image uses pinned Ruby in `Dockerfile` — no mise in Docker/Fly runtime.
- Node: dev tooling only (`package.json` for Playwright MCP); not part of the Rails UI.

## Alignment references

- Product guardrails: `context/foundation/prd.md`
- UI and domain shape: `context/foundation/shape-notes.md`
- Quality contract: `context/foundation/test-plan.md`
- Agent rules: `AGENTS.md`, `README.md`
