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

type ReviewScenario = {
  id: "fail" | "pass";
  prUrl: string;
  workflowRunUrl: string;
  jobLogUrl: string;
  workflowRunId: string;
  files: {
    prComment: string;
    workflowRun: string;
    jobLogs: string;
  };
};

const SCENARIOS: ReviewScenario[] = [
  {
    id: "fail",
    prUrl: "https://github.com/szymoniwacz/safelog-ai/pull/11",
    workflowRunUrl:
      "https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185",
    jobLogUrl:
      "https://github.com/szymoniwacz/safelog-ai/actions/runs/27760320185/job/82132673336",
    workflowRunId: "27760320185",
    files: {
      prComment: "01-pr-ai-review-comment-fail.png",
      workflowRun: "02-actions-workflow-run-fail.png",
      jobLogs: "03-actions-job-logs-fail.png",
    },
  },
  {
    id: "pass",
    prUrl: "https://github.com/szymoniwacz/safelog-ai/pull/12",
    workflowRunUrl:
      "https://github.com/szymoniwacz/safelog-ai/actions/runs/27763104255",
    jobLogUrl:
      "https://github.com/szymoniwacz/safelog-ai/actions/runs/27763104255/job/82142437908",
    workflowRunId: "27763104255",
    files: {
      prComment: "04-pr-ai-review-comment-pass.png",
      workflowRun: "05-actions-workflow-run-pass.png",
      jobLogs: "06-actions-job-logs-pass.png",
    },
  },
];

function selectedScenarios(): ReviewScenario[] {
  const filter = process.env.PLAYWRIGHT_CAPTURE_SCENARIO;
  if (filter === "fail" || filter === "pass") {
    return SCENARIOS.filter((scenario) => scenario.id === filter);
  }
  return SCENARIOS;
}

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

async function captureScenario(page: Page, scenario: ReviewScenario): Promise<void> {
  const jobLogsOnly = process.env.PLAYWRIGHT_CAPTURE_JOB_LOGS_ONLY === "1";

  if (!jobLogsOnly) {
    await page.goto(scenario.prUrl, { waitUntil: "domcontentloaded" });
    await expect(
      page.getByRole("heading", { name: "AI code review", exact: true }),
    ).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, scenario.files.prComment),
      fullPage: true,
    });

    await page.goto(scenario.workflowRunUrl, { waitUntil: "domcontentloaded" });
    await expect(page.getByText("AI Code Review", { exact: true }).first()).toBeVisible({
      timeout: 30_000,
    });
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, scenario.files.workflowRun),
      fullPage: false,
    });
  }

  await page.goto(scenario.jobLogUrl, { waitUntil: "domcontentloaded" });
  await page.locator("check-step[data-name]").first().waitFor({
    timeout: 30_000,
  });

  await expandJobLogSteps(page, scenario.workflowRunId);

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, scenario.files.jobLogs),
    fullPage: true,
  });
}

test("capture Champion M5 CI code review screenshots", async ({ page }) => {
  test.skip(
    !process.env.PLAYWRIGHT_CAPTURE_SCREENSHOTS,
    "Set PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 to run",
  );

  await page.setViewportSize({ width: 1440, height: 900 });

  for (const scenario of selectedScenarios()) {
    await test.step(`capture ${scenario.id} review scenario`, async () => {
      await captureScenario(page, scenario);
    });
  }
});
