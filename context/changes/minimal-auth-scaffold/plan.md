# Minimal Auth Scaffold (F-01) Implementation Plan

## Overview

Land roadmap **F-01**: Devise email/password authentication with only `database_authenticatable`, `registerable`, and `validatable`; a `users` table; generator Devise views; per-controller session gating via a shared authenticated base controller; a placeholder signed-in root page; and minimal layout navigation. This unblocks **S-01** (`account-access`) and all case-related slices without implementing case ownership or tests in this change.

## Current State Analysis

- **Auth:** Absent — no Devise gem, no `User` model, empty `db/schema.rb` (`version: 0`).
- **Routes:** Only `GET /up` health check (`config/routes.rb:6`).
- **Controllers:** `ApplicationController` only — no `before_action` auth (`app/controllers/application_controller.rb:1-7`).
- **Views:** Default Rails layout with scaffold branding (`app/views/layouts/application.html.erb:4-8` still says "Bootstrap Scaffold").
- **Tests:** No `spec/` or `test/` tree; RSpec deferred to **S-01** per planning decision.
- **Param filtering:** `:passw` (covers passwords) already in `config/initializers/filter_parameter_logging.rb:6-8`.

### Key Discoveries:

- `AGENTS.md` hard-limits Devise to three modules — no recoverable, confirmable, lockable, or OAuth.
- PRD Access Control requires flat per-user ownership later; F-01 only exposes `current_user` (no Pundit/CanCan).
- Fly health checks depend on public `/up` (`fly.toml` / `config/routes.rb`).

## Desired End State

After this plan:

1. A visitor can register, sign in, and sign out via standard Devise routes and generator ERB views.
2. `GET /` renders a minimal placeholder page only when authenticated; guests are redirected to sign-in (Devise default + explicit routing).
3. `GET /up` returns 200 without a session (unchanged for deploy health).
4. `users` exists in SQLite with Devise-required columns; `bin/ci` passes with no new test framework.
5. Future domain controllers have a documented pattern: inherit an authenticated base controller (not a global `ApplicationController` hook).

### Verification

- Manual: full sign-up → sign-in → placeholder root → sign-out → guest blocked from root; `/up` still OK.
- Automated: `mise exec -- bin/ci` green after `db:migrate`.

## What We're NOT Doing

- RSpec or any new test framework (deferred to **S-01** `account-access`).
- Debugging case models, ownership authorization, or cross-user isolation specs.
- Global `before_action :authenticate_user!` on `ApplicationController`.
- Extra Devise modules (`trackable`, `confirmable`, `recoverable`, `lockable`, OAuth).
- Custom password policy beyond Devise defaults (≥ 6 characters).
- Custom-styled auth UI or full application chrome (nav beyond email + sign out).
- Active Record Encryption, case routes, or AI/log intake.

## Implementation Approach

Use the standard Devise install/generator flow constrained to AGENTS.md modules. Introduce `AuthenticatedController < ApplicationController` with `before_action :authenticate_user!` so gating is **per-controller by inheritance** without a global hook. Mount `devise_for :users`, add a thin `DashboardController` (or `HomeController`) as the authenticated root placeholder, and keep the health route outside Devise and outside authenticated controllers.

## Critical Implementation Details

**Per-controller gating contract:** Do not add `authenticate_user!` to `ApplicationController`. Domain controllers added in later changes must inherit `AuthenticatedController` (or declare their own `before_action`). Document this in a one-line comment on `AuthenticatedController` so implementers of F-02/S-02 do not accidentally expose case routes.

## Phase 1: Devise & User Model

### Overview

Add Devise, configure minimal modules, create `User`, and migrate SQLite.

### Changes Required:

#### 1. Dependencies

**File**: `Gemfile`

**Intent**: Add the `devise` gem to the main bundle group so authentication is available in all environments.

**Contract**: New `gem "devise"` entry; run `mise exec -- bundle install` so `Gemfile.lock` updates.

#### 2. Devise installation

**Files**: `config/initializers/devise.rb`, `config/locales/devise.en.yml` (generator output), `config/environments/development.rb` / `production.rb` (mailer default URL if generator sets it)

