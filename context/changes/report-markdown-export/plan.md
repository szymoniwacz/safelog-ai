# Report Markdown Export (S-04) Implementation Plan

## Overview

Land roadmap **S-04** (FR-009): signed-in case owners copy and download the hypothesis-framed AI report as Markdown from case detail. Uses persisted `AiReport#markdown_body` from S-03 — no regeneration, no new AI calls.

## Current State Analysis

- **S-03:** `AiReport#markdown_body` encrypted text populated when status `generated`; show renders HTML from structured JSON.
- **Routes:** `POST analyze` member only; no export route.
- **Copy pattern:** Sanitized logs use readonly `<textarea>` + select-all instruction on show.

### Key Discoveries:

- AGENTS.md: export only validated report bodies already stored — never raw logs.
- PRD US-01: Markdown suitable for sharing without raw sensitive values (relies on upstream redaction + sanitized AI prompt).
- Authorization: `current_user.debugging_cases.find(id)` pattern from S-02/S-03.

## Desired End State

1. `GET /debugging_cases/:id/download_report` returns Markdown attachment for latest generated report.
2. Case show `_ai_report` partial includes readonly Markdown textarea when report is generated.
3. Request specs: owner download success, guest/other user denied, no raw secrets in body.
4. `bin/ci` green.

## What We're NOT Doing

- PDF/HTML export, clipboard API/Stimulus, email, report editing.
- Regenerating Markdown from structured JSON (use stored `markdown_body`).
- Archive (S-05), demo loader (S-06).

## Implementation Approach

Thin controller export action; helper for safe filename; extend existing report partial for copy. Specs follow S-03 analyze security patterns.

## Phase 1: Download Endpoint

### Overview

Authenticated GET returns Markdown file attachment from latest generated `AiReport`.

### Changes Required:

#### 1. Route

**File:** `config/routes.rb`

**Intent:** Member `get :download_report` on `debugging_cases`.

**Contract:** Requires authentication via controller.

#### 2. Controller action

**File:** `app/controllers/debugging_cases_controller.rb`

**Intent:** `#download_report` loads case via `current_user.debugging_cases.find`, finds latest `generated` ai_report, `send_data` markdown_body with `type: "text/markdown"`, `disposition: "attachment"`, filename from helper.

**Contract:** `head :not_found` when no generated report or blank markdown_body.

#### 3. Filename helper

**File:** `app/helpers/debugging_cases_helper.rb`

**Intent:** `report_download_filename(debugging_case)` → parameterized title + `-report.md`.

**Contract:** ASCII-safe slug; fallback if title blank.

#### 4. Request specs

**File:** `spec/requests/debugging_cases_report_export_spec.rb`

**Intent:** Guest redirect; owner with analyzed case gets 200, `text/markdown`, attachment disposition, body includes report content; case without report gets 404.

**Contract:** Create case + run analyze in spec setup.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec spec/requests/debugging_cases_report_export_spec.rb`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: download `.md` after analyze opens valid Markdown file

**Implementation Note:** Pause for human confirmation before Phase 2.

---

## Phase 2: Copy Markdown UI

### Overview

Readonly textarea on case show for copying report Markdown (FR-009 copy path).

### Changes Required:

#### 1. Report partial

**File:** `app/views/debugging_cases/_ai_report.html.erb`

**Intent:** When `ai_report.generated?` and `markdown_body` present, add section with readonly textarea containing `ai_report.markdown_body` and copy instruction (match sanitized logs pattern).

**Contract:** Do not render markdown textarea for failed/missing reports.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

#### Manual Verification:

- Browser: select-all copy from textarea works

**Implementation Note:** Pause for human confirmation before Phase 3.

---

## Phase 3: Security and Authorization Specs

### Overview

Prove cross-user export denial and no raw secret leakage in download body.

### Changes Required:

#### 1. Security examples

**File:** `spec/requests/debugging_cases_report_export_security_spec.rb`

**Intent:** Intake with known raw secret → analyze → download; assert body excludes raw secret, includes placeholders. References AGENTS.md.

**Contract:** Unique fake secrets per example.

#### 2. Authorization

**File:** extend export spec

**Intent:** User B GET download on user A case → 404.

#### 3. Handoff note

**File:** `context/changes/report-markdown-export/change.md`

**Intent:** S-05 archive and S-06 demo remain parallel follow-ons.

### Success Criteria:

#### Automated Verification:

- `mise exec -- bundle exec rspec`
- `mise exec -- bin/ci`

**Implementation Note:** Final phase for S-04.

---

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Download Endpoint

#### Automated

- [x] 1.1 `bundle exec rspec spec/requests/debugging_cases_report_export_spec.rb` passes
- [x] 1.2 `bin/ci` passes

#### Manual

- [ ] 1.3 Browser download produces valid `.md`

### Phase 2: Copy Markdown UI

#### Automated

- [x] 2.1 Full `bundle exec rspec` passes
- [x] 2.2 `bin/ci` passes

#### Manual

- [ ] 2.3 Browser copy from textarea

### Phase 3: Security and Authorization Specs

#### Automated

- [ ] 3.1 Security + authorization export specs pass
- [ ] 3.2 `bin/ci` passes
