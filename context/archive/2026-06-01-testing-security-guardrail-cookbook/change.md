---
change_id: testing-security-guardrail-cookbook
title: Security guardrail cookbook
status: archived
created: 2026-06-01
updated: 2026-06-01
archived_at: 2026-06-01T13:19:16Z
---

## Notes

Open a change folder for rollout Phase 1 of context/foundation/test-plan.md: "Security guardrail cookbook".
Risks covered: #1, #2, #4. Test types: request + service + model (gap-fill only).
Baseline: 116 RSpec examples with existing security request specs — map coverage gaps; do not duplicate protections already proven.
Priority: PRD guardrails (raw never persist, sanitized-only AI, encryption at rest, case authorization).
Risk response intent:
- #1: prove raw secrets never persist after intake; challenge show-page-only assertions.
- #2: prove analyze never sends raw secrets to AI; challenge FakeClient success without prompt inspection.
- #4: prove metadata fields redact on persist and in prompts; challenge title/description treated as safe.
Exclusions (§7): no E2E/Playwright, UI snapshots, or view cosmetic tests.
