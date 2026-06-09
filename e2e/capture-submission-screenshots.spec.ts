import { test, expect } from "@playwright/test";
import path from "node:path";
import { fillLogSourceSlot, signUp, uniqueEmail } from "./helpers";

const SCREENSHOT_DIR = path.join(
  process.cwd(),
  "context",
  "certification",
  "screenshots",
);

test.describe.configure({ mode: "serial" });

test("capture Builder submission screenshots on production", async ({ page }) => {
  test.skip(
    !process.env.PLAYWRIGHT_CAPTURE_SCREENSHOTS,
    "Set PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 to run",
  );

  const email = uniqueEmail("cert-demo");
  const rawEmail = uniqueEmail("customer-secret");
  const rawToken = `sk-cert-${Math.random().toString(36).slice(2, 10)}`;
  const sharedRequestId = `req-cert-${Math.random().toString(36).slice(2, 8)}`;
  const caseTitle = "Cert demo checkout failure";

  await page.goto("/users/sign_in");
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "01-sign-in.png"),
    fullPage: true,
  });

  await page.goto("/users/sign_up");
  await expect(page.getByRole("heading", { name: "Create your SafeLog AI account" })).toBeVisible();
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "02-sign-up.png"),
    fullPage: true,
  });

  await signUp(page, email);

  await expect(page.getByRole("heading", { name: "SafeLog AI", exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "New case" })).toBeVisible();
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "03-dashboard.png"),
    fullPage: true,
  });

  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill(caseTitle);
  await page.getByLabel("Customer reference").fill(`Contact ${rawEmail}`);

  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    name: "Rails",
    pastedContent: `User login failed for ${rawEmail}\nAuthorization: Bearer ${rawToken}`,
  });
  await fillLogSourceSlot(page, 2, {
    sourceType: "Aws cloudwatch",
    pastedContent: `Timeout for request_id=${sharedRequestId}`,
  });
  await fillLogSourceSlot(page, 3, {
    sourceType: "Browser console",
    pastedContent: `Error for request_id=${sharedRequestId}`,
  });

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "04-new-case-intake.png"),
    fullPage: true,
  });

  await page.getByRole("button", { name: "Create debugging case" }).click();

  await expect(page.getByRole("heading", { name: caseTitle })).toBeVisible();
  await expect(page.getByText(rawEmail)).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Redaction summary" })).toBeVisible();
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "05-case-redaction-summary.png"),
    fullPage: true,
  });

  await page.getByRole("button", { name: "Analyze case" }).click();
  await expect(page.getByText("Analysis complete.")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Hypothesis report" })).toBeVisible();
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "06-hypothesis-report.png"),
    fullPage: true,
  });

  await page.getByRole("button", { name: "Archive case" }).click();
  await expect(page.getByText("Case archived.")).toBeVisible();

  await page.getByRole("link", { name: "Archived" }).click();
  await expect(page.getByRole("link", { name: caseTitle })).toBeVisible();
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "07-archived-cases.png"),
    fullPage: true,
  });
});
