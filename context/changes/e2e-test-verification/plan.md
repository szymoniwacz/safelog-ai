# E2E Test Verification Implementation Plan

## Overview

Close Playwright browser E2E gaps identified in `research.md` by adding three
risk-driven specs under `e2e/` (excluding `capture-*` screenshot specs). Each
new spec mirrors an existing Capybara system example at real-Chromium depth for
Demo Day certification. Security oracles (DB scans, prompt inspection,
encryption, IDOR matrix beyond show-page 404) remain in RSpec only.

## Current State Analysis

Playwright today: 5 regression tests in 3 files (`authentication.spec.ts`,
`debugging-case-flow.spec.ts`, `demo-case.spec.ts`). Capybara covers two
additional user-visible edge cases Playwright lacks: form validation UX and
cross-user case isolation. Invalid sign-in is request-spec only.

### Key Discoveries:

- Capybara parity targets: `spec/system/debugging_case_validation_spec.rb`,
  `spec/system/user_isolation_spec.rb`, `spec/requests/devise/sessions_spec.rb`
  (invalid password)
- Existing Playwright patterns: `getByRole`, `getByLabel`, scoped `fieldset`
  legends, helpers in `e2e/helpers.ts` (`signUp`, `signIn`, `fillLogSourceSlot`)
- No `storageState` usage yet — introduce for signed-in setup reuse (per user
  constraint and Playwright best practice for multi-step specs)
- Playwright runs via `mise exec -- bin/e2e` against `RAILS_ENV=test`
  (`bin/e2e-server`); no Rails factory access from TypeScript — owner case in
  isolation spec must be seeded via owner UI session
