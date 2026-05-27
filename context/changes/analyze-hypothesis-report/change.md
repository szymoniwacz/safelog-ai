---
change_id: analyze-hypothesis-report
title: Analyze hypothesis report (S-03)
status: planned
created: 2026-05-27
updated: 2026-05-27
archived_at: null
---

## Notes

Roadmap **S-03** (`context/foundation/roadmap.md`). Synchronous Analyze case: extract correlation signals from sanitized evidence, call F-03 AI adapter, validate hypothesis-framed report, display on case detail. Prerequisites: S-02, F-03 complete.

**Phase 1 done:** `Correlation::ExtractSignals` — placeholder-based cross-source signals from sanitized logs + findings; 4 unit specs.

**Phase 2 done:** `Analysis::PromptBuilder`, `Analysis::AnalyzeCase` — extract/persist signals, sanitized prompt, AI call with retry-once, `AiReport` persistence; 5 service specs.

**Phase 3 done (uncommitted):** `POST analyze` member route + controller action; 3 request specs (guest redirect, cross-user 404, owner happy path).
