# Requirements: CI/CD AI code review

**Change:** `ci-cd-code-review`  
**Status:** draft  
**Depends on:** M5L2 agent in `packages/code-reviewer/` (local `git diff | npm run review`)

## Goal

Run an automated AI code review on every pull request targeting `main`. Post a structured summary as a PR comment and apply pass/fail labels. Allow on-demand re-runs without pushing new commits.

The workflow must stay easy to reason about: a thin GHA workflow orchestrates a composite action that owns the review steps.

## Non-goals (v1)

- Blocking merges or required status checks (advisory only).
- Plan-driven implementation review (`10x-impl-review-ci` skill) — separate concern.
- Inline review comments on specific diff lines.
- Evals / promptfoo regression suite (separate change: `code-review-evals`).
- Sending full repository context, AGENTS.md, or plan files to the model.
- Criteria that need broad product context: **business alignment**, **architectural fit** (parked for later).

## Context

| Asset | Role |
|-------|------|
| `packages/code-reviewer/` | TypeScript agent: stdin diff → structured JSON (`Review`) via Vercel AI SDK + Zod schema |
| `packages/code-reviewer/src/schemas/review-schema.ts` | Output contract today: 5 scored dimensions + `verdict` + `summary` |
| `.github/workflows/ci.yml` | Existing quality gates (RuboCop, Brakeman, RSpec) — unchanged by this change |

**Gap vs scratch spec:** the local agent scores five dimensions and has no `documentation` field. This change extends the schema and prompts to match the six criteria below.

## Triggers

| Event | Behavior |
|-------|----------|
| `pull_request` → `main` (`opened`, `synchronize`, `reopened`) | Run review automatically |
| Label `ai-cr:review` added to an open PR | Re-run review on demand (same inputs as automatic run) |

Re-runs replace the previous bot comment and refresh labels; they do not accumulate duplicate comments.

## Inputs to the reviewer

| Input | Required | Notes |
|-------|----------|-------|
| Git diff (PR merge-base…HEAD) | yes | Three-dot range against `github.base_ref`; same scope a human reviewer sees in “Files changed” |
| Pull request title | yes | Short intent signal; low token cost |
| Pull request description | no (v1) | **Decision:** omit in v1 to limit token spend. Title + diff are enough for a first useful review. Revisit if reviews lack PR intent context. |

The composite action must not fetch or send file contents outside the diff hunks unless the diff itself is empty (then exit gracefully with a neutral comment).

## Review criteria

Each criterion is scored **1–10** (1 = worst, 10 = best). Scores are included in the PR comment for transparency.

### 1. Implementation correctness

Does the code do what it claims, including edge cases and error paths, without regressions?

- **1:** Logic broken, obvious edge/error cases missed, or silent regressions.
- **10:** Correct on happy path, edge cases, and failure modes; no regressions.

### 2. Idiomaticity

Does the code follow language, framework, and project conventions?

- **1:** Fights stack idioms and repo patterns; reads foreign.
- **10:** Indistinguishable from well-written surrounding code.

### 3. Complexity

Is the solution as simple as the problem allows?

- **1:** Over-engineered or tangled; accidental complexity hides intent.
- **10:** Minimal, clear design that fully solves the problem.

### 4. Test / risk coverage

Are meaningful behaviors and risky paths tested proportionally to risk?

- **1:** Risky logic untested; tests absent, trivial, or useless.
- **10:** Risk-weighted coverage — likely break points tested deliberately.

### 5. Documentation

Are non-obvious decisions, public surfaces, and tricky code explained where needed?

- **1:** Opaque — intent must be reverse-engineered.
- **10:** Just enough docs/comments for the “why”, without restating the obvious.

### 6. Security and safety

Does the change avoid vulnerabilities, secret leaks, and unsafe handling of untrusted input?

- **1:** Exploitable flaw, secret leak, or unsafe trust of input.
- **10:** Input validated, secrets handled correctly, no new attack surface.

For SafeLog specifically: flag any attempt to persist raw logs, raw-to-placeholder mappings, or pre-redaction content — aligned with `AGENTS.md` hard rules.

## Verdict and pass/fail labels

The model returns a binding **`verdict`**: `pass` | `fail`.

