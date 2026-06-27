#!/usr/bin/env node
/**
 * Renders context/certification/architecture-report.md to PDF via Playwright.
 * Usage: node scripts/render-architecture-report-pdf.mjs
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const mdPath = join(root, "context/certification/architecture-report.md");
const htmlPath = join(root, "context/certification/architecture-report.html");
const pdfPath = join(root, "context/certification/architecture-report.pdf");

const md = readFileSync(mdPath, "utf8");
const body = md
  .replace(/^---[\s\S]*?---\n/, "")
  .replace(
    /```mermaid[\s\S]*?```/,
    `<pre class="diagram">User → DebuggingCasesController → Intake::ProcessCaseSubmission
  → Redaction::Engine → SQLite (encrypted)
Controller → Analysis::AnalyzeCase → Correlation::ExtractSignals
                              → Ai::Client (via PromptBuilder) → AiReport
Boundary: Redaction must not import Ai</pre>`,
  )
  .replace(/^# (.+)$/m, (_, title) => `<h1>${title}</h1>`)
  .replace(/^## (.+)$/gm, (_, title) => `<h2>${title}</h2>`)
  .replace(/^---$/gm, '<hr class="section-break" />')
  .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
  .replace(/`([^`]+)`/g, "<code>$1</code>")
  .replace(
    /^\|(.+)\|\n\|[-| :]+\|\n((?:\|.+\|\n?)*)/gm,
    (_, header, rows) => {
      const ths = header
        .split("|")
        .filter(Boolean)
        .map((c) => `<th>${c.trim()}</th>`)
        .join("");
      const trs = rows
        .trim()
        .split("\n")
        .map((row) => {
          const tds = row
            .split("|")
            .filter(Boolean)
            .map((c) => `<td>${c.trim()}</td>`)
            .join("");
          return `<tr>${tds}</tr>`;
        })
        .join("");
      return `<table><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>`;
    },
  )
  .replace(/^- (.+)$/gm, "<li>$1</li>")
  .replace(/(<li>[\s\S]*?<\/li>\n?)+/g, (block) => `<ul>${block}</ul>`)
  .replace(/^\d+\. (.+)$/gm, "<li>$1</li>")
  .replace(
    /\[([^\]]+)\]\(([^)]+)\)/g,
    '<a href="$2">$1</a>',
  )
  .split("\n\n")
  .map((block) => {
    const trimmed = block.trim();
    if (!trimmed) return "";
    if (/^<(h[12]|table|ul|pre|hr)/.test(trimmed)) return trimmed;
    return `<p>${trimmed.replace(/\n/g, "<br />")}</p>`;
  })
  .join("\n");

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>SafeLog AI — Architecture Report</title>
  <style>
    @page { size: A4; margin: 14mm 14mm; }
    body {
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
      font-size: 9.5pt;
      line-height: 1.38;
      color: #1a1a1a;
      max-width: 100%;
    }
    h1 {
      font-size: 18pt;
      margin: 0 0 6pt;
      border-bottom: 2px solid #2563eb;
      padding-bottom: 6pt;
    }
    h2 {
      font-size: 11pt;
      margin: 10pt 0 5pt;
      color: #1e40af;
    }
    p { margin: 0 0 8pt; }
    strong { font-weight: 600; }
    code {
      font-family: "SF Mono", Menlo, monospace;
      font-size: 9pt;
      background: #f3f4f6;
      padding: 1px 4px;
      border-radius: 3px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 8pt 0 10pt;
      font-size: 9.5pt;
    }
    th, td {
      border: 1px solid #d1d5db;
      padding: 5pt 6pt;
      text-align: left;
      vertical-align: top;
    }
    th { background: #eff6ff; font-weight: 600; }
    ul { margin: 4pt 0 8pt 16pt; padding: 0; }
    li { margin-bottom: 3pt; }
    pre.diagram {
      background: #f8fafc;
      border: 1px solid #cbd5e1;
      border-left: 4px solid #2563eb;
      padding: 10pt;
      font-size: 9pt;
      line-height: 1.35;
      white-space: pre-wrap;
      margin: 8pt 0;
    }
    hr.section-break { border: none; border-top: 1px solid #e5e7eb; margin: 10pt 0; }
    a { color: #2563eb; text-decoration: none; }
    .meta { color: #4b5563; font-size: 9.5pt; margin-bottom: 12pt; }
  </style>
</head>
<body>
${body}
</body>
</html>`;

writeFileSync(htmlPath, html);

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent(html, { waitUntil: "load" });
await page.pdf({
  path: pdfPath,
  format: "A4",
  printBackground: true,
  margin: { top: "14mm", right: "14mm", bottom: "14mm", left: "14mm" },
});
await browser.close();

console.log(`Wrote ${pdfPath}`);
