import { test, expect, type Page } from "@playwright/test";
import { execSync } from "node:child_process";
import path from "node:path";

const SCREENSHOT_DIR = path.join(
  process.cwd(),
  "context",
  "certification",
  "screenshots",
  "champion",
  "m5l4",
);

type PublishCapture = {
  workflowRunUrl: string;
  validateJobUrl: string;
  publishJobUrl: string;
  workflowRunId: string;
  packageUrl: string;
  prUrl: string;
  files: {
    workflowRun: string;
    validateJobLogs: string;
    publishJobLogs: string;
    packagePage: string;
    prMerged: string;
  };
};

const PUBLISH_RUN: PublishCapture = {
  workflowRunUrl:
    "https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234",
  validateJobUrl:
    "https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234/job/82493850438",
  publishJobUrl:
    "https://github.com/szymoniwacz/safelog-ai/actions/runs/27875364234/job/82493864466",
  workflowRunId: "27875364234",
  packageUrl:
    "https://github.com/users/szymoniwacz/packages/npm/package/ai-toolkit",
  prUrl: "https://github.com/szymoniwacz/safelog-ai/pull/13",
  files: {
    workflowRun: "01-publish-workflow-run.png",
    validateJobLogs: "02-validate-job-logs.png",
    publishJobLogs: "03-publish-job-logs.png",
    packagePage: "04-github-packages-page.png",
    prMerged: "05-pr-13-merged.png",
  },
};

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
  if (stepName === "Smoke test install and uninstall") {
    const start = lines.findIndex((line) => line.includes("smoke-install"));
    if (start >= 0) return lines.slice(start, start + 12).join("\n");
  }
  if (stepName === "Publish to GitHub Packages") {
    return lines.slice(0, 8).join("\n");
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

async function captureJobLogs(
  page: Page,
  jobUrl: string,
  runId: string,
  filename: string,
): Promise<void> {
  await page.goto(jobUrl, { waitUntil: "domcontentloaded" });
  await page.locator("check-step[data-name]").first().waitFor({
    timeout: 30_000,
  });
  await expandJobLogSteps(page, runId);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, filename),
    fullPage: true,
  });
}

test("capture Champion M5L4 publish workflow screenshots", async ({ page }) => {
  test.skip(
    !process.env.PLAYWRIGHT_CAPTURE_SCREENSHOTS,
    "Set PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 to run",
  );

  await page.setViewportSize({ width: 1440, height: 900 });

  await test.step("workflow run overview", async () => {
    await page.goto(PUBLISH_RUN.workflowRunUrl, { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Publish AI Toolkit", { exact: true }).first()).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, PUBLISH_RUN.files.workflowRun),
      fullPage: false,
    });
  });

  await test.step("validate job logs", async () => {
    await captureJobLogs(
      page,
      PUBLISH_RUN.validateJobUrl,
      PUBLISH_RUN.workflowRunId,
      PUBLISH_RUN.files.validateJobLogs,
    );
  });

  await test.step("publish job logs", async () => {
    await captureJobLogs(
      page,
      PUBLISH_RUN.publishJobUrl,
      PUBLISH_RUN.workflowRunId,
      PUBLISH_RUN.files.publishJobLogs,
    );
  });

  await test.step("GitHub Packages page", async () => {
    await page.goto(PUBLISH_RUN.packageUrl, { waitUntil: "domcontentloaded" });
    await expect(page.getByText("ai-toolkit").first()).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, PUBLISH_RUN.files.packagePage),
      fullPage: false,
    });
  });

  await test.step("merged PR #13", async () => {
    await page.goto(PUBLISH_RUN.prUrl, { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Merged", { exact: false }).first()).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, PUBLISH_RUN.files.prMerged),
      fullPage: true,
    });
  });
});
