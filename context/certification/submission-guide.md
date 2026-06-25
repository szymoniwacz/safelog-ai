---
project: SafeLog AI
updated: 2026-06-25
source: 10xDevs 3.0 — course email “module 5 / Architect + Champion submission form” (program week 5)
scope: certification deadlines, rules, and forms (Builder, Architect, Champion)
---

# 10xDevs 3.0 Certification — Deadlines and Submissions

> **Source:** official course email (module 5 launch). Supersedes the marketing-site note about “2 weeks after course end”.

## Three badges

| Badge | Modules | Required? |
|-------|---------|-----------|
| **10xBuilder** | M1–M3 | **Yes** — base certificate |
| **10xArchitect** | M4 | No — optional |
| **10xChampion** | M5 | No — optional |

Modules 4 and 5 are **not required** for the base **10xBuilder** certificate.

Full evidence checklist in this repo: [`certification-readiness.md`](certification-readiness.md).

---

## Submission deadlines

Deadlines are **shared across all certification levels**. Submissions accepted **until 23:59** on each date.

| # | Date | Notes |
|---|------|-------|
| **1** | **5 July 2026** | Only this round: **distinctions** and **Demo Day** eligibility |
| **2** | **10 August 2026** | — |
| **3** | **14 September 2026** | **Final** deadline |

*(As of 25 June 2026: ~10 days until round 1.)*

---

## Submission rules — plan your strategy

Same rules as Builder; especially important for optional badges:

1. **Everything in one round** — if you want more than one badge (e.g. Builder + Architect + Champion), you must submit **all relevant forms in the same deadline round**.

2. **One attempt only** — you certify in **one** chosen round. Consider submitting closer to the deadline, when you know exactly which badges you are applying for.

3. **No adding badges later** — if you submit Builder only in July, you receive a certificate with **that badge only**. You **cannot** add Architect or Champion in a later round.

---

## Forms

| Badge | Form |
|-------|------|
| **10xBuilder** (M1–M3) | Separate form — platform post: *10xBuilder certification: submission form and key rules* (official title on course platform is in Polish) |
| **10xArchitect** + **10xChampion** (M4–M5) | **One shared form** — choose Architect, Champion, or both; fields appear dynamically |

**Architect + Champion form:**  
https://baserow.io/form/fwnBioduXc90QTli6lsCVL_YgRdTECPTCmwiVhu8d-E

### How to fill in the form

Basic details, badge selection, and matching artifacts: **report** (Architect) or **screenshots** (Champion). Upload fields appear **dynamically** based on your choices.

Full course instructions (Circle): *Everything about the capstone project and 10xDevs 3.0 certification* (official title on course platform is in Polish).

---

## What to prepare — 10xArchitect (M4)

Evidence: a concise **architecture report** (two-pager) built from four Module 4 lesson artifacts:

| Lesson | Artifact |
|--------|----------|
| M4L2 | Repository map |
| M4L3 | Feature research |
| M4L4 | Refactoring plan |
| M4L5 | Domain notes (`context/domain/`) |

Generate the report with the M4L5 lesson prompt. **The report must be yours** — something you can defend, not a single-prompt dump accepted on faith.

### SafeLog AI — mapping

| Course requirement | Location in repo |
|--------------------|-------------------|
| Repository map | [`context/map/repo-map.md`](../map/repo-map.md) + artifacts 1–3 |
| Feature research | [`10x-archive/case-submission-flow-analysis/research.md`](../../10x-archive/case-submission-flow-analysis/research.md) |
| Refactoring plan | [`context/changes/refactor-opportunities/research.md`](../changes/refactor-opportunities/research.md) + [`plan.md`](../changes/refactor-opportunities/plan.md) if present |
| DDD / domain | [`context/domain/`](../domain/) |
| Architecture report (two-pager) | [`architecture-report.md`](architecture-report.md) · [`architecture-report.pdf`](architecture-report.pdf) |
| Readiness review | [`context/reviews/m4-architect-readiness-review.md`](../reviews/m4-architect-readiness-review.md) |
| Screenshots (excerpt PNGs) | [`screenshots/architect/`](screenshots/architect/) |

