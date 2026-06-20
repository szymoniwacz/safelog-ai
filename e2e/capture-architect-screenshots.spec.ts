import { test } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const SCREENSHOT_DIR = path.join(
  process.cwd(),
  "context",
  "certification",
  "screenshots",
  "architect",
);

const EXCERPT_DIR = path.join(
  process.cwd(),
  "context",
  "certification",
  "architect-excerpts",
);

type DocCapture = {
  excerptFile: string;
  sourceRef: string;
  filename: string;
};

const CAPTURES: DocCapture[] = [
  {
    excerptFile: "01-repo-map-tldr.md",
    sourceRef: "context/map/repo-map.md",
    filename: "01-repo-map-tldr.png",
  },
  {
    excerptFile: "02-structure-boundaries.md",
    sourceRef: "context/map/artifact-2-structure.md",
    filename: "02-structure-boundaries.png",
  },
  {
    excerptFile: "03-ranked-refactors.md",
    sourceRef: "context/changes/refactor-opportunities/research.md",
    filename: "03-ranked-refactors.png",
  },
  {
    excerptFile: "04-domain-distillation.md",
    sourceRef: "context/domain/01-domain-distillation.md",
    filename: "04-domain-distillation.png",
  },
  {
    excerptFile: "05-invariant-aggregate-plan.md",
    sourceRef: "context/domain/02-invariant-aggregate-refactor.md",
    filename: "05-invariant-aggregate-plan.png",
  },
  {
    excerptFile: "06-acl-plan.md",
    sourceRef: "context/domain/03-anti-corruption-layer.md",
    filename: "06-acl-plan.png",
  },
];

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

async function captureDocExcerpt(
  page: import("@playwright/test").Page,
  capture: DocCapture,
): Promise<void> {
  const excerptPath = path.join(EXCERPT_DIR, capture.excerptFile);
  if (!fs.existsSync(excerptPath)) {
    throw new Error(`missing English excerpt: ${excerptPath}`);
  }

  const content = fs.readFileSync(excerptPath, "utf8");

  await page.setContent(
    `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>${escapeHtml(capture.excerptFile)}</title>
    <style>
      body { margin: 0; background: #0d1117; color: #c9d1d9; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
      header { padding: 16px 24px; border-bottom: 1px solid #30363d; font-size: 14px; color: #58a6ff; }
      pre { margin: 0; padding: 24px; white-space: pre-wrap; line-height: 1.5; font-size: 13px; }
    </style>
  </head>
  <body>
    <header>SafeLog AI — Architect evidence (EN) — source: ${escapeHtml(capture.sourceRef)}</header>
    <pre>${escapeHtml(content)}</pre>
  </body>
</html>`,
  );

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, capture.filename),
    fullPage: true,
  });
}

test("capture Architect M4 submission screenshots", async ({ page }) => {
  test.skip(
    !process.env.PLAYWRIGHT_CAPTURE_SCREENSHOTS,
    "Set PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 to run",
  );

  await page.setViewportSize({ width: 1440, height: 900 });

  for (const capture of CAPTURES) {
    await test.step(capture.filename, async () => {
      await captureDocExcerpt(page, capture);
    });
  }
});
