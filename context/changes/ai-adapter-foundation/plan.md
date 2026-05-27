# AI Adapter Foundation (F-03) Implementation Plan

## Overview

Land roadmap **F-03**: a provider-agnostic AI client under `app/services/ai/`, a deterministic fake for tests/CI, an env-gated OpenAI adapter, and a hypothesis-report JSON validator. Bootstrap RSpec into `bin/ci` and GitHub Actions so security specs can prove sanitized-only prompts and zero real provider calls. No Analyze routes, correlation engine, or prompt persistence — **S-03** consumes this harness.

## Current State Analysis

- **Schema:** F-02 complete — `AiReport` stores encrypted `structured_json` + `markdown_body` with status enum (`app/models/ai_report.rb:1-12`).
- **Services:** No `app/services/` tree yet (`context/foundation/roadmap.md` baseline).
- **AI gems:** None in `Gemfile`; no OpenAI or HTTP client for AI.
- **Tests:** No `spec/` directory; F-01/F-02 deferred RSpec (`context/changes/encrypted-diagnostic-schema/plan-brief.md`).
- **CI:** `config/ci.rb` runs setup, RuboCop, bundler-audit, importmap audit, Brakeman — no test runner (`.github/workflows/ci.yml` mirrors scans only).
- **Param filtering:** `:token`, `:secret`, `:passw` already filtered (`config/initializers/filter_parameter_logging.rb:6-8`); no OpenAI-specific keys yet.

### Key Discoveries:

- AGENTS.md requires fake AI client in tests; CI must never call real providers.
- Shape-notes: provider-agnostic adapter; OpenAI first real provider; services live in `app/services/<domain>/`.
- PRD guardrails: AI receives sanitized evidence only; reports are hypothesis-framed with validated structure + uncertainty notes; invalid structured response retried once in **S-03** (not F-03).
- `AiReport#structured_json` / `#markdown_body` already encrypted at rest — adapter returns in-memory values; persistence is S-03's job.
- Never persist, log, or expose raw log text or raw-to-placeholder mappings after intake (AGENTS.md hard rules).

## Desired End State

After this plan:

1. `Ai::Client` contract exists with `#complete(request)` returning `Ai::CompletionResult` (structured hash + markdown string).
2. `Ai::Request` accepts only sanitized evidence (messages/content built upstream) — no raw log fields on the DTO.
3. `Ai::FakeClient` is the default in `test`; records last request in memory for specs; returns deterministic valid fixture JSON.
4. `Ai::OpenAiClient` calls OpenAI when `OPENAI_API_KEY` is set and env is not `test`; never loaded as default in CI.
5. `Ai::ResponseValidator` validates structured JSON against `Ai::ReportSchema` (hypotheses + uncertainty notes; rejects empty/missing required keys).
6. RSpec runs via `mise exec -- bundle exec rspec` in `bin/ci` and a new GitHub Actions job; WebMock blocks external HTTP in test.
7. Service specs prove: test env uses fake client, forbidden raw-like substrings in request content raise/fail, validator accepts fixture and rejects invalid JSON.
8. `bin/ci` green; no new routes, controllers, or DB migrations.

### Verification

- Automated: `bundle exec rspec`, `bin/ci`.
- Manual: `rails console` in development with/without `OPENAI_API_KEY` — resolver returns expected client class name (no live call required in F-03 manual check).

## What We're NOT Doing

- Analyze case controller, routes, views, or Stimulus/UI.
- Correlation signal extraction or full analyze orchestration (retry-once, `AiReport` status transitions) — **S-03**.
- Intake, redaction, or sanitized log persistence — **S-02**.
- Persisting AI prompts, raw provider responses, or request/response audit tables.
- Background jobs, Action Cable progress, or async analyze.
- Additional providers (Anthropic, etc.) beyond OpenAI skeleton.
- Request/system specs for HTTP (no analyze endpoints yet).
- Changes to `AiReport` model or schema.

## Implementation Approach

Add RSpec + WebMock first so every subsequent phase has executable proof. Introduce a narrow client interface and immutable-ish request/result objects under `app/services/ai/`. Use a small resolver (module or class method) keyed off `Rails.env` and `ENV["OPENAI_API_KEY"]` rather than a heavy DI container. Keep validation as pure Ruby (no JSON Schema gem unless implementer prefers stdlib-only hash checks). OpenAI adapter wraps `ruby-openai` with model name from env default (`gpt-4o-mini` or similar cost-bias for MVP).