- Analyze failure UX (risk #7) is **blocked**: `ClientResolver` always returns
  `FakeClient` in test env — out of scope for this change

## Desired End State

After this plan:

1. **`e2e/debugging-case-validation.spec.ts`** — 2 tests mirroring Capybara
   validation examples (no sources error; metadata preserved on error).
2. **`e2e/user-isolation.spec.ts`** — 1 test: other user visits owner case URL
   → public 404 page, no case title, no sanitized placeholder text.
3. **`e2e/authentication.spec.ts`** — 1 new test: invalid password stays on
   sign-in with Devise error copy; password not shown in page body.
4. **`e2e/helpers.ts`** — `storageState` auth helpers for signed-in setup reuse.
5. Playwright regression count: 5 → 9 tests (excluding `capture-*`).
6. All existing Playwright, Capybara, and request specs remain green; no RSpec
   security oracle duplication in browser layer.

### Verification

- Each phase: targeted Playwright run → full `bin/e2e` → `bin/ci`
- Optional one-time Demo Day browser smoke after Phase 3 (manual only)

## What We're NOT Doing

- Adding or weakening existing tests in `spec/` or `e2e/` (except additive edits
  to `authentication.spec.ts` and `helpers.ts`)
- Duplicating RSpec security oracles in Playwright (DB scan, prompt inspection,
  log-file guards, export sanitization proofs, encryption-at-rest)
- Cross-user analyze / archive / export browser matrix (stays in request specs)
- Analyze failure flash UX (risk #7) — blocked without `ClientResolver` test hook
- Production demo-loader gate browser spec (env stub stays in request specs)
- Cases index status badges / empty-state-only coverage (deferred per research)
- Clipboard/copy-button automation for sanitized logs or report markdown
- Wiring Playwright into `bin/ci` or GitHub Actions
- Modifying `capture-*` screenshot specs

## Implementation Approach

Add one new Playwright spec per phase, bottom-up by dependency:

1. Validation spec first — single-user, reuses existing sign-up flow; introduces
   `storageState` helper for signed-in reuse.
2. User isolation second — depends on `storageState` for owner session that
   creates a case via UI; other user uses fresh `signUp`.
3. Invalid sign-in last — isolated edit to `authentication.spec.ts`; no auth
   state file needed.

All assertions use UI-visible oracles only (`getByRole`, `getByLabel`, heading
text, field values). Do not add DB queries, network interception, or prompt
capture from the browser layer.

## Critical Implementation Details

**User isolation seeding:** Playwright cannot call `Intake::ProcessCaseSubmission`
directly. Owner must create a case through the UI in `test.beforeAll` (serial
suite). Capture the case show URL from `page.url()` after create. The test
body signs up a *different* user in a fresh context (no owner cookies) and
visits that URL. Mirror visible assertions from
`spec/system/user_isolation_spec.rb` — public 404 copy, absent case title,
absent `[REQUEST_1]`.

**storageState files:** Write auth state under `e2e/.auth/` (gitignored). Add
`e2e/.auth/` to `.gitignore` if absent. Do not commit storage state files.

**Validation path quirk:** Failed create is `render :new, status: :unprocessable_entity`
on POST `/debugging_cases` — no redirect. Browser URL stays **`/debugging_cases`**
(same as Capybara `debugging_cases_path` in
`spec/system/debugging_case_validation_spec.rb:17`). Assert error copy, "New
debugging case" heading, and preserved field values; optional
`toHaveURL(/\/debugging_cases$/)` for Capybara parity. Do **not** expect
`/debugging_cases/new` after failed POST.

## Phase 1: Form Validation UX (`e2e/debugging-case-validation.spec.ts`)

### Overview

Risk group: MVP intake constraint — user must submit at least one log source;
metadata must survive validation errors. Playwright parity with Capybara
`debugging_case_validation_spec.rb`.

### Changes Required:

#### 1. Auth helper with storageState

**File**: `e2e/helpers.ts`

**Intent**: Add helper to sign up a user and persist browser storage state to a
file path for reuse across tests in the same spec (e.g.
`saveAuthStorageState(page, path)` wrapping `page.context().storageState()`).
Optionally add `createAuthenticatedContext(browser, storagePath)` for
`browser.newContext({ storageState })`.

**Contract**: Exported functions usable from spec `beforeAll` / `beforeEach`;
paths under `e2e/.auth/`; no change to existing `signUp` / `signIn` signatures.

#### 2. Gitignore auth artifacts

**File**: `.gitignore`

**Intent**: Ignore `e2e/.auth/` so storage state files are never committed.

**Contract**: Single line entry; no other gitignore churn.

#### 3. Validation spec (new)

**File**: `e2e/debugging-case-validation.spec.ts`

**Intent**: Two tests mirroring Capybara validation examples:

1. **No log sources** — signed-in user fills Title only, clicks "Create
   debugging case", sees error copy ("prohibited this case from being saved",
   "must include at least one non-blank log source"), form heading "New
   debugging case" visible, Title field retains "Missing sources case".
2. **Metadata preserved** — signed-in user fills Title, Description, Customer
   reference, Environment, submits without sources, all four fields retain
   values after error.

Use `getByRole` / `getByLabel` selectors. Use `storageState` from `beforeAll`
sign-up to avoid repeating registration in each test.

**Contract**: No log source slots filled; no assertions on raw pasted secrets;
no DB or network oracles.

### Success Criteria:

#### Automated Verification:

- Targeted Playwright run:
  `mise exec -- bin/e2e e2e/debugging-case-validation.spec.ts`
- Full Playwright suite: `mise exec -- bin/e2e`
- Full CI gate: `mise exec -- bin/ci`

#### Manual Verification:

- None required for this phase

**Implementation Note**: Pause after automated verification passes before Phase 2.

---

## Phase 2: User Isolation UX (`e2e/user-isolation.spec.ts`)

### Overview

Risk group: #3 access control — user-visible half. Other user must see public
404 when visiting an owner case URL; no sanitized content leak on page. Request
spec matrix for analyze/archive/export stays in RSpec.

### Changes Required:

#### 1. User isolation spec (new)

**File**: `e2e/user-isolation.spec.ts`

**Intent**: One test mirroring `spec/system/user_isolation_spec.rb`:

- **`test.beforeAll` (serial):** Owner signs up via UI, creates minimal case
  (title "Owner-only browser case", one Rails log source with
  `request_id=req-browser-isolation-1`), saves owner `storageState` optional,
  records case show URL.
- **Test body:** Fresh user signs up (no owner cookies), navigates to recorded
  case URL, asserts:
  - Heading or text: "The page you were looking for doesn't exist" (public 404)
  - `getByRole('heading', { name: 'Owner-only browser case' })` not visible
  - "Sanitized log sources" heading not visible
  - `[REQUEST_1]` not visible

Use `getByRole` throughout. Do not assert HTTP status via API; assert visible
404 page copy only.

**Contract**: Case seeded via owner UI only; no test-only API endpoint; no
cross-user analyze/archive/export actions. File opens with
`test.describe.configure({ mode: 'serial' })` so `beforeAll` ordering stays
explicit if more tests are added later (global config already sets
`fullyParallel: false`, `workers: 1`).

### Success Criteria:

#### Automated Verification:

- Targeted Playwright run:
  `mise exec -- bin/e2e e2e/user-isolation.spec.ts`
- Full Playwright suite: `mise exec -- bin/e2e`
- Full CI gate: `mise exec -- bin/ci`

#### Manual Verification:

- None required for this phase

**Implementation Note**: Pause after automated verification passes before Phase 3.

---

## Phase 3: Invalid Sign-In UX (`e2e/authentication.spec.ts`)

### Overview

Risk group: FR-001 auth edge case — wrong password shows safe error UX without
echoing the submitted password. Request spec owns status-code and no-leak
oracle; Playwright adds browser-visible confirmation only.

### Changes Required:

#### 1. Invalid sign-in test (edit existing spec)

**File**: `e2e/authentication.spec.ts`

**Intent**: Add test "does not sign in with invalid password":

- Create user via `signUp` with known password
- Sign out from header
- Fill sign-in form manually (`getByLabel` Email/Password, click "Sign in") with
  wrong password — **do not** call `signIn()` (helper asserts success flash at
  `e2e/helpers.ts:32` and will fail on 422)
- Assert remains on sign-in page (`Sign in to SafeLog AI` heading visible)
- Assert Devise `#error_explanation` or equivalent error copy visible
- Assert page body does not contain the wrong password string

Use `getByRole` / `getByLabel`. Do not weaken existing three auth tests.

**Contract**: Additive test only; existing guest redirect, sign up, and sign
in-after-sign-out tests unchanged in behavior.

### Success Criteria:

#### Automated Verification:

- Targeted Playwright run:
  `mise exec -- bin/e2e e2e/authentication.spec.ts`
- Full Playwright suite: `mise exec -- bin/e2e`
- Full CI gate: `mise exec -- bin/ci`

#### Manual Verification:

- Optional Demo Day smoke: run `mise exec -- bin/e2e` once in a visible browser
  (`PWDEBUG=1` or `--headed`) and spot-check validation errors and 404 page
  render correctly in Chromium layout

**Implementation Note**: Phase 3 completes this change.

---

## Testing Strategy

### Playwright E2E (this change):

- Form validation — error copy, field preservation, signed-in context via
  `storageState`
- User isolation — public 404, no owner content or placeholders visible
- Invalid sign-in — error UX, no password echo in DOM

### RSpec (regression gates only — no new specs):

- Run full `bin/ci` after each phase to prove no weakening of request, service,
  model, or Capybara layers
- Do not add Playwright specs that duplicate
  `assert_no_raw_substring_in_persisted_data`, prompt capture, or authorization
  matrix oracles

### Manual Testing Steps:

1. Optional after Phase 3: headed Chromium run of full `bin/e2e` before Demo Day
2. Confirm validation error styling readable in real browser (not rack_test)

## Performance Considerations

Adding 4 Playwright tests increases local `bin/e2e` runtime modestly (~30–60s
total suite per test-plan §6.9). `workers: 1` and serial isolation setup avoid
DB collisions on shared test server.

## Migration Notes

No application code, schema, or route changes. Test-only additions under `e2e/`
and `.gitignore`.

## References

- Research: `context/changes/e2e-test-verification/research.md`
- Test plan: `context/foundation/test-plan.md` §6.8–§6.9, §7
- Capybara parity: `spec/system/debugging_case_validation_spec.rb`,
  `spec/system/user_isolation_spec.rb`
- Request auth oracle: `spec/requests/devise/sessions_spec.rb`
- Optional post-implement: update `context/foundation/test-plan.md` §6.9
  Playwright coverage map (5 → 9 tests, new file names) when closing this change

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Form Validation UX (`e2e/debugging-case-validation.spec.ts`)

#### Automated

- [x] 1.1 Targeted Playwright run: `mise exec -- bin/e2e e2e/debugging-case-validation.spec.ts` — b9ddf2a
- [x] 1.2 Full Playwright suite: `mise exec -- bin/e2e` — b9ddf2a
- [x] 1.3 Full CI gate: `mise exec -- bin/ci` — b9ddf2a

#### Manual

_(none)_

### Phase 2: User Isolation UX (`e2e/user-isolation.spec.ts`)

#### Automated

- [x] 2.1 Targeted Playwright run: `mise exec -- bin/e2e e2e/user-isolation.spec.ts` — 3f9ab8a
- [x] 2.2 Full Playwright suite: `mise exec -- bin/e2e` — 3f9ab8a
- [x] 2.3 Full CI gate: `mise exec -- bin/ci` — 3f9ab8a

#### Manual

_(none)_

### Phase 3: Invalid Sign-In UX (`e2e/authentication.spec.ts`)

#### Automated

- [x] 3.1 Targeted Playwright run: `mise exec -- bin/e2e e2e/authentication.spec.ts`
- [x] 3.2 Full Playwright suite: `mise exec -- bin/e2e`
- [x] 3.3 Full CI gate: `mise exec -- bin/ci`

#### Manual

- [ ] 3.4 Optional Demo Day smoke: headed Chromium run of `mise exec -- bin/e2e`
