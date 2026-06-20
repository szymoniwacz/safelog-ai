# Architect submission evidence (M4)

Primary evidence is **markdown** under [`context/map/`](../../../map/) and [`context/domain/`](../../../domain/) (course artifacts; some sections in Polish). **Submission PNGs use English excerpts** from [`context/certification/architect-excerpts/`](../../architect-excerpts/) — see [`architect-excerpts/README.md`](../../architect-excerpts/README.md).

| File | Source document | Content |
|------|-----------------|---------|
| `01-repo-map-tldr.png` | [`repo-map.md`](../../../map/repo-map.md) | TL;DR + territory table |
| `02-structure-boundaries.png` | [`artifact-2-structure.md`](../../../map/artifact-2-structure.md) | Service DAG + boundary rules |
| `03-ranked-refactors.png` | [`refactor-opportunities/research.md`](../../../changes/refactor-opportunities/research.md) | Ranked TD-2 / IMPL-1 / TD-5 |
| `04-domain-distillation.png` | [`01-domain-distillation.md`](../../../domain/01-domain-distillation.md) | Stack + runtime flow |
| `05-invariant-aggregate-plan.png` | [`02-invariant-aggregate-refactor.md`](../../../domain/02-invariant-aggregate-refactor.md) | INV-G1 + aggregate design |
| `06-acl-plan.png` | [`03-anti-corruption-layer.md`](../../../domain/03-anti-corruption-layer.md) | ACL port / adapter design |

Readiness audit: [`context/reviews/m4-architect-readiness-review.md`](../../../reviews/m4-architect-readiness-review.md).

## Re-capture

```bash
PLAYWRIGHT_SKIP_WEBSERVER=1 \
PLAYWRIGHT_CAPTURE_SCREENSHOTS=1 \
npx playwright test e2e/capture-architect-screenshots.spec.ts
```

Optional diagram asset (not PNG): [`context/map/diagrams/e2e-helper-hub.svg`](../../../map/diagrams/e2e-helper-hub.svg) — E2E dependency graph from dependency-cruiser.
