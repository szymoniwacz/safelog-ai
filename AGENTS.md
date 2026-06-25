# Repository Guidelines

SafeLog AI is a Rails 8.1 + SQLite app for safe multi-source log debugging (MVP database; PostgreSQL optional later for scale): redact in memory, store sanitized evidence only, then produce hypothesis-framed AI reports. Local toolchains use mise (`@.mise.toml`); Fly.io production uses `@Dockerfile` with pinned Ruby — never mise in Docker or Fly runtime.

## Hard rules for agents

- Never persist, log, send, or expose raw log text after intake.
- Never add columns such as `raw_content`, `original_content`, `encrypted_raw_content`, or equivalents.
- Raw input may exist only transiently during the current request/process.
- Raw-to-placeholder mappings must stay in memory only and must never be persisted, logged, hashed, or fingerprinted.
- Persist only sanitized content, redaction metadata, correlation signals, and validated AI reports.
- AI receives sanitized evidence only. Never send raw logs, raw identifiers, prompt content with raw values, or raw-to-placeholder mappings to AI.
- AI reports must be hypothesis-framed, not definitive conclusions.
- Tests must use a fake AI client. CI must never call real AI providers.
- Encrypt diagnostic text fields at rest using Rails Active Record Encryption (SQLite is the MVP store).
- Devise should use only `database_authenticatable`, `registerable`, and `validatable` unless explicitly changed.
- Do not scaffold React/Vite, background jobs, uploads, or external log integrations unless explicitly requested.
- Never overwrite `context/` documents. Treat them as project source of truth.
- Filter sensitive params (`@config/initializers/filter_parameter_logging.rb`).
- Run local commands via `mise exec --`. Production builds use Docker/Fly only.
- Full product guardrails: @context/foundation/prd.md

## Commands

`mise install` once, then:

- `mise exec -- bundle config set --local path vendor/bundle` && `mise exec -- bundle install` — gems into `vendor/bundle` only (see `.bundle/config`; never `gem install` outside Bundler)
- `mise exec -- bin/setup` — bundle path + deps + `db:prepare` (+ dev server unless `--skip-server`)
- `mise exec -- bin/dev` — Puma (port 3000)
- `mise exec -- bin/ci` — RuboCop, bundler-audit, importmap audit, Brakeman (`@config/ci.rb`, `@.github/workflows/ci.yml`)
- `mise exec -- bin/rubocop` / `bin/brakeman` / `bin/bundler-audit` — individual gates
- `mise exec -- bundle exec rspec spec/` — full RSpec suite (280 examples; `bin/ci` runs this gate)
- Partial `rspec` runs (single files or subdirs) skip the SimpleCov 100% threshold; full suite and CI enforce it.
- `mise exec -- bundle exec rspec spec/system` — Capybara user-flow specs (10 examples, rack_test driver)
- `mise exec -- bin/e2e` — Playwright Chromium E2E (`e2e/`; 19 functional + 4 capture = 23 total); optional local gate, not in `bin/ci` or GHA
- `mise exec -- bin/e2e e2e/accessibility.spec.ts` — optional axe WCAG A/AA spot-check (serious/critical violations) for dashboard, new-case form, cases index, and edit form

**Browser testing:** `bin/ci` and GitHub Actions run RSpec only — including Capybara system specs (`spec/system`, rack_test driver) for user-visible flows. Playwright is an optional local gate with real Chromium; it is intentionally absent from CI to avoid Chromium install latency. Run `mise exec -- bin/e2e` before Demo Day or after UI changes; run `e2e/accessibility.spec.ts` after UI changes that affect forms or layout.

RSpec lives under `spec/` with request, service, and model coverage. Run `mise exec -- bin/ci` before pushing — it runs RuboCop, security audits, and the full test suite. Gate parity (local vs GitHub Actions) is documented in `@context/foundation/test-plan.md` §6.7. New tests must prove raw logs never persist and never reach AI stubs.

## Style and commits

Ruby/Node versions: `@.mise.toml`; `@.rubocop.yml` omakase (CI-enforced). Keep app/controllers/ to HTTP only (params, session, render); put redaction, correlation, and AI in app/services/<domain>/ per `@context/foundation/shape-notes.md`. Commits: short imperative subjects (see `git log`). PRs: security note when touching log intake, encryption, or AI; `bin/ci` green.

<!-- BEGIN @szymoniwacz/ai-toolkit -->
Team agent rules for Rails projects using mise and conventional CI gates.

For review conventions, use the `code-review` skill installed at `.cursor/skills/code-review/`.

## Hard rules for agents

- Never persist, log, send, or expose raw sensitive intake data after sanitization or redaction.
- Never add columns such as `raw_content`, `original_content`, `encrypted_raw_content`, or equivalents for holding pre-redaction payloads.
- Raw input may exist only transiently during the current request or process.
- Raw-to-placeholder mappings must stay in memory only and must never be persisted, logged, hashed, or fingerprinted.
- Persist only sanitized content, redaction metadata, correlation signals, and validated AI reports.
- AI receives sanitized evidence only. Never send raw logs, raw identifiers, prompt content with raw values, or raw-to-placeholder mappings to AI.
- AI reports must be hypothesis-framed, not definitive conclusions.
- Tests must use a fake or stubbed AI client. CI must never call real AI providers.
- Encrypt sensitive diagnostic text fields at rest using Rails Active Record Encryption when the product handles such data.
- Devise should use only `database_authenticatable`, `registerable`, and `validatable` unless explicitly changed.
- Do not scaffold React/Vite, background jobs, uploads, or external log integrations unless explicitly requested.
- Never overwrite `context/` documents. Treat them as project source of truth.
- Filter sensitive params (`config/initializers/filter_parameter_logging.rb`).
- Run local commands via `mise exec --`. Production builds use Docker or the project's deployment runtime — never mise in container production images.
- Follow project guardrails in `context/foundation/prd.md` when present.

Commands, CI gates, and commit style: follow your project's existing `AGENTS.md` or run `mise exec -- bin/ci` before pushing.
<!-- END @szymoniwacz/ai-toolkit -->
