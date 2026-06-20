// Risk: test-plan #7 — invalid AI output fails safely in the browser (no report body, safe alert).
import { test, expect } from "@playwright/test";
import { fillLogSourceSlot, signUp, uniqueEmail } from "./helpers";

const FAILURE_MESSAGE = "Analysis could not be completed. Please try again later.";
const FAKE_REPORT_SNIPPET = "Checkout timeout may be caused by downstream payment latency.";

test("surfaces safe analyze failure after invalid AI responses", async ({ page }) => {
  const email = uniqueEmail("pw-analyze-fail");

  await page.route("**/analyze", async (route) => {
    const headers = {
      ...route.request().headers(),
      "X-E2E-AI-Client": "invalid",
    };
    await route.continue({ headers });
  });

  await signUp(page, email);
  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill("Analyze failure browser case");
  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    pastedContent: "request_id=req-analyze-fail-1",
  });
  await fillLogSourceSlot(page, 2, {
    sourceType: "Aws cloudwatch",
    pastedContent: "Timeout for request_id=req-analyze-fail-1",
  });
  await page.getByRole("button", { name: "Create debugging case" }).click();

  await expect(page.getByRole("heading", { name: "Analyze failure browser case" })).toBeVisible();

  await page.getByRole("button", { name: "Analyze case" }).click();

  await expect(page.locator(".flash-messages").getByText(FAILURE_MESSAGE)).toBeVisible();
  const reportSection = page.locator("section.card").filter({
    has: page.getByRole("heading", { name: "Hypothesis report" }),
  });
  await expect(reportSection.getByText(FAILURE_MESSAGE)).toBeVisible();
  await expect(page.getByText(FAKE_REPORT_SNIPPET)).toHaveCount(0);
  await expect(page.getByRole("link", { name: "download the report" })).toHaveCount(0);
  await expect(page.getByRole("textbox", { name: "Report Markdown" })).toHaveCount(0);
});
