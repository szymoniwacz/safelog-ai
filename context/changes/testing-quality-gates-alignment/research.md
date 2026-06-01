---
date: 2026-06-01T14:20:00+00:00
researcher: Composer
git_commit: 6751b3cca59a4a3c49c56ea1a40e24a0ef7f5226
branch: main
repository: safelog-ai
topic: "Rollout Phase 3 — Quality gates alignment (local bin/ci ↔ GitHub Actions)"
tags: [research, ci, github-actions, quality-gates, bin-ci]
status: complete
last_updated: 2026-06-01
last_updated_by: Composer
---

# Research: Rollout Phase 3 — Quality gates alignment

**Date**: 2026-06-01  
**Researcher**: Composer  
**Git Commit**: 6751b3cca59a4a3c49c56ea1a40e24a0ef7f5226  
**Branch**: main  
**Repository**: safelog-ai

## Research Question

Ground rollout Phase 3 of `context/foundation/test-plan.md`: document and verify local `bin/ci` ↔ GitHub Actions parity (env vars, command wrappers, gate coverage). Baseline: 122 RSpec examples; Phases 1–2 shipped security and HTTP path regression cookbooks.

## Summary

**Gate coverage is aligned** — every gate listed in test-plan §5 runs in both local `bin/ci` and GHA, but **orchestration, flags, and test env differ**. Local CI is one sequential pipeline (`config/ci.rb`); GHA splits into **four parallel jobs** (`scan_ruby`, `scan_js`, `lint`, `test`). The highest-signal parity gaps for Phase 3:

| Area | Local (`bin/ci`) | GHA (`.github/workflows/ci.yml`) | Risk if unaddressed |
|------|------------------|----------------------------------|---------------------|
| **Brakeman flags** | `--quiet --no-pager --exit-on-warn --exit-on-error` (`config/ci.rb:10`) | `--no-pager` only (`ci.yml:22`) | Local fails on Brakeman warnings; GHA may pass |
| **RuboCop formatter** | default (`bin/rubocop`) | `-f github` (`ci.yml:66`) | Cosmetic only; same offenses |
| **Encryption keys for RSpec** | Credentials via `RAILS_MASTER_KEY` / master.key (`test.rb:54-60`) | Explicit `RAILS_ACTIVE_RECORD_ENCRYPTION_*` CITest* vars (`ci.yml:74-76`) | Local works with credentials; GHA path documented in README — different bootstrap, same test behavior when keys present |
| **Setup step** | Full `bin/setup --skip-server` in pipeline (`ci.rb:4`) | Only `test` job runs `bin/setup --skip-server` (`ci.yml:87`) | Scan/lint jobs don't need DB; intentional |
| **Wrapper** | `mise exec -- bin/ci` (AGENTS.md) | `ruby/setup-ruby` + `bundler-cache` | Expected; document mise for local only |
| **Example count in docs** | AGENTS.md still says "116+ examples" | test-plan §5 says 122 | Stale contributor guidance |

**Cheapest Phase 3 deliverable:** Document the parity matrix in test-plan §6 (new gate cookbook subsection), align Brakeman invocation in GHA with `config/ci.rb` (one-line fix), refresh AGENTS.md example count, optional local encryption env documentation matching GHA CITest* keys for contributors without master.key.

**No new test examples required** — this phase is documentation + small config alignment, not RSpec growth.

## Detailed Findings

### Local CI pipeline

**Entry:** `bin/ci` → `config/ci.rb` via `ActiveSupport::ContinuousIntegration`.

```3:12:config/ci.rb
CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"
  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: RSpec", "bundle exec rspec"
end
```

**Setup** (`bin/setup:15-29`): `bundle config set --local path vendor/bundle`, `bundle install`, `bin/rails db:prepare`, log/tmp clear. Matches GHA test job prep.

**Bin wrappers:**

| Script | Behavior | Notes |
|--------|----------|-------|
| `bin/rubocop` | Prepends `--config .rubocop.yml` | GHA adds `-f github` at invoke time |
| `bin/brakeman` | Prepends `--ensure-latest` | Both local ci step and GHA invoke `bin/brakeman` |
| `bin/bundler-audit` | Adds `--config config/bundler-audit.yml` when empty/check | Same in both paths |

### GitHub Actions pipeline

**File:** `.github/workflows/ci.yml` — triggers on PR and push to `main`.

