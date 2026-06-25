import fs from "fs";
import path from "path";
import { type Browser, type BrowserContext, type Locator, type Page, expect } from "@playwright/test";

export const DEFAULT_PASSWORD = "password123";

export const DESTROY_CASE_CONFIRMATION =
  "Permanently delete this case? This action cannot be undone.";

export function uniqueEmail(prefix: string): string {
  const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  return `${prefix}-${suffix}@example.com`;
}

export async function signUp(
  page: Page,
  email: string,
  password: string = DEFAULT_PASSWORD,
): Promise<void> {
  await page.goto("/users/sign_up");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByLabel("Password confirmation").fill(password);
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText(`Signed in as ${email}.`)).toBeVisible();
}

export async function signIn(
  page: Page,
  email: string,
  password: string = DEFAULT_PASSWORD,
): Promise<void> {
  await page.goto("/users/sign_in");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByText(`Signed in as ${email}.`)).toBeVisible();
}

export function logSourceFieldset(page: Page, slot: number): Locator {
  return page.locator("fieldset").filter({
    has: page.locator("legend", { hasText: `Log source ${slot}` }),
  });
}

export async function saveAuthStorageState(page: Page, storagePath: string): Promise<void> {
  fs.mkdirSync(path.dirname(storagePath), { recursive: true });
  await page.context().storageState({ path: storagePath });
}

export async function createAuthenticatedContext(
  browser: Browser,
  storagePath: string,
): Promise<BrowserContext> {
  return browser.newContext({ storageState: storagePath });
}

export async function fillLogSourceSlot(
  page: Page,
  slot: number,
  options: { sourceType: string; pastedContent: string; name?: string },
): Promise<void> {
  const fieldset = logSourceFieldset(page, slot);
  await fieldset.getByLabel("Source type").selectOption({ label: options.sourceType });
  if (options.name) {
    await fieldset.getByLabel("Name (optional)").fill(options.name);
  }
  await fieldset.getByLabel("Pasted content").fill(options.pastedContent);
}

export async function goToCasesIndex(page: Page): Promise<void> {
  const allCasesLink = page.getByRole("link", { name: "All cases" });
  if (await allCasesLink.isVisible()) {
    await allCasesLink.click();
  } else {
    await page
      .getByRole("navigation", { name: "Main" })
      .getByRole("link", { name: "Cases", exact: true })
      .click();
  }

  await expect(page.getByRole("heading", { name: "Debugging cases" })).toBeVisible();
}

type DeleteScope = Pick<Locator, "getByRole">;

export async function clickDeleteWithConfirmation(
  page: Page,
  scope: DeleteScope,
  buttonName: string | RegExp = /Delete/,
): Promise<void> {
  page.once("dialog", async (dialog) => {
    expect(dialog.type()).toBe("confirm");
    expect(dialog.message()).toBe(DESTROY_CASE_CONFIRMATION);
    await dialog.accept();
  });

  await scope.getByRole("button", { name: buttonName }).click();
}
