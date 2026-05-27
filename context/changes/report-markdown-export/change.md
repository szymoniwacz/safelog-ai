---
change_id: report-markdown-export
title: Report Markdown export (S-04)
status: planned
created: 2026-05-27
updated: 2026-05-27
archived_at: null
---

## Notes

Roadmap **S-04** (`context/foundation/roadmap.md`). FR-009: copy and download hypothesis report as Markdown. Prerequisites: S-03 complete (`AiReport#markdown_body` populated on generated reports).

**Phase 1 done:** `GET download_report` member route; `send_data` attachment from latest generated report; 4 request specs.

**Phase 2 done (uncommitted):** Readonly Markdown textarea + download link on report partial; analyze request spec asserts copy/export UI.
