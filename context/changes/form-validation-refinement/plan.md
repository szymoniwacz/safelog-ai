# Form Validation Refinement Implementation Plan

## Overview

Improve the new debugging case form so validation failures clearly highlight the
affected fields, preserve all safe user input (metadata + source type/name), and
explain why pasted log content is cleared — without re-rendering raw logs in HTML
(AGENTS.md / S-02 security contract).

## Current State Analysis

The form (`app/views/debugging_cases/new.html.erb`) shows a global
`#error_explanation` banner on 422. Case metadata repopulates via
`assign_safe_metadata_for_form`; log source slots always render empty values.
There is no per-field error styling, no inline messages, and no `aria-invalid`.

Validation lives on `Intake::CaseSubmission` (`:title`, `:sources`). Source-type
errors use 1-based slot numbers in messages, but `source_types_are_valid` currently
indexes `sources_with_content` — so the reported slot number can disagree with
the UI fieldset when earlier slots are empty.

### Key Discoveries:

- Metadata repopulation works and is tested (request, system, E2E).
- `pasted_content` must never reappear in HTML after failed submit — enforced by
  controller comment and security specs.
- Hybrid form: metadata uses `form_with`; slots use manual `*_tag` helpers — needs
  explicit `@source_slots` ivar for repopulation.
- Failed POST URL stays `/debugging_cases` (not `/new`) — existing specs depend on this.

## Desired End State

After this plan, when create fails with 422:

1. **Title errors** highlight the Title field with inline message + `aria-invalid`.
2. **Source errors** highlight the correct log source fieldset(s) and relevant
   controls (type select; paste area when “no sources” or type invalid).
3. **Metadata fields** remain filled (unchanged behavior).
4. **`source_type` and `name`** repopulate per slot from submitted params.
5. **`pasted_content`** stays empty; a visible hint explains re-paste is required
   for security when the user had attempted to submit paste content.
6. Global `#error_explanation` banner remains for summary accessibility.
7. All existing security oracles still pass (no raw paste in response body).
8. Request, system, and E2E specs assert field-level UX where visible.

### Verification

- `mise exec -- bin/ci` green after each phase.
- Manual: submit invalid form in browser — see highlighted fields, preserved metadata
  and source type/name, empty paste with security hint.

## What We're NOT Doing

- Re-rendering `pasted_content` in HTML after validation failure.
- Adding React/Vite or a JS validation framework.
- Changing validation rules (still min one source, valid enum type, title required).
- New database columns or intake service architecture changes beyond slot-index fix.
- Paste-not-rerendered security oracle in Playwright (stays RSpec-only per TD-8).
- Clipboard/copy-button work or analyze flow changes.

## Implementation Approach

Bottom-up: fix slot-index accuracy in the validator, add controller ivars for
safe repopulation, add view helpers for error mapping, update template + CSS,
then extend tests at each layer.

Keep server-rendered ERB only. Map `:sources` error strings to slot indexes via
helper parsing (no new error attributes on `CaseSubmission`).

## Critical Implementation Details

**Slot index fix:** `source_types_are_valid` must iterate `sources.each_with_index`
and skip blank paste — not `sources_with_content.each_with_index`. Error text
`"source N has an invalid source type"` must match UI “Log source N” legend.

**Safe repopulation boundary:** Controller may assign `@source_slots` as an array
of length `SOURCE_SLOT_COUNT` with `source_type` and `name` only. Never assign
`pasted_content` to an ivar consumed by the view. Set
`@paste_cleared_on_validation_failure` when any submitted slot had non-blank
`pasted_content` in permitted params (boolean flag only — do not store paste text).

**Global “no sources” error:** When `errors[:sources]` includes
`"must include at least one non-blank log source"`, mark all three paste
textareas (or their parent `.form-field`) as invalid — user must add paste
somewhere.

**ActiveRecord persist failures:** When `result.errors` comes from
`ActiveRecord::RecordInvalid` (e.g. `:sanitized_content`), show the global
banner and repopulate safe metadata/slots only. Per-slot `:sources` highlighting
applies to `Intake::CaseSubmission` validation errors — not AR error keys.

**Name repopulation:** `name` is a user label (not log body). Repopulating it on
422 matches metadata echo policy. Security specs in this change remain
paste-textarea-only; do not expand AGENTS.md paste oracle to the name field.

## Phase 1: Validator fix and controller form state

### Overview

Correct source slot numbering in validation messages and expose safe form state
ivars on validation failure.

### Changes Required:

#### 1. Fix slot index in source type validation