**Intent**: Run `rails generate devise:install` and keep only stock configuration required for email/password sessions; no extra modules in the initializer.

**Contract**: Devise initializer loads; flash keys and mailer sender left at sensible defaults for MVP (localhost in development).

#### 3. User model & migration

**Files**: `app/models/user.rb`, `db/migrate/*_devise_create_users.rb`, `db/schema.rb`

**Intent**: Generate `User` with Devise and enable only `:database_authenticatable`, `:registerable`, `:validatable`.

**Contract**: Migration creates `users` with standard Devise columns (`email`, `encrypted_password`, `reset_password_token` may exist in migration template but unused modules stay disabled on the model); `User` model module list matches AGENTS.md exactly.

#### 4. Database prepare

**Intent**: Apply migration so the app boots with a `users` table.

**Contract**: `mise exec -- bin/rails db:migrate` succeeds; `db/schema.rb` version > 0 with `users` table.

### Success Criteria:

#### Automated Verification:

- Bundle resolves: `mise exec -- bundle install`
- Migration applies: `mise exec -- bin/rails db:migrate`
- App loads models: `mise exec -- bin/rails runner 'puts User.count'`

#### Manual Verification:

- `mise exec -- bin/rails console` can instantiate `User.new(email: 'a@b.com', password: 'secret')` (valid or invalid per validations)

**Implementation Note**: Pause for human confirmation after automated checks before Phase 2.

---

## Phase 2: Routes & Session Gating

### Overview

Wire Devise routes, authenticated base controller, placeholder root, and preserve public health check.

### Changes Required:

#### 1. Authenticated base controller

**File**: `app/controllers/authenticated_controller.rb`

**Intent**: Centralize session requirement for app pages without global ApplicationController filter.

**Contract**: Subclass of `ApplicationController` with `before_action :authenticate_user!`; short comment referencing future case controllers.

#### 2. Placeholder dashboard

