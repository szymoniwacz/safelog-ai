---
project: SafeLog AI
version: 1
status: draft
created: 2026-05-19
context_type: greenfield
product_type: web-app
target_scale:
  users: small
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: null
  after_hours_only: true
---

# SafeLog AI — Product Requirements Document

## Vision & Problem Statement

When debugging customer-reported production issues, engineers paste logs from multiple sources (application logs, infrastructure logs, APM-style traces, browser console output, customer reports) into AI tools. Those logs routinely contain API tokens, authorization headers, emails, customer IDs, request IDs, session IDs, IP addresses, phone numbers, card last4, and other sensitive values.

The cost today is twofold: correlating signals across sources is manual and slow, and sending or retaining raw logs creates unacceptable security and compliance risk (raw logs must not be persisted, logged, or sent to AI).

The insight that makes this product worth building: deterministic backend logic must redact and pseudonymize evidence in memory before any AI reasoning runs. AI helps hypothesize from sanitized evidence only; it does not magically know what happened in production.

## User & Persona

**Primary persona:** Solo developer (course project operator) acting as a backend/support engineer debugging SaaS-style production incidents. Uses SafeLog AI as an internal debugging assistant — not a customer-facing application.

**Context:** A multi-source incident (e.g. checkout/payment timeout) where pasted logs must be sanitized, correlated by case-local placeholders (e.g. `[REQUEST_1]`), and turned into a hypothesis-framed debugging report without ever persisting or transmitting raw log content.

## Success Criteria

### Primary

End-to-end MVP flow (user-confirmed, ~3 weeks after-hours):

1. User signs up or signs in with email and password.
2. User creates a debugging case (title, short description, customer_reference, environment).
3. User submits multiple log sources in one request (source type, optional name, pasted raw text). Source types: `rails_log`, `aws_cloudwatch`, `new_relic`, `browser_console`, `customer_report`, `other`. No live observability API integrations — manual paste only.
4. App processes raw input in memory only: detects sensitive data, assigns case-local pseudonymized placeholders, persists sanitized content and redaction findings (no original values), discards raw input. UI never shows raw content again.
5. Case detail shows sanitized logs (with copy), redaction/security summary (counts by type and risk level).
6. User clicks **Analyze case**: app extracts correlation signals from sanitized content, generates AI debugging report from sanitized evidence only, validates response (retry once on invalid).
7. User views hypothesis-framed AI report; can copy and download Markdown (`.md`).
8. User can archive a case; archived cases hidden from default list, visible via Archived filter.

**MVP constraint:** All log sources for a case must be added in the initial submission — not after case creation.

### Secondary

- **Load demo case** (non-production environments only): pre-built checkout/payment-timeout scenario with multiple sanitized sources for course demo and README walkthrough.

### Guardrails

- Raw logs are never persisted, logged, sent to AI, stored in files, or passed to asynchronous workers. No raw-to-placeholder maps or hashes/fingerprints of raw sensitive values in storage.
- Diagnostic text remains unreadable at rest without encryption keys (sanitized logs, customer_reference, correlation signals, AI report fields).
- AI reports are hypotheses only — no false certainty; validated structure with uncertainty notes.
- Users cannot access other users' debugging cases or exports.
- Automated tests run without calling a real AI provider API; security-focused tests prove raw content is not persisted or sent to AI.

## User Stories

### US-01: End-to-end safe debugging case

- **Given** a signed-in user on a fresh debugging case form
- **When** they submit a case with title, metadata, and multiple pasted log sources (checkout-timeout demo scenario)
- **Then** raw input is processed and discarded; they see only sanitized logs and a redaction/security summary with consistent placeholders (e.g. `[REQUEST_1]` across sources)

- **When** they click Analyze case
- **Then** they see correlation signals and a hypothesis-framed AI debugging report generated from sanitized evidence only

- **When** they copy or download Markdown
- **Then** they receive a `.md` report suitable for sharing without raw sensitive values

#### Acceptance Criteria

- Raw content does not appear in persisted records, AI prompts, or application logs after submission
- AI request includes pseudonymized placeholders (e.g. `[EMAIL_1]`) and does not include original sensitive values
- Invalid AI structured response is retried once; then report status is `failed` with a safe user message
- Authorization tests prove a user cannot access another user's case

