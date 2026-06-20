# E2E Testing Rules (Playwright)

- Use `getByRole`, `getByLabel`, and `getByText` as primary locators.
- Never use CSS selectors or XPath for locating elements.
- Each regression spec must be independently runnable with its own setup.
- Never use `page.waitForTimeout()`. Wait for visible state (`toBeVisible`, `toContainText`).
- Assert observable user outcomes tied to a `test-plan.md` risk, not implementation details.
- Use unique data (`uniqueEmail`, timestamps) to avoid collisions.
- Prefer `storageState` helpers in `e2e/helpers.ts` for signed-in flows.
- Security oracles (DB scans, prompt inspection) stay in RSpec — Playwright checks UI only.
