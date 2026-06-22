<!-- PLAN-REVIEW-REPORT -->
# Plan Review: E2E Test Verification Implementation Plan

- **Plan**: `context/changes/e2e-test-verification/plan.md`
- **Mode**: Deep
- **Date**: 2026-06-20
- **Verdict**: SOUND (after triage fixes)
- **Findings**: 0 critical, 2 warnings, 2 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| End-State Alignment | PASS ✅ |
| Lean Execution | PASS ✅ |
| Architectural Fitness | PASS ✅ |
| Blind Spots | WARNING ⚠️ |
| Plan Completeness | WARNING ⚠️ |

## Grounding

Grounding: 7/7 paths ✓, 4/4 symbols ✓, brief↔plan ✓

Paths verified: `e2e/helpers.ts`, `e2e/authentication.spec.ts`, `e2e/debugging-case-flow.spec.ts`, `spec/system/debugging_case_validation_spec.rb`, `spec/system/user_isolation_spec.rb`, `.gitignore`, `bin/e2e`.

Symbols verified: `signUp`, `signIn`, `fillLogSourceSlot` (no `storageState` yet — planned addition), `DebuggingCasesController#create` render-on-failure.

## Findings

### F1 — Phase 3 cannot use `signIn()` helper as-is

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 3 — Invalid Sign-In UX
- **Detail**: Plan says “Attempt `signIn` with wrong password (or fill form manually)” but `e2e/helpers.ts:32` always asserts `Signed in as ${email}.` Invalid credentials return 422 with Devise `#error_explanation` and no success flash (`spec/requests/devise/sessions_spec.rb:23-33`). Calling `signIn()` with a wrong password will fail at the helper assertion before the test can assert error UX.
- **Fix**: In Phase 3 Intent/Contract, require manual form fill + submit (or a new `attemptSignIn` helper without success assertion). Explicitly forbid calling existing `signIn()` for the failure path.
- **Decision**: FIXED — manual form fill required; `signIn()` forbidden on failure path

### F2 — Failed-create URL guidance is imprecise

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Critical Implementation Details — Validation path quirk
- **Detail**: Plan hedges that URL “may be `/debugging_cases/new` or POST redirect target.” Code shows `create` calls `render :new, status: :unprocessable_entity` on failure (`app/controllers/debugging_cases_controller.rb:37`) — no redirect. Browser URL stays **`/debugging_cases`** (POST target). Capybara confirms `have_current_path(debugging_cases_path)` (`spec/system/debugging_case_validation_spec.rb:17`). `/debugging_cases/new` is not the failure URL.
- **Fix**: Replace hedged URL note with: assert error copy + “New debugging case” heading + field values; optional `toHaveURL(/\/debugging_cases$/)` parity with Capybara. Do not expect `/debugging_cases/new` after failed POST.
- **Decision**: FIXED — `/debugging_cases` documented as failure URL

### F3 — `test-plan.md` §6.9 coverage map not in plan

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Lean Execution
- **Location**: What We're NOT Doing / plan-brief Out of scope
- **Detail**: Brief defers `test-plan.md` updates as optional follow-up. After implementation, §6.9 Playwright coverage map will be stale (5 tests → 9, new file names). Not blocking implement, but doc drift if forgotten.
- **Fix**: Add optional Phase 4 or post-implement note: update `context/foundation/test-plan.md` §6.9 table and Phase 6 note. Or accept drift until next test-plan refresh.
- **Decision**: FIXED — optional post-implement note added to References

### F4 — Isolation spec relies on global serial config, not explicit `describe.serial`

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architectural Fitness
- **Location**: Phase 2 — User Isolation UX
- **Detail**: Plan specifies `test.beforeAll (serial)` but `playwright.config.ts` already sets `fullyParallel: false` and `workers: 1`. With only one test in the file, this is safe today. If more tests are added later without `test.describe.configure({ mode: 'serial' })`, ordering assumptions could break.
- **Fix**: In Phase 2 Contract, add `test.describe.configure({ mode: 'serial' })` at file top for explicit intent (belt-and-suspenders). Optional — global config already sufficient for single-test file.
- **Decision**: FIXED — serial configure added to Phase 2 Contract

## Internal consistency checks

- **Contradiction scan**: No “What We're NOT Doing” items reappear in phases. Analyze failure correctly excluded despite research open question.
- **Promise gap**: All Desired End State items (3 specs, helpers, 9 tests, bin/ci green) map to Phases 1–3.
- **Progress↔Phase**: One `## Progress` section; 3 phase subsections; 10 automated + 1 manual checkbox match Success Criteria bullets. Phase blocks use plain `-` bullets only.
- **Test count**: 3 existing auth + 1 new + 1 flow + 1 demo + 2 validation + 1 isolation = 9 ✓

## Positive notes

- Cost×signal respected: security oracles stay in RSpec; Playwright asserts UI only.
- Phases are right-sized (one spec/risk group each) with correct gate order (targeted → full e2e → ci).
- User isolation seeding via owner UI is the correct constraint given no TypeScript factory access.
- `.gitignore` gap for `e2e/.auth/` is already called out in Phase 1.
