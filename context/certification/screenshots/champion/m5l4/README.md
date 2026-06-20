# Champion submission screenshots (M5L4 AI toolkit publish)

Captured from GitHub via Playwright (`e2e/capture-m5l4-screenshots.spec.ts`).

## Publish scenario (GitHub Packages Model 1)

[PR #13](https://github.com/szymoniwacz/safelog-ai/pull/13) merged → [run 27875364234](https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234) — `@szymoniwacz/ai-toolkit@0.1.0`

| File | Step |
|------|------|
| `01-publish-workflow-run.png` | Publish AI Toolkit workflow — validate + publish jobs green |
| `02-validate-job-logs.png` | Validate job — smoke test install/uninstall expanded |
| `03-publish-job-logs.png` | Publish job — `npm publish` to GitHub Packages |
| `04-github-packages-page.png` | Package page on GitHub Packages |
| `05-pr-13-merged.png` | Merged PR introducing the toolkit package |

## Re-capture

Requires `gh auth login` (job logs fetched via `gh run view --log`).

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-m5l4-screenshots.spec.ts
```

After publishing **0.1.1** (impl-review triage fixes), update run/job URLs in `e2e/capture-m5l4-screenshots.spec.ts` and re-run.
