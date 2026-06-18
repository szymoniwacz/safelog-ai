import { z } from "zod";

export const REVIEW_SCHEMA = z.object({
  implementationCorrectness: z.number().describe(
    "Poprawność implementacji: czy kod robi to, co deklaruje (skala 1-10). " +
      "1: logika jest błędna lub po cichu psuje istniejące zachowania. " +
      "10: poprawny na ścieżce głównej, w przypadkach brzegowych i w obsłudze błędów.",
  ),
  idiomaticity: z.number().describe(
    "Idiomatyczność: zgodność z konwencjami języka i projektu (skala 1-10)",
  ),
  complexity: z.number().describe(
    "Złożoność: prostota rozwiązania względem problemu (skala 1-10)",
  ),
  testRiskCoverage: z.number().describe(
    "Pokrycie testami proporcjonalne do ryzyka zmienianych ścieżek (skala 1-10)",
  ),
  securitySafety: z.number().describe(
    "Bezpieczeństwo: brak podatności i wycieków sekretów (skala 1-10)",
  ),
  verdict: z.enum(["pass", "fail"]).describe("Wiążący werdykt dla całej zmiany"),
  summary: z.string().describe("Podsumowanie w Markdown, gotowe jako komentarz do PR-a"),
});

export type Review = z.infer<typeof REVIEW_SCHEMA>;
