// Risk: test-plan #3 — exemplar for generated Playwright specs (getByRole, unique data, state waits).
import { test, expect } from "@playwright/test";
import { fillLogSourceSlot, signUp, uniqueEmail } from "./helpers";

test("signed-in user can create a debugging case in the browser", async ({ page }) => {
  const email = uniqueEmail("pw-seed");

  await signUp(page, email);
  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill(`Seed case ${Date.now()}`);
  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    pastedContent: "request_id=req-seed-1",
  });
  await page.getByRole("button", { name: "Create debugging case" }).click();

  await expect(page.getByRole("heading", { name: "Redaction summary" })).toBeVisible();
  await expect(page.getByText("req-seed-1")).toHaveCount(0);
});
