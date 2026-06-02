---
date: 2026-06-02T19:56:16+0200
researcher: Composer
git_commit: fd36fbf8d8d4acef33e2354294f1b04d5f7458d9
branch: main
repository: safelog-ai
topic: "Testing environment metadata redaction — gap analysis and implementation path"
tags: [research, codebase, environment, metadata-redaction, intake, security-specs, test-plan]
status: complete
last_updated: 2026-06-02
last_updated_by: Composer
---

# Research: Testing environment metadata redaction

**Date**: 2026-06-02T19:56:16+0200
**Researcher**: Composer
**Git Commit**: fd36fbf8d8d4acef33e2354294f1b04d5f7458d9
**Branch**: main
**Repository**: safelog-ai

## Research Question

What is required to close the deferred `environment` metadata redaction gap identified in test-plan Phase 1 (`testing-security-guardrail-cookbook`)? Where does the implementation diverge from title/description/customer_reference, what test patterns already exist, and what is the minimal change to align behavior and coverage?

## Summary

`environment` is the **only** case metadata field that bypasses `redact_metadata` at intake. It is persisted as plain text, rendered on show/index, and included verbatim in AI prompts via `PromptBuilder`. Phase 1 explicitly deferred environment redaction because test-plan risk #4 lists only title, description, and customer_reference — not environment.

Closing this slice requires **both** a one-line implementation fix in `Intake::ProcessCaseSubmission` and gap-fill tests mirroring existing per-field metadata patterns. The shared DB-scan oracle (`assert_no_raw_substring_in_persisted_data`) already scans the `environment` column but is never exercised with environment-only secrets. Tests written against current code would fail until intake applies `redact_metadata` to environment.

Recommended scope: implementation fix + three test additions (request analyze, service intake, service prompt) + test-plan §6.3/§6.6 doc update to extend risk #4 field list and remove deferral note.

## Detailed Findings

### 1. Intake — environment bypasses redaction

In `Intake::ProcessCaseSubmission`, title, description, and customer_reference pass through `redact_metadata` with the shared `PlaceholderRegistry`. Environment is assigned raw:

```28:33:app/services/intake/process_case_submission.rb
        debugging_case = @user.debugging_cases.create!(
          title: redact_metadata(@submission.title, registry),
          description: redact_metadata(@submission.description, registry),
          environment: @submission.environment,
          customer_reference: redact_metadata(@submission.customer_reference, registry)
        )
```

`redact_metadata` (lines 58–62) delegates to `Redaction::Engine.redact` with the same registry used for log sources (line 36). A secret in environment (e.g. `production — contact leak@secret.example`) would persist and propagate unchanged through show UI and AI prompts.

| Field | Intake | Shared registry | Encrypted at rest |
|-------|--------|-----------------|-------------------|
| title | `redact_metadata` | Yes | No (plain, redacted) |
| description | `redact_metadata` | Yes | No (plain, redacted) |
| customer_reference | `redact_metadata` | Yes | Yes |
| **environment** | **Raw passthrough** | **No** | No (plain, unsanitized) |

### 2. AI prompts — environment included as persisted

`Analysis::PromptBuilder` builds prompts from persisted sanitized evidence only (class comment, lines 4–5). Environment is included when present:

```36:43:app/services/analysis/prompt_builder.rb
    def user_message
      sections = []
      sections << "Case title: #{@debugging_case.title}"
      sections << "Environment: #{@debugging_case.environment}" if @debugging_case.environment.present?
      if @debugging_case.customer_reference.present?
        sections << "Customer reference: #{@debugging_case.customer_reference}"
      end
      sections << "Description: #{@debugging_case.description}" if @debugging_case.description.present?
```

There is no second redaction pass at the AI boundary. Secrets in environment reach the AI client unchanged — the same class of gap F1 fixed for description/title in architecture-alignment.

### 3. Controller and views — wired but no redaction

`DebuggingCasesController` permits `:environment` (line 96) and assigns it for form re-population (line 106). Views render persisted value directly (`show.html.erb`, `index.html.erb`, `new.html.erb`). No controller-level redaction; all sanitization is delegated to `ProcessCaseSubmission`.

### 4. DB-scan helper — already covers environment

`spec/support/security_persistence_helpers.rb` scans all four metadata columns:

```7:16:spec/support/security_persistence_helpers.rb
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
```

No test currently fails on environment because every spec uses benign `"production"` and injects secrets only into other fields.

### 5. Existing metadata redaction tests — title, description, customer_reference only

| Field | Request persist + analyze | Service persist | Service prompt |
|-------|-------------------------|-----------------|----------------|
| description | `debugging_cases_security_spec.rb:69–101` | `process_case_submission_spec.rb:106–133` | — |
| title | `debugging_cases_security_spec.rb:103–136` | same intake example | — |
| customer_reference | `debugging_cases_analyze_security_spec.rb:89–122` | `process_case_submission_spec.rb:87–104` | `prompt_builder_spec.rb:46–73` |
| **environment** | **None** | **None** | **None** |

**Gold-standard pattern** (customer_reference): isolated `describe` block, `SecureRandom`-prefixed secret only in target field, clean log paste (`Started GET /health`), field-level persist assertions, `assert_no_raw_substring_in_persisted_data`, and `fake_client.last_request` prompt join for analyze.

### 6. Implementation fix — one line

```ruby
environment: redact_metadata(@submission.environment, registry),
```

