# Account Access (S-01) Implementation Plan

## Overview

Land roadmap **S-01**: automated proof that email/password sign-up, sign-in, sign-out, and authenticated root access work on top of F-01 Devise scaffold. Adds FactoryBot, Devise request helpers, and request specs; optional minimal auth UI copy polish. Unblocks **S-02** (`safe-multi-source-intake`) without adding case routes or cross-user case authorization (that arrives with cases in S-02).

## Current State Analysis

- **Auth scaffold:** F-01 complete — `devise_for :users`, `User` model, generator Devise views under `app/views/devise/`.
- **Gating:** `DashboardController < AuthenticatedController` with `before_action :authenticate_user!`; root is `dashboard#show` (`config/routes.rb:13`).
- **Layout:** SafeLog AI title, flash display, signed-in nav with email + sign out (`app/views/layouts/application.html.erb`).
- **Tests:** RSpec + WebMock from F-03; **no** request/model factories or auth specs yet.
- **Health:** `GET /up` public (`config/routes.rb:7`).

### Key Discoveries:

- F-01 explicitly deferred RSpec to S-01 (`context/changes/minimal-auth-scaffold/plan.md:39`).
- `AuthenticatedController` comment points cross-user request coverage to S-01 — but with no case routes yet, S-01 covers **session gating only**; case isolation specs belong in S-02.
- AGENTS.md limits Devise to `database_authenticatable`, `registerable`, `validatable`.
- PRD FR-001 / US-01 require sign-up and sign-in; acceptance criterion "user A cannot access user B's case" needs case endpoints (S-02).

## Desired End State

After this plan:

1. Visitor can register via `POST /users` (Devise), sign in, reach `/`, sign out.
2. Guest `GET /` redirects to Devise sign-in.
3. Request specs cover registration success, invalid login, sign-out, and root gating.
4. `bin/ci` runs new specs green.
5. Devise auth pages use consistent SafeLog AI copy (minimal — no design system).

### Verification

- Automated: `bundle exec rspec spec/requests/` (or auth paths), `bin/ci`.
- Manual: browser sign-up → dashboard → sign-out → guest blocked (quick smoke).

## What We're NOT Doing

- Debugging case CRUD, intake, redaction, or AI flows (S-02+).
- Request specs for cross-user case access (S-02 — no case routes yet).
- Capybara/system specs or `rspec-rails` system test setup (speed bias; F-01 manual browser proof stands).
- OAuth, recoverable, confirmable, lockable Devise modules.
- Custom auth styling beyond light copy/nav tweaks.
- Global `authenticate_user!` on `ApplicationController`.

## Implementation Approach

Add `factory_bot_rails` for concise user setup. Configure `Devise::Test::IntegrationHelpers` for request specs. Write focused request examples against Devise routes and `GET /`. Keep UI changes to headings/copy and ensure sign-up/sign-in links visible on Devise shared links partial.

## Phase 1: Auth Test Harness

### Overview

Add FactoryBot and Devise integration helpers so request specs can create users and simulate sessions.

### Changes Required:

#### 1. FactoryBot gem

**File:** `Gemfile`

**Intent:** Add `factory_bot_rails` to `:development, :test` group.

**Contract:** `bundle install` succeeds; FactoryBot available in specs.

#### 2. FactoryBot configuration

**Files:** `spec/rails_helper.rb`, `spec/factories/users.rb`

**Intent:** `config.include FactoryBot::Syntax::Methods` in RSpec; define `:user` factory with sequence email and password meeting Devise minimum.

**Contract:** `create(:user)` persists valid `User` in test DB.

#### 3. Devise request helpers

**File:** `spec/rails_helper.rb`

**Intent:** `config.include Devise::Test::IntegrationHelpers, type: :request` (and optionally `:system` if added later).

