---
change_id: encrypted-diagnostic-schema
title: Encrypted diagnostic schema (roadmap F-02)
status: planned
created: 2026-05-27
updated: 2026-05-25
archived_at: null
---

## Notes

F-02 z @context/foundation/roadmap.md

Plan: `context/changes/encrypted-diagnostic-schema/plan.md` — schema/models/encryption only; no case routes.

Production deploy: set `RAILS_ACTIVE_RECORD_ENCRYPTION_*` Fly secrets per `context/deployment/deploy-plan.md` before encrypted writes.

Next slices: **S-02** intake/redaction (services + controllers), **F-03** AI adapter.