`redact_metadata` already returns early on blank (line 59), so optional/empty environment behavior is unchanged.

## Code References

- `app/services/intake/process_case_submission.rb:28-33` — environment passthrough (fix target)
- `app/services/intake/process_case_submission.rb:58-62` — shared `redact_metadata` helper
- `app/services/analysis/prompt_builder.rb:39` — environment in AI prompt
- `spec/support/security_persistence_helpers.rb:12` — environment already in DB scan
- `spec/requests/debugging_cases_analyze_security_spec.rb:89-122` — customer_reference metadata pattern to mirror
- `spec/services/intake/process_case_submission_spec.rb:106-133` — title/description service pattern
- `spec/services/analysis/prompt_builder_spec.rb:46-73` — metadata-only prompt pattern
- `context/foundation/test-plan.md:46,58,230-232,327-328` — risk #4 scope and Phase 1 deferral

## Architecture Insights

1. **Single redaction boundary at intake.** All metadata sanitization happens in `ProcessCaseSubmission` via the shared registry. PromptBuilder and views trust persisted values. Fixing intake fixes persist, show, and AI paths together.

2. **Shared registry enables cross-field placeholders.** If environment contains a `request_id` matching log paste, redacting through the shared registry would produce consistent `[REQUEST_N]` tokens — same behavior as customer_reference (see `process_case_submission_spec.rb:72-85`).

3. **Plain vs encrypted is intentional.** F-02 schema keeps title, description, environment as plain columns; customer_reference is encrypted. Redaction is the protection mechanism for plain metadata — environment should follow the same path as title/description.

4. **Test-first proof is straightforward.** Any environment-only secret test would fail today on persist, show, or prompt assertions — confirming the gap before the one-line fix.

## Historical Context (from prior changes)

- **`context/archive/2026-06-01-testing-security-guardrail-cookbook/research.md`** — Documented environment passthrough at `process_case_submission.rb:31`; explicitly out of Phase 1 scope because not in risk #4 field list. Open question: defer unless PRD expands.

- **`context/archive/2026-06-01-testing-security-guardrail-cookbook/plan.md`** — Out of scope: `environment` metadata redaction tests. Phase 1 closed #1/#2/#4 for title, description, customer_reference only.

- **`context/archive/2026-05-28-architecture-alignment/plan.md`** — Added title → `redact_metadata` for parity with description/customer_reference. Environment not included.

- **`context/reviews/mvp-impl-review.md` (F1)** — Fixed description bypass; noted plain `title`/`description`/`environment` intentional per F-02. F1 rationale: metadata misuse violates spirit of PRD NFR — applies equally to environment.

- **`context/foundation/test-plan.md` §6.6** — Phase 1 deferred items list includes `environment` metadata redaction alongside authorization matrix and encryption examples.

## Related Research

- `context/archive/2026-06-01-testing-security-guardrail-cookbook/research.md` — Phase 1 gap analysis; environment deferral decision
- `context/archive/2026-05-28-architecture-alignment/research.md` — Title metadata redaction parity; environment noted as optional follow-up
- `context/changes/testing-security-guardrail-cookbook/` — archived; canonical patterns for risk #4

## Recommended Implementation Scope

### Code change (required)

| File | Change |
|------|--------|
| `app/services/intake/process_case_submission.rb:31` | `environment: redact_metadata(@submission.environment, registry)` |

### Test additions (gap-fill only)

| File | Pattern |
|------|---------|
| `spec/requests/debugging_cases_analyze_security_spec.rb` | `"environment metadata redaction"` block — mirror customer_reference (persist + DB scan + analyze prompt) |
| `spec/services/intake/process_case_submission_spec.rb` | `"redacts secrets in environment metadata on persist"` — mirror title/description |
| `spec/services/analysis/prompt_builder_spec.rb` | `"excludes environment metadata-only secrets from the assembled prompt"` — mirror customer_reference |

Optional: show-response assertion in `debugging_cases_security_spec.rb` (title block includes show check at line 127).

### Documentation update

Extend test-plan risk #4 field list from `(title, description, customer_reference)` to include `environment` in §2 risk map (line 46), risk response guidance (line 58), and §6.3 cookbook (lines 230–232). Remove Phase 1 deferral note at lines 327–328.

### Out of scope

- Encryption of environment (F-02 intentional plain column)
- Changes to `security_persistence_helpers.rb` (already scans environment)
- Controller or view changes
- New dependencies or background jobs

### Expected example count delta

+3 examples (one per new spec block above); baseline 122 → 125.

### Verification commands

```bash
mise exec -- bundle exec rspec spec/requests/debugging_cases_analyze_security_spec.rb
mise exec -- bundle exec rspec spec/services/intake/process_case_submission_spec.rb spec/services/analysis/prompt_builder_spec.rb
mise exec -- bin/ci
```

## Open Questions

1. **Test-plan risk #4 expansion** — Should the plan formally extend risk #4 to include environment, or treat this as a follow-up parity fix outside the original field list? Research recommends expansion for consistency with F1 spirit and architecture-alignment title fix.

2. **Show-response test** — Is analyze + service coverage sufficient, or should HTTP show also assert environment secret absent from `response.body` (title block pattern)? Low cost to add for parity.

3. **Shared-registry cross-field test** — Should environment share `[REQUEST_N]` placeholders with log paste when both contain the same request ID? Existing customer_reference test covers this pattern; environment-specific cross-field test is optional unless product expects environment to carry correlation IDs.
