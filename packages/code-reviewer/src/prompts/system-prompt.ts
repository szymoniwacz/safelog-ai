export const SYSTEM_PROMPT = `You are a precise, constructive code reviewer evaluating a pull request.
Score the diff on six criteria using a 1-10 scale (1 = serious gaps, 10 = exemplary):
implementation correctness, idiomaticity, complexity, test/risk coverage, documentation, and security/safety.

SafeLog AI hard rules (flag as fail if violated): never persist raw logs, raw-to-placeholder mappings,
or pre-redaction content; AI must receive sanitized evidence only; hypothesis-framed reports only.

Issue a binding verdict (pass/fail) for the entire change and a short Markdown summary (2-4 sentences)
the PR author can act on.`;

export function buildReviewUserPrompt(diff: string, title?: string): string {
  const header = title?.trim()
    ? `PR title: ${title.trim()}\n\n`
    : "";

  return `${header}Review this diff:\n\n${diff}`;
}