## Functional Requirements

### Authentication & cases

- FR-001: User can sign up and sign in with email and password. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-002: User can create a debugging case with title, short description, customer_reference, and environment. Priority: must-have
  > Socrates: Counter-argument considered: customer_reference may itself be sensitive.
  > Resolution: kept; customer_reference is stored as encrypted diagnostic text at rest.

- FR-010: User can archive a debugging case; archived cases are hidden from the default list and reachable via an Archived filter. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Log intake & redaction

- FR-003: User can submit multiple log sources in one request (source type, optional name, pasted raw text). Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-004: System redacts raw log input in memory and persists only sanitized content and redaction findings (no original sensitive values). Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-005: User can view sanitized log sources and a redaction/security summary on the case detail page. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-006: User can copy sanitized log content. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Analysis & reports

- FR-007: User can run Analyze case to extract correlation signals and generate an AI debugging report from sanitized evidence only. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-008: User can view a structured, hypothesis-framed AI debugging report. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

- FR-009: User can copy and download the report as Markdown. Priority: must-have
  > Socrates: No counter-argument; it stands as written.

### Demo

- FR-011: User can load a pre-built demo case in development and test environments only. Priority: must-have
  > Socrates: Counter-argument considered: nice-to-have may be insufficient for course demo.
  > Resolution: promoted to must-have for presentation and README walkthrough.

## Non-Functional Requirements

- No trace of submitted raw log text remains in operator-accessible storage, application logs, AI prompts, or error details after the request that accepted it completes.
- Stored diagnostic text (sanitized logs, customer_reference, correlation signals, AI report bodies) remains unreadable at rest without encryption keys.
- Published debugging reports describe likely issues and suspected causes as hypotheses; they do not claim certainty about production root cause.
- Analyze case completes in the same browser session without requiring a background job in MVP (user receives outcome or failure in that session).

## Business Logic

Before any AI reasoning runs, the application deterministically redacts and pseudonymizes all log input in memory, discards raw content, and only then correlates sanitized signals and permits hypothesis-framed reports from that evidence.

Supporting behavior (user-facing, implementation-agnostic):

- **Inputs:** Pasted raw log text from multiple sources submitted together; optional case metadata (title, environment, customer_reference).
- **Processing:** Detect sensitive patterns (email, token, IP, session ID, customer ID, request ID, authorization header, phone, card last4); replace with case-local placeholders preserving cross-source correlation within one submission; persist findings as type, line number, placeholder, risk level — never original values.
- **Outputs:** Sanitized logs, redaction summary, correlation signals, validated AI report (structured fields + Markdown) using hypothesis language only.
- **User encounter:** Submit sources → see sanitized evidence and security summary → Analyze case → read/share hypothesis report.

## Access Control

- **Authentication:** Email and password sign-up and sign-in. Minimal account model — registration and credential validation only; no password recovery, OAuth, or additional auth modules unless explicitly added later.
- **Authorization:** Flat per-user ownership. A logged-in user can see and modify only their own debugging cases (list, detail, sanitized logs, redaction findings, correlation signals, AI reports, Markdown export, archive). Automated authorization tests must prove user A cannot access user B's cases.
- **Not in MVP:** Admin/support roles, multi-tenancy, team workspaces.

## Non-Goals

- **Real observability API integrations** — no live connections to cloud logging, APM, or error-tracking vendors; users paste exported logs manually.
- **Log management platform** — not a full observability or incident-command product, streaming log store, or vendor clone.
- **Raw log retention in any form** — no raw storage, raw-to-placeholder maps, or fingerprints/hashes of raw sensitive values.
- **Adding sources after initial submission** — all sources for a case must be submitted together in MVP.
- **Background jobs for analysis** — synchronous Analyze case only in MVP (boundaries should allow future async by case identifier).
- **Multi-tenancy and role models** — no team workspaces, admin/support roles, or shared case access.
- **Container packaging as MVP gate** — optional bonus near end; must not block core flow.
- **Separate rich client UI framework** — server-rendered pages for MVP; keep boundaries clean for a possible future UI replacement.

## Open Questions

_No open questions — shape session completed with quality check accepted (2026-05-19)._
