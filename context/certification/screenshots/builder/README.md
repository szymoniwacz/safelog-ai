# Builder submission screenshots (M1–M3)

Captured from **https://safelog-ai.fly.dev/** on **2026-06-26** via Playwright (`e2e/capture-submission-screenshots.spec.ts`). Includes full CRUD evidence (`08-cases-index-actions.png`).

**Note for reviewers:** these screenshots use **manual intake** (New case + paste). The public Fly app does not show **Load demo case** — that button appears only in local development/test. See [`../../certification-readiness.md`](../../certification-readiness.md) § Public demo vs local `load_demo`.

| File | Step |
|------|------|
| `01-sign-in.png` | Public sign-in page |
| `02-sign-up.png` | Registration page (empty form) |
| `03-dashboard.png` | Dashboard after registration |
| `04-new-case-intake.png` | New case form with multi-source paste (pre-submit) |
| `05-case-redaction-summary.png` | Case show — sanitized logs + redaction summary (raw secrets not visible) |
| `08-cases-index-actions.png` | Case index — **Actions** column (Edit / Delete) |
| `06-hypothesis-report.png` | After analyze — hypothesis report + correlation signals |
| `07-archived-cases.png` | Case index — Archived filter |

Attach **all 8** PNGs to the Builder form.

## Re-capture

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_BASE_URL=https://safelog-ai.fly.dev \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-submission-screenshots.spec.ts
```

Requires the Fly app to be running with CRUD deployed. Production demo path: **New case** + manual paste (no **Load demo case**).