**Files**: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/show.html.erb` (or `index`)

**Intent**: Prove end-to-end session gating with a trivial signed-in-only page at `/`.

**Contract**: Inherits `AuthenticatedController`; action renders minimal copy (e.g. signed-in email); no case data.

#### 3. Routes

**File**: `config/routes.rb`

**Intent**: Register Devise, set authenticated root, leave health check public.

**Contract**: `devise_for :users`; `root` points to dashboard#show (or index); `get "up"` remains as today with no auth wrapper.

#### 4. ApplicationController helpers

**File**: `app/controllers/application_controller.rb`

**Intent**: Ensure Devise helpers are available to views (`current_user`, `user_signed_in?`) without global authentication.

**Contract**: No `before_action :authenticate_user!` on `ApplicationController`; optional `protect_from_forgery` unchanged.

### Success Criteria:

#### Automated Verification:

- Routes list includes Devise and root: `mise exec -- bin/rails routes | grep -E 'devise|root|dashboard'`
- CI passes: `mise exec -- bin/ci`

#### Manual Verification:

- Guest visiting `/` redirects to sign-in
- Signed-in user visiting `/` sees placeholder (no 500)
- `curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/up` returns `200` without session

**Implementation Note**: Pause for human confirmation after manual routing checks before Phase 3.

---

## Phase 3: Views & Layout Shell

### Overview

Expose generator Devise views and minimal session affordances in the app layout.

### Changes Required:

#### 1. Devise views

**Files**: `app/views/devise/**` (generator output)

**Intent**: Use stock Devise ERB templates for registration, session, and shared links.

**Contract**: `rails generate devise:views` (or equivalent) produces sign-in, sign-up, and shared partials; forms POST to Devise routes.

#### 2. Layout navigation

**File**: `app/views/layouts/application.html.erb`

**Intent**: Show signed-in user email and a sign-out link when authenticated; hide when guest.

**Contract**: Conditional on `user_signed_in?`; `button_to` or `link_to` sign-out uses Devise route helpers; no case navigation yet.

#### 3. Branding cleanup

**File**: `app/views/layouts/application.html.erb`

**Intent**: Replace bootstrap scaffold placeholder titles with SafeLog AI naming.

**Contract**: `<title>` and `application-name` meta reflect project name (align with product, not generator default).

### Success Criteria:

#### Automated Verification:

- CI passes: `mise exec -- bin/ci`

#### Manual Verification:

- Register new account via `/users/sign_up`
- Sign in via `/users/sign_in`
- Layout shows email + sign out on dashboard and Devise pages after sign-in
- Sign out returns guest to signed-out state; cannot access `/` without signing in again

**Implementation Note**: Pause for human confirmation after UI smoke before Phase 4.

---

## Phase 4: Verify & Handoff Documentation

### Overview

Confirm CI green, record the per-controller auth contract for downstream changes, and update change identity.

### Changes Required:

#### 1. Change notes (optional, surgical)

**File**: `context/changes/minimal-auth-scaffold/change.md`

**Intent**: Append a short completion note only if useful for S-01 handoff — do not rewrite AGENTS.md.

**Contract**: `status: planned` → `implementing`/`implemented` is owned by implement skill; plan step only ensures `updated` date if edited manually later.

#### 2. Implementer handoff comment

**File**: `app/controllers/authenticated_controller.rb` (or `context/changes/minimal-auth-scaffold/change.md` Notes)

**Intent**: State explicitly that F-02/S-02 controllers must inherit `AuthenticatedController`.

**Contract**: One paragraph max; points to roadmap S-01 for RSpec auth coverage.

### Success Criteria:

#### Automated Verification:

- Full CI: `mise exec -- bin/ci`

#### Manual Verification:

- Repeat end-to-end smoke: register → root → sign out → guest blocked
- Confirm no raw/log-related code touched (auth-only change)

---

## Testing Strategy

### Unit Tests:

- None in F-01 (deferred to S-01 per decision).

### Integration Tests:

- None in F-01.

### Manual Testing Steps:

1. `mise exec -- bin/dev` — open app root as guest; expect redirect to sign-in.
2. Register with email/password (≥ 6 chars); expect redirect to signed-in root placeholder.
3. Confirm layout shows email and sign-out.
4. Sign out; confirm `/` requires sign-in again.
5. `curl` or browser: `/up` returns 200 as guest.
6. Run `mise exec -- bin/ci` locally before PR.

## Performance Considerations

Negligible — single-session cookie auth, no external IdP. SQLite `users` table is tiny for MVP scale.

## Migration Notes

First real migration in the repo. Use `db:migrate` (not hand-editing `schema.rb`). Rollback path: `db:rollback` on the Devise migration if install fails mid-way.

## References

- Roadmap F-01: `context/foundation/roadmap.md` (Minimal auth scaffold)
- PRD Access Control: `context/foundation/prd.md` §Access Control, FR-001
- AGENTS.md Devise module constraint
- Change identity: `context/changes/minimal-auth-scaffold/change.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Devise & User Model

#### Automated

- [x] 1.1 Bundle resolves: `mise exec -- bundle install`
- [x] 1.2 Migration applies: `mise exec -- bin/rails db:migrate`
- [x] 1.3 App loads models: `mise exec -- bin/rails runner 'puts User.count'`

#### Manual

- [ ] 1.4 Console can build `User` with email/password validations

### Phase 2: Routes & Session Gating

#### Automated

- [ ] 2.1 Routes include Devise and root
- [ ] 2.2 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 2.3 Guest `/` redirects to sign-in
- [ ] 2.4 Signed-in `/` shows placeholder
- [ ] 2.5 `/up` returns 200 without session

### Phase 3: Views & Layout Shell

#### Automated

- [ ] 3.1 CI passes: `mise exec -- bin/ci`

#### Manual

- [ ] 3.2 Register and sign in via Devise views
- [ ] 3.3 Layout shows email and sign out when signed in
- [ ] 3.4 Sign out blocks access to `/`

### Phase 4: Verify & Handoff Documentation

#### Automated

- [ ] 4.1 Full CI: `mise exec -- bin/ci`

#### Manual

- [ ] 4.2 End-to-end auth smoke repeated
- [ ] 4.3 Confirmed auth-only scope (no log/case code)
