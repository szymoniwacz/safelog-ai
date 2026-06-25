import { test, expect } from "@playwright/test";
import {
  DESTROY_CASE_CONFIRMATION,
  clickDeleteWithConfirmation,
  fillLogSourceSlot,
  goToCasesIndex,
  signUp,
  uniqueEmail,
} from "./helpers";

test("edits case metadata from the index and permanently deletes with confirmation", async ({
  page,
}) => {
  const email = uniqueEmail("pw-crud");
  const originalTitle = "CRUD intake case";
  const updatedTitle = "CRUD updated title";

  await signUp(page, email);

  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill(originalTitle);
  await page.getByLabel("Description").fill("Initial reporter notes");
  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    pastedContent: "request_id=req-pw-crud-1",
  });
  await page.getByRole("button", { name: "Create debugging case" }).click();
  await expect(page.getByRole("heading", { name: originalTitle })).toBeVisible();

  await goToCasesIndex(page);

  const caseRow = page.getByRole("row", { name: new RegExp(originalTitle) });
  await expect(caseRow.getByRole("link", { name: "Edit" })).toBeVisible();
  await expect(caseRow.getByRole("button", { name: "Delete" })).toBeVisible();

  await caseRow.getByRole("link", { name: "Edit" }).click();
  await expect(page.getByRole("heading", { name: "Edit debugging case" })).toBeVisible();
  await page.getByLabel("Title").fill(updatedTitle);
  await page.getByLabel("Description").fill("Updated reporter notes");
  await page.getByRole("button", { name: "Save changes" }).click();

  await expect(page.getByText("Case updated.")).toBeVisible();
  await expect(page.getByRole("heading", { name: updatedTitle })).toBeVisible();
  await expect(page.getByText("Updated reporter notes")).toBeVisible();

  await goToCasesIndex(page);
  await expect(page.getByRole("link", { name: updatedTitle })).toBeVisible();

  await clickDeleteWithConfirmation(page, page.getByRole("row", { name: new RegExp(updatedTitle) }));

  await expect(page.getByText("Case deleted.")).toBeVisible();
  await expect(page.getByRole("link", { name: updatedTitle })).toHaveCount(0);
  await expect(page.getByText("No active debugging cases yet")).toBeVisible();
});

test("delete on the case show page asks for irreversible confirmation", async ({ page }) => {
  const email = uniqueEmail("pw-crud-show");
  const title = "CRUD show delete case";

  await signUp(page, email);

  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill(title);
  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    pastedContent: "request_id=req-pw-crud-show",
  });
  await page.getByRole("button", { name: "Create debugging case" }).click();
  await expect(page.getByRole("heading", { name: title })).toBeVisible();
  await expect(page.getByRole("link", { name: "Edit case" })).toBeVisible();

  await clickDeleteWithConfirmation(page, page, "Delete case");

  await expect(page.getByText("Case deleted.")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Debugging cases" })).toBeVisible();
  await expect(page.getByRole("link", { name: title })).toHaveCount(0);
});

test("canceling delete confirmation keeps the case", async ({ page }) => {
  const email = uniqueEmail("pw-crud-cancel");
  const title = "CRUD cancel delete case";

  await signUp(page, email);

  await page.getByRole("link", { name: "New case" }).click();
  await page.getByLabel("Title").fill(title);
  await fillLogSourceSlot(page, 1, {
    sourceType: "Rails log",
    pastedContent: "request_id=req-pw-crud-cancel",
  });
  await page.getByRole("button", { name: "Create debugging case" }).click();

  page.once("dialog", async (dialog) => {
    expect(dialog.type()).toBe("confirm");
    expect(dialog.message()).toBe(DESTROY_CASE_CONFIRMATION);
    await dialog.dismiss();
  });

  await page.getByRole("button", { name: "Delete case" }).click();

  await expect(page.getByRole("heading", { name: title })).toBeVisible();
  await goToCasesIndex(page);
  await expect(page.getByRole("link", { name: title })).toBeVisible();
});