| Job | Steps | Equivalent local step |
|-----|-------|----------------------|
| `scan_ruby` | `bin/brakeman --no-pager`, `bin/bundler-audit` | ci.rb Brakeman + Gem audit |
| `scan_js` | `bin/importmap audit` | ci.rb Importmap audit |
| `lint` | RuboCop cache + `bin/rubocop -f github` | ci.rb Style: Ruby |
| `test` | `bin/setup --skip-server`, `bundle exec rspec` | ci.rb Setup + RSpec |

**Test job environment** (`ci.yml:70-76`):

```yaml
RAILS_ENV: test
RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY: "CITestPrimaryKey00000000000001"
RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY: "CITestDeterministicKey00000001"
RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT: "CITestKeyDerivationSalt000001"
```

**Local test encryption** (`config/environments/test.rb:54-60`): ENV vars applied only when `RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` is present; otherwise Rails uses credentials (requires `config/master.key` locally). README documents both paths (`README.md:35-43`).

### Parity verification (gate-by-gate)

| Gate | Local command | GHA command | Parity |
|------|---------------|-------------|--------|
| RuboCop | `bin/rubocop` | `bin/rubocop -f github` | ✅ Same config; formatter differs |
| bundler-audit | `bin/bundler-audit` | `bin/bundler-audit` | ✅ |
| importmap audit | `bin/importmap audit` | `bin/importmap audit` | ✅ |
| Brakeman | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | `bin/brakeman --no-pager` | ⚠️ Local stricter |
| RSpec | `bundle exec rspec` (after setup) | `bundle exec rspec` (after setup) | ✅ Same command; env differs |
| Setup | All gates preceded by setup in one pipeline | Only test job runs setup | ✅ Acceptable split |

### Documentation drift

| File | Issue |
|------|-------|
| `AGENTS.md:32` | "116+ examples" — stale (122 after Phase 2) |
| `test-plan.md §5` | Already says 122; Phase 3 note at line 111 says "documents gate parity" — §6 has no gate cookbook yet |
| `README.md:76-78` | Individual gate examples use `bundle exec rubocop/brakeman` instead of `bin/rubocop` / `bin/brakeman` — minor wrapper inconsistency |

### Historical context

- `context/archive/2026-05-27-ai-adapter-foundation/plan.md` — original RSpec wiring into `bin/ci` and GHA `test` job.
- `context/archive/2026-06-01-testing-critical-http-path-regression/plan.md` — Phase 2 verification used `mise exec -- bin/ci` as final gate.
- `context/foundation/test-plan.md §5` — authoritative gate list; Phase 3 rollout scoped to parity documentation, not new gates.

## Code References

- `config/ci.rb:3-12` — local sequential pipeline
- `.github/workflows/ci.yml:8-90` — four GHA jobs
- `bin/setup:15-29` — shared DB prep
- `config/environments/test.rb:54-60` — encryption ENV bootstrap
- `bin/brakeman:5` — `--ensure-latest` prepended
- `AGENTS.md:30-32` — mise + bin/ci contributor commands

## Architecture Insights

1. **`bin/ci` is the local source of truth** for gate order and Brakeman strictness; GHA should mirror security-critical flags, not the other way around.
2. **Parallel GHA jobs are intentional** — faster feedback; local `bin/ci` stays sequential for single-command developer UX.
3. **Encryption dual-path is by design** — credentials locally, explicit ENV in GHA so CI works without committing keys; document both in gate cookbook.
4. **mise is local-only** — AGENTS.md and `.mise.toml` explicitly exclude mise from Docker/Fly; GHA uses `ruby/setup-ruby`.

## Recommended Phase 3 Scope (for `/10x-plan`)

1. **Add test-plan §6.7** (or expand §5) — gate parity cookbook: local vs GHA matrix, mise wrapper, encryption env vars, when to run individual `bin/*` vs full `bin/ci`.
2. **Align GHA Brakeman** with `config/ci.rb` flags (`--quiet --exit-on-warn --exit-on-error`) — smallest code fix with real parity signal.
3. **Refresh AGENTS.md** example count (122) and point to gate cookbook section.
4. **Optional:** Document exporting CITest* encryption vars for local `bin/ci` when master.key absent (README snippet or test-plan only).
5. **Out of scope:** New RSpec examples, Playwright, post-edit hooks, GHA job consolidation, auto-deploy.

## Open Questions

- Should RuboCop `-f github` be added to `config/ci.rb` for formatter parity, or document as GHA-only annotation? **Recommend:** document only — no local benefit.
- Should a parity check be automated (script diffing commands) or prose-only? **Recommend:** prose cookbook + Brakeman flag alignment — sufficient for MVP course rollout.
