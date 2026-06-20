# Domain Distillation — SafeLog AI

Artifact from foundation docs, README, AGENTS.md, and runtime code (`app/models/`, `app/services/`, `app/controllers/`).

---

## Project context

| Document | Role |
|----------|------|
| `context/foundation/prd.md` | Active PRD — vision, FR-001–FR-011, guardrails |
| `context/foundation/shape-notes.md` | Shape session — domain decisions, non-goals |
| `context/map/repo-map.md` | Repo map — where business logic lives |
| `context/changes/case-submission-flow-analysis/research.md` | Intake → redaction → persist analysis |
| `context/changes/refactor-opportunities/research.md` | Structural refactor candidates |

### Stack and repo structure

| Layer | Location | Role |
|-------|----------|------|
| HTTP / API | `app/controllers/` | Thin orchestration — params, auth, redirect/render |
| Business logic | `app/services/{intake,redaction,correlation,analysis,ai,demo}/` | Domain pipeline (PRD guardrails) |
| Persistence | `app/models/` + `db/schema.rb` | Active Record, encryption, associations |
| UI | `app/views/debugging_cases/` | Server-rendered ERB |
| Security oracles | `spec/requests/*_security_spec.rb`, `spec/services/` | Contract: raw never persists / never reaches AI |

**Runtime flow (DAG):**

```
POST create → Intake::CaseSubmission (validation)
           → Intake::ProcessCaseSubmission (txn + Redaction::Engine)
           → show (sanitized evidence + redaction summary)

POST analyze → Analysis::AnalyzeCase
            → Correlation::ExtractSignals (pure)
            → Analysis::PromptBuilder → Ai::Client
            → Ai::ResponseValidator → persist AiReport
```

**Security boundary:** `Redaction::` does not import `Ai::` (repo-map, artifact-2).

## Ubiquitous Language (core concepts)

| Term | Meaning |
|------|---------|
| **Debugging case** | User-owned investigation unit; holds sanitized log sources and optional AI report |
| **Log source** | One pasted stream (Rails, CloudWatch, browser console, …) after redaction → `sanitized_content` only |
| **Redaction finding** | Metadata about what was masked (type, line, placeholder, risk) — no raw values |
| **Hypothesis report** | AI output framed as hypotheses + uncertainty — not definitive root cause |
| **Correlation signal** | Cross-source link (e.g. shared request_id) extracted from sanitized text |

**MODEL vs CODE gap (example):** PRD says “deterministic redaction gates AI”; code enforces procedurally in `ProcessCaseSubmission`, not via aggregate type — ranked refactor #1 in M4L4/M4L5 plans.
