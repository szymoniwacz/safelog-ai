import type { Review } from "../schemas/review-schema.js";
import { CRITERION_LABELS } from "../schemas/review-schema.js";

export const REVIEW_COMMENT_MARKER = "<!-- ai-code-review:marker -->";

export function formatReviewComment(review: Review): string {
  const scoreRows = Object.entries(CRITERION_LABELS)
    .map(([key, label]) => {
      const score = review[key as keyof typeof CRITERION_LABELS];
      return `| ${label} | ${score} |`;
    })
    .join("\n");

  return [
    "## AI code review",
    "",
    `**Verdict:** ${review.verdict}`,
    "",
    "| Criterion | Score |",
    "|-----------|------:|",
    scoreRows,
    "",
    review.summary.trim(),
    "",
    REVIEW_COMMENT_MARKER,
  ].join("\n");
}

export function formatNeutralComment(message: string): string {
  return ["## AI code review", "", message, "", REVIEW_COMMENT_MARKER].join("\n");
}