**Contract:** Request specs can call `sign_in user` / `sign_out :user`.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle install` succeeds
- `mise exec -- bundle exec rspec spec/factories/` or smoke spec proving factory loads (optional tiny `spec/models/user_spec.rb` for factory validity — only if needed)
- `mise exec -- bin/ci`

#### Manual Verification:

- `rails console` test env: `FactoryBot.create(:user)` works via runner if desired

**Implementation Note:** Pause for human confirmation before Phase 2.

---

## Phase 2: Auth Request Specs

### Overview

Cover FR-001 flows with request specs: registration, session, sign-out, protected root.

### Changes Required:

#### 1. Registration spec

**File:** `spec/requests/devise/registrations_spec.rb`

**Intent:** `POST /users` with valid email/password creates user and redirects (Devise default after sign-up); invalid params re-render with errors (no user created).

**Contract:** Assert response redirect or success path; assert `User.count` change; do not assert raw password in response body.

#### 2. Session spec

**File:** `spec/requests/devise/sessions_spec.rb`

**Intent:** `POST /users/sign_in` with valid credentials signs in and redirects; invalid credentials fail safely without revealing whether email exists (Devise default flash/message).

**Contract:** Use factory user; assert redirect to root or stored location; assert no password in response body.

#### 3. Dashboard / root gating spec

**File:** `spec/requests/dashboard_spec.rb`

**Intent:** Guest `GET /` redirects to sign-in; signed-in user `GET /` returns success and shows signed-in content (email or heading).

**Contract:** Uses `sign_in` helper; does not expose other users' data (only one user context here).

#### 4. Sign out spec

**File:** `spec/requests/devise/sessions_spec.rb` (same file, additional examples)

**Intent:** Signed-in user `DELETE /users/sign_out` clears session; subsequent `GET /` redirects to sign-in.

**Contract:** Follow Devise/Turbo method for sign out if request spec needs `delete` — match layout `button_to` behavior.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/requests/`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: sign-up → `/` → sign-out → guest redirected from `/`

**Implementation Note:** Pause for human confirmation before Phase 3.

---

## Phase 3: Minimal Auth UX Polish

### Overview

Light copy and navigation consistency on Devise views — enough for demo-ready auth without custom CSS framework.

### Changes Required:

#### 1. Devise view copy

**Files:** `app/views/devise/sessions/new.html.erb`, `app/views/devise/registrations/new.html.erb`, optionally `app/views/devise/shared/_links.html.erb`

**Intent:** Headings mention SafeLog AI; sign-up/sign-in links clear; keep generator form structure.

**Contract:** No new stylesheets required; semantic HTML only.

#### 2. Dashboard placeholder copy

**File:** `app/views/dashboard/show.html.erb`

**Intent:** Brief welcome text pointing forward to debugging cases (S-02) without implementing case UI.

**Contract:** Still shows `current_user.email`; no new routes.

#### 3. Handoff note

**File:** `context/changes/account-access/change.md` (Notes)

**Intent:** Note S-02 adds case routes + cross-user authorization request specs on `DebuggingCase`.

**Contract:** No edits to foundation PRD files.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser check: auth pages readable; sign-up/sign-in links work

**Implementation Note:** Final phase for S-01.

---

## Testing Strategy

### Unit Tests:

- Optional: `User` factory validity only if not covered by request specs.

### Request Tests:

- Registration create (valid/invalid)
- Session create (valid/invalid)
- Session destroy
- Root gating guest vs signed-in

### Manual Testing Steps:

1. Register new user in browser.
2. Sign out and sign in again.
3. Confirm guest cannot access `/`.
4. Confirm `/up` still 200 without session.

## Performance Considerations

None — standard Devise request specs.

## Migration Notes

None.

## References

- Roadmap S-01: `context/foundation/roadmap.md`
- F-01 handoff: `context/changes/minimal-auth-scaffold/change.md`
- PRD FR-001, US-01 (partial — case isolation in S-02)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Auth Test Harness

#### Automated

- [x] 1.1 `bundle install` succeeds with FactoryBot
- [x] 1.2 User factory creates valid records in test
- [x] 1.3 `bin/ci` passes

#### Manual

- [ ] 1.4 Devise integration helpers available in request specs

### Phase 2: Auth Request Specs

#### Automated

- [x] 2.1 `bundle exec rspec spec/requests/` passes
- [x] 2.2 `bin/ci` passes

#### Manual

- [ ] 2.3 Browser auth flow smoke (sign-up, sign-in, sign-out, guest blocked)

### Phase 3: Minimal Auth UX Polish

#### Automated

- [ ] 3.1 Full `bundle exec rspec` passes
- [ ] 3.2 `bin/ci` passes

#### Manual

- [ ] 3.3 Auth pages show SafeLog copy and working links
