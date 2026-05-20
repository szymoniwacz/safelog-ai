# SafeLog AI

Rails app for safe multi-source log debugging. **MVP database: SQLite** — simpler, cheaper Fly/course deploy; Rails Active Record Encryption still applies. Agent and product context: `AGENTS.md`, `context/foundation/`.

## Getting started

Use [mise](https://mise.jdx.dev/) for Ruby/Node (see `.mise.toml`). Gems install **only** into `vendor/bundle` via Bundler — do not use system-wide `gem install`.

```bash
mise install
mise exec -- bundle config set --local path vendor/bundle
mise exec -- bundle install
mise exec -- bin/setup --skip-server   # db:prepare + deps check
mise exec -- bin/dev                   # http://localhost:3000
```

Quality gates: `mise exec -- bin/ci` (RuboCop, Brakeman, bundler-audit). When RSpec is added: `mise exec -- bundle exec rspec spec/`.
