import { appendFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

import "../lib/load-env.js";

import { reviewPullRequest } from "./agent/reviewer.js";
import {
  formatNeutralComment,
  formatReviewComment,
} from "./lib/format-comment.js";
import { readStdin } from "./lib/read-stdin.js";

const MAX_DIFF_CHARS = 100_000;

function truncateDiff(diff: string): string {
  if (diff.length <= MAX_DIFF_CHARS) return diff;

  return `${diff.slice(0, MAX_DIFF_CHARS)}\n\n(diff truncated — review covers first ${MAX_DIFF_CHARS} characters)`;
}

async function writeOutput(name: string, value: string): Promise<void> {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (!outputPath) return;

  await appendFile(outputPath, `${name}=${value}\n`);
}

async function main(): Promise<void> {
  const rawDiff = await readStdin();
  const title = process.env.PR_TITLE ?? "";
  const diff = truncateDiff(rawDiff.trim());

  if (!diff) {
    const comment = formatNeutralComment(
      "No file changes to review in this diff. Skipping pass/fail labels.",
    );
    await writeOutput("verdict", "skip");
    await writeFile("/tmp/review-comment.md", comment);
    process.stdout.write(comment);
    return;
  }

  const review = await reviewPullRequest({ title, diff });
  const comment = formatReviewComment(review);

  await writeOutput("verdict", review.verdict);
  await writeFile("/tmp/review-comment.md", comment);
  process.stdout.write(comment);
}

const isCliEntry = process.argv[1] === fileURLToPath(import.meta.url);

if (isCliEntry) {
  main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`code-reviewer: ${message}\n`);
    process.exitCode = 1;
  });
}
