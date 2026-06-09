import { test, expect } from "@playwright/test";
import { DEFAULT_PASSWORD, signIn, signUp, uniqueEmail } from "./helpers";

test.describe("Authentication", () => {
  test("guest is redirected to sign in from dashboard and cases", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/users\/sign_in$/);
    await expect(page.getByRole("heading", { name: "Sign in to SafeLog AI" })).toBeVisible();

    await page.goto("/debugging_cases");
    await expect(page).toHaveURL(/\/users\/sign_in$/);
  });

  test("user can sign up and reach the dashboard", async ({ page }) => {
    const email = uniqueEmail("pw-signup");

    await signUp(page, email);

    await expect(page.getByRole("heading", { name: "SafeLog AI", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "New case" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Load demo case" })).toBeVisible();
  });

  test("user can sign in after sign out", async ({ page }) => {
    const email = uniqueEmail("pw-signin");
    const password = DEFAULT_PASSWORD;

    await signUp(page, email, password);
    await page.getByRole("button", { name: "Sign out" }).click();

    await page.goto("/");
    await expect(page).toHaveURL(/\/users\/sign_in$/);

    await signIn(page, email, password);
    await expect(page.getByRole("heading", { name: "SafeLog AI", exact: true })).toBeVisible();
  });
});
