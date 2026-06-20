# SafeLog AI — Repo map (onboarding)

**Synthesized from:** artifact-1-territory · artifact-2-structure · artifact-3-contributors
**Updated:** 2026-06-09 · **Map window:** git/structure analysis (actual repo age ~3 weeks)

---

## 1. TL;DR

SafeLog AI is a **Rails 8 monolith** (SQLite, Devise, server-rendered ERB): the user pastes logs, the backend **redacts in memory**, persists only sanitized evidence, then produces a **hypothesis-framed** AI report — raw logs never reach the DB or the model. This is a **young solo MVP** (~3 weeks of history), not a legacy monolith — the map describes direction of work, not years of team specialization.

**Where work lives (runtime):** `app/services/*` (pipeline), thin HTTP in `app/controllers`, UI in `app/views/debugging_cases/`, oracles in `spec/requests` and `spec/services`. **High git activity, not product runtime:** `context/changes/` and `context/archive/` — 10x slice documentation, not deployable code.

**Pain points:** orchestrator `Analysis::AnalyzeCase`, HTTP corridor (`routes → controller → views → request specs`), security oracles, E2E hub `e2e/helpers.ts`. **No cycles** in Ruby services; **`redaction ⊥ ai`** boundary holds.

**Contributors:** single maintainer — “who to ask” map is topic routing + fallback to `context/foundation/`.

## 2. Territory — core vs periphery

| Zone | Depth | Git activity | Runtime? |
|------|-------|--------------|----------|
| **Service pipeline** (`intake`, `redaction`, `correlation`, `analysis`, `ai`) | Deep — product logic, PRD guardrails | Medium | **Yes** |
| **HTTP slice** (controller, views, routes) | Medium — orchestration + UI | High | **Yes** |
| **Security oracles** (`spec/requests/*_security*`) | Deep — security contract | Highest runtime | **Yes (tests)** |
| **`context/changes/`** | Shallow for deploy — slice plans | **Highest in repo** | **No** — documentation workflow |
| **Deploy / cert / E2E** | Operational layer | June 2026 growth | Partial |

**Catalog illusion:** top git folder is `context/changes/` — **documentation workflow**, not a runtime bounded context. Completed slices → `context/archive/`.
