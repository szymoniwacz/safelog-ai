import { test, expect } from "@playwright/test";
import { fillLogSourceSlot, signUp, uniqueEmail } from "./helpers";

test("full debugging case journey in the browser", async ({ page }) => {
  const email = uniqueEmail("pw-flow");
  const rawEmail = uniqueEmail("customer-secret");
  const rawToken = `sk-pw-flow-${Math.random().toString(36).slice(2, 10)}`;
  const sharedRequestId = `req-pw-flow-${Math.random().toString(36).slice(2, 8)}`;

  await signUp(page, email);

  await page.getByRole("link", { name: "New case" }).click();
  await expect(page.getByRole("heading", { name: "New debugging case" })).toBeVisible();

  await page.getByLabel("Title").fill("Playwright checkout failure");
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

  await page.getByRole("button", { name: "Create debugging case" }).click();

  await expect(page.getByRole("heading", { name: "Playwright checkout failure" })).toBeVisible();
  await expect(page.getByText(rawEmail)).toHaveCount(0);
  await expect(page.getByText(rawToken)).toHaveCount(0);
  await expect(page.getByText(sharedRequestId)).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Redaction summary" })).toBeVisible();

  const sanitizedSection = page.locator("section.card").filter({ hasText: "Sanitized log sources" });
  const railsLog = sanitizedSection.getByRole("textbox", { name: "Sanitized log for Rails" });
  await expect(railsLog).toContainText("[EMAIL_1]");
  await expect(railsLog).toContainText("[AUTH_1]");

  await page.getByRole("button", { name: "Analyze case" }).click();
  await expect(page.getByText("Analysis complete.")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Hypothesis report" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Correlation signals" })).toBeVisible();
  const correlationSection = page.locator("section.card").filter({
    has: page.getByRole("heading", { name: "Correlation signals" }),
  });
  await expect(correlationSection).toContainText("[REQUEST_1]");

  const reportMarkdown = page.getByRole("textbox", { name: "Report Markdown" });
  await expect(reportMarkdown).toContainText("## Hypothesis report");

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("link", { name: "download the report" }).click();
  const download = await downloadPromise;
  const downloadBody = await download.createReadStream();
  const chunks: Buffer[] = [];
  for await (const chunk of downloadBody!) {
    chunks.push(Buffer.from(chunk));
  }
  const markdown = Buffer.concat(chunks).toString("utf8");
  expect(markdown).toContain("## Hypothesis report");
  expect(markdown).not.toContain(rawEmail);
  expect(markdown).not.toContain(rawToken);

  await page.getByRole("button", { name: "Archive case" }).click();
  await expect(page.getByText("Case archived.")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Debugging cases" })).toBeVisible();

  await page.getByRole("link", { name: "Archived" }).click();
  await expect(page.getByRole("link", { name: "Playwright checkout failure" })).toBeVisible();

  await page.getByRole("link", { name: "Active" }).click();
  await expect(page.getByText("No active debugging cases yet")).toBeVisible();
});
