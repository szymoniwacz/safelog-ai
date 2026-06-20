import path from "path";
import { test, expect } from "@playwright/test";
import {
  createAuthenticatedContext,
  saveAuthStorageState,
  signUp,
  uniqueEmail,
} from "./helpers";

const authFile = path.join(__dirname, ".auth", "validation-user.json");

test.describe("Debugging case validation", () => {
  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    const email = uniqueEmail("pw-validation");

    await signUp(page, email);
    await saveAuthStorageState(page, authFile);
    await context.close();
  });

  test("re-renders the new case form with validation errors when no log sources are provided", async ({
    browser,
  }) => {
    const context = await createAuthenticatedContext(browser, authFile);
    const page = await context.newPage();

    await page.goto("/debugging_cases/new");
    await page.getByLabel("Title").fill("Missing sources case");
    await page.getByRole("button", { name: "Create debugging case" }).click();

    await expect(page).toHaveURL(/\/debugging_cases$/);
    await expect(page.getByRole("heading", { name: "New debugging case" })).toBeVisible();
    await expect(page.getByText("prohibited this case from being saved")).toBeVisible();
    await expect(page.getByText("must include at least one non-blank log source")).toBeVisible();
    await expect(page.getByLabel("Title")).toHaveValue("Missing sources case");

    await context.close();
  });

  test("preserves metadata fields when validation fails", async ({ browser }) => {
    const context = await createAuthenticatedContext(browser, authFile);
    const page = await context.newPage();

    await page.goto("/debugging_cases/new");
    await page.getByLabel("Title").fill("Metadata preserve case");
    await page.getByLabel("Description").fill("Reporter notes");
    await page.getByLabel("Customer reference").fill("Ticket #999");
    await page.getByLabel("Environment").fill("staging");
    await page.getByRole("button", { name: "Create debugging case" }).click();

    await expect(page.getByRole("heading", { name: "New debugging case" })).toBeVisible();
    await expect(page.getByLabel("Title")).toHaveValue("Metadata preserve case");
    await expect(page.getByLabel("Description")).toHaveValue("Reporter notes");
    await expect(page.getByLabel("Customer reference")).toHaveValue("Ticket #999");
    await expect(page.getByLabel("Environment")).toHaveValue("staging");

    await context.close();
  });
});