| Verdict | Label applied | Label removed |
|---------|---------------|---------------|
| `pass` | `ai-cr:passed` (green) | `ai-cr:failed` |
| `fail` | `ai-cr:failed` (red) | `ai-cr:passed` |

**Pass bar (deterministic, post-model):** `verdict: pass` from structured output. Do not derive pass/fail from score averages in v1 — the model already synthesizes criteria into one verdict.

If the review step errors (API failure, empty diff, invalid JSON), do **not** apply pass/fail labels; post a neutral error comment and fail the workflow job so the run is visible in Actions.

## Outputs

### PR comment

Markdown body built from `summary` plus a compact score table:

```markdown
## AI code review

**Verdict:** pass | fail

| Criterion | Score |
|-----------|------:|
| Implementation correctness | 8 |
| … | … |

<model summary — 2–4 sentences, actionable>
```

Include an HTML comment marker (e.g. `<!-- ai-code-review:marker -->`) so re-runs can find and replace the prior bot comment.

### Labels

- `ai-cr:passed` — green  
- `ai-cr:failed` — red  
- `ai-cr:review` — user-applied trigger for on-demand re-run (never set by the bot)

Label colors are configured once in the repository; the workflow only adds/removes labels.

## Architecture

```
.github/workflows/ai-code-review.yml     # triggers, permissions, calls composite action
.github/actions/code-review/action.yml # checkout, diff, node setup, run agent, gh comment + labels
packages/code-reviewer/                # agent library + CLI (extended for PR metadata)
```

**FR-1** A dedicated workflow file (separate from `ci.yml`) owns AI review triggers and permissions.  
**FR-2** Review logic lives in a **composite action** under `.github/actions/code-review/`.  
**FR-3** The composite action invokes `packages/code-reviewer` (npm ci + `npm run review` or a small `review-pr` script), piping the diff on stdin.  
**FR-4** PR title (and optional future description) are passed via env vars or CLI flags — not embedded in the diff string.  
**FR-5** The action uses `gh` to post/update the PR comment and manage labels.  
**FR-6** `OPENAI_API_KEY` is read from GitHub Actions secrets; never logged or written to the comment.  
**FR-7** Extend `REVIEW_SCHEMA`, system prompt, and TypeScript types with the sixth criterion (`documentation`) and English criterion descriptions (replace Polish Zod `.describe()` text for consistency with GHA output).

## Permissions and secrets

| Item | Requirement |
|------|-------------|
| `OPENAI_API_KEY` | Repository secret |
| `GITHUB_TOKEN` | Default token with `pull-requests: write` and `contents: read` |
| Fork PRs | Skip review on `pull_request` from forks (no secrets on untrusted code) OR document explicit opt-in — **default: skip with neutral comment** |

Optional: `CODE_REVIEWER_MODEL` secret to override default `gpt-4o-mini`.

## Observability

- Workflow run appears under Actions with clear job name (e.g. “AI code review”).
- Job logs may include criterion scores and verdict; they must **not** include the full diff or API key.
- Failed runs are distinguishable from `fail` verdicts (infrastructure vs review outcome).

## Acceptance criteria

1. Opening a PR to `main` triggers one review comment within a reasonable time (< 5 min for typical diff sizes).
2. Pushing new commits updates the same comment (not a thread of duplicates).
3. Adding label `ai-cr:review` re-runs without a new push.
4. Passing review adds `ai-cr:passed` and removes `ai-cr:failed`; failing review does the inverse.
5. Local CLI still works: `git diff | npm run review` produces JSON matching the extended schema.
6. Fork PRs do not expose `OPENAI_API_KEY` to untrusted workflows.

## Open questions

| # | Question | Proposed default |
|---|----------|------------------|
| Q1 | Include PR description in v2? | Start without; add truncated body if reviews lack context |
| Q2 | Required check / merge gate? | No — advisory labels only in v1 |
| Q3 | Diff size cap | Truncate diff with explicit “(truncated)” notice if over ~100k chars; still run review on head |
| Q4 | Parked criteria (business alignment, architectural fit) | Separate change once PR template links plans routinely |

## References

- Scratch notes: `.cursor/prompts/m5l3-requirements.md`
- Next steps: `.cursor/prompts/m5l3-cicd.md` → `/10x-research ci-cd-code-review` → `/10x-plan ci-cd-code-review`
- Certification gap: `context/certification/certification-readiness.md` — “CI/CD AI integration”
