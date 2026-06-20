# Architect certification excerpts (English)

English submission copies for Playwright screenshot capture. **Course artifacts remain in Polish** under `context/map/` and `context/domain/` — these excerpts are for reviewer-facing PNGs only.

| Excerpt file | Original source |
|--------------|-----------------|
| `01-repo-map-tldr.md` | `context/map/repo-map.md` |
| `02-structure-boundaries.md` | `context/map/artifact-2-structure.md` |
| `03-ranked-refactors.md` | `context/changes/refactor-opportunities/research.md` |
| `04-domain-distillation.md` | `context/domain/01-domain-distillation.md` |
| `05-invariant-aggregate-plan.md` | `context/domain/02-invariant-aggregate-refactor.md` |
| `06-acl-plan.md` | `context/domain/03-anti-corruption-layer.md` |

Re-capture PNGs after editing excerpts:

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
  npx playwright test e2e/capture-architect-screenshots.spec.ts
```
