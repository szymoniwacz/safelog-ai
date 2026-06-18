import { test, expect, type Page } from "@playwright/test";
import { execSync } from "node:child_process";
import path from "node:path";

const SCREENSHOT_DIR = path.join(
  process.cwd(),
  "context",
  "certification",
  "screenshots",
  "champion",
);

const PR_URL = "https://github.com/szymoniwacz/safelog-ai/pull/11";
const WORKFLOW_RUN_URL =
  "https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185";
const JOB_LOG_URL =
  "https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185/job/82132673336";
const WORKFLOW_RUN_ID = "27760320185";

function stripLogLine(raw: string): string {
  return raw
    .replace(/^\ufeff/, "")
    .replace(/^\d{4}-\d{2}-\d{2}T[\d:.]+Z\s*/, "")
    .replace(/\u001b\[[0-9;]*m/g, "");
}

function fetchRunLogsByStep(runId: string): Map<string, string[]> {
  const logText = execSync(`gh run view ${runId} --log`, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });

  const byStep = new Map<string, string[]>();
  for (const line of logText.split("\n")) {
    const parts = line.split("\t");
    if (parts.length < 3) continue;

    const stepName = parts[1];
    const message = stripLogLine(parts.slice(2).join("\t"));
    if (!byStep.has(stepName)) byStep.set(stepName, []);
    byStep.get(stepName)!.push(message);
  }

  return byStep;
}

function stepLogSnippet(stepName: string, lines: string[]): string {
  if (stepName === "Run ./.github/actions/code-review") {
    const start = lines.findIndex((line) => line.includes("npm run review:pr"));
    const end = lines.findIndex((line) => line.includes("Posted review comment"));
    if (start >= 0 && end > start) {
      return lines.slice(start, end + 1).join("\n");
    }
  }

  const maxLines = stepName.startsWith("Post Run") || stepName === "Complete job" ? 6 : 10;
  return lines.slice(0, maxLines).join("\n");
}

async function expandJobLogSteps(page: Page, runId: string): Promise<void> {
  const logsByStep = fetchRunLogsByStep(runId);
  const steps = page.locator("check-step[data-name]");
  const count = await steps.count();

  for (let i = 0; i < count; i++) {
    const step = steps.nth(i);
    const name = await step.getAttribute("data-name");
    if (!name) continue;

    const snippet = stepLogSnippet(name, logsByStep.get(name) ?? []);
    await step.evaluate(
      (element, { snippet: text }) => {
        const summary = element.querySelector("summary.js-check-step-summary");
        const details = summary?.closest("details");
        if (!details) return;

        details.open = true;
        element.querySelector(".js-checks-log-display-error")?.remove();

        const container =
          details.querySelector(".js-checks-log-display-container") ??
          details.querySelector(".js-checks-log-display");
        if (!(container instanceof HTMLElement)) return;

        container.replaceChildren();
        const pre = document.createElement("pre");
        pre.className = "color-fg-default px-3 py-2";
        pre.style.whiteSpace = "pre-wrap";
        pre.style.fontFamily =
          'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace';
        pre.style.fontSize = "12px";
        pre.style.lineHeight = "1.45";
        pre.style.margin = "0";
        pre.textContent = text;
        container.appendChild(pre);
        container.hidden = false;
        container.style.display = "block";
      },
      { snippet },
    );
  }
}

test("capture Champion M5 CI code review screenshots", async ({ page }) => {
  test.skip(
    !process.env.PLAYWRIGHT_CAPTURE_SCREENSHOTS,
    "Set PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 to run",
  );

  await page.setViewportSize({ width: 1440, height: 900 });

  if (!process.env.PLAYWRIGHT_CAPTURE_JOB_LOGS_ONLY) {
    await page.goto(PR_URL, { waitUntil: "domcontentloaded" });
    await expect(
      page.getByRole("heading", { name: "AI code review", exact: true }),
    ).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "01-pr-ai-review-comment.png"),
      fullPage: true,
    });

    await page.goto(WORKFLOW_RUN_URL, { waitUntil: "domcontentloaded" });
    await expect(
      page.getByText("AI Code Review", { exact: true }).first(),
    ).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, "02-actions-workflow-run.png"),
      fullPage: false,
    });
  }

  await page.goto(JOB_LOG_URL, { waitUntil: "domcontentloaded" });
  await expect(
    page.getByRole("heading", { name: "AI code review" }).first(),
  ).toBeVisible({
    timeout: 30_000,
  });
  await page.locator("check-step[data-name]").first().waitFor({
    timeout: 30_000,
  });

  await expandJobLogSteps(page, WORKFLOW_RUN_ID);

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, "03-actions-job-logs.png"),
    fullPage: true,
  });
});