**File**: `app/services/intake/case_submission.rb`

**Intent**: Ensure invalid source type errors reference the actual UI slot number
(1–3), not the index among filled sources only.

**Contract**: `source_types_are_valid` loops `sources.each_with_index`, skips
blank `pasted_content`, adds `"source #{index + 1} has an invalid source type"`.
Existing error message substring `"invalid source type"` preserved for specs.

#### 2. Safe source slot repopulation ivars

**File**: `app/controllers/debugging_cases_controller.rb`

**Intent**: On create failure, populate view state for metadata (existing) plus
per-slot `source_type` and `name`; set boolean paste-cleared notice flag.

**Contract**:

- Rename or extend `assign_safe_metadata_for_form` → `assign_form_state_on_failure`
  (or call both from create failure path).
- Set `@source_slots` to normalized array of `{ source_type:, name: }` with length
  `DebuggingCasesHelper::SOURCE_SLOT_COUNT`, padding missing entries with blanks.
- Set `@paste_cleared_on_validation_failure` true when any permitted source hash
  had non-blank `pasted_content`.
- `new` action initializes `@source_slots` to empty slots and
  `@paste_cleared_on_validation_failure` false.

#### 3. Service spec for slot index

**File**: `spec/services/intake/case_submission_spec.rb`

**Intent**: Prove invalid type on slot 2 (slot 1 empty) reports `"source 2"`.

**Contract**: New example with two slots — first blank paste, second with invalid
`source_type` — expects error message to include `"source 2"`.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/services/intake/case_submission_spec.rb`
- `mise exec -- bundle exec rspec spec/requests/debugging_cases_spec.rb`

#### Manual Verification:

- None for this phase.

---

## Phase 2: View helpers, template, and CSS

### Overview

Render field-level errors, invalid styling, accessibility attributes, source slot
repopulation, and paste-cleared security hint.

### Changes Required:

#### 1. Form error helpers

**File**: `app/helpers/debugging_cases_helper.rb`

**Intent**: Centralize mapping from `@errors` to field/slot UI state.

**Contract**: Add helpers (names at implementer discretion), minimally:

- `title_field_invalid?(errors)` — `errors[:title].any?`
- `sources_error_messages(errors)` — array of `:sources` messages
- `invalid_source_slot_numbers(errors)` — parse 1-based N from `"source N ..."` messages
- `missing_sources_error?(errors)` — detects blank-sources message
- `form_field_css_class(base, invalid:)` — returns `"form-field form-field--invalid"` when invalid
- `field_error_id(field_key)` — stable id for `aria-describedby`

No raw paste content in helper APIs.

#### 2. Template updates

**File**: `app/views/debugging_cases/new.html.erb`

**Intent**: Apply helpers to metadata fields and each log source slot; show inline
errors; repopulate safe slot values.

**Contract**:

- Title field: error class, inline `<span class="field-error">`, `aria-invalid`,
  `aria-describedby` when `errors[:title]` present.
- Each log source fieldset: add `fieldset--invalid` when slot N in
  `invalid_source_slot_numbers` or when `missing_sources_error?` (paste fields).
- `select_tag` / `text_field_tag` use `@source_slots[index][:source_type]` /
  `[:name]`; `pasted_content` textarea value always blank/nil.
- When `@paste_cleared_on_validation_failure`, show `.callout` or `.card__hint`
  near log sources: pasted content cleared for security — re-paste to continue.
- Keep global `#error_explanation` banner.

#### 3. Invalid field CSS

**File**: `app/assets/stylesheets/application.css`

**Intent**: Visible invalid state matching existing danger palette.

**Contract**: Add styles for `.form-field--invalid` (border/outline on inputs),
`.fieldset--invalid` (fieldset border/legend emphasis), `.field-error` (inline
text using `--color-danger-text`). Follow existing `#error_explanation` tokens.

#### 4. Helper spec

**File**: `spec/helpers/debugging_cases_helper_spec.rb` (new)

**Intent**: Unit-test slot number parsing and missing-sources detection from error
objects without full request cycle.

