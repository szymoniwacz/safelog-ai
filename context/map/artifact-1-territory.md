# Artifact 1 — Territory map (git history)

**Project:** SafeLog AI  
**Window:** 2026-05-18 → 2026-06-09 (requested: 12 months; **actual repo lifetime ~3 weeks**, 114 commits)  
**Method:** `git log` file/folder frequency, monthly split, co-change pairs (all commits + runtime-focused subset)  
**Noise filtered:** `vendor/`, `Gemfile.lock`, `db/schema.rb` (regenerated), `storage/`, `log/`, `tmp/`, Playwright artifacts, screenshots

## Executive summary

SafeLog AI is a **young, solo-maintained Rails MVP**. Hands-on runtime churn concentrates in **`app/services/*`** (domain pipeline), **`app/controllers` + views**, and **`spec/`** (especially request security oracles). Parallel **`context/changes/*`** folders track vertical slices; they dominate commit volume but are **documentation**, not deployable runtime. Completed slices were **archived** to `context/archive/` (54 file touches).

Work shifted from **feature slices (May 2026)** to **certification, deploy, and quality polish (June 2026)**.

---

## Top activity — folders / modules (filtered, 2-level depth)

| Rank | Area | Touches | Role |
|------|------|---------|------|
| 1 | `context/changes/` | 146 | Change plans, research (10x workflow; now mostly archived) |
| 2 | `context/archive/` | 54 | Completed slice docs moved out of active changes |
| 3 | `app/views/` | 46 | Server-rendered UI (`debugging_cases/`, `devise/`, `dashboard/`) |
| 4 | `context/foundation/` | 34 | PRD, roadmap, test-plan, infra |
| 5 | `spec/requests/` | 32 | HTTP + security oracles |
| 6 | `spec/services/` | 30 | Unit tests for domain services |
| 7 | `context/reviews/` | 20 | Impl/readiness reviews |
| 8 | `app/controllers/` | 15 | Thin HTTP layer |
| 9 | `app/models/` | 14 | Active Record models |
| 10 | `app/services/ai/` | 11 | Client resolver, FakeClient, OpenAI adapter, validation |

**Interpretation:** `context/changes/` looks like the biggest “module” in git but is **documentation territory**. For runtime, the real centers are **`spec/requests`**, **`spec/services`**, **`app/views/debugging_cases`**, and **`app/services/*`**.

### Runtime-only ranking (excludes `context/`)

| Rank | Area | Touches |
|------|------|---------|
| 1 | `spec/requests/` | 32 |
| 2 | `spec/services/` | 30 |
| 3 | `app/views/debugging_cases/` | 21 |
| 4 | `app/controllers/` | 15 |
| 5 | `app/models/` | 14 |
| 6 | `app/services/ai/` | 11 |
| 7 | `config/initializers/` | 10 |

### Deeper — `app/services/` (runtime core, 33 total touches)

| Subdomain | Touches | Responsibility |
|-----------|---------|----------------|
| `app/services/ai/` | 11 | Client resolver, FakeClient, OpenAI adapter, validation |
| `app/services/analysis/` | 7 | Analyze orchestration, prompt builder, report parse |
| `app/services/redaction/` | 6 | In-memory redaction engine, placeholders |
| `app/services/intake/` | 5 | Case submission, multi-source paste |
| `app/services/correlation/` | 2 | Signal extraction |
| `app/services/demo/` | 2 | Dev/test demo loader |

---

## Top activity — files (filtered)

| Rank | File | Touches | Notes |
|------|------|---------|-------|
| 1 | `context/reviews/mvp-impl-review.md` | 11 | Point-in-time review |
| 2 | `README.md` | 10 | Also appears in bootstrap commits (see hub files) |
| 3 | `AGENTS.md` | 10 | Agent onboarding |
| 4 | `context/foundation/test-plan.md` | 10 | Quality gates |
| 5 | `app/controllers/debugging_cases_controller.rb` | 10 | Main HTTP entry for product |
| 6 | `config/routes.rb` | 9 | Route surface; co-changes with controller |
| 7 | `context/changes/encrypted-diagnostic-schema/plan.md` | 9 | **Archived** — see existence check |
| 8 | `Gemfile` | 8 | Dependency changes (not lockfile) |
| 9 | `app/views/debugging_cases/show.html.erb` | 8 | Case show + redaction summary |
| 10 | `spec/requests/debugging_cases_security_spec.rb` | 7 | Raw-log guardrail oracle |

---

## Activity over time

Full quarterly split is not meaningful (all commits fall in **Q2 2026**). Monthly split is more informative:

| Period | Dominant areas | Narrative |
|--------|----------------|-----------|
| **May 2026** | `context/changes/` (109), `app/views/` (46), `context/archive/` (37), `spec/requests/` (23), `spec/services/` (22) | MVP feature verticals: intake, redaction, analyze, AI, encryption schema; slices archived as completed |
| **June 2026** | `context/foundation/` (24), `context/changes/` (37), `context/archive/` (17), `context/reviews/` (11), `spec/requests/` (9) | Builder certification, deploy evidence, Playwright, health-check updates |

**Trend:** steady product work in May → outward-facing polish and certification in June. No sign of a “broken hotspot” (repeated fixes in one file without feature progress) — changes track planned slices.

