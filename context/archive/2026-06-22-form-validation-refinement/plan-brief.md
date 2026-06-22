# Form Validation Refinement — Plan Brief

> Full plan: `context/changes/form-validation-refinement/plan.md`
> Research: `context/changes/form-validation-refinement/research.md`

## What & Why

The new debugging case form is unclear on validation failure: errors appear only
in a top banner, log source fields reset, and users cannot see which inputs failed.
We will add field-level error highlighting, preserve safe input (metadata + source
type/name), and explain why pasted logs are cleared — without breaking the S-02
security rule that raw paste must never re-render in HTML.

## Starting Point

Today the form repopulates case metadata on 422 and shows `#error_explanation`.
Log source slots always render empty. No per-field CSS or inline errors. A bug in
`source_types_are_valid` can report the wrong slot number when earlier slots are
empty.

## Desired End State

On failed submit, users see which fields failed (title, specific log source slots),
metadata and source type/name stay filled, paste areas stay empty with a security
hint, and accessibility attributes link errors to fields. All security specs still
prove no raw paste in the response.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Paste repopulation | Never re-render `pasted_content` | AGENTS.md guardrail — raw logs must not persist in HTML after intake attempt | Research |
| Safe slot repopulation | Repopulate `source_type` + `name` only | Improves UX without exposing log body | Research / Plan |
| Error mapping | Parse `:sources` messages in view helpers | Avoids validator API churn; messages already include slot numbers | Plan |
| Slot index fix | Validate with `sources.each_with_index` | Error “source N” must match UI “Log source N” fieldset | Plan |
| Missing sources UX | Highlight all paste fields | User must add paste somewhere — global error has no single slot | Plan |
| Paste security hint | Show when user submitted any paste on failed 422 | Explains empty textareas without storing paste text | Plan |
| JS framework | None — server-rendered ERB + CSS | Matches existing stack and intake MVP | Research |
| Security oracle layer | RSpec only for paste-not-in-body | TD-8 — Playwright stays UX-only | Research |

## Scope

**In scope:**

- Field-level invalid styling, inline errors, `aria-invalid` / `aria-describedby`
- Controller `@source_slots` + `@paste_cleared_on_validation_failure`
- Validator slot-index fix
- Request, system, E2E test updates

**Out of scope:**

- Re-rendering pasted log content
- New validation rules, JS frameworks, DB changes
- Analyze flow, clipboard, CI Playwright wiring

## Architecture / Approach

```
POST create fails
  → assign_form_state_on_failure (metadata + @source_slots without paste)
  → render new.html.erb with @errors
  → helpers map errors → field/slot invalid CSS + inline messages
  → paste textareas always empty; hint if @paste_cleared_on_validation_failure
```

Three phases: (1) validator + controller state, (2) helpers + view + CSS,
(3) cross-layer tests.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Validator + controller | Correct slot numbers; safe repopulation ivars | Regressing metadata repopulation |
| 2. View + CSS + a11y | Visible field errors; paste-cleared hint | Over-highlighting wrong slots if parser wrong |
| 3. Tests | bin/ci + system + E2E green; security oracles intact | E2E port 3000 dev-server collision |

**Prerequisites:** None — builds on existing intake form.
**Estimated effort:** ~1–2 focused sessions across 3 phases.

## Open Risks & Assumptions

- User expectation of “all fields filled” means metadata + source labels, not paste body.
- Invalid styling must remain readable with existing dark/light CSS tokens.
- E2E should use `PORT=3010 CI=1` if dev server occupies 3000.

## Success Criteria (Summary)

- Validation failures highlight the correct fields/slots with inline messages.
- Metadata and source type/name survive 422; paste does not.
- Security specs still prove no raw paste in HTML response.
- `bin/ci` and validation E2E specs pass.
