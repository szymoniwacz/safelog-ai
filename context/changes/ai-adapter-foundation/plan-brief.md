# AI Adapter Foundation (F-03) — Plan Brief

> Full plan: `context/changes/ai-adapter-foundation/plan.md`

## What & Why

Roadmap **F-03** lands the provider-agnostic AI adapter layer: a small client contract, a deterministic fake for tests/CI, an env-gated OpenAI implementation, and a validated hypothesis-report JSON schema. **S-03** (`analyze-hypothesis-report`) needs this harness before Analyze case can be built or security-tested. Raw logs must never reach AI; CI must never call a real provider.

## Starting Point

F-02 is complete: domain models including `AiReport` (`structured_json`, `markdown_body` encrypted; status enum `pending`/`processing`/`generated`/`failed`). No `app/services/`, no RSpec tree, no AI gems. `bin/ci` runs RuboCop + security scans only (`config/ci.rb`).

## Desired End State

`app/services/ai/` exposes `Ai::Client#complete` with sanitized-only request objects. Test/CI resolves to `Ai::FakeClient` (deterministic, in-memory call recording). Production/development with `OPENAI_API_KEY` can use `Ai::OpenAiClient`. `Ai::ReportSchema` + `Ai::ResponseValidator` enforce hypothesis-framed structured JSON. RSpec runs in `bin/ci` and GitHub Actions; specs prove fake client is default in test, external HTTP is blocked, and forbidden raw-like strings in prompts raise or fail assertions. No controllers, analyze orchestration, or prompt persistence.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Service location | `app/services/ai/` | Matches AGENTS.md / shape-notes service boundary | Plan |
| Client API | Single `#complete(Ai::Request) → Ai::CompletionResult` | One sync call fits MVP Analyze; async later by case ID | Plan |
| Request payload | Sanitized messages array + case metadata ids only | Never pass raw logs or placeholder maps to adapter | Plan |
| Test default | `Ai::FakeClient` in `test` env | CI never needs API keys or network | Plan |
| Real provider | OpenAI via `ruby-openai`, env-gated | Shape-notes first provider; swap adapter without touching S-03 | Plan |
| Report schema | Ruby validator class + fixture JSON | PRD requires validated structure + uncertainty notes | Plan |
| Retry on invalid | Deferred to S-03 orchestrator | F-03 owns contract + validator; analyze service owns retry-once | Plan |
| RSpec bootstrap | This change (not S-01) | PRD guardrails require fake AI tests before S-03 | Plan |
| HTTP in tests | WebMock `disable_net_connect!` | Belt-and-suspenders beyond FakeClient default | Plan |
| Prompt persistence | None — FakeClient in-memory only | AGENTS.md forbids persisting raw prompts | Plan |
| Markdown body | Returned alongside structured hash | Matches `AiReport` two-column storage from F-02 | Plan |

## Scope

**In scope:** RSpec install + CI wiring, `Ai::Client` contract, `Ai::Request`/`Ai::CompletionResult`, `Ai::FakeClient`, `Ai::ClientResolver`, `Ai::OpenAiClient`, `Ai::ReportSchema`, `Ai::ResponseValidator`, service specs, filter sensitive env params.

**Out of scope:** Analyze controller/routes, correlation extraction, intake/redaction, persisting prompts or provider responses outside `AiReport`, background jobs, Anthropic/other providers, full S-03 orchestration/retry UX.

## Architecture / Approach

```
S-03 (later) ──► Ai::ClientResolver.current ──► Ai::Client#complete
                         │
            test/CI ─────┴──► FakeClient (fixture + call log in memory)
            prod+key ───────► OpenAiClient (ruby-openai)

Ai::ResponseValidator ◄── structured hash from CompletionResult
         │
         └── valid → persist to AiReport (S-03)
```

Resolver reads `Rails.env` and `ENV["OPENAI_API_KEY"]`. Adapter receives only pre-sanitized evidence strings built upstream in S-03.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. RSpec + CI | `rspec-rails`, WebMock, `bin/ci` + GH Actions step | CI flakiness if net not blocked |
| 2. Client contract + FakeClient | Interface, DTOs, resolver, deterministic fake | Leaking raw fields into `Ai::Request` |
| 3. Report schema + validator | Hypothesis JSON contract + validation errors | Schema too loose (allows certainty language) |
| 4. OpenAiClient + security specs | Env-gated real adapter + sanitized-only tests | Accidental real API call in CI |

**Prerequisites:** F-02 complete. **Estimated effort:** ~2 sessions across 4 phases.

## Open Risks & Assumptions

- **Schema fields** are inferred from PRD (hypotheses + uncertainty); S-03 UI may refine display fields without adapter changes if JSON is stable.
- **`ruby-openai` gem** adds dependency surface; pinned in Gemfile.lock with bundler-audit gate.
- **Development default** uses FakeClient unless `OPENAI_API_KEY` set — avoids surprise API spend.
- Assumes S-03 builds sanitized prompt text from `LogSource#sanitized_content` only, not adapter responsibility.

## Success Criteria (Summary)

- RSpec runs green in local `bin/ci` and GitHub Actions without network or API keys.
- Fake client is default in test; OpenAI client only when key present outside test.
- Validator rejects non-hypothesis-shaped JSON; accepts fixture matching PRD guardrails.
- No new DB tables or routes; no prompt persistence columns.
