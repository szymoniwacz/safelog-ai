---
change_id: encrypted-diagnostic-schema
title: Encrypted diagnostic schema (roadmap F-02)
status: archived
created: 2026-05-27
updated: 2026-05-28
archived_at: 2026-05-28T17:40:13Z
---

## Notes

F-02 z @context/foundation/roadmap.md

**Delivered:** Five domain tables (`debugging_cases`, `log_sources`, `redaction_findings`, `correlation_signals`, `ai_reports`) with Active Record Encryption on diagnostic text (`customer_reference`, `sanitized_content`, `payload`, `structured_json`, `markdown_body`). No case routes, controllers, or intake/AI services in this change.

**Handoff:**
- **S-02** (`safe-multi-source-intake`) — redaction engine, case controllers (inherit `AuthenticatedController`), persist sanitized evidence only.
- **F-03** (`ai-adapter-test-harness`) — provider-agnostic AI client + fake for CI.
- **S-03+** — analyze flow; `AiReport#status`: `pending` → `processing` → `generated` / `failed`.

Production: set `RAILS_ACTIVE_RECORD_ENCRYPTION_*` Fly secrets per `context/deployment/deploy-plan.md` before encrypted writes in production.
