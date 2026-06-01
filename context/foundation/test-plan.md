# Test Plan

> Phased test rollout for this project. Strategy is frozen at the top
> (§1–§5); cookbook patterns at the bottom (§6) fill in as phases ship.
> Read before writing any new test.
>
> Refresh: re-run `/10x-test-plan --refresh` when stale (see §8).
>
> Last updated: 2026-06-01

## 1. Strategy

Tests follow three non-negotiable principles for this project:

1. **Cost × signal.** The cheapest test that gives a real signal for the
   risk wins. Do not promote to e2e because e2e "feels safer." Do not put a
   vision model on top of a deterministic diff that already catches the
   regression.
2. **User concerns are first-class evidence.** Risks anchored in "the team
   is worried about X, and the failure would surface somewhere in the
   intake/redaction/AI pipeline" carry the same weight as PRD lines or
   hot-spot data.
3. **Risks are scenarios, not code locations.** This plan documents *what
   could fail* and *why we believe it's likely* — drawn from documents,
   interview, and codebase *signal* (churn, structure, test base). It does
   NOT claim to know which line owns the failure. That knowledge is
   produced by `/10x-research` during each rollout phase. If the plan and
   research disagree about where the failure lives, research is the
   ground truth.

Hot-spot scope used for likelihood weighting: `app/`, `spec/`, `config/`.

## 2. Risk Map

