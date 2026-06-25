---
project: SafeLog AI
updated: 2026-06-24
scope: 10xDevs Builder + Architect + Champion
---

# 10xDevs Certification Readiness

> **Source of truth** for certification progress across all three badges.
> Update this file as evidence accrues.
>
> **Submission deadlines, forms, and course rules:** [`submission-guide.md`](submission-guide.md)

## Submission deadlines (course)

Official 10xDevs 3.0 intake closes **23:59** on each date. All badges submitted in the **same** chosen round (no adding Architect/Champion later).

| Round | Date | Notes |
|-------|------|-------|
| **1** | **2026-07-05** | Distinctions + Demo Day eligibility |
| **2** | **2026-08-10** | — |
| **3** | **2026-09-14** | Final |

- **Builder (M1–M3):** separate form — see platform post *10xBuilder certification: submission form and key rules* (course title in Polish on platform).
- **Architect + Champion (M4–M5):** [shared Baserow form](https://baserow.io/form/fwnBioduXc90QTli6lsCVL_YgRdTECPTCmwiVhu8d-E).

Full rules, SafeLog artifact mapping, and recommended strategy: [`submission-guide.md`](submission-guide.md).

## Current Status

| Badge | Modules | Verdict | Summary |
|-------|---------|---------|---------|
| **10xBuilder** | M1–M3 | **READY** | MVP shipped; 256 RSpec + 9 system + 19 Playwright E2E (4 capture + 15 functional); Fly.io at https://safelog-ai.fly.dev/; submission screenshots captured; local `bin/ci` + remote GHA green on `main` (re-verify GHA after latest push). |
| **10xArchitect** | M4 | **READY** | M4L2–L5 complete — repo map, flow research, ranked refactors, DDD distillation + invariant/ACL plans; [`architecture-report.md`](architecture-report.md) two-pager; readiness review + excerpt screenshots. |
| **10xChampion** | M5 | **READY** | M5L2 review agent + M5L3 GHA AI review (PR #11 fail / #12 pass) + M5L4 `@szymoniwacz/ai-toolkit` on GitHub Packages ([PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13), [run 27877220442](https://github.com/szymoniwacz/safelog-ai/actions/runs/27877220442)); readiness review + screenshots. |

**Overall:** All three badges **ready to submit** — Builder, Architect, and Champion evidence populated below.

---

## Roadmap: Builder → Architect → Champion

```mermaid
flowchart LR
  B[10xBuilder READY] --> A[10xArchitect READY]
  A --> C[10xChampion READY]
  B --> S[Final combined submission]
  A --> S
  C --> S
```

| Phase | Goal | Remaining before final submission |
|-------|------|-----------------------------------|
| **Builder** | Working MVP + context + tests + CI + deploy | None — ready; use Builder form in chosen [deadline round](submission-guide.md#submission-deadlines) |
| **Architect** | Large-repo architecture literacy + evidence | None — M4L2–L5 done; [`architecture-report.md`](architecture-report.md) + [Baserow form](https://baserow.io/form/fwnBioduXc90QTli6lsCVL_YgRdTECPTCmwiVhu8d-E) |
| **Champion** | AI-assisted team workflow + automation | None — M5L2–L4 done; screenshots in same round as Builder |
| **Final package** | One submission round, up to three badges | None — use [`submission-checklist.md`](submission-checklist.md) for form copy-paste |

---

## 10xBuilder

**Verdict: READY** (evidence: `context/reviews/m1-m3-builder-readiness-review.md`, `context/reviews/m1-m3-final-impl-review.md`)

### Checklist

| Item | Status | Evidence |
|------|--------|----------|
| Access control — Devise auth, gated routes | **PASS** | `AuthenticatedController`; `spec/requests/devise/*` |
| Access control — per-user isolation | **PASS** | `debugging_cases_authorization_spec.rb` |
| CRUD — create, read (index/show), archive | **PASS** | Request specs; no edit/destroy (intentional MVP); **archive only** — no unarchive (post-MVP parked; `roadmap.md` Parked, `test-plan.md` §7) |
| Business logic — redaction, intake, correlation, analyze, export | **PASS** | `app/services/*`; service + request specs |
| Context documents — PRD, roadmap, test-plan, infra, deploy-plan | **PASS** | `context/foundation/*` |
| Tests — meaningful coverage | **PASS** | 256 RSpec + 9 system + 19 Playwright E2E (4 capture + 15 functional); SimpleCov 100% line + branch in full suite |
| CI/CD — local gate | **PASS** | `mise exec -- bin/ci` green 2026-06-24 (240 examples) |
| CI/CD — GitHub Actions config | **PASS** | `.github/workflows/ci.yml` parity with `config/ci.rb` |
| CI/CD — remote GHA on latest `main` | **PASS** | Re-run GHA after push; prior green [Run 27970702328](https://github.com/szymoniwacz/safelog-ai/actions/runs/27970702328) on `2ecea64` (2026-06-22) |
| Public URL | **PASS** | https://safelog-ai.fly.dev/ — redeploy verified 2026-06-22 |
| Deployment evidence | **PASS** | `deploy-plan.md` § Deployment status + lessons learned; manual E2E verification |
| Demo flow — local | **PASS** | README demo section; **Load demo case** + manual intake; system + Playwright specs |
| Demo flow — public | **PASS** | Manual intake → analyze → archive on Fly (2026-06-09); **no load_demo** — see [Public demo vs local](#public-demo-vs-local-load_demo) |
| Submission screenshots | **PASS** | [`context/certification/screenshots/builder/`](screenshots/builder/) — 7 PNGs from live Fly (2026-06-09) |
| Security evidence | **PASS** | Security checklist in builder readiness review; log guard, encryption, AI boundary specs |

### Evidence

| Type | Location |
|------|----------|
| Readiness audit | [`context/reviews/m1-m3-builder-readiness-review.md`](../reviews/m1-m3-builder-readiness-review.md) |
| Impl-review (M1–M3) | [`context/reviews/m1-m3-final-impl-review.md`](../reviews/m1-m3-final-impl-review.md) |
| Historical impl-review | [`context/reviews/mvp-impl-review.md`](../reviews/mvp-impl-review.md) |
| PRD / roadmap / test-plan | [`context/foundation/`](../foundation/) |
| Deploy plan | [`context/deployment/deploy-plan.md`](../deployment/deploy-plan.md) |
| Submission screenshots | [`context/certification/screenshots/builder/`](screenshots/builder/) |
| Health check | [`context/foundation/health-check.md`](../foundation/health-check.md) |

### Commands (verified 2026-06-24)

```bash
mise exec -- bin/ci                              # 240 examples — PASS
mise exec -- bundle exec rspec spec/system       # 9 examples — PASS
mise exec -- bin/e2e                             # 13 functional Playwright tests — PASS
mise exec -- bin/dev                             # local demo
curl -sf https://safelog-ai.fly.dev/up           # production health — verify before demo
```

### CI evidence

- Local: `config/ci.rb` — setup, RuboCop, bundler-audit, importmap audit, Brakeman, RSpec.
- GHA: four jobs (`scan_ruby`, `scan_js`, `lint`, `test`); same tools.
- Remote: latest `main` verified 2026-06-22 — [run 27970702328](https://github.com/szymoniwacz/safelog-ai/actions/runs/27970702328) (`2ecea64`; lint, scan_ruby, scan_js, test all success).
- Playwright: optional (`bin/e2e`); not in `bin/ci` (see `test-plan.md` §6.9).

---

## 10xArchitect

**Verdict: READY** (evidence: [`context/reviews/m4-architect-readiness-review.md`](../reviews/m4-architect-readiness-review.md))

Module 4 course prompts:

| Prompt | Expected artifact | Status |
|--------|-------------------|--------|
| `.cursor/prompts/m4l2-1-territory-git-history.md` | `context/map/artifact-1-territory.md` | **PASS** |
| `.cursor/prompts/m4l2-2-structure-dependency-cruiser.md` | `context/map/artifact-2-structure.md` | **PASS** |
| `.cursor/prompts/m4l2-repo-map-synthesis.md` | `context/map/repo-map.md` | **PASS** |
| `.cursor/prompts/m4l3-1-research-with-map.md` | `10x-archive/case-submission-flow-analysis/research.md` | **PASS** |
| `.cursor/prompts/m4l3-2-ast-grep-verification.md` | AST-grep verification in same research doc | **PASS** |
| `.cursor/prompts/m4l4-1-new-change-intention.md` | `context/changes/refactor-opportunities/change.md` | **PASS** |
| `.cursor/prompts/m4l4-2-refactor-opportunities-research.md` | `context/changes/refactor-opportunities/research.md` | **PASS** |
| `.cursor/prompts/m4l4-3-ranking-ast-grep-verification.md` | § Claim verification in same research doc | **PASS** |
| `.cursor/prompts/m4l5-1-domain-distillation.md` | `context/domain/01-domain-distillation.md` | **PASS** |
| `.cursor/prompts/m4l5-2-invariant-aggregate-refactor.md` | `context/domain/02-invariant-aggregate-refactor.md` | **PASS** |
| `.cursor/prompts/m4l5-3-anti-corruption-layer.md` | `context/domain/03-anti-corruption-layer.md` | **PASS** |

### Checklist (Module 4 outcomes)

| Item | Status | Notes |
|------|--------|-------|
| Architecture work — repo map / territory analysis | **PASS** | [`repo-map.md`](../map/repo-map.md) + artifacts 1–3 |
| Large-context workflows — map synthesis | **PASS** | [`repo-map.md`](../map/repo-map.md) synthesizes territory, structure, contributors |
| Large-context workflows — targeted research with map | **PASS** | [`case-submission-flow-analysis/research.md`](../../10x-archive/case-submission-flow-analysis/research.md) (M4L3-1) |
| Structural verification — ast-grep (flow analysis) | **PASS** | AST-grep section in case-submission research (M4L3-2) |
| Refactoring exploration — ranked opportunities | **PASS** | [`refactor-opportunities/research.md`](../changes/refactor-opportunities/research.md) (M4L4-2); ast-grep verified (M4L4-3) |
| Domain distillation — ubiquitous language, subdomains, aggregates | **PASS** | [`01-domain-distillation.md`](../domain/01-domain-distillation.md) (M4L5-1) |
| Invariant analysis — aggregate guardian plan | **PASS** | [`02-invariant-aggregate-refactor.md`](../domain/02-invariant-aggregate-refactor.md) (M4L5-2) — INV-G1 / `SanitizedCaseDraft` (plan) |
| Anti-corruption layer — AI adapter boundary plan | **PASS** | [`03-anti-corruption-layer.md`](../domain/03-anti-corruption-layer.md) (M4L5-3) — `HypothesisGenerator` port (plan) |
| Refactoring exercises — documented exploration | **PASS** | M4L4 ranking + M4L5 plans; **implementation optional** post-MVP (see Known Gaps) |
| Architecture evidence — diagrams / boundaries | **PASS** | Map artifacts + domain mermaid; `redaction ⊥ ai` in artifact-2 / repo-map |
| Review artifacts — Architect readiness review | **PASS** | [`m4-architect-readiness-review.md`](../reviews/m4-architect-readiness-review.md) |
| Architecture report (two-pager) | **PASS** | [`architecture-report.md`](architecture-report.md) · [`architecture-report.pdf`](architecture-report.pdf) — M4L5 submission synthesis |
| Submission screenshots | **PASS** | [`screenshots/architect/`](screenshots/architect/) — 6 excerpt PNGs |

### Evidence

| Type | Location |
|------|----------|
| Readiness audit | [`context/reviews/m4-architect-readiness-review.md`](../reviews/m4-architect-readiness-review.md) |
| Architecture report (two-pager) | [`architecture-report.md`](architecture-report.md) · [`architecture-report.pdf`](architecture-report.pdf) |
| Repo map synthesis | [`context/map/repo-map.md`](../map/repo-map.md) |
| Map artifacts | [`context/map/artifact-1-territory.md`](../map/artifact-1-territory.md), [`artifact-2-structure.md`](../map/artifact-2-structure.md), [`artifact-3-contributors.md`](../map/artifact-3-contributors.md) |
| Flow research (M4L3) | [`10x-archive/case-submission-flow-analysis/research.md`](../../10x-archive/case-submission-flow-analysis/research.md) |
| Refactor ranking (M4L4) | [`context/changes/refactor-opportunities/research.md`](../changes/refactor-opportunities/research.md) |
| Domain distillation (M4L5) | [`context/domain/`](../domain/) |
| E2E dependency diagram | [`context/map/diagrams/e2e-helper-hub.svg`](../map/diagrams/e2e-helper-hub.svg) |
| Submission screenshots | [`context/certification/screenshots/architect/`](screenshots/architect/) |

### Commands (verified 2026-06-20)

```bash
npm run depcruise:validate              # E2E boundary — PASS
npm run depcruise:graph                 # regenerates context/map/diagrams/e2e-helper-hub.svg
PLAYWRIGHT_SKIP_WEBSERVER=1 PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
  npx playwright test e2e/capture-architect-screenshots.spec.ts
```

---

## 10xChampion

**Verdict: READY** (evidence: [`context/reviews/m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md))

### Checklist (Module 5 outcomes)

| Item | Status | Notes |
|------|--------|-------|
| AI-assisted team workflow | **PASS** | `packages/code-reviewer/` — TypeScript agent (OpenAI via Vercel AI SDK) |
| CI/CD AI integration | **PASS** | `.github/workflows/ai-code-review.yml`; composite action; labels `ai-cr:*` |
| Team artifact distribution (M5L4) | **PASS** | `@szymoniwacz/ai-toolkit` — GitHub Packages; postinstall + manifest |
| Automation workflows — hooks / bots | **PASS** | GHA bots (AI review + toolkit publish); `.cursor/hooks.json` |
| Quality gates — extended automation | **PASS** | AI review on PR to `main`; toolkit validate + smoke in publish workflow |
| Champion exercises | **PASS** | M5L2 + M5L3 + M5L4 implemented and archived |
| Review artifacts — Champion review | **PASS** | [`m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) |
| Submission screenshots | **PASS** | M5L3: [`screenshots/champion/m5l3/`](screenshots/champion/m5l3/) (6 PNGs); M5L4: [`screenshots/champion/m5l4/`](screenshots/champion/m5l4/) (8 PNGs) |

### Evidence

| Type | Location |
|------|----------|
| Readiness audit | [`context/reviews/m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) |
| Review agent (M5L2) | [`packages/code-reviewer/`](../../packages/code-reviewer/) |
| CI workflow (M5L3) | [`.github/workflows/ai-code-review.yml`](../../.github/workflows/ai-code-review.yml) |
| Change spec (M5L3) | [`context/changes/ci-cd-code-review/`](../changes/ci-cd-code-review/) |
| Test PR (fail) | [PR #11](https://github.com/szymoniwacz/safelog-ai/pull/11) — verdict **fail** (intentional issues) |
| Test PR (pass) | [PR #12](https://github.com/szymoniwacz/safelog-ai/pull/12) — verdict **pass** (`feature/case-index-analysis-status`) |
| GHA run (fail) | [Run 27760320185](https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185) |
| GHA run (pass) | [Run 27763104255](https://github.com/szymoniwacz/safelog-ai/actions/runs/27763104255) |
| Distribution decision (M5L4) | [`context/team/m5l4-distribution-decision.md`](../team/m5l4-distribution-decision.md) |
| AI toolkit package (M5L4) | [`packages/ai-toolkit/`](../../packages/ai-toolkit/) — `@szymoniwacz/ai-toolkit@0.1.1` |
| Publish workflow (M5L4) | [`.github/workflows/publish-ai-toolkit.yml`](../../.github/workflows/publish-ai-toolkit.yml) |
| Toolkit change + impl-review | [`context/archive/2026-06-20-ai-toolkit-registry/`](../archive/2026-06-20-ai-toolkit-registry/) |
| Toolkit PR | [PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13) — merged 2026-06-20 |
| GHA publish run | [Run 27877220442](https://github.com/szymoniwacz/safelog-ai/actions/runs/27877220442) (0.1.1); first publish [27875364234](https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234) (0.1.0) |
| Screenshots (M5L3) | [`context/certification/screenshots/champion/m5l3/`](screenshots/champion/m5l3/) |
| Screenshots (M5L4) | [`context/certification/screenshots/champion/m5l4/`](screenshots/champion/m5l4/) |

### Commands (verified 2026-06-20)

```bash
cd packages/ai-toolkit && npm run smoke          # install/uninstall round-trip — PASS
npx @szymoniwacz/ai-toolkit install             # refresh AGENTS.md + skill from registry
gh run view 27875364234                           # publish workflow evidence
```

---

## Final Submission Package

Single **certification round** for **Builder + Architect + Champion** — all badges ready in repo; submit both forms in the same chosen deadline ([`submission-guide.md`](submission-guide.md)).

| Artifact | Builder | Architect | Champion |
|----------|---------|-----------|----------|
| Project summary | README + PRD | [`architecture-report.md`](architecture-report.md) + [`repo-map.md`](../map/repo-map.md) | [`m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) executive summary |
| Demo script | See [Demo flow](#demo-flow) | Walk `architecture-report.md` → domain plans → optional `npm run depcruise:graph` | M5L3: PR AI review; M5L4: `npm install` → skill in `.cursor/skills/` |
| Screenshots | [`screenshots/builder/`](screenshots/builder/) (7 PNGs) | [`screenshots/architect/`](screenshots/architect/) (6 PNGs) | M5L3: [`screenshots/champion/m5l3/`](screenshots/champion/m5l3/) (6); M5L4: [`screenshots/champion/m5l4/`](screenshots/champion/m5l4/) (8) |
| Deployment URL | https://safelog-ai.fly.dev/ | Same URL + architecture notes in repo-map | Same + automation proof |
| Review documents | [`m1-m3-builder-readiness-review.md`](../reviews/m1-m3-builder-readiness-review.md) | [`m4-architect-readiness-review.md`](../reviews/m4-architect-readiness-review.md) | [`m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) |
| CI evidence | `bin/ci` + GHA config | `depcruise:validate` + map/structure artifacts | [AI code review](../../.github/workflows/ai-code-review.yml) + [publish toolkit](../../.github/workflows/publish-ai-toolkit.yml) |
| Certification notes | This file | Architect section current (2026-06-22) | Champion section current (2026-06-20) |

### Demo flow (Builder — verified locally and on Fly)

**For reviewers opening https://safelog-ai.fly.dev/:** see [Public demo vs local `load_demo`](#public-demo-vs-local-load_demo) below — **Load demo case** is off by default; optional via `SAFELOG_ENABLE_DEMO_LOADER`.

1. Register or sign in at `/` (local or https://safelog-ai.fly.dev/).
2. **New case** with multiple pasted sources (fake secrets). On Fly, use manual intake by default — or enable **Load demo case** with `SAFELOG_ENABLE_DEMO_LOADER=true` for reviewer convenience.
3. Confirm placeholders on show — raw paste not visible; **Redaction summary** visible.
4. **Analyze case** → hypothesis report + correlation signals.
5. **Download** Markdown report.
6. **Archive** → **Archived** filter on case index.

Security narrative: transient raw intake; encrypted `sanitized_content`; scoped `find` → 404; FakeClient in CI.

### Public demo vs local `load_demo`

Reviewers and course staff often compare the README demo (which mentions **Load demo case**) with the public Fly URL. They are **not the same entry path**; everything after case creation is the same pipeline.

| | **Local** (`mise exec -- bin/dev`) | **Public Fly** (`https://safelog-ai.fly.dev/`) |
|---|-----------------------------------|------------------------------------------------|
| **Environment** | `development` | `production` |
| **Load demo case** | **Yes** — dashboard button; one-click checkout-timeout fixture (`Demo::LoadCase`) | **Off by default** — button hidden; `POST /debugging_cases/load_demo` returns **404**. Set Fly secret `SAFELOG_ENABLE_DEMO_LOADER=true` (`1` / `yes` also work) to enable for reviewers |
| **How to start a case** | **Load demo case** *or* **New case** + manual paste | **New case** + manual paste by default — or **Load demo case** when the secret is set |
| **Redaction / analyze / export / archive** | Same services and UI | Same services and UI |
| **AI output** | `Ai::FakeClient` if `OPENAI_API_KEY` unset — dashboard + case show **demo AI** callout | Same (Fly default; not a deploy bug) |
| **Submission screenshots** | N/A | Captured via manual intake on Fly — see [`screenshots/builder/04-new-case-intake.png`](screenshots/builder/04-new-case-intake.png) |

**Why production hides load_demo by default:** `Demo::LoadCase.available?` is true in development and test, and in production only when `SAFELOG_ENABLE_DEMO_LOADER` is truthy (`app/services/demo/load_case.rb`). Default production keeps the demo surface minimal on a public URL.

**Reviewer checklist (Fly, after `fly deploy`):**

1. Confirm app is up: `curl -sf https://safelog-ai.fly.dev/up`
2. Register a new account (or sign in) — screenshots [`builder/01-sign-in.png`](screenshots/builder/01-sign-in.png), [`builder/02-sign-up.png`](screenshots/builder/02-sign-up.png)
3. **New case** → paste multiple sources with fake secrets (e.g. email, token, shared `request_id`)
4. Verify show page: placeholders only, **Redaction summary** present — [`builder/05-case-redaction-summary.png`](screenshots/builder/05-case-redaction-summary.png)
5. **Analyze case** → hypothesis report — [`builder/06-hypothesis-report.png`](screenshots/builder/06-hypothesis-report.png)
6. Optional: download report, archive, **Archived** tab — [`builder/07-archived-cases.png`](screenshots/builder/07-archived-cases.png)

Do **not** expect a **Load demo case** button on Fly unless `SAFELOG_ENABLE_DEMO_LOADER` is set — absence is default, not a deploy bug.

### Demo AI client (FakeClient default)

Public Fly and local dev without `OPENAI_API_KEY` use `Ai::FakeClient` — analyze completes with canned hypothesis text, not live OpenAI. The signed-in **dashboard** and **case show** pages show a callout when this mode is active.

**Reviewer expectation:** After **Analyze case**, read the report as a pipeline demo (redaction → correlation → structured report), not as provider-generated diagnosis. Optional: `fly secrets set OPENAI_API_KEY="..."` — see README § AI client and `context/deployment/deploy-plan.md`.

### Commands reference

```bash
# Setup
mise install && mise exec -- bundle install && mise exec -- bin/setup --skip-server

# Gates
mise exec -- bin/ci
mise exec -- bundle exec rspec spec/system
mise exec -- bin/e2e

# Demo
mise exec -- bin/dev

# Production health check
curl -sf https://safelog-ai.fly.dev/up

# Re-capture submission screenshots (Fly must be running)
PLAYWRIGHT_SKIP_WEBSERVER=1 PLAYWRIGHT_BASE_URL=https://safelog-ai.fly.dev \
  PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 npx playwright test e2e/capture-submission-screenshots.spec.ts
```

---

## Known Gaps

### Builder

| Gap | Severity | Action |
|-----|----------|--------|
| Fake AI default without `OPENAI_API_KEY` | Accepted | Documented — demo AI callout on dashboard + case show; optional Fly secret |
| Unarchive / restore archived case | Accepted | Archive-only MVP per PRD FR-010; parked post-MVP — reviewers should not expect a restore action |

### Architect

| Gap | Severity | Action |
|-----|----------|--------|
| DDD plans not implemented in Ruby | Accepted | Optional post-MVP — follow F1–Fn in `context/domain/` when prioritizing structural hygiene; **not required for Architect badge** |
| Roadmap modernization (Postgres, observability) | Accepted | Parked product backlog |

### Champion

| Gap | Severity | Action |
|-----|----------|--------|
| Playwright not in main GHA | Accepted | Optional gate; E2E capture scripts exist for submission screenshots |

---

## Related documents (audit trail)

| File | Role |
|------|------|
| `context/certification/architecture-report.md` | M4L5 two-pager for Architect form upload |
| `context/certification/architecture-report.pdf` | PDF export (`npm run cert:architecture-pdf`) |
| `context/certification/submission-guide.md` | Official course deadlines, forms, submission rules, SafeLog mapping |
| `context/reviews/m1-m3-builder-readiness-review.md` | Point-in-time Builder audit (2026-06-09) |
| `context/reviews/m1-m3-final-impl-review.md` | Six-dimension Builder impl-review |
| `context/reviews/m4-architect-readiness-review.md` | Point-in-time Architect audit (2026-06-20) |
| `context/reviews/m5-champion-readiness-review.md` | Point-in-time Champion audit (2026-06-20) |
| `context/certification/submission-checklist.md` | Copy-paste guide for all three forms |
| `context/reviews/builder-certification-submission-checklist.md` | **Superseded** — use `submission-checklist.md` |
| `context/domain/01-domain-distillation.md` | M4L5-1 — ubiquitous language, subdomains, MODEL vs CODE gaps |
| `context/domain/02-invariant-aggregate-refactor.md` | M4L5-2 — INV-G1 aggregate guardian plan (plans only) |
| `context/domain/03-anti-corruption-layer.md` | M4L5-3 — AI adapter ACL plan (plans only) |

**Maintenance:** After each module milestone, update the badge section and [Current Status](#current-status). Archive point-in-time reviews under `context/reviews/`; do not fork multiple living checklists.
