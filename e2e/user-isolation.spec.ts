import path from "path";
import { test, expect } from "@playwright/test";
import {
  fillLogSourceSlot,
  saveAuthStorageState,
  signUp,
  uniqueEmail,
} from "./helpers";

test.describe.configure({ mode: "serial" });

const authFile = path.join(__dirname, ".auth", "isolation-owner.json");
let ownerCaseUrl = "";

test.describe("User isolation", () => {
  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    const email = uniqueEmail("pw-isolation-owner");

    await signUp(page, email);
    await page.getByRole("link", { name: "New case" }).click();
    await page.getByLabel("Title").fill("Owner-only browser case");
    await fillLogSourceSlot(page, 1, {
      sourceType: "Rails log",
      pastedContent: "request_id=req-browser-isolation-1",
    });
    await page.getByRole("button", { name: "Create debugging case" }).click();

    await expect(page.getByRole("heading", { name: "Owner-only browser case" })).toBeVisible();
    ownerCaseUrl = page.url();
    await saveAuthStorageState(page, authFile);
    await context.close();
  });

  test("does not show another user's case content in the browser", async ({ page }) => {
    const otherEmail = uniqueEmail("pw-isolation-other");

    await signUp(page, otherEmail);
    await page.goto(ownerCaseUrl);

    const publicNotFound = page.getByText("The page you were looking for doesn't exist");
    const recordNotFound = page.getByRole("heading", {
      name: /RecordNotFound in DebuggingCasesController#show/,
    });
    await expect(publicNotFound.or(recordNotFound)).toBeVisible();
    await expect(page.getByRole("heading", { name: "Owner-only browser case" })).toHaveCount(0);
    await expect(page.getByRole("heading", { name: "Sanitized log sources" })).toHaveCount(0);
    await expect(page.getByText("[REQUEST_1]")).toHaveCount(0);
  });
});
