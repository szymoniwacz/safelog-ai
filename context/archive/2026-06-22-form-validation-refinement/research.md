---
date: 2026-06-22T18:30:00+02:00
researcher: Cursor Agent
git_commit: b26c7f21eadb1e33cdceb31c27866aa3e3c4816d
branch: form-validation-refinement
repository: safelog-ai
topic: "Debugging logs form validation UX — error highlighting and field repopulation"
tags: [research, codebase, debugging-cases, intake, form-validation, ux]
status: complete
last_updated: 2026-06-22
last_updated_by: Cursor Agent
---

# Research: Debugging logs form validation UX — error highlighting and field repopulation

**Date**: 2026-06-22T18:30:00+02:00  
**Researcher**: Cursor Agent  
**Git Commit**: b26c7f21eadb1e33cdceb31c27866aa3e3c4816d  
**Branch**: form-validation-refinement  
**Repository**: safelog-ai

## Research Question

Debugging logs form does not work as expected. It is unclear. Validations should highlight fields with errors and previously filled in fields should remain filled with previous data.

## Summary

The new debugging case form (`app/views/debugging_cases/new.html.erb`) already **re-populates case metadata** (title, description, customer reference, environment) on validation failure and shows a **global error summary** (`#error_explanation`). It does **not** highlight individual fields, does **not** repopulate log source slots (`source_type`, `name`, `pasted_content`), and **intentionally never re-renders pasted log content** after a failed submit — a security contract from S-02 intake (AGENTS.md guardrail).

The user's expectation of “all fields remain filled” **conflicts partially** with the established no-paste-repopulation rule. A refinement plan should:

1. Add **per-field error highlighting** and inline messages for metadata and source slots.
2. Keep **pasted_content empty** on 422 (non-negotiable security).
3. Optionally repopulate **non-secret source metadata** (`source_type`, `name`) if product agrees.
4. Improve **clarity** (which slot failed, focus/scroll, `aria-invalid`).

Metadata repopulation and error banner behavior are already covered by request, system, and E2E specs. Field-level highlighting is **net-new** work with no prior archived plan.

## Detailed Findings

### Form structure and validation entry point

Single ERB template — no partials. Three fixed log source slots (`DebuggingCasesHelper::SOURCE_SLOT_COUNT = 3`).

**POST flow:**

```
POST /debugging_cases
  → DebuggingCasesController#create
    → Intake::CaseSubmission.new(params)
    → Intake::ProcessCaseSubmission.call
         ├─ invalid? → Result(errors: submission.errors)
         └─ persist failure → Result(errors: record.errors)
    ├─ success → redirect to show
    └─ failure → assign_safe_metadata_for_form + @errors + render :new, 422
```

Failed POST stays at `/debugging_cases` (not `/debugging_cases/new`) — `render :new, status: :unprocessable_entity`.

### Validation rules (`Intake::CaseSubmission`)

| Rule | Attribute | Message |
|------|-----------|---------|
| `validates :title, presence: true` | `:title` | `"can't be blank"` |
| `at_least_one_source_with_content` | `:sources` | `"must include at least one non-blank log source"` |
| `source_types_are_valid` | `:sources` | `"source N has an invalid source type"` |

Only slots with non-blank `pasted_content` are validated for source type. Blank slots are ignored.

`description`, `customer_reference`, and `environment` have **no presence validations** — optional metadata.

### Current error display

Global banner only (`new.html.erb:6–14`):

- Renders `#error_explanation` with `@errors.full_messages` as a bullet list.
- Errors attach to `:title` and `:sources` at the model level, but the view does **not** map them to individual fields.
- No `field_with_errors` wrapper, no per-input CSS, no `aria-invalid` / `aria-describedby`.

CSS (`application.css:566–584`): styles the summary box only — no invalid-input classes.

### Current field repopulation

| Field group | Repopulates on 422? | Mechanism |
|-------------|---------------------|-----------|
| Title, description, customer_reference, environment | **Yes** | `assign_safe_metadata_for_form` → `@title`, etc.; form fields use `value:` |
| Log source `source_type`, `name`, `pasted_content` | **No** | Manual tags hard-coded to `nil` (`new.html.erb:48–66`) |

Controller comment (`debugging_cases_controller.rb:106–107`):

> Pasted log content is intentionally omitted on validation failure — raw logs must not be re-rendered in HTML (AGENTS.md).

### Test coverage (existing behavior)

