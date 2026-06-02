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
- `mise exec -- bundle exec rspec spec/` — full RSpec suite (127 examples; `bin/ci` runs this gate)

RSpec lives under `spec/` with request, service, and model coverage. Run `mise exec -- bin/ci` before pushing — it runs RuboCop, security audits, and the full test suite. Gate parity (local vs GitHub Actions) is documented in `@context/foundation/test-plan.md` §6.7. New tests must prove raw logs never persist and never reach AI stubs.

## Style and commits

Ruby/Node versions: `@.mise.toml`; `@.rubocop.yml` omakase (CI-enforced). Keep app/controllers/ to HTTP only (params, session, render); put redaction, correlation, and AI in app/services/<domain>/ per `@context/foundation/shape-notes.md`. Commits: short imperative subjects (see `git log`). PRs: security note when touching log intake, encryption, or AI; `bin/ci` green.