---

## Co-change — what changes together

### All commits (includes vertical-slice docs + code)

| Pair | Shared commits | Inference |
|------|----------------|-----------|
| `context/changes` ↔ `spec/requests` | 19 | 10x slice workflow: plan + security request spec in same commit |
| `context/changes` ↔ `spec/services` | 17 | Slice workflow: plan + service unit tests |
| `app/controllers` ↔ `context/changes` | 11 | Controller changes bundled with change docs |
| `app/views` ↔ `context/changes` | 11 | UI changes bundled with change docs |
| `context/changes` ↔ `context/foundation` | 9 | Slice work tied to foundation docs updates |

**Top triple:** `app/controllers` + `app/views` + `context/changes` (7 commits) — vertical slice with HTTP + UI.

**Domain + tests:** `app/services` + `spec/services` appear together in **13 commits** (classic TDD slice pattern).

### Runtime-only (excludes doc-only commits; commits with 1–25 runtime files, 65 commits)

| Pair | Shared commits | Inference |
|------|----------------|-----------|
| `app/controllers` ↔ `spec/requests` | 9 | HTTP surface and request specs move together |
| `app/controllers` ↔ `app/views` | 7 | Controller + ERB template coupling |
| `app/controllers` ↔ `config/routes.rb` | 7 | Route registration with controller changes |
| `app/views` ↔ `spec/requests` | 6 | UI + request spec in same slice |
| `config/routes.rb` ↔ `spec/requests` | 6 | Route changes validated by request specs |
| `app/models` ↔ `db/migrate` | 6 | Schema migrations with model updates |
| `app/services/ai` ↔ `spec/services` | 5 | AI boundary tested with service specs |

**Runtime top triple:** `app/controllers` + `config/routes.rb` + `spec/requests` (6 commits) — the **debugging-cases HTTP slice** is the tightest operational coupling.

**Runtime inference:** the corridor `routes` → `controller` → `views/debugging_cases` → `spec/requests` is the product's spine. Domain services couple to `spec/services`, not directly to views.

---

## Hub files — cross-area “common denominators”

Files that appear in commits touching many top-level areas (bootstrap commits inflate breadth):

| File | Pattern | Interpretation |
|------|---------|----------------|
| `README.md`, `Gemfile`, `.gitignore`, `Dockerfile`, `config/database.yml`, `bin/setup` | Co-change with ~55 areas | **Bootstrap / repo-wide setup commits** — not runtime coupling |
| `config/routes.rb` | Co-change with ~55 areas, but **7 focused runtime commits** with `app/controllers` | Meaningful **HTTP entry hub** |
| `config/initializers/filter_parameter_logging.rb` | Wide co-change | Security hardening bundled with feature slices |
| `.github/workflows/ci.yml`, `config/ci.rb` | Wide co-change | CI gate updates alongside feature work |

**No single i18n or generated contract file** acts as a hidden runtime hub (unlike large OSS frontends). Closest real hubs: **`config/routes.rb`** + **`debugging_cases_controller.rb`**.

---

## Existence check — strongly coupled paths from history

| Path | Status |
|------|--------|
| `app/controllers/debugging_cases_controller.rb` | ✓ exists |
| `config/routes.rb` | ✓ exists |
| `spec/requests/debugging_cases_security_spec.rb` | ✓ exists |
| `app/services/analysis/analyze_case.rb` | ✓ exists |
| `app/services/redaction/engine.rb` | ✓ exists |
| `context/changes/encrypted-diagnostic-schema/plan.md` | ✗ **archived** → `context/archive/2026-05-27-encrypted-diagnostic-schema/plan.md` |

Active `context/changes/` contains only `README.md` — completed slices live under `context/archive/`.

---

## Contributors (territory signal)

| Author | Commits (12 mo) | Note |
|--------|-----------------|------|
| Szymon Iwacz | 114 | Sole human contributor |

Contributor map (artifact 3) will be thin; territory analysis still valid for solo MVP.

---

## Implications for map synthesis (artifact 2+)

1. **Treat `context/changes/` as high git activity but non-runtime** — do not rank it as a deployable module; use `context/archive/` for historical slice references.
2. **Runtime core for Deep Focus candidates:** `app/services/{intake,redaction,analysis,ai}`, `app/controllers/debugging_cases_controller.rb`, `spec/requests/*_security_spec.rb`.
3. **Highest co-change corridor:** HTTP slice (`routes` → `controller` → `views/debugging_cases` → `spec/requests`) + analyze/AI services + their specs.
4. **June shift:** certification/deploy paths (`context/certification/`, `e2e/`, `fly.toml`) are active but peripheral to product logic.
5. **Limitation:** 3-week history — trends are directional, not statistically robust. State this in `repo-map.md` § Limitations.

---

## Method notes

- Commands: `git log --since="2025-06-09" --name-only`, Python co-change script on commit batches
- Runtime-focused co-change excludes commits touching >25 runtime files (bootstrap merges)
- `db/schema.rb` excluded as generated; migrations (`db/migrate/`) kept as intentional changes
- Folder depth: 2 levels for `app/services/*`, `app/views/*`, `spec/*`, `context/*`; 1 level elsewhere
