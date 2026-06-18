# Opportunity Map

## Context

- **Project / context**: SafeLog AI — MVP shipped (F-01–S-06 done); Builder READY; Architect IN PROGRESS (M4L2–L5 exploration complete, refactor implementation pending)
- **Data constraint**: Mock / local / read-only / non-sensitive
- **Date**: 2026-06-17

## Map

| Signal | Existing / default response | Thin complement | First useful version | Data risk | Direction if valuable |
|---|---|---|---|---|---|
| Pasting multi-source prod logs into generic AI chat exposes secrets | ChatGPT/Claude paste; engineer self-redacts; observability UIs stay separate | Pre-paste secret scanner (local CLI) before any AI tool | Script: scan fixture logs → flag/redact patterns → stdout only | mock / local | Product feature (pre-intake gate) |
| Cross-source correlation by hand across Rails/CloudWatch/APM/browser | Engineer hunts matching request IDs/timestamps in separate tabs | SafeLog case with sanitized placeholders (already built) | Demo-case walkthrough on mock fixtures; measure time-to-correlate vs manual | mock / local | Product (core wedge — extend, don't replace) |
| New log lines arrive after case creation; MVP blocks append | Re-create full case or paste everything again in one shot | Export sanitized logs + re-import as new case | Read-only spike: document "append sources" UX on demo fixture only | mock / local | Product feature (post-MVP) |
| Engine findings hash → DB with no typed contract (TD-2) | Implicit 4-key hash at sole `create!` call-site; security specs scan values not keys | `RedactionFinding.build_from_engine_finding` at persist seam | Contract spec + factory on demo fixture; no schema change | mock / local | Review / CI gate + internal refactor |
| Intake changes risk silent regressions (27 gaps, 15 untested paths) | `bin/ci` + security oracles; manual review of `ProcessCaseSubmission` | Rollback specs (G-01/G-02) before any extraction | Add 2 rollback examples on synthetic failure; green `bin/ci` | mock / local | Review / CI gate |
| Windows CRLF pastes may corrupt line-based redaction (TD-5) | LF-only `split(/\n/)`; no CRLF specs | Normalize `\r\n` → `\n` in Engine | Characterization spec with `"line\r\nsecret"` input; then normalize | mock / local | Feature (paste fidelity) or Wait |
| Manual `fly deploy`; no GHA deploy workflow | Fly CLI + deploy-plan; `/up` health check | GHA workflow triggered on tag/main (read-only smoke after deploy) | Draft workflow YAML; dry-run against staging/mock | local / non-sensitive | Async / remote work |
| E2E covers happy path only (TD-8) | 135 RSpec + 5 Playwright happy-path; `bin/e2e` optional | One Playwright spec for validation failure | Single E2E: submit empty sources → see error; no prod data | mock / local | Review / CI gate |

## Signal Detail

### P-1: Raw secrets in generic AI paste

**Signal:** When debugging production incidents, engineers paste logs from multiple sources into ChatGPT/Claude; logs contain tokens, emails, IDs, and other sensitive values.

**Existing / default response:** Generic AI chat accepts arbitrary paste; security depends entirely on engineer judgment; observability tools (CloudWatch, New Relic, Rails logs) remain separate silos.

**Thin complement:** Local pre-paste linter that flags or redacts known patterns before content reaches any AI tool — does not replace SafeLog's case workflow.

**First useful version:** CLI script over checkout-timeout demo fixtures; outputs redacted preview to stdout; nothing persisted.

**Data risk:** mock / local — demo fixtures only.

**Direction if valuable:** Product feature (pre-intake gate) or Wait — SafeLog MVP already addresses this for users who adopt the app; bypass risk remains when engineers are in a hurry.

---

### P-2: Manual cross-source correlation

**Signal:** Correlating request IDs, timestamps, and error signals across Rails, CloudWatch-style, APM, browser console, and customer reports is manual and slow.

**Existing / default response:** SafeLog MVP (sanitized placeholders, correlation signals, hypothesis report); or manual tab-switching in observability UIs + AI chat.

**Thin complement:** SafeLog case detail already joins sources — extend correlation display, don't rebuild observability.

**First useful version:** Timed walkthrough on demo case vs manual fixture correlation; document gaps in correlation signal coverage.

**Data risk:** mock / local — demo case and fixtures.

**Direction if valuable:** Product — core wedge; extend correlation rules and signal extraction, not replace source systems.

---

### P-3: Cannot append sources after case creation

**Signal:** Real incidents often produce new log lines after initial triage; MVP requires all sources in one submission.

**Existing / default response:** Re-create case with all sources again, or work outside SafeLog until complete.

**Thin complement:** "Duplicate case with new source" flow linking to prior sanitized case (read-only reference).

**First useful version:** Paper prototype / spike doc on demo fixture — no DB migration; validate whether append is essential vs accidental MVP constraint.

**Data risk:** mock / local.

**Direction if valuable:** Product feature — but PRD explicitly parked this; check essential vs accidental complexity before building.

---

### I-1: Implicit findings persist contract (TD-2)

**Signal:** Every intake/refactor touches an implicit 4-key hash (`finding_type`, `line_number`, `placeholder`, `risk_level`) passed directly to `create!` with zero compile-time or spec-level contract enforcement.

**Existing / default response:** Security oracles scan persisted values for raw substrings; `engine_spec` checks hash shape; no mapper/DTO at persist seam.

**Thin complement:** `RedactionFinding.build_from_engine_finding(finding)` at sole call-site in `ProcessCaseSubmission`.

**First useful version:** Contract spec whitelisting keys ⊆ AR attrs + factory method; swap one line at persist seam; `bin/ci` green.

**Data risk:** mock / local — synthetic fixtures and demo case.

**Direction if valuable:** Review / CI gate — prerequisite for safe intake evolution and Architect refactor evidence.

---

### I-2: Intake refactor regression risk (TD-1, G-01–G-15)

**Signal:** `ProcessCaseSubmission` mixes orchestration, transaction, metadata redaction, and AR persist (~72 lines, 4 responsibilities); 15 test gaps including inner-loop rollback untested.

**Existing / default response:** `bin/ci` (135 RSpec) + security spec bundle; manual code review before touching intake.

**Thin complement:** Rollback specs (G-01, G-02) before any extraction; then optional `Intake::RedactMetadata` extract (IMPL-1).

**First useful version:** Two new examples — `log_sources.create!` fails → no partial case; `redaction_findings.create!` fails → full rollback.

**Data risk:** mock / local — stubbed AR failures in specs.

**Direction if valuable:** Review / CI gate — unblocks IMPL-1 and Architect certification refactor implementation.

---

### I-3: CRLF paste fidelity (TD-5)

**Signal:** Windows-style `\r\n` line endings in pasted logs may retain trailing `\r`, affecting line numbers and pattern matching; zero CRLF specs today.

**Existing / default response:** LF-only engine split; undocumented behavior.

**Thin complement:** Normalize `\r\n`/`\r` → `\n` before split in `Redaction::Engine`.

**First useful version:** Characterization spec documenting current behavior on `"line\r\nsecret"` input; then normalize + update spec.

**Data risk:** mock / local.

**Direction if valuable:** Feature (paste fidelity) — low blast radius; or Wait if Windows paste is rare for persona.

---

### I-4: Manual deploy, no CI deploy gate

**Signal:** Production deploy is manual `fly deploy`; no GHA workflow; Fly app intentionally suspended when not needed.

**Existing / default response:** `context/deployment/deploy-plan.md`; manual CLI; `/up` health check on Fly.

**Thin complement:** GHA deploy workflow on tag or manual dispatch with post-deploy smoke.

**First useful version:** Draft workflow YAML; dry-run lint; no secrets in repo.

**Data risk:** local / non-sensitive — workflow config only.

**Direction if valuable:** Async / remote work — post-MVP ops; not blocking certification.

---

### I-5: E2E happy-path only (TD-8)

**Signal:** Playwright suite (5 tests) covers login → archive happy path; validation failures and single-source submissions untested at browser level.

**Existing / default response:** Request specs cover many HTTP paths; E2E optional (`bin/e2e` not in `bin/ci`).

**Thin complement:** One Playwright spec for validation failure (empty sources).

**First useful version:** Single E2E: submit case with no sources → error message visible.

**Data risk:** mock / local — rack_test/Playwright against local dev server.

**Direction if valuable:** Review / CI gate — cheap confidence for form UX regressions.

## Recommended First Candidate

```text
Candidate:
Intake finding persist contract (TD-2)

Reads:
Demo fixture logs (CaseFixture), engine_spec examples, redaction_finding AR attrs

Returns:
Contract spec + RedactionFinding.build_from_engine_finding factory;
single-line swap at process_case_submission.rb:46; bin/ci green

Does not do:
Schema migration, full ProcessCaseSubmission extraction (IMPL-1),
metadata encryption (TD-7), demo facade (TD-10), CRLF normalize (TD-5)

Data risk:
mock / local — synthetic and demo fixtures only; no production DB

Direction if it proves valuable:
Review / CI gate → enables safe intake extensions and Architect refactor slice
```

## Why This Candidate

**I-1 (TD-2)** ranks first because:

1. **Repeats regularly** — every findings extension or intake touch hits the implicit hash→DB seam.
2. **Combines two sources** — redaction engine output shape + persistence layer contract.
3. **Clear manual pain today** — rename/remove a hash key → runtime `RecordInvalid` with no spec catching it.
4. **Testable on mock data** — contract spec + factory; ~4 files; reversible; `bin/ci` is the gate.
5. **Does not replace a platform** — complements existing AR model and security oracles.
6. **Clear later direction** — natural home for IMPL-1 persist extraction; Architect certification evidence.

**Not the others (for now):**

- **P-1 / P-2:** SafeLog MVP already ships the product wedge; validate adoption/bypass with `/10x-mom-test` before new product surface.
- **P-3:** PRD-parked; may be essential complexity — mom-test before shaping.
- **I-2:** Strong #2 — rollback specs are prerequisite for IMPL-1; pair immediately after TD-2 or in same change.
- **I-3:** Low cost but lower repeat frequency unless Windows paste is confirmed pain.
- **I-4 / I-5:** Ops/E2E polish; not blocking Architect path.

## Next Direction If Valuable

**Chosen path:** Validate, then shape — `/10x-mom-test` → `/10x-shape`

Run `/10x-mom-test` on two threads:

1. **Product (P-1, P-2, P-3):** Do engineers actually bypass SafeLog for ChatGPT when incidents hit? Do they re-create cases because append is missing? Past behavior, not hypotheticals.
2. **Internal (I-1):** Has the implicit findings contract caused a near-miss or slowed a change? Would a factory at the persist seam have caught it?

If product signals survive mom-test → `/10x-shape` for post-MVP features (append sources, pre-paste gate).

If internal signal survives (likely — ranked #1 in refactor research) → `/10x-new` → `/10x-plan` → `/10x-implement` for TD-2 contract spec + factory, without waiting for full product validation.
