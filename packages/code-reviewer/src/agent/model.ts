import "../lib/load-env.js";

import { openai } from "@ai-sdk/openai";
import type { LanguageModel } from "ai";

const DEFAULT_MODEL = "gpt-4o-mini";

function firstConfiguredModel(...candidates: Array<string | undefined>): string {
  for (const candidate of candidates) {
    const trimmed = candidate?.trim();
    if (trimmed) return trimmed;
  }

  return DEFAULT_MODEL;
}

export function resolveModelId(model?: string): string {
  return firstConfiguredModel(
    model,
    process.env.CODE_REVIEWER_MODEL,
    process.env.OPENAI_MODEL,
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
