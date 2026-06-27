---
project: SafeLog AI
updated: 2026-06-26
scope: Copy-paste guide for all three 10xDevs certification forms
---

# Certification Submission Checklist

> **Rules:** Submit **Builder** and **Architect/Champion** forms in the **same deadline round**. You cannot add badges later.
>
> Deadlines (23:59): **2026-07-05** · **2026-08-10** · **2026-09-14** (final)

---

## Before you submit

| Step | Command / action | Expected | Status |
|------|------------------|----------|--------|
| Local CI | `mise exec -- bin/ci` | 280 examples, 0 failures | **DONE** 2026-06-26 |
| Fly deploy (CRUD on production) | `fly deploy --app safelog-ai` | `/up` 200; **Cases** index shows **Actions** | **DONE** 2026-06-26 |
| Builder screenshots 01–08 | `e2e/capture-submission-screenshots.spec.ts` | 8 PNGs in `screenshots/builder/` | **DONE** 2026-06-26 |
| Production health | `curl -sf https://safelog-ai.fly.dev/up` | HTTP 200 | **DONE** |
| Architect PDF | `npm run cert:architecture-pdf` | `architecture-report.pdf` exists | **DONE** |

---

## Form 1 — 10xBuilder (M1–M3)

Platform post (course): *10xBuilder certification: submission form and key rules* (official title on the course platform is in Polish).

### Copy-paste values

| Field (typical) | Value |
|-----------------|-------|
| **Project name** | SafeLog AI |
| **Public URL** | https://safelog-ai.fly.dev/ |
| **Repository** | https://github.com/szymoniwacz/safelog-ai |
| **Stack** | Rails 8.1, SQLite, Devise, server-rendered ERB, Fly.io |
| **CI evidence** | https://github.com/szymoniwacz/safelog-ai/actions/runs/28200826502 |

### Project summary

SafeLog AI is a Rails app for safe multi-source production incident debugging. Raw logs are redacted **in memory** before persistence and before any AI call — only sanitized evidence is stored (encrypted in SQLite). The user creates a case from multiple pasted log sources, reviews the redaction summary, runs AI analysis (hypothesis-framed report, not a verdict), exports Markdown, edits case metadata, deletes or archives cases. Auth: Devise; per-user isolation (404 cross-user). Tests: 280 RSpec + 10 system + 23 Playwright E2E (4 capture + 19 functional); fake AI in CI.

### Screenshots to attach

Upload **all 8** PNGs from [`screenshots/builder/`](screenshots/builder/) (captured 2026-06-26 on live Fly with CRUD):

1. `01-sign-in.png`
2. `02-sign-up.png`
3. `03-dashboard.png`
4. `04-new-case-intake.png`
5. `05-case-redaction-summary.png`
6. `08-cases-index-actions.png` — **Cases** index with **Actions** column (Edit / Delete)
7. `06-hypothesis-report.png`
8. `07-archived-cases.png`

**Note for reviewers:** Fly production hides **Load demo case** by default — use **New case** + manual paste, or ask the deployer to set `SAFELOG_ENABLE_DEMO_LOADER=true` on Fly for the one-click fixture. See [`certification-readiness.md`](certification-readiness.md) § Public demo vs local `load_demo`.

### Supporting docs (links if form allows)

| Doc | Path |
|-----|------|
| Readiness audit | `context/reviews/m1-m3-builder-readiness-review.md` |
| PRD | `context/foundation/prd.md` |
| Deploy plan | `context/deployment/deploy-plan.md` |

---

## Form 2 — 10xArchitect + 10xChampion (M4–M5)

**URL:** https://baserow.io/form/fwnBioduXc90QTli6lsCVL_YgRdTECPTCmwiVhu8d-E

Select **both** Architect and Champion in the same submission.

### 10xArchitect (M4)

