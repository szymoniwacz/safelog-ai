# M5L4 — distribution decision

**Date:** 2026-06-18  
**Project:** SafeLog AI

## Audience

Me — solo developer, several repos on GitHub (`szymoniwacz/*`). I want the same AI skills and rules installable in each project without copying files by hand.

## Choice

**Model 1: GitHub Packages** — npm package `@szymoniwacz/ai-toolkit`, published via GitHub Actions, installed with `npm install` in the consumer repo.

## Why

I already work on GitHub (code, Actions, Packages). Auth is `GITHUB_TOKEN`. I do not need AWS or a custom API — no enterprise team and no external consumers.

## Not doing

- **CodeArtifact (Model 2)** — unnecessary AWS infrastructure.
- **Custom API + CLI (Model 3)** — no need to gate access.

## Next

Package in `packages/ai-toolkit/`: code-review skill, rules snippet from `AGENTS.md`, install/uninstall scripts, publish workflow.
