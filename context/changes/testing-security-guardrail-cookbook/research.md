---
date: 2026-06-01T12:00:00+00:00
researcher: Cursor Agent
git_commit: 1598d9ef98f9f532fad811769ff06db250b8d16a
branch: main
repository: safelog-ai
topic: "Phase 1 security guardrail cookbook — coverage gaps for risks #1, #2, #4"
tags: [research, testing, security, redaction, ai-boundary]
status: complete
last_updated: 2026-06-01
last_updated_by: Cursor Agent
---

# Research: Security guardrail cookbook (Phase 1)

**Date**: 2026-06-01  
**Researcher**: Cursor Agent  
**Git Commit**: `1598d9ef98f9f532fad811769ff06db250b8d16a`  
**Branch**: `main`  
**Repository**: safelog-ai

## Research Question

Ground rollout Phase 1 of `context/foundation/test-plan.md` for risks **#1** (raw persist), **#2** (raw in AI/correlation), and **#4** (metadata redaction). Map what 116 existing RSpec examples already prove, identify gap-fill-only additions, and verify or correct the test plan’s risk response guidance.

## Summary

The codebase already has **strong request-layer guardrails** for all three risks. The main POST security spec scans persisted models (not show-page-only). Analyze security inspects `FakeClient#last_request` and correlation payloads. Title and description metadata have dedicated HTTP examples with prompt inspection.

**Gap-fill targets (small, high-signal):**

