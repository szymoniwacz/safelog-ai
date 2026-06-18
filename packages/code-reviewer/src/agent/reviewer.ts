import { Output, ToolLoopAgent, stepCountIs } from "ai";

import { buildReviewUserPrompt, SYSTEM_PROMPT } from "../prompts/system-prompt.js";
import { REVIEW_SCHEMA, type Review } from "../schemas/review-schema.js";
import { createReviewModel } from "./model.js";

const DEFAULT_MAX_STEPS = 2;

export type CodeReviewerOptions = {
  model?: string;
  maxSteps?: number;
};

export function createCodeReviewer(options: CodeReviewerOptions = {}) {
  const maxSteps = options.maxSteps ?? DEFAULT_MAX_STEPS;

  return new ToolLoopAgent({
    model: createReviewModel(options.model),
    instructions: SYSTEM_PROMPT,
    tools: {},
    output: Output.object({ schema: REVIEW_SCHEMA }),
    stopWhen: stepCountIs(maxSteps),
  });
}

export async function reviewDiff(
  diff: string,
  options: CodeReviewerOptions = {},
): Promise<Review> {
  const trimmed = diff.trim();
  if (!trimmed) {
    throw new Error("Diff is empty. Pipe git diff output: git diff | npm run review");
  }

  const reviewer = createCodeReviewer(options);
  const { output } = await reviewer.generate({
    prompt: buildReviewUserPrompt(trimmed),
  });

  if (!output) {
    throw new Error("Reviewer returned no structured output.");
  }

  return output;
}