| Layer | File | Asserts |
|-------|------|---------|
| Service | `spec/services/intake/case_submission_spec.rb` | Error keys for blank sources, invalid source type |
| Request | `spec/requests/debugging_cases_spec.rb:66–130` | 422, error copy, metadata preserved, paste **not** in body |
| Security | `spec/requests/debugging_cases_security_spec.rb:222–238` | Paste not echoed on blank-title failure |
| System | `spec/system/debugging_case_validation_spec.rb` | Error banner, title/metadata preserved |
| E2E | `e2e/debugging-case-validation.spec.ts` | Same as system spec in real browser |

**Not tested today:** per-field error CSS, source slot highlighting, `source_type`/`name` repopulation.

### UX gaps vs user expectation

| Expected | Current |
|----------|---------|
| Highlight fields with errors | Summary box only |
| All filled fields remain | Metadata yes; source slots no |
| Clear which log source failed | Message says “source N…” but no fieldset highlight |
| Accessible error association | Missing |

### Recommended refinement scope (for planning)

**In scope (aligned with security):**

- Field-level error classes and inline messages for `:title` and `:sources` errors.
- Highlight affected fieldsets (e.g. title field; log source N when type invalid or when global sources error).
- Repopulate `source_type` and optional `name` from permitted params (no secrets — name is user label, not log body).
- Keep `pasted_content` always empty on re-render; show helper text explaining why paste is cleared.
- `aria-invalid`, `aria-describedby`, optional scroll-to-first-error.

**Out of scope / must not change:**

- Re-rendering raw pasted log content in HTML after validation failure.
- Client-side JS framework — stay server-rendered ERB unless a minimal vanilla enhancement is justified.

## Code References

- `app/views/debugging_cases/new.html.erb:6–14` — global `#error_explanation` banner
- `app/views/debugging_cases/new.html.erb:21–39` — metadata fields with repopulation via `@title`, etc.
- `app/views/debugging_cases/new.html.erb:42–68` — three log source slots; values always `nil`
- `app/controllers/debugging_cases_controller.rb:28–38` — create failure path
- `app/controllers/debugging_cases_controller.rb:106–114` — `assign_safe_metadata_for_form` (metadata only)
- `app/services/intake/case_submission.rb:12–14,37–48` — validation rules
- `app/assets/stylesheets/application.css:566–584` — `#error_explanation` styles only
- `app/helpers/debugging_cases_helper.rb:4–8` — `SOURCE_SLOT_COUNT = 3`
- `spec/requests/debugging_cases_spec.rb:115–130` — pasted content must not appear in 422 response
- `e2e/debugging-case-validation.spec.ts` — browser validation UX parity

## Architecture Insights

- **Validation lives on the service form object** (`Intake::CaseSubmission`), not ActiveRecord — errors are `:title` and `:sources` only at intake time.
- **Split repopulation policy** is intentional: metadata is safe to echo; pasted logs are transient intake and must not persist in HTML after submit attempt.
- **Hybrid form**: metadata uses `form_with` builder; source slots use manual `*_tag` helpers — any repopulation for sources needs explicit `@sources` ivar or similar, not form builder magic.
- **No JavaScript** on the form — all UX changes can be server-rendered; optional small progressive enhancement only.
- **422 URL quirk**: failed create renders `new` template at POST URL — E2E/system specs assert `/debugging_cases`, not `/debugging_cases/new`.

## Historical Context (from prior changes)

- `context/archive/2026-05-27-safe-multi-source-intake/plan.md:51–55` — original contract: metadata may repopulate; pasted fields must not on validation failure.
- `context/reviews/mvp-impl-review.md` — “failed intake does not repopulate pasted fields” marked PASS.
- `context/changes/case-submission-flow-analysis/research.md` — documents full HTTP flow and test matrix; identified G-14 (E2E validation gap, now closed).
- `context/archive/2026-06-20-e2e-test-verification/plan.md` — added Playwright validation specs; paste-not-rerendered deliberately left in RSpec only.
- `context/changes/refactor-opportunities/research.md` — G-14 DONE; paste-on-422 still RSpec-only (TD-8 PARTIAL).

## Related Research

- `context/changes/case-submission-flow-analysis/research.md` — end-to-end submission flow
- `context/changes/refactor-opportunities/research.md` — test backlog (G-14, G-15, TD-8)

## Open Questions

1. **Repopulate `source_type` and `name` on 422?** Safe from AGENTS.md perspective (not raw log body). Improves UX when only one slot has invalid type — user does not re-select type/name after fixing paste.
2. **Per-slot vs global `:sources` error?** Today all source errors use `:sources` attribute — plan may need error indexing or custom error objects to highlight slot 2 vs slot 1.
3. **Helper copy for empty paste fields?** Should the form explain “paste cleared for security — re-paste logs to continue” on every 422, or only when user had content?
4. **Invalid source type with empty paste in other slots?** Edge case: user fills slot 1 paste but leaves default blank source type — error message includes slot number; field highlight should match.
