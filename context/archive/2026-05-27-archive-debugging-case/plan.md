# Archive Debugging Case (S-05) Implementation Plan

## Overview

Land roadmap **S-05** (FR-010): case list with active/archived filter; archive action sets `archived_at`; archived cases hidden from default list.

## Current State Analysis

- **Schema:** `debugging_cases.archived_at` nullable datetime (F-02).
- **Routes:** `new`, `create`, `show`, `analyze`, `download_report` — no `index` or `archive`.
- **UI:** Dashboard → new case only; show has no archive control.

## Desired End State

1. `DebuggingCase.active` / `.archived` scopes on `user.debugging_cases`.
2. `GET /debugging_cases` — active cases default; `?filter=archived` for archived.
3. `POST /debugging_cases/:id/archive` sets `archived_at`, redirects to index.
4. Archive button on show; cases index linked from dashboard.
5. Request specs for archive + index + authorization.
6. `bin/ci` green.

## What We're NOT Doing

- Unarchive, delete, bulk operations.
- Demo loader (S-06).
- Hiding archived case show/analyze by direct URL (owner can open from archived list).

## Phase 1: Archive Action and Model Scopes

### Overview

Model scopes and member archive route; redirect with flash (dashboard until index lands in Phase 2).

### Changes Required:

#### 1. Model scopes

**File:** `app/models/debugging_case.rb`

**Intent:** `scope :active, -> { where(archived_at: nil) }`, `scope :archived, -> { where.not(archived_at: nil) }`, `#archive!` sets `archived_at` to `Time.current`.

**Contract:** Idempotent-safe: re-archive updates timestamp or no-op if already archived (pick one — no-op if already archived).

#### 2. Route and controller

**Files:** `config/routes.rb`, `app/controllers/debugging_cases_controller.rb`

**Intent:** Member `post :archive`; `#archive` loads case via `current_user.debugging_cases.find`, calls `archive!`, redirects with notice.

**Contract:** Owner-only via scoped find (404 cross-user).

#### 3. Model + request specs

**Files:** `spec/models/debugging_case_spec.rb`, `spec/requests/debugging_cases_archive_spec.rb`

**Intent:** Scopes exclude/include correctly; owner POST archive sets `archived_at`; guest redirect; other user 404.

### Success Criteria:

#### Automated Verification:

- `bundle exec rspec spec/models/debugging_case_spec.rb spec/requests/debugging_cases_archive_spec.rb`
- `bin/ci`

**Implementation Note:** Pause before Phase 2.

---

## Phase 2: Case Index and Filter UI

### Overview

List active/archived cases; dashboard link; archive redirect to index; archive button on show.

### Changes Required:

#### 1. Index action

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `#index` loads `@debugging_cases` from `current_user.debugging_cases.active` or `.archived` based on `params[:filter] == "archived"`.

#### 2. Routes

**File:** `config/routes.rb`

**Intent:** Add `:index` to `debugging_cases` resources.

#### 3. Views

**Files:** `app/views/debugging_cases/index.html.erb`, update `show.html.erb`, `dashboard/show.html.erb`

**Intent:** Table/list of cases with title, environment, created_at; Active \| Archived filter links; Archive button on show (hidden if already archived); dashboard link to cases.

#### 4. Update archive redirect

**Intent:** Redirect to `debugging_cases_path` after archive.

### Success Criteria:

#### Automated Verification:

- `bundle exec rspec spec/requests/debugging_cases_index_spec.rb`
- `bin/ci`

**Implementation Note:** Pause before Phase 3.

---

## Phase 3: Authorization and Index Specs

### Overview

Prove filter behavior and cross-user index isolation.

### Changes Required:

#### 1. Index request specs

**File:** `spec/requests/debugging_cases_index_spec.rb`

**Intent:** Active list excludes archived; archived filter includes only archived; cross-user cannot see other's cases.

#### 2. Handoff note

**File:** `change.md`

**Intent:** S-06 demo loader remains.

### Success Criteria:

#### Automated Verification:

- `bundle exec rspec`
- `bin/ci`

**Implementation Note:** Final phase for S-05.

---

## Progress

### Phase 1: Archive Action and Model Scopes

#### Automated

- [x] 1.1 Model + archive request specs pass
- [x] 1.2 `bin/ci` passes

### Phase 2: Case Index and Filter UI

#### Automated

- [x] 2.1 Index request specs pass
- [x] 2.2 `bin/ci` passes

### Phase 3: Authorization and Index Specs

#### Automated

- [x] 3.1 Full `bundle exec rspec` passes
- [x] 3.2 `bin/ci` passes
