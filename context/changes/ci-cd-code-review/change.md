---
change_id: ci-cd-code-review
title: CI/CD AI code review on pull requests
status: implemented
created: 2026-06-18
updated: 2026-06-18
archived_at: null
---

## Notes

M5L3 — wire the M5L2 `packages/code-reviewer` agent into GitHub Actions so every PR to `main` gets an automated, structured review comment and pass/fail labels.

- Requirements: `requirements.md`
- Workflow: `.github/workflows/ai-code-review.yml`
- Composite action: `.github/actions/code-review/`

## Setup (one-time)

1. Add repository secret `OPENAI_API_KEY`.
2. Create labels: `ai-cr:passed`, `ai-cr:failed`, `ai-cr:review`.
3. Open a PR to `main` to verify the workflow run and PR comment.