## Critical Implementation Details

**Sanitized-only boundary:** `Ai::Request` must not define attributes for raw log text, original values, or placeholder-to-raw maps. Upstream S-03 builds `messages` from `LogSource#sanitized_content` and correlation payloads only. Add a lightweight guard in `Ai::Request` initialization (e.g. reject keys matching `/raw|original|mapping/i` in metadata) if metadata hash is used.

**No prompt logging:** Do not `Rails.logger.info` request bodies. FakeClient may store `@last_request` on the instance for tests only — not ActiveSupport::CurrentAttributes that could leak across requests in dev.

**Test network:** In `spec/rails_helper.rb`, `WebMock.disable_net_connect!(allow_localhost: true)` so a misconfigured resolver cannot hit OpenAI in CI.

## Phase 1: RSpec and CI Wiring

### Overview

Bootstrap RSpec and WebMock; wire `bundle exec rspec` into local CI and GitHub Actions so later phases have a test runner from the first commit.

### Changes Required:

#### 1. Gem dependencies

**File:** `Gemfile`

**Intent:** Add `rspec-rails` to `:development, :test`; add `webmock` to `:test` only.

**Contract:** After `bundle install`, `bundle exec rspec` command exists; no production dependency on test gems.

#### 2. RSpec install

**Files:** `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb` (generator output)

**Intent:** Run `rails generate rspec:install`; configure `rails_helper` to require Rails environment; enable WebMock net disconnect in test suite setup.

**Contract:** `mise exec -- bundle exec rspec` exits 0 with zero examples (or one pending smoke example if generator adds none — prefer one `spec/smoke_spec.rb` that `expect(true).to eq(true)` until Phase 2 adds real specs, then remove smoke).

#### 3. Local CI step

**File:** `config/ci.rb`

**Intent:** Add step after Brakeman: `"Tests: RSpec", "bundle exec rspec"`.

**Contract:** `mise exec -- bin/ci` runs RSpec; failure fails CI script.

#### 4. GitHub Actions job

**File:** `.github/workflows/ci.yml`

**Intent:** Add `test` job parallel to `lint`/`scan_*`: checkout, setup-ruby with bundler-cache, run `bin/setup --skip-server`, then `bundle exec rspec`.

**Contract:** PR workflow includes RSpec; no secrets required for job to pass.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle install` succeeds with new gems
- `mise exec -- bundle exec rspec` passes
- `mise exec -- bin/ci` passes

#### Manual Verification:

- Confirm GitHub Actions workflow file syntax is valid (optional local `actionlint` if available)

**Implementation Note:** Pause for human confirmation after automated checks before Phase 2.

---

## Phase 2: Client Contract, DTOs, FakeClient, Resolver

### Overview

Define the adapter interface, sanitized request/result objects, deterministic fake implementation, and environment-based resolver.

### Changes Required:

#### 1. Client interface

**File:** `app/services/ai/client.rb`

**Intent:** Define `Ai::Client` as a module or abstract class with `#complete(request)` raising `NotImplementedError` in base, or document duck-type contract in module.

**Contract:** `#complete` accepts `Ai::Request`, returns `Ai::CompletionResult`; no side-effect persistence.

#### 2. Request and result objects

**Files:** `app/services/ai/request.rb`, `app/services/ai/completion_result.rb`

**Intent:** `Ai::Request` holds `messages:` (Array of `{ role:, content: }` with string roles) and optional `case_ref:` (String, sanitized identifier for tracing — not raw customer data). `Ai::CompletionResult` holds `structured:` (Hash) and `markdown:` (String).

**Contract:** No `raw_*`, `original_*`, or mapping fields; initializer validates message contents are Strings.

#### 3. Fake client

**File:** `app/services/ai/fake_client.rb`

**Intent:** Implements `Ai::Client`; stores `attr_reader :last_request`; `#complete` returns fixed valid structured hash + markdown from `spec/support/fixtures/ai/` (or inline minimal fixture until Phase 3 extracts schema).

**Contract:** Deterministic output across calls; implements same interface as real client.

#### 4. Resolver

**File:** `app/services/ai/client_resolver.rb`

**Intent:** `Ai::ClientResolver.current` returns `FakeClient.new` when `Rails.env.test?`; returns `OpenAiClient.new` when `ENV["OPENAI_API_KEY"].present?` and not test; otherwise `FakeClient.new` in development/test default.