---

## What to prepare — 10xChampion (M5)

**One** of two Module 5 projects is enough. Publishing a company repo is **not** required. Evidence: **screenshots** showing the workflow works in your context or a standalone PoC.

### Option A — CI/CD code review pipeline (M5L2–M3)

- pipeline view with at least one visible job,
- pipeline or job logs during code review execution,
- PR with an agent code-review comment (screenshot).

### Option B — Team AI artifact registry (M5L4)

- repo or registry where the workflow exists (screenshot),
- package definition or equivalent artifact definition (e.g. `package.json`),
- list of published versions (registry UI or CLI).

### SafeLog AI — mapping

SafeLog covers **both** Champion paths (review pipeline + package registry).

| Requirement | Location |
|-------------|----------|
| M5L2 agent | [`packages/code-reviewer/`](../../packages/code-reviewer/) |
| M5L3 workflow | [`.github/workflows/ai-code-review.yml`](../../.github/workflows/ai-code-review.yml); PR [#11](https://github.com/szymoniwacz/safelog-ai/pull/11) (fail), [#12](https://github.com/szymoniwacz/safelog-ai/pull/12) (pass) |
| M5L4 registry | [`packages/ai-toolkit/`](../../packages/ai-toolkit/) — `@szymoniwacz/ai-toolkit`; publish [run 27877220442](https://github.com/szymoniwacz/safelog-ai/actions/runs/27877220442) |
| M5L3 screenshots | [`screenshots/champion/m5l3/`](screenshots/champion/m5l3/) |
| M5L4 screenshots | [`screenshots/champion/m5l4/`](screenshots/champion/m5l4/) |
| Readiness review | [`context/reviews/m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) |

---

## What to prepare — 10xBuilder (M1–M3)

Form fields and instructions — on the course platform (*10xBuilder certification*; Polish title on platform). Minimum course requirements include **full CRUD** on a primary resource, business logic, tests, and auth — SafeLog maps CRUD to **debugging cases** (create, index/show, edit/update metadata, destroy, plus archive).

| Type | Location |
|------|----------|
| Live app | https://safelog-ai.fly.dev/ |
| Readiness review | [`context/reviews/m1-m3-builder-readiness-review.md`](../reviews/m1-m3-builder-readiness-review.md) |
| Screenshots | [`screenshots/builder/`](screenshots/builder/) |
| CI | `bin/ci` + [GHA run 28185226849](https://github.com/szymoniwacz/safelog-ai/actions/runs/28185226849) |

---

## Recommended strategy for SafeLog AI

Repo status (2026-06-25): **Builder, Architect, and Champion — READY** ([`certification-readiness.md`](certification-readiness.md)).

Given “one round, one deadline, no add-ons”:

1. **Pick a round** — distinctions / Demo Day → **5 July 2026**; otherwise a later round, but before **14 September 2026**.
2. **In the same round**, submit the **Builder** form plus the **Architect/Champion** form (select both optional badges).
3. **Builder:** screenshots + URL + CI evidence from [`screenshots/builder/`](screenshots/builder/); **`fly deploy`** so live app shows CRUD **Actions** on `/debugging_cases`.
4. **Architect:** upload [`architecture-report.pdf`](architecture-report.pdf) (or link [`architecture-report.md`](architecture-report.md)).
5. **Champion:** screenshots from [`screenshots/champion/`](screenshots/champion/) — both paths (M5L3 + M5L4) already captured.
6. **Copy-paste helper:** [`submission-checklist.md`](submission-checklist.md).

---

## Related documents

| File | Role |
|------|------|
| [`submission-checklist.md`](submission-checklist.md) | Copy-paste values for Builder + Architect/Champion forms |
| [`architecture-report.pdf`](architecture-report.pdf) | M4L5 PDF for Architect form upload |
| [`certification-readiness.md`](certification-readiness.md) | READY status, checklists, verification commands |
| [`README.md`](README.md) | Certification folder index |
| [`context/reviews/`](../../reviews/) | Per-badge readiness audits |
