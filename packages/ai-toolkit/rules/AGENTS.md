Team agent rules for Rails projects using mise and conventional CI gates.

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

## Commands

Run `mise install` once, then:

- `mise exec -- bundle config set --local path vendor/bundle` && `mise exec -- bundle install` — gems into `vendor/bundle` only (see `.bundle/config`; never `gem install` outside Bundler)
- `mise exec -- bin/setup` — bundle path + deps + `db:prepare` (+ dev server unless `--skip-server`)
- `mise exec -- bin/dev` — Puma (port 3000)
- `mise exec -- bin/ci` — RuboCop, bundler-audit, Brakeman, and the full test suite
- `mise exec -- bin/rubocop` / `bin/brakeman` / `bin/bundler-audit` — individual gates
- `mise exec -- bundle exec rspec spec/` — full RSpec suite
- `mise exec -- bundle exec rspec spec/system` — system specs when present

RSpec lives under `spec/` with request, service, and model coverage. Run `mise exec -- bin/ci` before pushing. New tests for sensitive-data features must prove raw intake never persists and never reaches AI stubs.

## Style and commits

Ruby/Node versions: `.mise.toml`; RuboCop omakase (CI-enforced). Keep `app/controllers/` to HTTP only (params, session, render); put domain logic in `app/services/<domain>/`. Commits: short imperative subjects (see `git log`). PRs: include a security note when touching intake, encryption, or AI; keep `bin/ci` green.