**Contract:** `Rails.env.test?` always yields fake; method is the single entry point S-03 will call.

#### 5. Autoloading

**File:** `config/application.rb` or rely on Rails 8 `app/services` autoload (verify `app/services` is in autoload paths — add `config.autoload_paths` only if needed)

**Intent:** `Ai::FakeClient` loadable from console and specs without manual require.

**Contract:** `mise exec -- bin/rails runner 'puts Ai::ClientResolver.current.class.name'` succeeds.

#### 6. Service specs

**Files:** `spec/services/ai/fake_client_spec.rb`, `spec/services/ai/client_resolver_spec.rb`, `spec/services/ai/request_spec.rb`

**Intent:** Prove fake returns deterministic result; resolver returns `FakeClient` in test; request rejects forbidden metadata keys if guard implemented.

**Contract:** Examples cover happy path and sanitized boundary.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/ai/`
- `mise exec -- bin/rails runner 'puts Ai::ClientResolver.current.class.name'` prints `Ai::FakeClient` in development
- `mise exec -- bin/ci`

#### Manual Verification:

- Optional console: build `Ai::Request` with placeholder-only message, call `FakeClient#complete`, inspect result keys

**Implementation Note:** Pause for human confirmation before Phase 3.

---

## Phase 3: Report Schema and Response Validator

### Overview

Codify the hypothesis-framed structured JSON contract and validate provider/fake output before S-03 persistence logic exists.

### Changes Required:

#### 1. Report schema definition

**File:** `app/services/ai/report_schema.rb`

**Intent:** Constants or class methods documenting required top-level keys, e.g. `summary` (String), `hypotheses` (Array of Hash with `title`, `description`, optional `confidence`), `uncertainty_notes` (Array of String, min 1). Optional: `correlation_highlights` (Array) for cross-source signals.

**Contract:** Schema documented in code comments linking PRD hypothesis guardrail; no certainty-language lint in F-03 (out of scope unless simple keyword denylist is trivial).

#### 2. Response validator

**File:** `app/services/ai/response_validator.rb`

**Intent:** `Ai::ResponseValidator.call(structured)` returns success object or raises `Ai::InvalidResponseError` with safe message (no provider payload echo). Validates types, presence, non-empty hypotheses array.

**Contract:** Accepts Hash (symbol or string keys); rejects nil, empty hypotheses, missing uncertainty_notes.

#### 3. Fixture alignment

**Files:** `spec/support/fixtures/ai/valid_report.json`, update `FakeClient` to load or mirror this fixture

**Intent:** Single canonical valid JSON used by fake client and validator specs.

**Contract:** Fixture passes validator; tampered fixture (missing `uncertainty_notes`) fails.

#### 4. Validator specs

**File:** `spec/services/ai/response_validator_spec.rb`

**Intent:** Table-driven examples for valid fixture, missing keys, wrong types, empty arrays.

**Contract:** Full branch coverage of validator public API.

#### 5. Integrate validator with fake client (optional thin wrapper)

**File:** `app/services/ai/fake_client.rb` (adjust if needed)

**Intent:** Fake always returns validator-approved structured hash so S-03 can trust adapter output shape.

**Contract:** `#complete` result passes `ResponseValidator` without raise.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/ai/response_validator_spec.rb`
- `mise exec -- bundle exec rspec spec/services/ai/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Console: `Ai::ResponseValidator.call(JSON.parse(File.read(...)))` on valid and invalid samples

**Implementation Note:** Pause for human confirmation before Phase 4.

---

## Phase 4: OpenAI Client and Security Specs

### Overview

Add env-gated OpenAI adapter and security-focused specs proving CI isolation and sanitized prompt boundary.

### Changes Required:

#### 1. OpenAI gem

**File:** `Gemfile`

**Intent:** Add `ruby-openai` to main group (used in production when key present).

**Contract:** `bundle install` + bundler-audit still passes.

#### 2. OpenAI client

**File:** `app/services/ai/open_ai_client.rb`

**Intent:** Implements `Ai::Client`; uses API key from `ENV["OPENAI_API_KEY"]`; model from `ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")`; sends chat completion with messages from request; parses JSON from assistant content into structured hash + markdown (either separate fields in JSON or markdown derived via template — prefer provider returns JSON matching schema and separate markdown field in parsed hash).

**Contract:** Raises clear error when key missing; does not log message bodies; not instantiated in test by resolver.

