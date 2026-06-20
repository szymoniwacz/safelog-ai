---
name: code-review
description: Review code changes against team engineering conventions, testing standards and security expectations. Use when the user says "review code", "check this PR", "review my changes", or "code review".
---

# Code Review

Review code changes against team Rails engineering conventions. This skill is for **IDE-assisted review** — not CI automation. Read the diff or changed files, apply the categories below, and produce structured findings.

## Workflow

1. Identify the change scope (staged diff, PR diff, or files the user points at).
2. Read each changed file with enough surrounding context to judge intent.
3. Check every category below. Skip categories that do not apply to the change.
4. Classify each issue by severity and include `file:line` when possible.
5. End with exactly one verdict: `APPROVE`, `REQUEST CHANGES`, or `NEEDS DISCUSSION`.

## Review categories

### Naming

- Ruby methods and variables: descriptive `snake_case` (no abbreviations except `url`, `id`, `api`, `config`).
- Booleans: predicate methods (`active?`, `valid?`) or clear names (`is_enabled` only when a predicate suffix is awkward).
- Classes and modules: `CamelCase`; match file name (`user_service.rb` → `UserService`).
- Constants: `SCREAMING_SNAKE_CASE`.
- Service objects live under `app/services/<domain>/` with names that describe the action (`Intake::Sanitizer`, not `Helper`).

### Error handling

- Do not swallow exceptions with empty `rescue` blocks; log, re-raise, or return a structured error.
- Error messages state what failed and include safe, non-sensitive context.
- HTTP/controller errors return appropriate status codes and actionable messages — no raw stack traces to clients.
- Use `ensure` for cleanup when resources are opened.
- Prefer raising domain-specific errors over generic strings when the caller must branch.

### Ruby / Rails

- Controllers stay thin: params, auth/session, render/redirect only — business logic belongs in services or models.
- Active Record: avoid N+1 queries; use scopes and validations intentionally; migrations must be reversible when feasible.
- Strong parameters and authorization checks at boundaries.
- Prefer `mise exec --` for local Ruby/Bundler commands when the repo uses mise.
- Follow RuboCop omakase / project RuboCop config; do not fight the linter without justification.
- No new framework scaffolding (React/Vite, background jobs, file uploads, external integrations) unless explicitly requested.
- Never overwrite `context/` documents — treat them as project source of truth.

### Function and service design

- Single responsibility: if you need "and" to describe it, split it.
- Prefer keyword arguments or a small options hash over long positional parameter lists.
- Early returns over deep nesting.
- Query methods (`find_*`, `fetch_*`, predicate readers) should be side-effect free.
- Services expose a clear public entry point (e.g. `#call`) and return a predictable result object or raise.

### Security

- No secrets in code; use credentials, ENV, or Rails encrypted credentials as the project does.
- Validate and sanitize user input at system boundaries.
- SQL via Active Record or parameterized queries only — no string interpolation in SQL.
- Filter sensitive params in `config/initializers/filter_parameter_logging.rb` when adding new secret-bearing fields.
- Encrypt sensitive diagnostic or PII fields at rest when the product handles them (Active Record Encryption).
- When handling intake of sensitive raw data: never persist, log, send, or expose raw values after redaction; keep redaction mappings in memory only for the current request/process.
- AI integrations receive sanitized evidence only; reports must be hypothesis-framed, not definitive conclusions.
- Tests must stub or fake external AI providers — CI must never call real AI APIs.

### Testing

- RSpec examples describe behavior: `"returns empty array when no results found"`, not `"works"`.
- Each example owns its setup; avoid order-dependent global state.
- Prefer specific matchers (`eq`, `match`, `change`) over bare truthiness checks.
- Cover edge cases: empty collections, nil, boundaries, and failure paths.
- Security- and data-handling changes need examples proving sensitive raw data never persists and never reaches AI stubs.
- Run `mise exec -- bin/ci` (or project equivalent) before approving — RuboCop, bundler-audit, Brakeman, and the full RSpec suite should pass.

## Output format

Organize findings under severity headings. Use `file:line` references when known.

```markdown
## Critical
- `app/services/intake/sanitizer.rb:42` — Raw payload written to `raw_content` column; violates no-raw-persistence rule.

## Warning
- `app/controllers/reports_controller.rb:18` — Business logic in controller; move to a service.

## Suggestion
- `app/models/user.rb:7` — Rename `get_user` to `find_by_email` for clarity.

**Verdict:** REQUEST CHANGES
```

### Severity guide

| Severity | Use when |
| -------- | -------- |
| **Critical** | Security flaw, data-loss risk, broken invariant, or hard rule violation — must fix before merge |
| **Warning** | Convention violation, maintainability risk, or missing test coverage for risky change |
| **Suggestion** | Style, naming, or minor improvement — optional |

### Verdict guide

| Verdict | Use when |
| ------- | -------- |
| **APPROVE** | No Critical or Warning findings; Suggestions are optional |
| **REQUEST CHANGES** | One or more Critical or Warning findings |
| **NEEDS DISCUSSION** | Architectural or product trade-off that code alone cannot resolve |

## What not to do

- Do not invoke CI review agents, GitHub Actions, or external scoring tools — this skill is standalone IDE review.
- Do not invent conventions outside the categories above unless the project's `AGENTS.md` or `context/` docs define them.
- Do not request changes for pre-existing issues untouched by the current diff unless they are Critical security regressions introduced indirectly.
