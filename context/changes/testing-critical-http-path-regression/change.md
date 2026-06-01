---
change_id: testing-critical-http-path-regression
title: Critical HTTP path regression
status: planned
created: 2026-06-01
updated: 2026-06-01
archived_at: null
---

## Notes

Open a change folder for rollout Phase 2 of context/foundation/test-plan.md: "Critical HTTP path regression".
Risks covered: #3, #6, #7. Test types planned: request/integration.
Baseline: 119 RSpec examples; Phase 1 shipped security cookbook (§6.1/§6.3–§6.5). Gap-fill authorization matrix, demo gate, and analyze failure/retry paths — do not duplicate security guardrails already proven.
Risk response intent:
- #3: prove cross-user show, analyze, archive, and export return 404 (not 403 leak); challenge signed-in user implies only own cases reachable.
- #6: prove load demo returns 404 outside development/test; challenge happy path only in development.
- #7: prove invalid AI output retries then fails safely with hypothesis framing required; challenge first successful analyze proves validator exists.
Exclusions (§7): no E2E/Playwright, UI snapshots, or view cosmetic tests.