#### 3. Sensitive param filter

**File:** `config/initializers/filter_parameter_logging.rb`

**Intent:** Add `:openai_api_key` or filter `OPENAI_API_KEY` if ever passed as param (defensive).

**Contract:** Filter list includes API-key-like symbols.

#### 4. OpenAI client specs (stubbed)

**File:** `spec/services/ai/open_ai_client_spec.rb`

**Intent:** Use WebMock to stub OpenAI HTTP; one example proves `#complete` maps response JSON to `CompletionResult`; no real network.

**Contract:** Examples run with `OPENAI_API_KEY=dummy` in example metadata only; WebMock intercepts.

#### 5. Security / guardrail specs

**File:** `spec/services/ai/sanitized_prompt_guard_spec.rb` (or examples in `request_spec`)

**Intent:** Assert `ClientResolver.current` is `FakeClient` in test; building request with forbidden substring in content (simulating raw leak) fails guard; document that persistence layer must not store prompts.

**Contract:** Spec names reference AGENTS.md guardrail; CI passes without API key.

#### 6. Handoff note

**File:** `context/changes/ai-adapter-foundation/change.md` (Notes append)

**Intent:** Document S-03 entry points: `ClientResolver.current`, `ResponseValidator`, retry belongs in analyze service.

**Contract:** Notes mention unlocks S-03; no edits to foundation PRD files.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`
- `mise exec -- bin/bundler-audit` (no new critical CVEs ignored)

#### Manual Verification:

- With real key locally (optional, not CI): single manual `OpenAiClient#complete` in console — operator responsibility; not required for F-03 sign-off

**Implementation Note:** Final phase — human confirms before archive/S-03 planning.

---

## Testing Strategy

### Unit Tests:

- `Ai::Request` sanitization guards
- `Ai::FakeClient` determinism and `last_request`
- `Ai::ClientResolver` env matrix (test vs dev vs key present)
- `Ai::ResponseValidator` valid/invalid payloads
- `Ai::OpenAiClient` with WebMock stub

### Integration Tests:

- None for HTTP endpoints (no routes in F-03)

### Manual Testing Steps:

1. Run full `bin/ci` without `OPENAI_API_KEY` — all green.
2. `rails runner` resolver class name in development without key — `FakeClient`.
3. Optionally set key in development and stub-only spec pattern review — no CI key.

## Performance Considerations

Sync OpenAI call latency acceptable for MVP Analyze (S-03); F-03 does not add timeouts yet — S-03 may wrap with reasonable read timeout on HTTP client if `ruby-openai` exposes it.

## Migration Notes

No database migrations. Gem additions only.

## References

- Roadmap F-03: `context/foundation/roadmap.md`
- PRD guardrails: `context/foundation/prd.md` (Success Criteria, FR-007, FR-008)
- F-02 handoff: `context/changes/encrypted-diagnostic-schema/change.md`
- AGENTS.md AI and test rules

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: RSpec and CI Wiring

#### Automated

- [x] 1.1 `bundle install` succeeds with new gems
- [x] 1.2 `bundle exec rspec` passes
- [x] 1.3 `bin/ci` passes

#### Manual

- [ ] 1.4 GitHub Actions workflow includes RSpec job (syntax valid)

### Phase 2: Client Contract, DTOs, FakeClient, Resolver

#### Automated

- [ ] 2.1 `bundle exec rspec spec/services/ai/` passes
- [ ] 2.2 `rails runner` prints `Ai::FakeClient` for resolver in development
- [ ] 2.3 `bin/ci` passes

#### Manual

- [ ] 2.4 Console smoke: `FakeClient#complete` returns structured + markdown keys

### Phase 3: Report Schema and Response Validator

#### Automated

- [ ] 3.1 `bundle exec rspec spec/services/ai/response_validator_spec.rb` passes
- [ ] 3.2 `bundle exec rspec spec/services/ai/` passes
- [ ] 3.3 `bin/ci` passes

#### Manual

- [ ] 3.4 Console: validator accepts fixture, rejects tampered JSON

### Phase 4: OpenAI Client and Security Specs

#### Automated

- [ ] 4.1 Full `bundle exec rspec` passes
- [ ] 4.2 `bin/ci` passes
- [ ] 4.3 `bin/bundler-audit` passes

#### Manual

- [ ] 4.4 Optional local OpenAI smoke with real key (not required for CI)
