# Champion submission screenshots (M5 CI code review)

Captured from GitHub on 2026-06-18 via Playwright (`e2e/capture-champion-screenshots.spec.ts`).

| File | Step |
|------|------|
| `01-pr-ai-review-comment.png` | [PR #11](https://github.com/szymoniwacz/safelog-ai/pull/11) — AI code review bot comment (verdict **fail**, label `ai-cr:failed`) |
| `02-actions-workflow-run.png` | [Workflow run 27760320185](https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185) — **AI Code Review** job summary |
| `03-actions-job-logs.png` | [Job 82132673336](https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185/job/82132673336) — all steps expanded; log lines from `gh run view` (GitHub UI hides log text without browser session) |

Test PR branch: `test/ai-code-review-workflow` → `main` (intentional security issues for review validation).

## Re-capture

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-champion-screenshots.spec.ts

# Job logs only (faster; requires `gh auth login`):
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
PLAYWRIGHT_CAPTURE_JOB_LOGS_ONLY=1 \
npx playwright test e2e/capture-champion-screenshots.spec.ts
```

Requires public GitHub access to the URLs in the spec. Screenshot `03` expands every job step and fills log panes from `gh run view <run-id> --log` (same content as the Actions UI when signed in). Update run/job URLs in the spec if re-capturing against a newer workflow.
