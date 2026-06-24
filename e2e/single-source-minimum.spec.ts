import { test, expect } from "@playwright/test";
import { fillLogSourceSlot, signUp, uniqueEmail } from "./helpers";

test("creates a case with one log source and shows the case page", async ({ page }) => {
  const email = uniqueEmail("pw-single-source");
  const title = "Minimal single-source case";

  await signUp(page, email);

  await page.getByRole("link", { name: "New case" }).click();
  await expect(page.getByRole("heading", { name: "New debugging case" })).toBeVisible();

  await page.getByLabel("Title").fill(title);

  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    name: "Rails",
    pastedContent: "Started GET /health",
  });

  await page.getByRole("button", { name: "Create debugging case" }).click();

  await expect(page.getByRole("heading", { name: title })).toBeVisible();
});