**Contract**: Cover `"source 2 has an invalid source type"` and global sources message.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/helpers/debugging_cases_helper_spec.rb`
- `mise exec -- bin/rubocop`

#### Manual Verification:

- Start dev server; submit form with blank title — title field shows red border +
  inline error; banner still visible.
- Submit with paste but no source type — correct slot highlighted; type/name preserved
  if previously selected; paste empty with security hint.

---

## Phase 3: Test coverage across layers

### Overview

Extend request, system, and E2E specs for field highlighting, source metadata
repopulation, and unchanged paste security oracles.

### Changes Required:

#### 1. Request specs — field UX + repopulation

**File**: `spec/requests/debugging_cases_spec.rb`

**Intent**: Assert HTML contains invalid field markers and repopulated source type
without echoing paste.

**Contract**:

- Blank title: response includes `form-field--invalid` (or aria-invalid on title input)
  and preserved title value (existing).
- Invalid source type on slot 1: body includes invalid marker on fieldset/slot;
  selected `source_type` value preserved in `<select>`; body does **not** include
  pasted secret string (extend existing security pattern).
- New case: slot 2 invalid with slot 1 empty — error text includes `"source 2"`.

#### 2. Security spec — unchanged paste oracle

**File**: `spec/requests/debugging_cases_security_spec.rb`

**Intent**: Confirm paste still never appears after failure when field highlighting added.

**Contract**: Existing examples remain green; add assertion that
`form-field--invalid` or `aria-invalid` present when failure includes paste —
optional strengthening, not replacement of negated secret assertion.

#### 3. System specs — visible highlighting

**File**: `spec/system/debugging_case_validation_spec.rb`

**Intent**: Browser-level proof of field error styling and source type preservation.

**Contract**:

- Blank title example: `have_css(".form-field--invalid")` or title input
  `[aria-invalid='true']`.
- New example: fill slot 1 paste + invalid source type + name → submit → name and
  type preserved, paste field empty, invalid styling on slot 1 fieldset.

#### 4. E2E specs — Playwright parity

**File**: `e2e/debugging-case-validation.spec.ts`

**Intent**: Mirror new system assertions in real Chromium.

**Contract**:

- Extend “no log sources” test: expect title field invalid state (class or
  `aria-invalid`).
- Add test: invalid source type with paste — type/name preserved, paste empty,
  security hint visible. Paste-not-rerendered proof stays in RSpec only (TD-8).

### Success Criteria:

#### Automated Verification:

- `mise exec -- bin/ci`
- `mise exec -- bundle exec rspec spec/system/debugging_case_validation_spec.rb`
- `PORT=3010 CI=1 mise exec -- bin/e2e e2e/debugging-case-validation.spec.ts`

#### Manual Verification:

- Run `bin/e2e --headed e2e/debugging-case-validation.spec.ts` — error styling
  readable in real browser (not rack_test).

**Implementation Note**: After Phase 3 automated gates pass, confirm manual browser
check before archiving the change.

---

## Testing Strategy

### Unit Tests:

- `CaseSubmission` slot-index fix (Phase 1).
- Helper error parsing (Phase 2 — required helper spec).

### Request Tests:

- Field markers, metadata + source_type/name repopulation, paste never in body.

### System / E2E Tests:

- Visible invalid styling; source metadata preserved; paste cleared with hint.

### Security Tests (must not regress):

- `debugging_cases_security_spec.rb` — no raw paste in 422 response body.

## Performance Considerations

Negligible — helper parsing over small error arrays; no extra DB queries.

## Migration Notes

None. Pure presentation + controller ivar change; no schema migration.

## References

- Research: `context/changes/form-validation-refinement/research.md`
- S-02 intake contract: `context/archive/2026-05-27-safe-multi-source-intake/plan.md`
- Capybara validation parity: `spec/system/debugging_case_validation_spec.rb`
- Playwright validation parity: `e2e/debugging-case-validation.spec.ts`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Validator fix and controller form state

#### Automated

- [ ] 1.1 `bundle exec rspec spec/services/intake/case_submission_spec.rb`
- [ ] 1.2 `bundle exec rspec spec/requests/debugging_cases_spec.rb`

#### Manual

- [ ] 1.3 None for this phase

### Phase 2: View helpers, template, and CSS

#### Automated

- [ ] 2.1 `bundle exec rspec spec/helpers/debugging_cases_helper_spec.rb`
- [ ] 2.2 `bin/rubocop`

#### Manual

- [ ] 2.3 Dev browser: blank title shows field highlight + inline error
- [ ] 2.4 Dev browser: paste + invalid type shows slot highlight, type/name kept, paste cleared with hint

### Phase 3: Test coverage across layers

#### Automated

- [ ] 3.1 `bin/ci`
- [ ] 3.2 `bundle exec rspec spec/system/debugging_case_validation_spec.rb`
- [ ] 3.3 `PORT=3010 CI=1 bin/e2e e2e/debugging-case-validation.spec.ts`

#### Manual

- [ ] 3.4 Headed Playwright: validation styling readable in Chromium
