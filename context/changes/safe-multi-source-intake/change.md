---
change_id: safe-multi-source-intake
title: Safe multi-source intake (S-02)
status: plan_reviewed
created: 2026-05-27
updated: 2026-05-27
archived_at: null
---

## Notes

Roadmap **S-02** north star (`context/foundation/roadmap.md`). In-memory redaction, sanitized persistence only, case UI. Prerequisites: F-01, F-02, S-01 complete.

**Phase 1 done:** `Redaction::Engine`, `PlaceholderRegistry`, `Patterns`, `Result` + unit specs (7 examples). Cross-source request_id correlation via shared registry verified.

**Phase 2 done:** `Intake::CaseSubmission`, `Intake::ProcessCaseSubmission` — transactional create with shared registry; `customer_reference` redacted per plan review F2; 5 service specs prove no raw persistence.

**Phase 3 done:** `DebuggingCasesController`, routes, param filtering for pasted content; minimal new/show stubs; 6 request specs (auth gating, create redirect, sanitized show). Restart dev server after filter_parameter_logging change.

**Phase 4 done (uncommitted):** Full new form (3 fixed source slots), show with metadata/redaction summary/readonly copy textareas, helper, dashboard link. Manual browser check recommended.
