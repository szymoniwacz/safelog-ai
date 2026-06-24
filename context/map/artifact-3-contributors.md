# Artifact 3 — Contributors map (git history)

**Project:** SafeLog AI  
**Window:** 2026-05-18 → 2026-06-09 (requested: 12 months; **actual repo lifetime ~3 weeks**, 116 commits)  
**Inputs:** [`artifact-1-territory.md`](artifact-1-territory.md), [`artifact-2-structure.md`](artifact-2-structure.md)  
**Method:** `git log --since="2025-06-09"` with path→area mapping; bot/agent authors filtered  
**Date:** 2026-06-09

## Executive summary

SafeLog AI is a **solo-maintained MVP**. After filtering bots and agent-only commit metadata, **one human contributor** appears in the last 12 months: **Szymon Iwacz** (116 commits, 100% of history).

The contributors map is still **useful for onboarding**: it maps the five highest-risk runtime areas (from territory + structure) to a **thematic support profile** — who to ask about security oracles, the analyze pipeline, HTTP slice, domain redaction, or deploy/E2E. In practice, all five routes point to the same maintainer; external support falls back to **`context/foundation/`**, **`context/archive/`** slice docs, and course staff.

---

## Top 5 areas — potential contact needed

Derived from artifact-1 (git activity + co-change) and artifact-2 (structure risk + testability):

| Rank | Area | Why contact may be needed | Structural / territory signal |
|------|------|---------------------------|-------------------------------|
| 1 | **Security oracles** (`spec/requests/*_security_spec.rb`, filter params) | Raw-log guardrails, encryption, AI boundary — wrong change breaks compliance narrative | #1 runtime co-change with `context/changes`; artifact-2: extend security specs before refactors |
| 2 | **Analyze + AI boundary** (`app/services/analysis/`, `app/services/ai/`) | Highest orchestrator complexity (`AnalyzeCase`); adapter swap, retry, prompt contract | artifact-2 Deep Focus; `redaction ⊥ ai` must hold |
| 3 | **HTTP slice** (`routes` → `controller` → `views/debugging_cases`) | Tightest runtime coupling; UI + request specs move together | artifact-1 top triple; artifact-2 controller fan-out |
| 4 | **Domain pipeline** (`intake`, `redaction`, `correlation`) | In-memory redaction, placeholders, sanitized persistence — core product logic | Linear chain intake → redaction; security-critical |
| 5 | **Deploy / E2E / certification** (`e2e/`, Fly.io, `context/certification/`) | Public demo vs local `load_demo`, submission screenshots, Playwright hub | June 2026 activity shift; artifact-2 E2E hub fragility |

**Not listed as contact areas:** `context/changes/` (documentation workflow, archived), `context/foundation/` (reference docs — ask maintainer or read first).

---

## Contributors by area (12 months, bots filtered)

**Filter applied:** exclude authors matching `bot`, `dependabot`, `github-actions`, `renovate`, `copilot`, `claude`, `codex`, `cursor`, `agent`, `noreply` (case-insensitive).  
**Result:** no bot or agent-only authors in history; all commits attributed to Szymon Iwacz (`szymon@iwacz.pl`).

### Area → who worked here (commit touches in area)

| Area | Key contributor(s) | Commits touching area | Notes |
|------|----------------------|----------------------:|-------|
| Security oracles | Szymon Iwacz | 27 | Dominant testing investment; security cookbook slices |
| HTTP slice | Szymon Iwacz | 17 | `debugging_cases_controller`, views, routes |
| Deploy / E2E / certification | Szymon Iwacz | 14 | Fly deploy, Playwright, submission PNGs |
| Analyze + AI boundary | Szymon Iwacz | 12 | AnalyzeCase, FakeClient, OpenAI adapter |
| Domain pipeline | Szymon Iwacz | 11 | Intake, redaction engine, correlation |

*“Commits touching area” = commits that modified at least one file mapped to that area (a commit can touch multiple areas).*

---

## Support line — thematic profile

### Szymon Iwacz — sole maintainer

| Thematic bucket | File-touch signal (12 mo) | Ask about |
|-----------------|---------------------------|-----------|
| **Security & request oracles** | 32 | `*_security_spec.rb`, raw-log persistence guards, filter params, authorization |
| **HTTP / debugging cases UI** | 36 | Controller actions, ERB templates, routes, Devise gating |
| **Service unit tests** | 30 | `spec/services/*`, fake AI client, analyze/intake/redaction behavior |
| **Certification & submission** | 17 | Readiness doc, screenshots, demo script, public vs local Fly |
| **Active Record / schema** | 14 | Models, migrations, encryption at rest |
| **Deploy & Fly.io** | 12 | `Dockerfile`, `fly.toml`, health check, production config |
| **Intake & redaction pipeline** | 11 | Paste intake, placeholders, `Redaction::Engine` |
| **AI adapter boundary** | 11 | `ClientResolver`, FakeClient, OpenAI, response validation |

**Suggested routing (onboarding cheat sheet):**

| If you need help with… | Contact | Fallback if unavailable |
|------------------------|---------|-------------------------|
| Security spec failing / raw log leak concern | Szymon Iwacz | `context/foundation/test-plan.md`, `spec/requests/debugging_cases_security_spec.rb` |
| Analyze / AI report / correlation | Szymon Iwacz | `app/services/analysis/analyze_case.rb`, archived `analyze-hypothesis-report` slice |
| New HTTP action or UI on cases | Szymon Iwacz | artifact-1 HTTP spine; request specs in `spec/requests/` |
| Redaction / intake behavior | Szymon Iwacz | `context/foundation/prd.md` guardrails; `spec/services/redaction/` |
| Fly deploy / E2E / submission | Szymon Iwacz | `context/deployment/deploy-plan.md`, `README` demo section |

---

## Limitations

1. **Single contributor** — no cross-checking ownership; bus factor = 1.
2. **Short history** (~3 weeks) — thematic buckets overlap (same person did everything); not a long-term specialization map.
3. **Agent-assisted work** — commits are human-authored (`Szymon Iwacz`); Cursor/AI may have assisted but no separate agent git identity to filter.
4. **Documentation vs runtime** — high activity in `context/changes/` (artifact-1) does not imply a second “docs team”; same maintainer.

State these in `repo-map.md` § Limitations and § Who to ask.

---

## Implications for repo-map synthesis

1. **§ Who to ask:** one row per [Top 5 area](#top-5-areas--potential-contact-needed) → Szymon Iwacz + doc fallback.
2. **Do not invent secondary owners** — honesty beats fake RACI on a solo MVP.
3. **Pair with artifact-2** — contact routing follows structural risk (orchestrator, E2E hub, security specs).
4. **Future contributors:** when a second author appears, re-run this prompt and split area leaders.

---

## Method notes

- Commands: `git log --since="2025-06-09" --pretty=format:%H|%an|%ae --name-only`
- Area mapping: path prefixes aligned with artifact-1 runtime ranking and artifact-2 Deep Focus zones
- Bot filter regex: `bot|dependabot|github-actions|renovate|copilot|claude|codex|cursor|agent|noreply`
- Commit counted for area if any changed file matches area prefix
