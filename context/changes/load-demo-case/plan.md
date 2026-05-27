# Load Demo Case (S-06) Implementation Plan

## Overview

Land roadmap **S-06** (FR-011): environment-gated demo loader that creates a checkout/payment-timeout debugging case through the standard intake pipeline.

## Current State Analysis

- Intake, analyze, export, archive complete.
- No demo fixtures or loader.
- Test env runs in CI — demo must work in test for specs.

## Desired End State

1. `Demo::CaseFixture` defines demo submission attributes (raw paste strings — transient).
2. `Demo::LoadCase.call(user:)` validates env, builds `CaseSubmission`, calls `ProcessCaseSubmission`.
3. `POST /debugging_cases/load_demo` available in dev/test only; 404 in production.
4. Dashboard shows **Load demo case** when available.
5. Specs: sanitized persistence, cross-source placeholders, production 404.
6. `bin/ci` green.

## What We're NOT Doing

- Pre-seeded DB fixtures bypassing intake.
- Demo in production/staging.
- Auto-analyze on load (user can analyze manually).

## Phase 1: Demo Fixture and Load Service

### Overview

Fixture constants and service wrapping intake.

### Changes Required:

#### 1. Case fixture

**File:** `app/services/demo/case_fixture.rb`

**Intent:** Module with `submission_attributes` returning hash for `Intake::CaseSubmission` — checkout timeout title, 2+ sources with correlating request_id, fake email/token for redaction demo.

**Contract:** Raw strings only in this file; never persisted except via redaction engine.

#### 2. Load service

**File:** `app/services/demo/load_case.rb`

**Intent:** `Demo::LoadCase.available?` → development or test; `.call(user:)` returns `ProcessCaseSubmission` result or unavailable error.

**Contract:** No DB writes when unavailable.

#### 3. Service specs

**File:** `spec/services/demo/load_case_spec.rb`

**Intent:** Creates case with 2 sources, shared `[REQUEST_1]`, no raw email in DB.

### Success Criteria:

- `bundle exec rspec spec/services/demo/`
- `bin/ci`

**Implementation Note:** Pause before Phase 2.

---

## Phase 2: Route and Controller

### Overview

HTTP entry with environment guard.

### Changes Required:

#### 1. Route

**File:** `config/routes.rb` — `post :load_demo, on: :collection`

#### 2. Controller

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `#load_demo` returns 404 unless `Demo::LoadCase.available?`; else call service, redirect to show on success.

#### 3. Request specs

**File:** `spec/requests/debugging_cases_load_demo_spec.rb`

### Success Criteria:

- Request specs pass; `bin/ci` green

**Implementation Note:** Pause before Phase 3.

---

## Phase 3: UI and Production Guard Spec

### Overview

Dashboard button; explicit production 404 spec.

### Changes Required:

#### 1. Dashboard UI

**File:** `app/views/dashboard/show.html.erb`

**Intent:** Show `button_to "Load demo case"` when `Demo::LoadCase.available?`

#### 2. Production spec

**Intent:** Stub `Rails.env.production?` → POST load_demo → 404

#### 3. Handoff

**File:** `change.md` — MVP feature slices complete

### Success Criteria:

- Full `bin/ci` green

---

## Progress

### Phase 1: Demo Fixture and Load Service

#### Automated

- [x] 1.1 `bundle exec rspec spec/services/demo/` passes
- [x] 1.2 `bin/ci` passes

### Phase 2: Route and Controller

#### Automated

- [x] 2.1 Load demo request specs pass
- [x] 2.2 `bin/ci` passes

### Phase 3: UI and Production Guard Spec

#### Automated

- [ ] 3.1 Full `bin/ci` passes
