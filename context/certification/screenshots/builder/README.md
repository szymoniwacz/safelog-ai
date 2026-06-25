# Builder submission screenshots (M1–M3)

Captured from **https://safelog-ai.fly.dev/** on 2026-06-24 via Playwright (`e2e/capture-submission-screenshots.spec.ts`).

**Note for reviewers:** these screenshots use **manual intake** (New case + paste). The public Fly app does not show **Load demo case** — that button appears only in local development/test. See [`../../certification-readiness.md`](../../certification-readiness.md) § Public demo vs local `load_demo`.

| File | Step |
|------|------|
| `01-sign-in.png` | Public sign-in page |
| `02-sign-up.png` | Registration page (empty form) |
| `03-dashboard.png` | Dashboard after registration |
| `04-new-case-intake.png` | New case form with multi-source paste (pre-submit) |
| `05-case-redaction-summary.png` | Case show — sanitized logs + redaction summary (raw secrets not visible) |
| `06-hypothesis-report.png` | After analyze — hypothesis report + correlation signals |
| `07-archived-cases.png` | Case index — Archived filter |
| `08-cases-index-actions.png` | Case index — **Actions** column (Edit / Delete); capture after CRUD is on Fly |

**Note:** PNGs `01`–`07` were captured 2026-06-24 (pre-CRUD index actions). They remain valid for intake → analyze → archive. Re-run capture after deploying CRUD to add `08` (recommended for Builder reviewers).

## Re-capture

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_BASE_URL=https://safelog-ai.fly.dev \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-submission-screenshots.spec.ts
```

Requires the Fly app to be running. Production demo path: **New case** + manual paste (no **Load demo case**).
