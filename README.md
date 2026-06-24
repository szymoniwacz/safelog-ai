# SafeLog AI

Rails 8.1 app for safe multi-source log debugging. Paste logs from several sources into a **debugging case**, redact sensitive values in memory, store **sanitized evidence only**, correlate signals across sources, and generate a **hypothesis-framed** AI report.

**MVP database:** SQLite (simpler local and Fly.io deploy). Diagnostic text fields are encrypted at rest with Rails Active Record Encryption.

Further product and agent context: `AGENTS.md`, `context/foundation/`. Certification progress (Builder / Architect / Champion): `context/certification/certification-readiness.md`. Architect two-pager: `context/certification/architecture-report.md`.

## Security principles

- **No raw log persistence** — pasted log text exists only transiently during the current request/process. The database stores sanitized content and redaction metadata, never raw input.
- **In-memory redaction** — raw-to-placeholder mappings stay in memory only and are never persisted, logged, or sent to AI.
- **Sanitized evidence to AI** — the AI adapter receives redacted log text and correlation signals only.
- **Hypothesis-framed reports** — AI output is structured as hypotheses, not definitive root-cause conclusions.
- **Encryption at rest** — `customer_reference`, `sanitized_content`, correlation payloads, and AI report bodies use Active Record Encryption.

## Getting started

