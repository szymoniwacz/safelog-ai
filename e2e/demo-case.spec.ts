import { test, expect } from "@playwright/test";
import { signUp, uniqueEmail } from "./helpers";

test("loads the demo case with sanitized evidence", async ({ page }) => {
  const email = uniqueEmail("pw-demo");

  await signUp(page, email);
  await page.getByRole("button", { name: "Load demo case" }).click();

  await expect(page.getByText("Demo case loaded.")).toBeVisible();
  await expect(page.getByRole("heading", { name: /Checkout payment timeout/ })).toBeVisible();
  const sanitizedSection = page.locator("section.card").filter({ hasText: "Sanitized log sources" });
  await expect(sanitizedSection.getByRole("textbox").first()).toContainText("[REQUEST_1]");
  await expect(page.getByText("checkout-demo@example.com")).toHaveCount(0);
  await expect(page.getByText("sk-demo-checkout-token-not-real")).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Sanitized log sources" })).toBeVisible();
});