The top failure scenarios this project must protect against, ordered by
risk = impact × likelihood. Risks are failure scenarios in user / business
terms, not test names. The Source column cites the *evidence that surfaced
this risk* — never a specific file as "where the failure lives" (that is
research's job, see §1 principle #3).

| # | Risk (failure scenario) | Impact | Likelihood | Source (evidence — not anchor) |
|---|-------------------------|--------|------------|--------------------------------|
| 1 | Raw log substring persists in database after intake | High | High | PRD guardrails; AGENTS.md; interview Q1; hot-spot dir `spec/requests/` (21 commits/30d) |
| 2 | Raw secret reaches AI prompt or correlation payload | High | High | PRD US-01; AGENTS.md; interview Q1; hot-spot dir `app/services/ai/` (11 commits/30d) |
| 3 | User B accesses User A's debugging case (IDOR) | High | Medium | PRD Access Control; interview Q3; archive safe-multi-source-intake plan |
| 4 | Secret in case metadata (title, description, customer_reference) stored or sent to AI unredacted | High | Medium | PRD FR-002; interview Q2; architecture-alignment change notes |
| 5 | Diagnostic text stored as readable plaintext in SQLite | High | Low | PRD NFR encryption; roadmap F-02; interview Q2 (GHA encryption boot) |
| 6 | Demo case loader reachable in production | Medium | Low | PRD FR-011; interview Q5 negative space |
| 7 | Invalid AI output presented without hypothesis framing or uncertainty | Medium | Medium | PRD guardrails; interview Q3; hot-spot dir `app/services/analysis/` (7 commits/30d) |

### Risk Response Guidance

| Risk | What would prove protection | Must challenge | Context `/10x-research` must ground | Likely cheapest layer | Anti-pattern to avoid |
|------|-----------------------------|----------------|--------------------------------------|-----------------------|-----------------------|
| #1 | Known secret email/token in pasted content never appears in persisted diagnostic columns after POST intake | Placeholders on show page prove redaction ran, not that DB is clean | Intake transaction path; which columns hold diagnostic text; encrypted vs plain fields | Request spec scanning all persisted models + show response | Asserting response body only without DB scan |
| #2 | Analyze flow never sends raw intake substrings to fake AI client or correlation JSON | FakeClient returning canned output means prompts were never inspected | Prompt assembly boundary; correlation extractor inputs; ClientResolver in test | Request/service spec with FakeClient capture + joined prompt text | Mocking redaction internals instead of exercising HTTP intake |
| #3 | Cross-user show, analyze, archive, and export return 404 (not 403 leak) | Signed-in user implies only their own cases are reachable | Controller scoping pattern; all mutating routes on DebuggingCase | Request spec matrix per action with two users | Testing only GET show while leaving analyze/export unguarded |
| #4 | Secrets in title, description, and customer_reference redact on persist and in analyze prompts | Title/description treated as safe because they are not log paste fields | Shared registry in intake; metadata fields included in PromptBuilder | Request security spec per metadata field | Testing description only while title stays plain |
| #5 | Encrypted diagnostic columns store ciphertext, not plaintext markers | Model `encrypts` declaration alone proves nothing at rest | Which models/columns use Active Record Encryption; test env key source | Model spec with raw SQL `select_value` | Reading decrypted attribute only without SQLite column check |
| #6 | Load demo returns 404 outside development/test | Demo fixture content matters less than availability gate | Demo availability check; production env config | Request spec with `allow` on availability helper | Testing happy path only in development |
| #7 | Generated reports require hypotheses and uncertainty_notes; invalid JSON retries then fails safely | First successful analyze proves validator exists, not retry/failure path | Analyze orchestration; ResponseValidator rules; report status enum | Service spec for invalid response + request spec for failed status | Asserting markdown contains keywords copied from FakeClient fixture |

## 3. Phased Rollout

Each row is a discrete rollout phase that will open its own change folder
via `/10x-new`. Status moves left-to-right through the values below; the
orchestrator updates Status as artifacts appear on disk.

| # | Phase name | Goal (one line) | Risks covered | Test types | Status | Change folder |
|---|------------|-----------------|---------------|------------|--------|---------------|
| 1 | Security guardrail cookbook | Codify security spec patterns; close residual metadata/export/analyze gaps | #1, #2, #4 | request + service + model | complete | testing-security-guardrail-cookbook |
| 2 | Critical HTTP path regression | Defend full request journeys: create → show → analyze → export → archive; demo path | #3, #6, #7 | request/integration | complete | testing-critical-http-path-regression |
| 3 | Quality gates alignment | Document and verify local `bin/ci` ↔ GitHub Actions parity | cross-cutting | gates | complete | testing-quality-gates-alignment |

## 4. Stack

The classic test base for this project. AI-native tools (if any) carry a
`checked:` date so future readers can see which lines need re-verification.

| Layer | Tool | Version | Notes |
|-------|------|---------|-------|
| unit + integration | RSpec | 3.x (via rspec-rails) | Primary layer; 122 examples across services, requests, models |
| HTTP integration | RSpec request specs | — | Preferred over browser e2e for auth + case flows |
| API mocking | WebMock | — | Blocks real OpenAI calls; used with FakeClient |
| factories | FactoryBot | — | User and domain fixtures |
| static security | Brakeman + bundler-audit + importmap audit | — | Wired in `bin/ci` and GitHub Actions |
| e2e / browser | none | — | Request specs sufficient for MVP; see §7 |
| accessibility | none | — | Manual smoke for UI changes; no axe wired |

**Stack grounding tools (current session):**
- Docs: none (Context7 / framework docs MCP not available in session) — skipped; checked: 2026-05-29
- Search: web search MCP available — used for Rails encryption CI patterns during plan write; checked: 2026-05-29
- Runtime/browser: none — request specs preferred over Playwright; checked: 2026-05-29
- Provider/platform: GitHub Actions workflow present — quality-gate parity relevant for Phase 3; checked: 2026-05-29

## 5. Quality Gates

The full set of gates that must pass before a change reaches production.

| Gate | Where | Required? | Catches |
|------|-------|-----------|---------|
| RuboCop | `bin/ci`, GHA `lint` | required | style drift |
| bundler-audit | `bin/ci`, GHA `scan_ruby` | required | vulnerable gems |
| importmap audit | `bin/ci`, GHA `scan_js` | required | JS dependency CVEs |
| Brakeman | `bin/ci`, GHA `scan_ruby` | required | Rails security patterns |
| RSpec (122) | `bin/ci`, GHA `test` | required | logic and security regressions |
| Full `bin/ci` locally before push | developer workflow | required (AGENTS.md) | combined gate failures |
| Browser e2e on critical flows | — | not planned | — |
| Post-edit agent hook | — | not planned | — |

Phase 3 rollout gate parity is documented in §6.7.

## 6. Cookbook Patterns

How to add new tests in this project. Each sub-section is filled in once
the relevant rollout phase ships; before that, the sub-section reads
"TBD — see §3 Phase N."

### 6.1 Adding a service unit test

Use a **service spec** when you need to prove behavior inside a single service
boundary without HTTP overhead — especially redaction, prompt assembly, or
orchestration that request specs would duplicate at higher cost.

**When to prefer service vs request:** Service specs for `PromptBuilder`,
`ProcessCaseSubmission`, and correlation extractors; request specs when auth,
routing, redirects, or full intake→analyze journeys matter (see §6.2).

**References:**
- Intake + metadata persist: `spec/services/intake/process_case_submission_spec.rb`
- AI prompt assembly: `spec/services/analysis/prompt_builder_spec.rb`
- Redaction engine: `spec/services/redaction/engine_spec.rb`

**Run:** `mise exec -- bundle exec rspec spec/services/<domain>/<file>_spec.rb`

**Security note:** For risks #1/#4 metadata paths, include
`assert_no_raw_substring_in_persisted_data` (§6.5) or prompt content
inspection (§6.3) — not only attribute equality on one field.

### 6.2 Adding a request/integration test

Use a **request spec** when auth, routing, redirects, status codes, or a
full HTTP journey matter — especially IDOR scoping, environment gates, and
controller → service orchestration. Prefer **service specs** for retry/validator
logic that request specs would duplicate at higher cost (see §6.1); add the
request layer when the risk is about what the user receives over HTTP.

**When to prefer request vs service:**

| Concern | Layer | Why |
|---------|-------|-----|
| Cross-user 404, flash, redirect | Request | Proves HTTP status and response oracles |
| Demo loader gate outside dev/test | Request (+ light service) | Request proves route + env wiring; service anchors `available?` |
| Analyze retry / validator rules | Service first, then request | Service proves orchestration; request proves safe failure UI + export block |

**Risk #3 — authorization matrix (IDOR)**

- Canonical file: `spec/requests/debugging_cases_authorization_spec.rb`
- Shared helper: `spec/support/request_status_helpers.rb`
  (`expect_not_found_without_forbidden`) — assert 404, not 403.
- Matrix: `owner` vs `other_user` on every `:id` action (show, analyze,
  archive, download_report). Assert side effects (no `ai_reports`, no
  archive, no export body leak) — not status alone.
- Body-leak oracle on cross-user show: assert case-specific sanitized
  content absent (e.g. `[REQUEST_1]`), not title strings (local error pages
  can echo spec literals in stack traces).
- Export-with-report: owner analyzes first (`Ai::ClientResolver` →
  `FakeClient`), then cross-user download must 404 without report markdown.
- **Guest redirects** live in per-feature specs (not duplicated here):
  `debugging_cases_spec.rb`, `debugging_cases_analyze_spec.rb`,
  `debugging_cases_archive_spec.rb`, `debugging_cases_report_export_spec.rb`,
  `debugging_cases_load_demo_spec.rb`, `debugging_cases_index_spec.rb`.
- **Anti-pattern:** testing only GET show while leaving analyze/export
  unguarded; asserting signed-in user implies access without a second user.

**Risk #6 — demo loader gate**

- Canonical request pattern: `spec/requests/debugging_cases_load_demo_spec.rb`
  (`returns not found in production` — stub `Rails.env.development?` and
  `test?` to false; assert 404 and no case created).
- Service anchor: `spec/services/demo/load_case_spec.rb` (`.available?` false
  when `production?` stubbed).
- UI visibility: `spec/requests/dashboard_spec.rb` (button hidden when
  unavailable).
- **Anti-pattern:** happy path only in test env without a production-like
  gate; stubbing `available?` alone without exercising env logic.

**Risk #7 — analyze journey**

- Success path: `spec/requests/debugging_cases_analyze_spec.rb` (owner POST →
  redirect, hypothesis report UI, `be_generated`).
- Failure after retry: same file — stub `Ai::ClientResolver.current` →
  `AiTestClients::InvalidClient` (`spec/support/ai_test_clients.rb`); assert
  alert flash, `failed` report, no generated summary text, export 404, two
  client calls.
- Service depth (retry logic): `spec/services/analysis/analyze_case_spec.rb`
- **Anti-pattern:** FakeClient success alone proves validator/retry paths;
  copying fixture strings into assertions without independent oracle.

**Run:**

```bash
mise exec -- bundle exec rspec spec/requests/debugging_cases_authorization_spec.rb spec/requests/debugging_cases_load_demo_spec.rb spec/requests/debugging_cases_analyze_spec.rb
```

### 6.3 Adding a security guardrail test

Security guardrails prove **PRD/AGENTS.md invariants**, not happy paths.
Pick the cheapest layer that catches the risk (see §2 Risk Response Guidance).

**Risk #1 — raw never persists after intake**
- Canonical request pattern: `spec/requests/debugging_cases_security_spec.rb`
- Shared DB-scan oracle: `spec/support/security_persistence_helpers.rb`
  (`assert_no_raw_substring_in_persisted_data`) — scans `DebuggingCase`
  diagnostic columns, all `LogSource#sanitized_content`, and
  `RedactionFinding` rows.
- **Anti-pattern:** `spec/requests/debugging_cases_spec.rb` POST example
  asserts show response only — placeholders on the page do not prove SQLite
  is clean.

**Risk #2 — sanitized-only AI**
- Canonical request pattern: `spec/requests/debugging_cases_analyze_security_spec.rb`
- Capture prompts via `Ai::FakeClient#last_request`; join message contents
  and assert raw substrings absent. Success from FakeClient alone is not
  proof — inspect the prompt.
- Service layer: `spec/services/analysis/prompt_builder_spec.rb`,
  `spec/services/analysis/analyze_case_spec.rb`
- Boundary docs: `spec/services/ai/sanitized_prompt_guard_spec.rb`

**Risk #4 — metadata (title, description, customer_reference)**
- Per-field HTTP blocks: `spec/requests/debugging_cases_security_spec.rb`
  (title, description)
- Metadata-only in analyze prompts (no overlapping log secret):
  `spec/requests/debugging_cases_analyze_security_spec.rb`
  (`customer_reference metadata redaction`)
- Service metadata persist: `spec/services/intake/process_case_submission_spec.rb`

**Run:** `mise exec -- bundle exec rspec spec/requests/debugging_cases_security_spec.rb spec/requests/debugging_cases_analyze_security_spec.rb`

### 6.4 Adding an encryption-at-rest check

Encryption at rest (risk **#5**) is already covered — do not duplicate unless
a new encrypted column ships.

**Reference:** `spec/models/encryption_at_rest_spec.rb`

**Pattern:** Read the SQLite column with raw SQL (`select_value`) and assert
the stored value does **not** contain a known plaintext marker; separately
assert the decrypted Active Record attribute round-trips. Declaring
`encrypts` on the model is necessary but not sufficient proof.

**Run:** `mise exec -- bundle exec rspec spec/models/encryption_at_rest_spec.rb`

### 6.5 Adding tests for new intake or redaction behavior

Any new intake or redaction path must prove **raw substrings never persist**
after the change — not only that placeholders appear in the UI.

**Required oracle:** Call `assert_no_raw_substring_in_persisted_data(secret)`
from `spec/support/security_persistence_helpers.rb` after intake (service or
request). Use unique random secrets per example (`SecureRandom`) so tests
do not collide.

**References:**
- HTTP intake: `spec/requests/debugging_cases_security_spec.rb`
- Service intake: `spec/services/intake/process_case_submission_spec.rb`
- Redaction unit: `spec/services/redaction/engine_spec.rb`

**Run:** `mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb spec/requests/debugging_cases_security_spec.rb`

### 6.7 Running and aligning quality gates

Use **`mise exec -- bin/ci`** before push — it runs every gate in §5 sequentially
via `config/ci.rb`. GitHub Actions runs the same gates in **four parallel jobs**
(`.github/workflows/ci.yml`). See §5 for what each gate catches; this section
documents **local vs GHA parity**.

**When to run what:**

| Need | Command |
|------|---------|
| Full pre-push check | `mise exec -- bin/ci` |
| Style only | `mise exec -- bin/rubocop` |
| Rails security scan | `mise exec -- bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` |
| Gem CVEs | `mise exec -- bin/bundler-audit` |
| JS importmap CVEs | `mise exec -- bin/importmap audit` |
| Tests only (after setup) | `mise exec -- bundle exec rspec spec/` |

Prefer `bin/*` wrappers over bare `bundle exec` — they pin config (e.g.
`.rubocop.yml`, `config/bundler-audit.yml`) and match `bin/ci`.

**Gate parity matrix:**

| Gate | Local (`config/ci.rb`) | GHA job / step | Parity notes |
|------|------------------------|----------------|--------------|
| Setup | `bin/setup --skip-server` (first step) | `test` job only | Scan/lint jobs skip DB; intentional |
| RuboCop | `bin/rubocop` | `lint` → `bin/rubocop -f github` | Same config; `-f github` is annotation-only in GHA |
| bundler-audit | `bin/bundler-audit` | `scan_ruby` | ✅ Same wrapper |
| importmap audit | `bin/importmap audit` | `scan_js` | ✅ Same command |
| Brakeman | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | `scan_ruby` → same flags | ✅ Aligned (Phase 3 rollout) |
| RSpec | `bundle exec rspec` | `test` → same command | ✅ Same runner |

**Encryption for tests:** GHA `test` job sets CI-only
`RAILS_ACTIVE_RECORD_ENCRYPTION_*` env vars (see `.github/workflows/ci.yml`).
Local test uses credentials via `config/master.key` by default
(`config/environments/test.rb`). Without `master.key`, export the same CITest*
vars locally before `bin/ci`:

```bash
export RAILS_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="CITestPrimaryKey00000000000001"
export RAILS_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="CITestDeterministicKey00000001"
export RAILS_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="CITestKeyDerivationSalt000001"
```

**Toolchain:** Local commands use `mise exec --` (see AGENTS.md); GHA uses
`ruby/setup-ruby` with `bundler-cache` — never mise in Docker/Fly.

**Run:** `mise exec -- bin/ci`

### 6.6 Per-rollout-phase notes

**Phase 1 — Security guardrail cookbook** (`testing-security-guardrail-cookbook`,
2026-06-01): Closed gap-fill coverage for risks #1, #2, #4. Baseline grew
116 → 119 examples (+ shared helper extraction, PromptBuilder metadata-only
prompt, intake title/description persist, analyze customer_reference-only
isolation). Request-layer guardrails were already strong; additions are
service/request depth and cookbook documentation. **Deferred:** `environment`
metadata redaction; risk #3 authorization matrix (Phase 2 rollout); new
encryption model examples (risk #5 — documented in §6.4 only); export spec
duplication.

**Phase 2 — Critical HTTP path regression** (`testing-critical-http-path-regression`,
2026-06-01): Closed gap-fill coverage for risks #3, #6, #7. Baseline grew
119 → 122 examples (+ shared `AiTestClients` / `RequestStatusHelpers`,
authorization matrix oracles, analyze HTTP failure path, demo `.available?`
production service example, §6.2 cookbook). Files touched:
`spec/support/ai_test_clients.rb`, `spec/support/request_status_helpers.rb`,
`spec/requests/debugging_cases_authorization_spec.rb`,
`spec/requests/debugging_cases_analyze_spec.rb`,
`spec/services/demo/load_case_spec.rb`, `spec/services/analysis/analyze_case_spec.rb`
(client extraction). **Deferred:** dedup of cross-user examples in
per-feature request specs; OpenAI invalid-JSON parse specs; correlation
persisted-on-failure service assertion.

**Phase 3 — Quality gates alignment** (`testing-quality-gates-alignment`,
2026-06-01): Documented local `bin/ci` ↔ GHA parity; aligned Brakeman flags in
`.github/workflows/ci.yml` with `config/ci.rb`; shipped §6.7 gate cookbook.
Example count unchanged (122). Files touched: `.github/workflows/ci.yml`,
`AGENTS.md`, `context/foundation/test-plan.md` §6.7/§6.6. **Deferred:** GHA job
consolidation; automated parity diff script; RuboCop `-f github` in local CI.

## 7. What We Deliberately Don't Test

Exclusions agreed during the rollout (Phase 2 interview, Q5). Future
contributors should respect these unless the underlying assumption changes.

- **Browser e2e / Capybara / Playwright flows** — request specs cover auth and case HTTP paths with higher signal per cost. Re-evaluate if UI becomes a rich client or critical flows need JavaScript-only behavior. (Source: Phase 2 interview Q5; user /10x-test-plan input.)
- **UI snapshot tests** — brittle for server-rendered Rails views; low regression signal for PRD guardrails. Re-evaluate if a rich client ships. (Source: user /10x-test-plan input.)
- **View cosmetic / CSS-only changes** — no automated test budget; prioritize raw-log, AI-boundary, encryption, and authorization specs. (Source: user /10x-test-plan input.)
- **AI-native vision or multimodal review** — security regressions are deterministic; FakeClient + prompt inspection suffices. Re-evaluate if UI-only leaks become a top risk. (Source: Phase 2 interview Q5.)
- **Exhaustive redaction regex catalog** — heuristic gaps are documented in code comments; tests cover representative patterns, not every edge token shape. Re-evaluate if new pattern classes ship. (Source: Phase 2 interview Q5; AGENTS.md guardrails.)
- **Real OpenAI API in CI or local default** — violates AGENTS.md; WebMock + FakeClient only. Re-evaluate never for CI; production uses optional `OPENAI_API_KEY`. (Source: AGENTS.md.)
- **Rate limiting / abuse flood scenarios** — solo course MVP with flat user ownership; low blast radius. Re-evaluate if multi-tenant or public signup scales. (Source: Phase 2 interview Q5.)

## 8. Freshness Ledger

- Strategy (§1–§5) last reviewed: 2026-06-01
- Stack versions last verified: 2026-06-01
- AI-native tool references last verified: 2026-05-29

Refresh (`/10x-test-plan --refresh`) when:

- a new top-3 risk surfaces from the roadmap or archive,
- a recommended tool's `checked:` date is older than three months,
- the project's tech stack changes (new framework, new test runner),
- §7 negative-space no longer matches what the team believes.
