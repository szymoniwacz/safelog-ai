<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: AI Toolkit Registry

- **Plan**: `context/changes/ai-toolkit-registry/plan.md`
- **Scope**: Full plan (Phases 1–5)
- **Date**: 2026-06-20
- **Verdict**: APPROVED (after triage fixes)
- **Findings**: 0 critical, 2 warnings, 3 observations — 4 fixed, 1 documented

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | PASS |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

## Findings

### F1 — Manifest `files` paths are doubled

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: `packages/ai-toolkit/install.js:87-89`
- **Detail**: `listFilesRecursive(skillDest, consumerRoot)` already returns paths like `.cursor/skills/code-review/SKILL.md` relative to consumer root. The `.map((file) => \`${SKILL_REL}/${file}\`)` prepends the skill prefix again, producing `.cursor/skills/code-review/.cursor/skills/code-review/SKILL.md` in `.cursor/.ai-toolkit-manifest.json`. Uninstall still works (removes `SKILL_REL` directory wholesale and skips skill entries in the manifest loop), but manifest data is wrong for any future manifest-driven logic.
- **Fix**: Use `listFilesRecursive(skillDest, skillDest)` and map to `${SKILL_REL}/${file}`, or drop the map and use paths from `consumerRoot` base directly.
- **Decision**: FIXED

### F2 — Installed skill not committable (gitignore)

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Architecture
- **Location**: `.gitignore:52`, consumer install target `.cursor/skills/code-review/`
- **Detail**: `.cursor/skills/` is gitignored (10x course policy). After `npm install`, the skill exists locally but is not in git. Commit `33bd57d` added manifest + AGENTS.md sentinels but not the skill file. Fresh clone requires `npm install` + GitHub Packages auth to get the skill — correct for npm-distributed artifacts, but README does not call this out for safelog-ai dogfooding.
- **Fix A ⭐ Recommended**: Document in root README or `packages/ai-toolkit/README.md` that cloned repos must run `npm install` (with Packages auth) to materialize `.cursor/skills/code-review/`.
  - Strength: Matches npm-distribution model; no gitignore policy change.
  - Tradeoff: Extra setup step for new clones.
  - Confidence: HIGH — skill is intentionally gitignored.
  - Blind spot: CI/dev onboarding docs outside this change.
- **Fix B**: Add `!/.cursor/skills/code-review/` exception to `.gitignore` and commit the installed skill.
  - Strength: Skill available without npm auth on clone.
  - Tradeoff: Duplicates source in `packages/ai-toolkit/`; fights gitignore convention.
  - Confidence: MED — works but dilutes single-source-of-truth.
  - Blind spot: Other `.cursor/skills/*` course skills still ignored.
- **Decision**: FIXED (Fix A — README note)

### F3 — AGENTS.md content duplication in publisher repo

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: `AGENTS.md:42-80`
- **Detail**: Dogfooding in safelog-ai appends a rules snippet that largely mirrors existing `AGENTS.md` hard rules + Commands + Style. By design for cross-repo portability, but increases token noise in this repo. Consider trimming `packages/ai-toolkit/rules/AGENTS.md` in a future `0.1.1` to a delta-only snippet when installing into repos that already have full rules.
- **Fix**: Trimmed `packages/ai-toolkit/rules/AGENTS.md` to hard rules + pointer (removed duplicate Commands/Style). Re-run `npx @szymoniwacz/ai-toolkit install` in safelog-ai to refresh AGENTS.md sentinel block.
- **Decision**: FIXED

### F4 — `change.md` status not closed out

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Success Criteria
- **Location**: `context/changes/ai-toolkit-registry/change.md:4`
- **Detail**: All Progress checkboxes are `[x]` including Phase 5, but `status` is still `implementing`. Epilogue (`status: implemented`) was not run per `/10x-implement` ritual.
- **Fix**: Set `status: implemented` (or `impl_reviewed` after this review) and `updated: 2026-06-20`.
- **Decision**: FIXED

### F5 — Progress rows lack commit SHAs

- **Severity**: 💡 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Success Criteria
- **Location**: `context/changes/ai-toolkit-registry/plan.md` Progress section
- **Detail**: Phase-end commit ritual did not append ` — <sha>` to Progress rows. Work landed in PR #13 (`4c5b97d`) and consumer commit (`33bd57d`). `/10x-archive` will warn on missing SHAs only.
- **Fix**: Optional backfill with `4c5b97d` / `33bd57d` on phase rows, or leave as-is.
- **Decision**: FIXED