Use [mise](https://mise.jdx.dev/) for Ruby and Node (see `.mise.toml`). Gems install **only** into `vendor/bundle` via Bundler — do not use system-wide `gem install`.

```bash
mise install
mise exec -- bundle config set --local path vendor/bundle
mise exec -- bundle install
mise exec -- bin/setup --skip-server   # db:prepare + deps check
mise exec -- bin/dev                   # http://localhost:3000
```

### First-time credentials / encryption setup

`config/master.key` is gitignored and required locally to decrypt `config/credentials.yml.enc`.

**Course / project clone:** obtain `config/master.key` from the project owner, or — if you are starting a fresh independent clone — generate your own credentials and encryption keys (do not reuse production keys).

**Active Record Encryption** keys must be present in Rails credentials (`active_record_encryption` block) or in `RAILS_ACTIVE_RECORD_ENCRYPTION_*` environment variables. Generate a credentials snippet with:

```bash
mise exec -- bin/rails db:encryption:init
```

Then merge into credentials via `mise exec -- bin/rails credentials:edit`.

CI supplies `RAILS_MASTER_KEY` (GitHub secret) and CI-only `RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and `RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` — see `.github/workflows/ci.yml`.

For local vs production behavior, see `config/initializers/active_record_encryption.rb` and `context/deployment/deploy-plan.md`.

Register or sign in (Devise). All case flows require authentication.

## Demo flow

1. Open the dashboard at `/`.
2. **Load demo case** (development and test by default; optional on production via `SAFELOG_ENABLE_DEMO_LOADER`) — one-click checkout/payment-timeout fixture with three sources (Rails, CloudWatch, browser console). Same intake pipeline as manual submission; raw fixture values are redacted before persistence.
3. Or choose **New debugging case** and paste multiple log sources manually.
4. On the case page, review sanitized sources, redaction findings, and correlation signals.
5. Click **Analyze case** to run correlation extraction and AI analysis.
6. Copy or **download** the Markdown report when analysis succeeds.
7. **Archive** cases you no longer need; view archived cases from the index filter.

The demo loader is off in production by default (`POST /debugging_cases/load_demo` returns 404). Certification reviewers can enable it on Fly with `fly secrets set SAFELOG_ENABLE_DEMO_LOADER=true --app safelog-ai`. See `context/certification/certification-readiness.md` § **Public demo vs local load_demo** for reviewer guidance on https://safelog-ai.fly.dev/.

## AI client

| Environment | `OPENAI_API_KEY` | Client |
|-------------|------------------|--------|
| `test` | any | `Ai::FakeClient` (always; CI never calls real providers) |
| `development` / `production` | unset | `Ai::FakeClient` (deterministic canned report) |
| `development` / `production` | set | `Ai::OpenAiClient` (OpenAI Chat Completions) |

When the fake client is active outside test, the dashboard and case page show a short **demo AI** notice. Analyze still runs end-to-end but returns deterministic sample hypotheses — not live OpenAI output.

**Fly reviewers:** https://safelog-ai.fly.dev/ ships without `OPENAI_API_KEY` by design. Sign in, create a case, click **Analyze case**, and expect the notice plus canned report text. That is the intended certification demo; set `OPENAI_API_KEY` in Fly secrets only when you want real provider output (`fly secrets set OPENAI_API_KEY="..." --app safelog-ai`).

Copy `.env.example` to `.env` at the repo root. In **development** and **test**, `dotenv-rails` loads `.env` on boot. Restart the server after changing keys.

```bash
mise exec -- bin/dev                   # http://localhost:3000
```

You can still export manually if you prefer:

```bash
set -a && source .env && set +a
mise exec -- bin/dev
```

## Code review agent (M5L2 + M5L3)

TypeScript agent in `packages/code-reviewer/` — local CLI (M5L2) and GitHub Actions on pull requests (M5L3).

### Local review

Environment load order:

1. repo root `.env` (fallback — same `OPENAI_API_KEY` as SafeLog analyze)
2. `packages/code-reviewer/.env` (optional; overrides only keys defined there)

See `packages/code-reviewer/.env.example`. No package-local `.env` is required when root `.env` is set.

```bash
cd packages/code-reviewer && npm install
git diff | npm run review
```

### CI review (M5L3)

Workflow: `.github/workflows/ai-code-review.yml` — runs on every PR to `main` and when label `ai-cr:review` is added.

| Secret | Required |
|--------|----------|
| `OPENAI_API_KEY` | yes |
| `CODE_REVIEWER_MODEL` | no (defaults to `OPENAI_MODEL` / `gpt-4o-mini`) |

Create labels once in the repo: `ai-cr:passed` (green), `ai-cr:failed` (red), `ai-cr:review` (manual re-run trigger).

Fork PRs are skipped (no secrets on untrusted code). Reviews are **advisory** — labels only, no merge gate in v1.

Requirements: `context/changes/ci-cd-code-review/requirements.md`.

## Production (Fly.io)

**URL:** https://safelog-ai.fly.dev/

Manual deploy via `fly deploy --app safelog-ai` (see `context/deployment/deploy-plan.md`). SQLite persists on a Fly volume at `/rails/storage`. Health check: `GET /up` (200).

**Public demo (reviewers):** sign up or sign in, then use **New debugging case** and paste multiple log sources manually. **Load demo case** is off on Fly by default; set `SAFELOG_ENABLE_DEMO_LOADER=true` as a Fly secret to show the one-click fixture for certification review. After case creation, redaction, analyze, export, and archive behave the same as locally. Full comparison: `context/certification/certification-readiness.md` § Public demo vs local `load_demo`.

## Quality gates

### Test layers

| Layer | Command | Covers |
|-------|---------|--------|
| **RSpec (full)** | `mise exec -- bundle exec rspec spec/` | 240 examples — services, request specs, models, system; 100% line + branch coverage in full suite / CI |
| **Capybara system** | `mise exec -- bundle exec rspec spec/system` | 9 examples — server-rendered user flows via rack_test (in `bin/ci`) |
| **Playwright E2E** | `mise exec -- bin/e2e` | 15 functional + 4 opt-in capture specs in real Chromium; optional before release — not in `bin/ci` |
| **Playwright a11y** | `mise exec -- bin/e2e e2e/accessibility.spec.ts` | axe WCAG A/AA spot-check (serious/critical) on dashboard and new-case form; optional |

Partial `rspec` runs (single file or subdirectory) skip the SimpleCov minimum threshold; `bin/ci` and CI enforce 100% line + branch coverage on the full suite.

Playwright boots a **test** Rails server (`bin/e2e-server`) with the same CI encryption env vars as GitHub Actions.

Run individual gates:

```bash
mise exec -- bundle exec rspec spec/
mise exec -- bundle exec rspec spec/system   # Capybara user-flow specs
mise exec -- bin/e2e                        # Playwright browser E2E (installs Chromium on first run)
mise exec -- bin/rubocop
mise exec -- bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
mise exec -- bin/bundler-audit
mise exec -- bin/importmap audit
```

Or run the full CI script (setup, RuboCop, bundler-audit, importmap audit, Brakeman, RSpec):

```bash
mise exec -- bin/ci
```

Tests use a fake AI client and assert that raw log values never persist or reach AI prompts.

**Dependency audit:** `Gemfile` pins transitive gems with known CVEs (`faraday`, `concurrent-ruby`); `bin/bundler-audit` runs in `bin/ci`.

## MVP limitations

- **Paste only** — no file uploads or external log integrations (CloudWatch, New Relic, etc.).
- **Create-time intake** — log sources are submitted with the case; no adding sources after create.
- **Synchronous analyze** — no background jobs; analysis runs in the request.
- **SQLite** — single-node MVP store; PostgreSQL is a future scale option.
- **Archive only** — cases can be archived but not unarchived (conscious post-MVP scope; see `context/foundation/roadmap.md` Parked and `test-plan.md` §7).
- **Server-rendered UI** — no React/Vite front end.

## Architecture (brief)

HTTP stays thin in `app/controllers/`. Domain logic lives in `app/services/`:

| Namespace | Role |
|-----------|------|
| `Redaction::` | In-memory redaction engine and placeholder registry |
| `Intake::` | Case submission validation and persistence pipeline |
| `Correlation::` | Cross-source signal extraction from sanitized content |
| `Analysis::` | Prompt building, AI orchestration, report parsing |
| `Ai::` | Client contract, fake/OpenAI adapters, response validation |
| `Demo::` | Environment-gated demo fixture loader |

Models: `DebuggingCase`, `LogSource`, `RedactionFinding`, `CorrelationSignal`, `AiReport`, `User`.
