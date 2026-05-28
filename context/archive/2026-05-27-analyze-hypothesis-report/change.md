---
change_id: analyze-hypothesis-report
title: Analyze hypothesis report (S-03)
status: archived
created: 2026-05-27
updated: 2026-05-28
archived_at: 2026-05-28T17:40:13Z
---

## Notes

Roadmap **S-03** (`context/foundation/roadmap.md`). Synchronous Analyze case: extract correlation signals from sanitized evidence, call F-03 AI adapter, validate hypothesis-framed report, display on case detail. Prerequisites: S-02, F-03 complete.

**Delivered:** Correlation extractor, prompt builder, analyze orchestrator, POST analyze route, case show UI for signals + report, AGENTS.md security specs. 68 RSpec examples; `bin/ci` green.

**Handoff to S-04:** `AiReport#markdown_body` and structured JSON are ready for copy/download Markdown export.

## Phase log

- Phase 1: `Correlation::ExtractSignals`
- Phase 2: `Analysis::PromptBuilder`, `Analysis::AnalyzeCase` (retry-once)
- Phase 3: Analyze route + controller action
- Phase 4: Analyze button, correlation signals + hypothesis report UI
- Phase 5: Analyze security request specs (sanitized AI prompts, correlation payload, show response)
