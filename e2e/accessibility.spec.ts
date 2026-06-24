import { test, expect, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import type { Result } from "axe-core";
import { signUp, uniqueEmail } from "./helpers";

// Automated WCAG 2.0/2.1 Level A + AA rules via axe tags (not full manual WCAG coverage).
const WCAG_AA_TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"] as const;

function formatAxeViolations(violations: Result[]): string {
  if (violations.length === 0) return "";
  return violations
    .map((v) => `${v.id} (${v.impact}): ${v.help}\n  ${v.helpUrl}`)
    .join("\n");
}

async function expectNoSeriousOrCriticalViolations(page: Page): Promise<void> {
  const results = await new AxeBuilder({ page })
    .withTags([...WCAG_AA_TAGS])
    .analyze();

  const blocking = results.violations.filter(
    (v) => v.impact === "critical" || v.impact === "serious",
  );

  expect(blocking, formatAxeViolations(blocking)).toEqual([]);
}

test("dashboard after sign up has no serious or critical WCAG violations", async ({ page }) => {
  const email = uniqueEmail("pw-a11y-dashboard");

  await signUp(page, email);
  await expect(page.getByRole("heading", { name: "SafeLog AI", exact: true })).toBeVisible();

  await expectNoSeriousOrCriticalViolations(page);
});

test("new debugging case form has no serious or critical WCAG violations", async ({ page }) => {
  const email = uniqueEmail("pw-a11y-new-case");

  await signUp(page, email);
  await page.getByRole("link", { name: "New case" }).click();
  await expect(page.getByRole("heading", { name: "New debugging case" })).toBeVisible();

  await expectNoSeriousOrCriticalViolations(page);
});
