import { fileURLToPath } from "node:url";

import { reviewDiff } from "./agent/reviewer.js";
import { readStdin } from "./lib/read-stdin.js";

export {
  reviewDiff,
  reviewPullRequest,
  createCodeReviewer,
  type CodeReviewerOptions,
  type PullRequestReviewInput,
} from "./agent/reviewer.js";
export { resolveModelId, createReviewModel } from "./agent/model.js";
export { buildReviewUserPrompt, SYSTEM_PROMPT } from "./prompts/system-prompt.js";
export {
  REVIEW_SCHEMA,
  CRITERION_LABELS,
  type Review,
} from "./schemas/review-schema.js";
export {
  formatReviewComment,
  formatNeutralComment,
  REVIEW_COMMENT_MARKER,
} from "./lib/format-comment.js";
export { readStdin } from "./lib/read-stdin.js";

async function main(): Promise<void> {
  const diff = await readStdin();
  const review = await reviewDiff(diff);
  process.stdout.write(`${JSON.stringify(review, null, 2)}\n`);
}

const isCliEntry = process.argv[1] === fileURLToPath(import.meta.url);

if (isCliEntry) {
  main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`code-reviewer: ${message}\n`);
    process.exitCode = 1;
  });
}
