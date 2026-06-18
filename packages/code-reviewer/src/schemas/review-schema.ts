import { z } from "zod";

export const REVIEW_SCHEMA = z.object({
  implementationCorrectness: z.number().describe(
    "Implementation correctness: does the code do what it claims, including edge cases and error paths? (1-10). " +
      "1: broken logic, missed edge cases, or silent regressions. " +
      "10: correct on happy path, edge cases, and failure modes.",
  ),
  idiomaticity: z.number().describe(
    "Idiomaticity: alignment with language, framework, and project conventions (1-10). " +
      "1: fights stack idioms. 10: indistinguishable from well-written surrounding code.",
  ),
  complexity: z.number().describe(
    "Complexity: is the solution as simple as the problem allows? (1-10). " +
      "1: over-engineered or tangled. 10: minimal, clear design.",
  ),
  testRiskCoverage: z.number().describe(
    "Test / risk coverage: meaningful behaviors and risky paths tested proportionally to risk (1-10). " +
      "1: risky logic untested. 10: deliberate coverage of likely break points.",
  ),
  documentation: z.number().describe(
    "Documentation: non-obvious decisions, public surfaces, and tricky code explained where needed (1-10). " +
      "1: intent must be reverse-engineered. 10: just enough docs for the why, without restating the obvious.",
  ),
  securitySafety: z.number().describe(
    "Security and safety: no vulnerabilities, secret leaks, or unsafe handling of untrusted input (1-10). " +
      "1: exploitable flaw or secret leak. 10: input validated, secrets handled correctly. " +
      "For SafeLog: flag any attempt to persist raw logs or raw-to-placeholder mappings.",
  ),
  verdict: z.enum(["pass", "fail"]).describe("Binding verdict for the entire change"),
  summary: z.string().describe("Markdown summary (2-4 sentences, actionable) for the PR comment"),
});

export type Review = z.infer<typeof REVIEW_SCHEMA>;

export const CRITERION_LABELS: Record<
  keyof Omit<Review, "verdict" | "summary">,
  string
> = {
  implementationCorrectness: "Implementation correctness",
  idiomaticity: "Idiomaticity",
  complexity: "Complexity",
  testRiskCoverage: "Test / risk coverage",
  documentation: "Documentation",
  securitySafety: "Security and safety",
};