1. **Service-layer metadata in AI prompts** — `Analysis::PromptBuilder` and `Analysis::AnalyzeCase` only prove log-paste secrets in prompts; metadata-only secrets (especially `customer_reference` without overlapping log text) are thinner at the service layer.
2. **Intake service metadata persist** — `Intake::ProcessCaseSubmission` spec proves `customer_reference` + sources but not **title/description** redaction on persist (HTTP spec owns this today).
3. **Cookbook extraction** — duplicate `assert_no_raw_substring_in_persisted_data` helpers and document anti-patterns (`debugging_cases_spec` show-only POST).
4. **Do not duplicate** — encryption-at-rest model specs (risk **#5**), authorization matrix (risk **#3**, Phase 2), export security request spec (already covers post-analyze download/show).

Baseline confirmed: **116 examples, 0 failures** (`bundle exec rspec spec/ --dry-run`).

## Detailed Findings

### Risk #1 — Raw log substring persists after intake

**Failure path (grounded):**

- HTTP: `DebuggingCasesController#create` → `Intake::ProcessCaseSubmission` → `Redaction::Engine` on sources + `redact_metadata` on title/description/customer_reference (`app/services/intake/process_case_submission.rb:27-47`).
- Persisted diagnostic text: `debugging_cases` (title, description, environment, customer_reference), `log_sources.sanitized_content`, `redaction_findings` (placeholder metadata only — no raw original column in schema).

**Existing proof (adequate at request layer):**

```42:61:spec/requests/debugging_cases_security_spec.rb
  def assert_no_raw_substring_in_persisted_data(raw_substring)
    DebuggingCase.find_each do |debugging_case|
      [
        debugging_case.title,
        debugging_case.description,
        debugging_case.environment,
        debugging_case.customer_reference
      ].compact.each do |value|
        expect(value.to_s).not_to include(raw_substring)
      end
    end
    # ... LogSource, RedactionFinding
  end
```

- Example: `"does not persist raw log substrings in diagnostic text columns"` scans DB after POST — **correctly challenges show-page-only** anti-pattern.
- Separate example still checks show response (complementary, not sole oracle).

**Service-layer coverage:**

- `spec/services/intake/process_case_submission_spec.rb` — `"does not persist raw secrets in encrypted diagnostic fields"` scans cases, log sources, findings for email in customer_reference + paste — **does not** assert title/description metadata redaction.

**Anti-pattern present elsewhere (document, do not copy):**

```52:64:spec/requests/debugging_cases_spec.rb
    it "creates a case and redirects to show without exposing raw secrets" do
      # ...
      expect(response.body).not_to include(secret_email)
    end
```

No DB scan — cookbook should cite `debugging_cases_security_spec` as canonical for #1, not this example.

**Post-analyze tables:** `correlation_signals.payload`, `ai_reports.structured_json` / `markdown_body` are not in intake POST scan helper. Analyze security spec asserts correlation payload after analyze (`debugging_cases_analyze_security_spec.rb:61-73`). Not a Phase 1 gap for intake #1.

**Encryption intersection:** `title` / `description` are **plaintext SQLite columns** (`db/schema.rb`); only `customer_reference` on `DebuggingCase` uses `encrypts`. Raw-substring DB scan via Active Record is correct for title/description; raw SQL ciphertext checks live in `encryption_at_rest_spec` (risk #5, already covered).

**Verified response guidance:** Prove persist with multi-table scan — **confirmed**. Challenge show-only — **already met** in security request spec.

**Cheapest gap-fill:** Optional intake service example for title/description persist only if cookbook wants a non-HTTP reference; otherwise document HTTP spec as canonical and extract shared support helper.

---

### Risk #2 — Raw secret reaches AI prompt or correlation payload

**Failure path (grounded):**

- HTTP analyze: `DebuggingCasesController#analyze` → `Analysis::AnalyzeCase` → `Correlation::ExtractSignals` (sanitized log placeholders only) → `Analysis::PromptBuilder` (reads **persisted** case fields + correlation JSON) → `Ai::ClientResolver.current.complete` (`app/services/analysis/prompt_builder.rb:36-52`).
- `Ai::Request` does not re-scan message content (`spec/services/ai/sanitized_prompt_guard_spec.rb` documents this); prompt safety depends on upstream sanitization.

**Existing proof:**

| Layer | File | What it proves |
|-------|------|----------------|
| Request | `spec/requests/debugging_cases_analyze_security_spec.rb` | Joined `fake_client.last_request` prompt excludes raw email/token/request_id; correlation `payload` sanitized |
| Service | `spec/services/analysis/analyze_case_spec.rb` | Prompt excludes log-paste email |
| Service | `spec/services/correlation/extract_signals_spec.rb` | JSON payload excludes raw secrets |
| Service | `spec/services/ai/sanitized_prompt_guard_spec.rb` | CI uses FakeClient; rejects `metadata: { raw_content: ... }` |

**Challenge “FakeClient success without prompt inspection”:** Analyze security and `analyze_case_spec` **do** inspect `last_request` — guidance holds; no new request spec needed for that anti-pattern alone.

**Gaps:**

1. **`PromptBuilder`** (`spec/services/analysis/prompt_builder_spec.rb`) — secret only in **pasted_content**; persisted title is static `"Checkout failure"`. No case where metadata fields (title, description, customer_reference) carry the secret into `user_message` sections.
2. **`AnalyzeCase` service** — same: only log-paste secret in prompt test.
3. **Overlapping oracle in analyze security:** `secret_email` appears in both `customer_reference` and rails log paste (`debugging_cases_analyze_security_spec.rb:20-27`). A regression that redacted logs but leaked metadata in prompt could still fail on log lines — **customer_reference-only** fixture would isolate metadata in prompt (#4 overlap).

**Verified response guidance:** HTTP intake + FakeClient capture — **confirmed**. Anti-pattern “mock redaction internals” — tests use real `ProcessCaseSubmission` / HTTP; **confirmed**.

**Cheapest gap-fill:** One `PromptBuilder` (or `AnalyzeCase`) service example: metadata-only secret in `customer_reference` (and optionally title), clean log paste, assert joined prompt excludes raw and includes placeholder. No new WebMock/FakeClient wiring beyond existing patterns.

---

### Risk #4 — Metadata (title, description, customer_reference) redact on persist and in prompts

**Redaction implementation:** Shared `PlaceholderRegistry` across metadata and sources (`process_case_submission.rb:23-32, 58-61`).

**Existing proof:**

| Field | Persist | Analyze prompt | Layer |
|-------|---------|------------------|-------|
| title | ✓ | ✓ | `debugging_cases_security_spec.rb` `"title metadata redaction"` |
| description | ✓ | ✓ | same file `"description metadata redaction"` |
| customer_reference | ✓ (main POST + intake service) | ✓ (via overlapping secrets in analyze security) | request + intake service |

**Gaps:**

1. **customer_reference-only** — no example where the secret appears **only** in `customer_reference` with benign log paste (isolates metadata in `PromptBuilder` user_message line 40-41).
2. **Service-layer metadata** — title/description covered at HTTP only; intake service gap noted above.
3. **environment** — passed through without `redact_metadata` (`process_case_submission.rb:31`). Test plan lists title, description, customer_reference only — **out of Phase 1 scope** unless PRD expands.

**Verified response guidance:** Per-field HTTP tests exist for title and description — **confirmed**. Challenge “title/description assumed safe” — **already met**. Anti-pattern “description only” — **avoided** (title block exists).

---

### Export and authorization (phase goal mentions export; risks deferred)

- **Export:** `spec/requests/debugging_cases_report_export_security_spec.rb` — download + show markdown exclude raw secrets; IDOR 404 on cross-user download. **No gap-fill** for #1/#2/#4.
- **Authorization (risk #3):** `spec/requests/debugging_cases_authorization_spec.rb` — Phase 2 per test plan; user priority note is satisfied elsewhere.

---

### Encryption at rest (user priority; risk #5)

- `spec/models/encryption_at_rest_spec.rb` — raw SQL `select_value` for `customer_reference`, `sanitized_content`, `payload`, `structured_json`, `markdown_body`.
- **Cookbook §6.4** should reference this file; **no new model examples** unless combining redaction failure detection with ciphertext (unnecessary for Phase 1 risks).

---

## Coverage map (116 examples)

| Spec file | Examples (approx.) | Risks | Notes |
|-----------|-------------------|-------|-------|
| `debugging_cases_security_spec.rb` | 5 | #1, #4 | Canonical DB scan + metadata blocks |
| `debugging_cases_analyze_security_spec.rb` | 3 | #2 | Prompt + correlation + show |
| `debugging_cases_report_export_security_spec.rb` | 3 | (export) | Already strong |
| `process_case_submission_spec.rb` | 5 | #1, #4 partial | customer_reference persist |
| `analyze_case_spec.rb` | 4 | #2 partial | Prompt for log secret only |
| `prompt_builder_spec.rb` | 1 | #2 partial | Log secret only |
| `extract_signals_spec.rb` | 4 | #2 | Payload JSON |
| `sanitized_prompt_guard_spec.rb` | 4 | #2 boundary | Docs + metadata guard |
| `encryption_at_rest_spec.rb` | 4 | #5 | Cookbook only |
| `debugging_cases_spec.rb` | POST show-only | — | Anti-pattern reference |

## Risk response guidance verification

| Risk | Test plan guidance | Research verdict |
|------|-------------------|------------------|
| #1 | DB scan, not show-only | **Verified** at request layer; intake service + `debugging_cases_spec` gaps noted |
| #2 | FakeClient prompt inspection | **Verified**; add service metadata prompt test |
| #4 | All metadata fields + prompts | **Verified** for title/description HTTP; **gap** for customer_reference-only isolation + service layer |

No speculative risks; no hot-spot anchor corrections needed for §2 Source column.

## Recommended plan scope (gap-fill only)

1. **Extract** `assert_no_raw_substring_in_persisted_data` to `spec/support/security_persistence_helpers.rb` (or similar) — used by request + intake specs; document in §6.3.
2. **Add** one service spec example: metadata-only secret in `customer_reference` (and/or title) → `PromptBuilder` / `AnalyzeCase` prompt exclusion.
3. **Add** one request spec example (or extend analyze security): `customer_reference`-only secret, clean log line, persist + analyze prompt assertions.
4. **Optional:** intake service example for title/description persist (1 example) if cookbook wants service-level canonical intake test.
5. **Write** `context/foundation/test-plan.md` §6.1, §6.3, §6.4, §6.5 from existing references — **no new examples** for encryption/authorization/export beyond documentation.
6. **Do not add:** duplicate full POST security flows, show-only oracles, E2E, view tests (§7 exclusions).

## Code References

- `app/services/intake/process_case_submission.rb:27-61` — intake redaction boundary
- `app/services/analysis/prompt_builder.rb:36-52` — prompt assembly from persisted fields
- `app/services/correlation/extract_signals.rb:53-58` — scans sanitized_content placeholders only
- `spec/requests/debugging_cases_security_spec.rb:42-157` — canonical #1/#4 request patterns
- `spec/requests/debugging_cases_analyze_security_spec.rb:45-73` — canonical #2 request patterns
- `spec/models/encryption_at_rest_spec.rb:9-23` — raw SQL ciphertext pattern for cookbook §6.4

## Historical Context

- `context/archive/2026-05-27-safe-multi-source-intake/` — established intake + redaction pipeline.
- `context/archive/2026-05-28-architecture-alignment/` — metadata fields in shared registry (aligns with risk #4).
- `context/foundation/test-plan.md` §2 Risk Response Guidance — intent matches implementation; gaps are **depth at service layer** and **cookbook documentation**, not missing request guardrails.

## Open Questions

- Should Phase 1 extract the persistence helper before or as part of the first new example? (Recommend: extract first, then wire intake + security specs — single refactor commit in plan.)
- Is `environment` metadata redaction in scope for a follow-up slice? (Not in test plan #4 list; defer unless PRD requires.)
