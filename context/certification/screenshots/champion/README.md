# Champion submission screenshots (M5 CI code review)

Captured from GitHub via Playwright (`e2e/capture-champion-screenshots.spec.ts`).

## Fail scenario (intentional security issues)

Branch `test/ai-code-review-workflow` → [PR #11](https://github.com/szymoniwacz/safelog-ai/pull/11)

| File | Step |
|------|------|
| `01-pr-ai-review-comment-fail.png` | Bot comment — verdict **fail**, label `ai-cr:failed` |
| `02-actions-workflow-run-fail.png` | [Run 27760320185](https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185) |
| `03-actions-job-logs-fail.png` | [Job 82132673336](https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185/job/82132673336) — all steps expanded |

## Pass scenario (legitimate feature PR)

Branch `feature/case-index-analysis-status` → [PR #12](https://github.com/szymoniwacz/safelog-ai/pull/12)

| File | Step |
|------|------|
| `04-pr-ai-review-comment-pass.png` | Bot comment — verdict **pass**, label `ai-cr:passed` |
| `05-actions-workflow-run-pass.png` | [Run 27763104255](https://github.com/szymoniwacz/safelog-ai/actions/runs/27763104255) |
| `06-actions-job-logs-pass.png` | [Job 82142437908](https://github.com/szymoniwacz/safelog-ai/actions/runs/27763104255/job/82142437908) — all steps expanded |

Job log screenshots (`03`, `06`) expand every step and fill log panes from `gh run view <run-id> --log` (GitHub UI hides log text without a browser session).

## Re-capture

```bash
# All scenarios (fail + pass; requires `gh auth login` for job logs):
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-champion-screenshots.spec.ts

# Pass only (PR #12):
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
PLAYWRIGHT_CAPTURE_SCENARIO=pass \
npx playwright test e2e/capture-champion-screenshots.spec.ts

# Job logs only:
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
PLAYWRIGHT_CAPTURE_JOB_LOGS_ONLY=1 \
PLAYWRIGHT_CAPTURE_SCENARIO=pass \
npx playwright test e2e/capture-champion-screenshots.spec.ts
```

Update URLs in `e2e/capture-champion-screenshots.spec.ts` when re-capturing against newer PRs or workflow runs.

## M5L4 — AI toolkit publish

See [`m5l4/`](m5l4/) — GitHub Packages publish evidence ([PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13), [run 27875364234](https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234)).