| Field (typical) | Value |
|-----------------|-------|
| **Architecture report** | Upload [`architecture-report.pdf`](architecture-report.pdf) |
| **Report source (markdown)** | [`architecture-report.md`](architecture-report.md) |
| **Repo map** | `context/map/repo-map.md` |
| **Flow research** | `10x-archive/case-submission-flow-analysis/research.md` |
| **Refactor ranking** | `context/changes/refactor-opportunities/research.md` |
| **Domain notes** | `context/domain/` (3 files) |
| **Readiness review** | `context/reviews/m4-architect-readiness-review.md` |

**Screenshots (optional supplement):** 6 PNGs in [`screenshots/architect/`](screenshots/architect/)

**Defensibility one-liner:** Report synthesizes M4L2–L5 artifacts with ast-grep verification — repo map, intake flow research, ranked refactors, DDD distillation + invariant/ACL plans (plans only; implementation optional post-MVP).

### 10xChampion (M5)

Course requires **one** of two paths; SafeLog covers **both**.

#### Option A — CI/CD code review (M5L2–M3)

| Evidence | Location |
|----------|----------|
| Agent | `packages/code-reviewer/` |
| Workflow | `.github/workflows/ai-code-review.yml` |
| Fail PR | https://github.com/szymoniwacz/safelog-ai/pull/11 |
| Pass PR | https://github.com/szymoniwacz/safelog-ai/pull/12 |
| Screenshots | [`screenshots/champion/m5l3/`](screenshots/champion/m5l3/) — **form: 04, 05, 06 (pass)** |

#### Option B — Team AI registry (M5L4)

| Evidence | Location |
|----------|----------|
| Package | `@szymoniwacz/ai-toolkit@0.1.1` on GitHub Packages |
| Source | `packages/ai-toolkit/` |
| Publish workflow | `.github/workflows/publish-ai-toolkit.yml` |
| Publish run | https://github.com/szymoniwacz/safelog-ai/actions/runs/27877220442 |
| Toolkit PR | https://github.com/szymoniwacz/safelog-ai/pull/13 |
| Screenshots | [`screenshots/champion/m5l4/`](screenshots/champion/m5l4/) (8 PNGs) |

**Champion summary:** Code review pipeline (TypeScript agent + GHA on PRs to `main`, fail/pass scenarios) and team AI toolkit distribution via GitHub Packages with postinstall into Cursor skills/rules.

### Readiness review

`context/reviews/m5-champion-readiness-review.md`

---

## Demo script (all badges)

1. Open https://safelog-ai.fly.dev/ → sign up / sign in.
2. **New debugging case** → paste ≥2 log sources with fake secrets (email, token, shared request_id).
3. Confirm show page: placeholders only, **Redaction summary** visible.
4. **Analyze case** → hypothesis report + correlation signals.
5. **Edit** case metadata from **Cases** index or case show; **Delete** (irreversible browser confirm) or **Archive** → **Archived** filter.
6. Optional: **Download** Markdown report.

Local alternative: `mise exec -- bin/dev` → **Load demo case** (dev/test only).

---

## Verification log (2026-06-26)

| Check | Result |
|-------|--------|
| `bin/ci` | 280 examples, 0 failures; 100% line + branch coverage |
| `bundle exec rspec spec/system` | 10 examples, 0 failures |
| `bin/e2e --grep-invert capture` | 19 functional tests passed |
| `fly deploy --app safelog-ai` | Success; [GHA deploy 28200851152](https://github.com/szymoniwacz/safelog-ai/actions/runs/28200851152) |
| Builder screenshots 01–08 | Captured on https://safelog-ai.fly.dev/ |
| `npm run depcruise:validate` | 0 violations |
| `packages/ai-toolkit` smoke | passed |
| Fly `/up` | 200 |
| GHA `main` CI | [run 28200826502](https://github.com/szymoniwacz/safelog-ai/actions/runs/28200826502) on `80ab4d1` (2026-06-26) |

---

## Related

| File | Role |
|------|------|
| [`certification-readiness.md`](certification-readiness.md) | Full checklists per badge |
| [`submission-guide.md`](submission-guide.md) | Course deadlines and rules |
| [`architecture-report.pdf`](architecture-report.pdf) | Architect upload artifact |
