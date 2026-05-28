# Architecture Alignment — Plan Brief

> Full plan: `context/changes/architecture-alignment/plan.md`  
> Research: `context/changes/architecture-alignment/research.md`

## What & Why

Post-MVP cleanup to align the **read/display path** with canonical service boundaries (`AGENTS.md`, shape-notes). The write pipeline is already correct; helpers currently hold correlation parsing, AI JSON parsing, redaction summary aggregation, and export filename logic. This change relocates that logic into small domain services and fixes minor naming/doc drift — **no new product features**.

## Starting Point

MVP (F-01–S-06) is implemented and impl-review approved. `DebuggingCasesHelper` contains domain read logic; archived plan diagrams slightly misstate correlation persistence ownership; `AGENTS.md` still says “No test suite yet.”

## Desired End State

- Read-path domain logic lives under `app/services/{correlation,redaction,analysis}/`
- Helpers remain presentation-only (labels, select options, slot count)
- Controller `#show` and `#download_report` call services, not helper parsers
- Minor F-03 contract alignment (`case_ref` string), orchestrator ownership documented
- Stale docs/fixtures cleaned; `bin/ci` green throughout

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Read-path refactor scope | Extract 4 small `.call` services | Matches existing service pattern; no presenter layer | Research |
| Helper fate | Remove domain methods; keep UI helpers only | AGENTS.md boundary rule | Research |
| Correlation persistence | Keep in `Analysis::AnalyzeCase` | Matches detailed S-03 plan; don't move to extractor | Research |
| Double `ResponseValidator` | Keep both client + orchestrator calls | Planned defense-in-depth; not drift | Research |
| Title metadata | Redact via same `redact_metadata` as description | Metadata parity after F1 description fix | Plan |
| `valid_report.json` | Delete unused fixture | `ReportSchema` canonical inline is source of truth | Plan |
| Re-analyze behavior | Document append-only; no behavior change | Out of MVP scope | Research |

## Scope

**In scope:**

- `Correlation::ParsePayload`, `Redaction::SummaryCounts`, `Analysis::ParseStructuredReport`, `Analysis::ReportFilename`
- Controller/helper/view wiring for read path
- Title redaction in intake; `case_ref` as string
- Comments on orchestrator persistence; AGENTS.md + impl-review doc hygiene
- Service specs + existing request specs still green

**Out of scope:**

- New features, routes, models, migrations
- Moving correlation persistence into `ExtractSignals`
- Removing orchestrator-level `ResponseValidator`
- Renaming archived `ai-adapter-foundation` change folder
- Full `Analysis::ReportExport` orchestrator (export lookup stays in controller)
- Background jobs, React, new redaction patterns

## Architecture / Approach

```
show/download_report (controller)
  → Correlation::ParsePayload / Redaction::SummaryCounts /
    Analysis::ParseStructuredReport / Analysis::ReportFilename
  → views (presentation helpers only)
```

Write path unchanged: `Intake → Redaction → AnalyzeCase → ExtractSignals → PromptBuilder → Ai::Client`.

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Read-path services | Domain parsers moved out of helper | View partial must receive new ivars |
| 2. Naming & intake parity | `case_ref`, title redaction, orchestrator comments | None — behavior-preserving |
| 3. Doc & dead-code cleanup | AGENTS.md, fixture removal, review doc sync | None |

**Prerequisites:** MVP complete; `bin/ci` green on `main`  
**Estimated effort:** ~1 session across 3 phases

## Open Risks & Assumptions

- Re-analyze continues to append rows; show uses latest — documented, not changed
- Partial `_redaction_summary.html.erb` switches from helper call to controller-provided summary hash

## Success Criteria (Summary)

- No domain logic in `DebuggingCasesHelper` beyond UI formatting
- All existing request/security specs pass unchanged behavior
- `bin/ci` green after each phase
