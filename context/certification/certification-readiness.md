---
project: SafeLog AI
updated: 2026-06-20
scope: 10xDevs Builder + Architect + Champion
---

# 10xDevs Certification Readiness

> **Source of truth** for certification progress across all three badges.
> Update this file as evidence accrues. Do not invent Architect or Champion proof — use `TODO` / `NOT VERIFIED` until artifacts exist.

## Current Status

| Badge | Modules | Verdict | Summary |
|-------|---------|---------|---------|
| **10xBuilder** | M1–M3 | **READY** | MVP shipped; 135 RSpec + system + Playwright; Fly.io live at https://safelog-ai.fly.dev/; submission screenshots captured; local `bin/ci` + remote GHA green on `main` (2026-06-09). |
| **10xArchitect** | M4 | **IN PROGRESS** | M4L2–L5 complete (map, flow research, refactor ranking, domain distillation, invariant + ACL plans); pending Architect review, refactor **implementation**, modernization. |
| **10xChampion** | M5 | **READY** | M5L2 review agent + M5L3 GHA AI review (PR #11 fail / #12 pass) + M5L4 `@szymoniwacz/ai-toolkit` on GitHub Packages ([PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13), [run 27875364234](https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234)); Champion readiness review + screenshots. |

**Overall:** Builder and Champion **ready to submit**. Architect **in progress** — M4L2–L5 exploration and DDD planning complete; ranked refactor plans in `context/domain/`; review + refactor implementation pending.

---

## Roadmap: Builder → Architect → Champion

```mermaid
flowchart LR
  B[10xBuilder READY] --> A[10xArchitect IN PROGRESS]
  A --> C[10xChampion READY]
  B --> S[Final combined submission]
  A --> S
  C --> S
```

| Phase | Goal | Remaining before final submission |
|-------|------|-----------------------------------|
| **Builder** | Working MVP + context + tests + CI + deploy | None — ready to submit |
| **Architect** | Large-repo architecture literacy + evidence | M4L2–L5 complete (incl. domain distillation + refactor plans); remaining: Architect review, implement ranked refactors, modernization |
| **Champion** | AI-assisted team workflow + automation | None — M5L2–L4 done; readiness review + screenshots captured |
| **Final package** | One submission, three badges | All sections below populated; demo script; screenshots |

---

## 10xBuilder

**Verdict: READY** (evidence: `context/reviews/m1-m3-builder-readiness-review.md`, `context/reviews/m1-m3-final-impl-review.md`)

### Checklist

| Item | Status | Evidence |
|------|--------|----------|
| Access control — Devise auth, gated routes | **PASS** | `AuthenticatedController`; `spec/requests/devise/*` |
| Access control — per-user isolation | **PASS** | `debugging_cases_authorization_spec.rb` |
| CRUD — create, read (index/show), archive | **PASS** | Request specs; no edit/destroy (intentional MVP) |
| Business logic — redaction, intake, correlation, analyze, export | **PASS** | `app/services/*`; service + request specs |
| Context documents — PRD, roadmap, test-plan, infra, deploy-plan | **PASS** | `context/foundation/*` |
| Tests — meaningful coverage | **PASS** | 135 RSpec + 7 system + 5 Playwright |
| CI/CD — local gate | **PASS** | `mise exec -- bin/ci` green 2026-06-09 |
| CI/CD — GitHub Actions config | **PASS** | `.github/workflows/ci.yml` parity with `config/ci.rb` |
| CI/CD — remote GHA on latest `main` | **PASS** | [Run 27228714749](https://github.com/szymoniwacz/safelog-ai/actions/runs/27228714749) on `3c92dcb` (2026-06-09); all four jobs green; 135 RSpec examples |
| Public URL | **PASS** | https://safelog-ai.fly.dev/ — live; deploy verified 2026-06-09 |
| Deployment evidence | **PASS** | `deploy-plan.md` § Deployment status + lessons learned; manual E2E verification (2026-06-09) |
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

### Commands (verified 2026-06-09)

```bash
mise exec -- bin/ci                              # 135 examples — PASS
mise exec -- bundle exec rspec spec/system       # 7 examples — PASS
mise exec -- bin/e2e                             # 5 Playwright tests — PASS
mise exec -- bin/dev                             # local demo
```

### CI evidence

- Local: `config/ci.rb` — setup, RuboCop, bundler-audit, importmap audit, Brakeman, RSpec.
- GHA: four jobs (`scan_ruby`, `scan_js`, `lint`, `test`); same tools.
- Remote: latest `main` verified 2026-06-09 — [run 27228714749](https://github.com/szymoniwacz/safelog-ai/actions/runs/27228714749) (`3c92dcb`; lint, scan_ruby, scan_js, test all success).
- Playwright: optional (`bin/e2e`); not in `bin/ci` (see `test-plan.md` §6.9).

---

## 10xArchitect

**Verdict: IN PROGRESS** — M4L2–L5 exploration and DDD planning complete; Architect review and refactor **implementation** pending.

Module 4 course prompts:

| Prompt | Expected artifact | Status |
|--------|-------------------|--------|
| `.cursor/prompts/m4l2-1-territory-git-history.md` | `context/map/artifact-1-territory.md` | **PASS** |
| `.cursor/prompts/m4l2-2-structure-dependency-cruiser.md` | `context/map/artifact-2-structure.md` | **PASS** |
| `.cursor/prompts/m4l2-repo-map-synthesis.md` | `context/map/repo-map.md` | **PASS** |
| `.cursor/prompts/m4l3-1-research-with-map.md` | `context/changes/case-submission-flow-analysis/research.md` | **PASS** |
| `.cursor/prompts/m4l3-2-ast-grep-verification.md` | AST-grep verification in same research doc | **PASS** |
| `.cursor/prompts/m4l4-1-new-change-intention.md` | `context/changes/refactor-opportunities/change.md` | **PASS** |
| `.cursor/prompts/m4l4-2-refactor-opportunities-research.md` | `context/changes/refactor-opportunities/research.md` | **PASS** |
| `.cursor/prompts/m4l4-3-ranking-ast-grep-verification.md` | § Weryfikacja twierdzeń in same research doc | **PASS** |
| `.cursor/prompts/m4l5-1-domain-distillation.md` | `context/domain/01-domain-distillation.md` | **PASS** |
| `.cursor/prompts/m4l5-2-invariant-aggregate-refactor.md` | `context/domain/02-invariant-aggregate-refactor.md` | **PASS** |
| `.cursor/prompts/m4l5-3-anti-corruption-layer.md` | `context/domain/03-anti-corruption-layer.md` | **PASS** |

### Checklist (Module 4 outcomes — placeholders)

| Item | Status | Notes |
|------|--------|-------|
| Architecture work — repo map / territory analysis | **PASS** | [`repo-map.md`](../map/repo-map.md) + artifacts 1–3 |
| Large-context workflows — map synthesis | **PASS** | [`repo-map.md`](../map/repo-map.md) synthesizes territory, structure, contributors |
| Large-context workflows — targeted research with map | **PASS** | [`case-submission-flow-analysis/research.md`](../changes/case-submission-flow-analysis/research.md) (M4L3-1) |
| Structural verification — ast-grep (flow analysis) | **PASS** | AST-grep section in case-submission research (M4L3-2) |
| Refactoring exploration — ranked opportunities | **PASS** | [`refactor-opportunities/research.md`](../changes/refactor-opportunities/research.md) (M4L4-2); ast-grep verified (M4L4-3) |
| Domain distillation — ubiquitous language, subdomains, aggregates | **PASS** | [`01-domain-distillation.md`](../domain/01-domain-distillation.md) (M4L5-1) |
| Invariant analysis — aggregate guardian plan | **PASS** | [`02-invariant-aggregate-refactor.md`](../domain/02-invariant-aggregate-refactor.md) (M4L5-2) — INV-G1 / `SanitizedCaseDraft` |
| Anti-corruption layer — AI adapter boundary plan | **PASS** | [`03-anti-corruption-layer.md`](../domain/03-anti-corruption-layer.md) (M4L5-3) — `HypothesisGenerator` port |
| Refactoring exercises — documented change | **PARTIAL** | Structural ranking (M4L4: TD-2 #1) + DDD plans (M4L5); **code implementation + impl-review not started** |
| Modernization work — evidence | **TODO** | Roadmap parked items (Postgres, observability) not started |
| Architecture evidence — diagrams / boundaries | **PASS** | Map artifacts + domain context diagram; redaction ⊥ AI boundary in artifact-2 / repo-map / domain distillation |
| Review artifacts — Architect impl/plan review | **TODO** | No `context/reviews/*architect*` artifact |

### Evidence

| Artifact | Status | Location |
|----------|--------|----------|
| Territory map (M4L2-1) | **PASS** | [`context/map/artifact-1-territory.md`](../map/artifact-1-territory.md) |
| Structure map (M4L2-2) | **PASS** | [`context/map/artifact-2-structure.md`](../map/artifact-2-structure.md) |
| Contributors map | **PASS** | [`context/map/artifact-3-contributors.md`](../map/artifact-3-contributors.md) |
| Repo map synthesis | **PASS** | [`context/map/repo-map.md`](../map/repo-map.md) |
| Case submission flow research (M4L3-1) | **PASS** | [`context/changes/case-submission-flow-analysis/research.md`](../changes/case-submission-flow-analysis/research.md) |
| AST-grep verification (M4L3-2) | **PASS** | Same research doc — § AST-grep verification |
| Refactor opportunities (M4L4-2) | **PASS** | [`context/changes/refactor-opportunities/research.md`](../changes/refactor-opportunities/research.md) — ranked TD-2, IMPL-1, TD-5 |
| Ranking ast-grep verification (M4L4-3) | **PASS** | Same research doc — § Weryfikacja twierdzeń (ast-grep) |
| Domain distillation (M4L5-1) | **PASS** | [`context/domain/01-domain-distillation.md`](../domain/01-domain-distillation.md) |
| Invariant aggregate refactor plan (M4L5-2) | **PASS** | [`context/domain/02-invariant-aggregate-refactor.md`](../domain/02-invariant-aggregate-refactor.md) |
| Anti-corruption layer plan (M4L5-3) | **PASS** | [`context/domain/03-anti-corruption-layer.md`](../domain/03-anti-corruption-layer.md) |
| Architect review | **TODO** | `context/reviews/*architect*` |

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
| AI toolkit package (M5L4) | [`packages/ai-toolkit/`](../../packages/ai-toolkit/) — `@szymoniwacz/ai-toolkit@0.1.0` |
| Publish workflow (M5L4) | [`.github/workflows/publish-ai-toolkit.yml`](../../.github/workflows/publish-ai-toolkit.yml) |
| Toolkit change + impl-review | [`context/archive/2026-06-20-ai-toolkit-registry/`](../archive/2026-06-20-ai-toolkit-registry/) |
| Toolkit PR | [PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13) — merged 2026-06-20 |
| GHA publish run | [Run 27875364234](https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234) |
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

Single packet for **Builder + Architect + Champion** when all badges are ready.

| Artifact | Builder | Architect | Champion |
|----------|---------|-----------|----------|
| Project summary | README + PRD | [`repo-map.md`](../map/repo-map.md) TL;DR + [`context/domain/`](../domain/) DDD artifacts | [`m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) executive summary |
| Demo script | See [Demo flow](#demo-flow) | TODO | M5L3: open PR → AI review comment; M5L4: `npm install` → skill in `.cursor/skills/` |
| Screenshots | [`screenshots/builder/`](screenshots/builder/) (7 PNGs, Fly 2026-06-09) | TODO | M5L3: [`screenshots/champion/m5l3/`](screenshots/champion/m5l3/) (6 PNGs); M5L4: [`screenshots/champion/m5l4/`](screenshots/champion/m5l4/) (8 PNGs) |
| Deployment URL | https://safelog-ai.fly.dev/ | Same URL + architecture notes | Same + automation proof |
| Review documents | `m1-m3-*` reviews | TODO | [`m5-champion-readiness-review.md`](../reviews/m5-champion-readiness-review.md) |
| CI evidence | `bin/ci` + GHA config | TODO — include map/structure gates if added | [AI code review](../../.github/workflows/ai-code-review.yml) + [publish toolkit](../../.github/workflows/publish-ai-toolkit.yml) |
| Certification notes | This file | Update Architect section | Champion section current (2026-06-20) |

### Demo flow (Builder — verified locally and on Fly)

**For reviewers opening https://safelog-ai.fly.dev/:** see [Public demo vs local `load_demo`](#public-demo-vs-local-load_demo) below — the Fly URL does **not** offer **Load demo case**.

1. Register or sign in at `/` (local or https://safelog-ai.fly.dev/).
2. **New case** with multiple pasted sources (fake secrets). On Fly, use manual intake — **Load demo case** is dev/test only.
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
| **Load demo case** | **Yes** — dashboard button; one-click checkout-timeout fixture (`Demo::LoadCase`) | **No** — button hidden; `POST /debugging_cases/load_demo` returns **404** (by design) |
| **How to start a case** | **Load demo case** *or* **New case** + manual paste | **New case** only — paste ≥2 log sources (Rails, CloudWatch, browser console, etc.) |
| **Redaction / analyze / export / archive** | Same services and UI | Same services and UI |
| **AI output** | Fake client if `OPENAI_API_KEY` unset (notice on case page) | Same |
| **Submission screenshots** | N/A | Captured via manual intake on Fly — see [`screenshots/builder/04-new-case-intake.png`](screenshots/builder/04-new-case-intake.png) |

**Why production has no load_demo:** `Demo::LoadCase.available?` is true only in development and test (`app/services/demo/load_case.rb`). Production keeps the demo surface minimal and avoids a dev-only shortcut on a public URL.

**Reviewer checklist (Fly, after `fly deploy`):**

1. Confirm app is up: `curl -sf https://safelog-ai.fly.dev/up`
2. Register a new account (or sign in) — screenshots [`builder/01-sign-in.png`](screenshots/builder/01-sign-in.png), [`builder/02-sign-up.png`](screenshots/builder/02-sign-up.png)
3. **New case** → paste multiple sources with fake secrets (e.g. email, token, shared `request_id`)
4. Verify show page: placeholders only, **Redaction summary** present — [`builder/05-case-redaction-summary.png`](screenshots/builder/05-case-redaction-summary.png)
5. **Analyze case** → hypothesis report — [`builder/06-hypothesis-report.png`](screenshots/builder/06-hypothesis-report.png)
6. Optional: download report, archive, **Archived** tab — [`builder/07-archived-cases.png`](screenshots/builder/07-archived-cases.png)

Do **not** expect a **Load demo case** button on Fly; that is not a deploy bug.

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
| Fake AI default without `OPENAI_API_KEY` | Accepted | Document in demo; optional Fly secret |

### Architect

| Gap | Action |
|-----|--------|
| M4L5 DDD plans complete; **code not changed** | Implement ranked refactors per plans: (1) intake aggregate [`02-invariant-aggregate-refactor.md`](../domain/02-invariant-aggregate-refactor.md) F1–F5; (2) AI ACL [`03-anti-corruption-layer.md`](../domain/03-anti-corruption-layer.md) F1–F6; structural TD-2/IMPL-1 from M4L4 aligns with intake plan |
| No Architect review document | Run course Architect review workflow when refactor implementation ships |
| No post-MVP modernization change | Pick from roadmap Parked or course exercise |

### Champion

| Gap | Severity | Action |
|-----|----------|--------|
| Toolkit **0.1.1** not yet published | Low | Bump version + push to `main` to publish impl-review triage fixes (manifest paths, trimmed rules) |
| Playwright not in main GHA | Accepted | Optional gate; E2E capture scripts exist for submission screenshots |

---

## Related documents (audit trail)

| File | Role |
|------|------|
| `context/reviews/m1-m3-builder-readiness-review.md` | Point-in-time Builder audit (2026-06-09) |
| `context/reviews/m1-m3-final-impl-review.md` | Six-dimension Builder impl-review |
| `context/reviews/m5-champion-readiness-review.md` | Point-in-time Champion audit (2026-06-20) |
| `context/reviews/builder-certification-submission-checklist.md` | **Superseded** — merged here; kept for link stability |
| `context/domain/01-domain-distillation.md` | M4L5-1 — ubiquitous language, subdomains, MODEL vs CODE gaps |
| `context/domain/02-invariant-aggregate-refactor.md` | M4L5-2 — INV-G1 aggregate guardian plan (plans only) |
| `context/domain/03-anti-corruption-layer.md` | M4L5-3 — AI adapter ACL plan (plans only) |

**Maintenance:** After each module milestone, update the badge section and [Current Status](#current-status). Archive point-in-time reviews under `context/reviews/`; do not fork multiple living checklists.
