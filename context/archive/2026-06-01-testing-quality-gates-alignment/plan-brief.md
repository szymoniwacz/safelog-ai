# Quality Gates Alignment — Plan Brief

> Full plan: `context/changes/testing-quality-gates-alignment/plan.md`
> Research: `context/changes/testing-quality-gates-alignment/research.md`

## What & Why

Phase 3 of the test rollout **documents and aligns** local `bin/ci` with GitHub Actions. All gates already run in both paths; the real gap is Brakeman strictness (local fails on warnings, GHA may not) plus missing contributor documentation for env vars and command wrappers.

## Starting Point

122 RSpec examples, all green. Phases 1–2 shipped security and HTTP cookbooks (§6.1–§6.6). `config/ci.rb` and `.github/workflows/ci.yml` exist but Brakeman flags differ; AGENTS.md still says "116+ examples."

## Desired End State

GHA Brakeman matches local strictness; test-plan §6.7 gate cookbook documents parity; AGENTS.md refreshed. No new tests; example count stays 122.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
|----------|--------|------------------|--------|
| Brakeman alignment direction | GHA mirrors `config/ci.rb` | Local pipeline is source of truth for security strictness | Research |
| RuboCop `-f github` | Document only; no local change | Formatter difference; same offenses detected | Research |
| Parity verification | Prose cookbook, not diff script | Sufficient for MVP rollout; lowest cost | Research |
| RSpec growth | None | Phase 3 is gates/docs, not test coverage | Research / Plan |
| Encryption local path | Document CITest* ENV option | Dual-path by design; helps contributors without master.key | Research |
| README bin/* wrappers | Optional minimal fix | Lower priority than §6.7 + AGENTS.md | Plan |

## Scope

**In scope:**

- Align `.github/workflows/ci.yml` Brakeman flags with `config/ci.rb`
- Add `test-plan.md` §6.7 gate cookbook + §6.6 Phase 3 notes; mark §3 complete
- Update `AGENTS.md` example count (122) and gate cookbook pointer

**Out of scope:**

- New RSpec examples, GHA job consolidation, RuboCop formatter unification, hooks, auto-deploy

## Architecture / Approach

Two phases: (1) one-line Brakeman fix in GHA, verify `bin/ci`; (2) cookbook prose + AGENTS refresh. Parallel GHA jobs stay; local `bin/ci` stays sequential.

## Phases at a Glance

| Phase | What it delivers | Key risk |
|-------|------------------|----------|
| 1. Brakeman parity | GHA matches local strict Brakeman | Existing Brakeman warnings may fail GHA after alignment |
| 2. Cookbook + docs | §6.7, §6.6, AGENTS.md refresh | Over-long §6.7 duplicating §5 |

**Prerequisites:** Phase 2 archived; 122-example baseline green; research complete.

**Estimated effort:** ~1 session, two small phases.

## Open Risks & Assumptions

- Brakeman flag alignment may expose warnings previously ignored on GHA — fix any warnings found or document blockers.
- Example count in AGENTS.md must stay in sync with `rspec --dry-run` after future test phases.

## Success Criteria (Summary)

- Local and GHA Brakeman use identical flags.
- §6.7 enables a contributor to verify gate parity without reading this plan.
- `bin/ci` green; 122 examples unchanged.
