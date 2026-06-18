import "../lib/load-env.js";

import { openai } from "@ai-sdk/openai";
import type { LanguageModel } from "ai";

const DEFAULT_MODEL = "gpt-4o-mini";

export function resolveModelId(model?: string): string {
  return (
    model ??
    process.env.CODE_REVIEWER_MODEL ??
    process.env.OPENAI_MODEL ??
    DEFAULT_MODEL
  );
}

export function createReviewModel(model?: string): LanguageModel {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error(
      "OPENAI_API_KEY is required.",
    );
  }

  return openai(resolveModelId(model));
}
