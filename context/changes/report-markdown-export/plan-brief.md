# Report Markdown Export (S-04) — Plan Brief

> Full plan: `context/changes/report-markdown-export/plan.md`

## What & Why

Roadmap **S-04** completes US-01 sharing: after S-03 analyze, the user can **copy** the hypothesis report Markdown on case show and **download** it as a `.md` file. Content comes from persisted `AiReport#markdown_body` only — already sanitized/validated at analyze time.

## Starting Point

S-03 delivers generated `AiReport` rows with encrypted `markdown_body` and structured JSON. Case show renders HTML hypothesis report but has no copy/download affordances. No export route exists.

## Desired End State

On case show with a generated report: readonly Markdown textarea for copy (FR-006 pattern); **Download report** link returns `text/markdown` attachment. Cross-user download denied. Request specs prove export works and excludes raw intake secrets. `bin/ci` green.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| -------- | ------ | ---------------- | ------ |
| Markdown source | `AiReport#markdown_body` from latest generated report | S-03 already persists validated Markdown | Plan |
| Download route | `GET download_report` member on `debugging_cases` | Thin controller; no new service needed for MVP | Plan |
| Copy UX | Readonly textarea + select-all instruction | Matches sanitized log copy pattern (no Stimulus) | Plan |
| Missing report | 404 when no generated report | Avoid empty/misleading downloads | Plan |
| Filename | Slug from case title + `-report.md` | Human-readable, safe ASCII | Plan |

## Scope

**In scope:** Download action, copy textarea on report partial, authorization + security request specs.

**Out of scope:** PDF export, email share, editing report, archive (S-05), demo loader (S-06).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| ----- | ---------------- | -------- |
| 1. Download endpoint | GET member route + attachment response + specs | Wrong content-type or filename |
| 2. Copy UI | Markdown textarea on show | Accidentally showing failed report body |
| 3. Security specs | Cross-user 404 + no raw in download | Flaky secret strings |

**Prerequisites:** S-03. **Estimated effort:** ~1–2 sessions across 3 phases.

## Success Criteria (Summary)

- Owner downloads `.md` with hypothesis report content after analyze.
- Copy textarea present on show for generated reports.
- Cross-user download blocked; no raw secrets in export body.
