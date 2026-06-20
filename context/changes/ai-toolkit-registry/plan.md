# AI Toolkit Registry Implementation Plan

## Overview

Materialize `@szymoniwacz/ai-toolkit` under `packages/ai-toolkit/` — a private npm package on GitHub Packages that distributes a Rails-adapted `code-review` Cursor skill and an `AGENTS.md` rules snippet to consumer repos via install/uninstall scripts and a path-filtered publish workflow. Model 1 (GitHub Packages) only; `packages/code-reviewer/` stays a separate, repo-local CI agent.

## Current State Analysis

Nothing is implemented for M5L4 distribution. The repo has M5L2/M5L3 PR review automation (`packages/code-reviewer/` + `.github/workflows/ai-code-review.yml`) but no `packages/ai-toolkit/`, no publish workflow, and no consumer install path. M5L4 guidance lives in `.cursor/prompts/m5l4-github-packages-spec-*.md` and `.cursor/prompts/m5l4-shared-*.md`. Course config templates referenced in research are not present in the workspace; implementation follows the spec prompts directly.

Three code-review layers must stay separate: the TS OpenAI agent (CI scores), Cursor platform subagent skills (`review-bugbot`, `review-security`), and this toolkit's orchestration skill (Critical/Warning/Suggestion + APPROVE/REQUEST CHANGES).

### Key Discoveries:

- `context/team/m5l4-distribution-decision.md:12-25` — Model 1 locked; package contents defined
- `context/changes/ai-toolkit-registry/research.md:129-149` — templates default to `.claude/` and `@twoj-zespol`; SafeLog needs `.cursor/`, `AGENTS.md`, `@szymoniwacz`
- `AGENTS.md:5-40` — rules source: hard rules + Commands + Style sections (user choice)
- `.github/workflows/ai-code-review.yml:20` — existing GHA uses `checkout@v6` and Node 22 via composite action
- Root `package.json` exists for Playwright/E2E only — no npm workspaces; publisher keeps ai-toolkit standalone per user choice

## Desired End State

After this plan:

1. `packages/ai-toolkit/` contains a publishable npm package with skill, rules snippet, install/uninstall scripts, and README.
2. `.github/workflows/publish-ai-toolkit.yml` validates on PR, runs an installer smoke test, and publishes to GitHub Packages on push to `main` when `packages/ai-toolkit/**` changes and `package.json` version is bumped.
3. A consumer Rails repo at repo root can add scope-mapped `.npmrc`, run `npm install @szymoniwacz/ai-toolkit`, and receive `.cursor/skills/code-review/SKILL.md` plus a sentinel block appended to `AGENTS.md`, tracked in `.cursor/.ai-toolkit-manifest.json`.
4. `@szymoniwacz/ai-toolkit` appears as a private package on GitHub Packages linked to `szymoniwacz/safelog-ai`.

**Verify:** `npm pack --dry-run` in package dir; publish workflow green on main; smoke script passes in CI; manual install into a temp consumer dir shows skill + sentinels + manifest; `npx @szymoniwacz/ai-toolkit uninstall` (or bin equivalent) removes managed artifacts.

## What We're NOT Doing

- CodeArtifact / AWS infrastructure (Model 2) — reject `setup-cicd` and `tf-registry` skills for this change
- Custom API + CLI delivery (Model 3)
- Bundling `packages/code-reviewer/` into ai-toolkit v1
- Adding ai-toolkit as root `package.json` dependency or npm workspaces
- Modifying `.github/workflows/ci.yml` or `ai-code-review.yml`
- Auto semver bump or tag-triggered publish in v1
- Public package visibility
- Supporting monorepo consumer layouts (apps/ subdirs) in v1 — document Rails-at-root only

## Implementation Approach

Follow M5L4 GitHub Packages specs (`.cursor/prompts/m5l4-github-packages-spec-pack.md`, `m5l4-github-packages-spec-cicd.md`) with SafeLog adaptations: Cursor paths, `@szymoniwacz` scope, monorepo `packages/ai-toolkit/` layout, Node 22, `checkout@v6`. Generate skill content from `m5l4-shared-conventions.md` adapted for Rails/SafeLog plus security rules from `AGENTS.md`. Installer is manifest-driven, sentinel-based, idempotent, and non-fatal on postinstall failure per spec.

## Critical Implementation Details

Postinstall runs during `npm install` in the **consumer** repo and must locate the consumer project root (directory containing `package.json` or git root — prefer nearest `package.json` walking up from `process.cwd()`). The smoke test in CI must simulate this by creating a temp consumer dir with a minimal `package.json`, copying or linking the packed tarball, running install, asserting files, then uninstall — not by running postinstall from the publisher tree (which would mutate safelog-ai itself).

Sentinel markers must use `@szymoniwacz/ai-toolkit` exactly:

```text
<!-- BEGIN @szymoniwacz/ai-toolkit -->
<!-- END @szymoniwacz/ai-toolkit -->
```

Reinstall replaces content between sentinels in place and overwrites `.cursor/skills/code-review/` entirely.

## Phase 1: Package Skeleton

### Overview

Create `packages/ai-toolkit/` with `package.json`, README stub, and directory layout matching the M5L4 pack spec. Scope `@szymoniwacz/ai-toolkit`, version `0.1.0`, GitHub Packages registry, published `files` whitelist.

### Changes Required:

#### 1. Package manifest

**File**: `packages/ai-toolkit/package.json`

**Intent**: Define the publishable npm package with GitHub Packages registry, postinstall hook, bin entry for manual install/uninstall, and a strict `files` array so only distributable artifacts ship.

**Contract**: `name: "@szymoniwacz/ai-toolkit"`, `version: "0.1.0"`, `license: "UNLICENSED"`, `publishConfig.registry: "https://npm.pkg.github.com"`, `files: ["skills/", "rules/", "install.js", "uninstall.js", "README.md"]`, `scripts.postinstall: "node install.js"`, `bin` mapping to a small CLI that delegates to install/uninstall (e.g. `"ai-toolkit": "./bin/ai-toolkit.js"`), `engines.node: ">=20"`. No `private: true` (must be publishable). Include `repository` field pointing at `szymoniwacz/safelog-ai` for GitHub Packages linking.

#### 2. Directory layout

**File**: `packages/ai-toolkit/` (structure)

**Intent**: Establish the artifact tree before content and scripts land in later phases.

**Contract**: Directories `skills/code-review/`, `rules/`, `bin/`; placeholder `README.md`; stub `install.js`, `uninstall.js`, `skills/code-review/SKILL.md`, `rules/AGENTS.md` (minimal valid frontmatter / content so `npm pack --dry-run` succeeds early).

#### 3. Package lockfile

**File**: `packages/ai-toolkit/package-lock.json`

**Intent**: Pin dependency resolution for reproducible CI (`npm ci` in publish workflow).

**Contract**: Generated by `npm install` in `packages/ai-toolkit/` with no runtime dependencies (installer uses Node built-ins only).

### Success Criteria:

#### Automated Verification:

- `cd packages/ai-toolkit && npm pack --dry-run` lists only whitelisted files
- `node -e "JSON.parse(require('fs').readFileSync('packages/ai-toolkit/package.json','utf8'))"` succeeds
- `test -f packages/ai-toolkit/package-lock.json`

#### Manual Verification:

- `package.json` `name`, `publishConfig.registry`, and `files` match M5L4 spec
- No secrets, tokens, or `_authToken` lines in any committed file

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Install and Uninstall Scripts

### Overview

Implement manifest-driven, idempotent install/uninstall for Cursor + AGENTS.md, with postinstall and bin entry points.

### Changes Required:

#### 1. Install script

**File**: `packages/ai-toolkit/install.js`

**Intent**: Copy the `code-review` skill into `.cursor/skills/code-review/`, append or update the rules sentinel block in consumer `AGENTS.md`, and write `.cursor/.ai-toolkit-manifest.json` listing installed paths and package version.

**Contract**:
- Resolve consumer root: walk up from `process.cwd()` for nearest `package.json`; fall back to git root or cwd
- Skill target: `.cursor/skills/code-review/` — copy from package `skills/code-review/` (overwrite on reinstall)
- Rules target: consumer repo `AGENTS.md` — append sentinel block at end if missing; if sentinels exist, replace inner content only
- Rules source: package `rules/AGENTS.md`
- Manifest: `.cursor/.ai-toolkit-manifest.json` with `{ package, version, installedAt, files: [...] }`
- Idempotent: second run updates, never duplicates sentinels or skill files
- Postinstall resilience: catch errors, log warning, exit 0 (per spec — do not fail consumer `npm install`)
- Bin re-entry: same logic when invoked via `ai-toolkit install`

#### 2. Uninstall script

**File**: `packages/ai-toolkit/uninstall.js`

**Intent**: Remove only manifest-tracked files and the sentinel block; never delete user-managed AGENTS.md content outside sentinels.

**Contract**:
- Read `.cursor/.ai-toolkit-manifest.json`; remove listed files/directories
- Strip content between `<!-- BEGIN @szymoniwacz/ai-toolkit -->` and `<!-- END @szymoniwacz/ai-toolkit -->` inclusive markers from `AGENTS.md`
- If manifest missing, no-op with message (do not guess paths)
- Invoked from bin as `ai-toolkit uninstall`

#### 3. Bin CLI

**File**: `packages/ai-toolkit/bin/ai-toolkit.js`

**Intent**: Expose explicit `install` and `uninstall` subcommands for reinstall after skill updates without full package reinstall.

**Contract**: Node shebang script; `install` → `require('../install.js')` or equivalent; `uninstall` → uninstall module; usage text on unknown args.

### Success Criteria:

#### Automated Verification:

- `node --check packages/ai-toolkit/install.js`
- `node --check packages/ai-toolkit/uninstall.js`
- `node --check packages/ai-toolkit/bin/ai-toolkit.js`

#### Manual Verification:

- Local temp-dir test: create dir with `package.json`, run `node /path/to/install.js`, verify `.cursor/skills/code-review/SKILL.md`, sentinel block at end of `AGENTS.md`, manifest present
- Re-run install: sentinels not duplicated; skill overwritten
- Run uninstall: skill dir and manifest removed; AGENTS.md pre-existing content preserved

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 3: Skill and Rules Content

### Overview

Author the distributable `code-review` skill (Rails/SafeLog adapted) and the `rules/AGENTS.md` snippet (hard rules + Commands + Style from safelog-ai `AGENTS.md`).

### Changes Required:

#### 1. Code review skill

**File**: `packages/ai-toolkit/skills/code-review/SKILL.md`

**Intent**: Provide a Cursor agent skill that reviews code against team conventions with severity-ordered findings and a final verdict, adapted for Rails repos in the `szymoniwacz/*` ecosystem.

**Contract**:
- YAML frontmatter: `name: code-review`, `description:` per `m5l4-shared-spec-skill.md`
- Trigger phrases: "review code", "check this PR", "review my changes", "code review"
- Categories: Naming, Error handling, Ruby/Rails (replacing TypeScript section), Function/service design, Security, Testing — derived from `m5l4-shared-conventions.md` with Rails idioms (`mise exec --`, RSpec, `app/services/<domain>/`, RuboCop omakase, Brakeman, no raw log persistence, encryption, hypothesis-framed AI reports where relevant)
- Output format: Critical → Warning → Suggestion; each finding with `file:line` when possible; final line `APPROVE`, `REQUEST CHANGES`, or `NEEDS DISCUSSION`
- Do not reference or invoke `packages/code-reviewer/` — this is IDE orchestration, not the CI agent

#### 2. Rules snippet

**File**: `packages/ai-toolkit/rules/AGENTS.md`

**Intent**: Supply the content installed between sentinel markers — portable agent guidance for Rails repos without safelog-ai-specific product paragraphs.

**Contract**: Include adapted content from `AGENTS.md` sections **Hard rules for agents**, **Commands**, and **Style and commits** (lines 5–40). Replace SafeLog-product-specific intro with a one-line generic preamble (e.g. team agent rules for Rails projects). Strip `@context/foundation/prd.md` pointer or replace with "follow project PRD in context/ if present". Keep `mise exec --`, RSpec, RuboCop, service-object layout, commit style, security rules. No repo-specific example counts (e.g. "135 examples") — use generic wording.

#### 3. Package README

**File**: `packages/ai-toolkit/README.md`

**Intent**: Document package purpose, install prerequisites, and uninstall — consumer-facing, not safelog-ai internal.

**Contract**: Sections: What it installs, Requirements (Node ≥20, GitHub Packages auth), Consumer `.npmrc` scope line (`@szymoniwacz:registry=https://npm.pkg.github.com`), local auth (`npm login` / user `.npmrc`), CI auth note (`GH_PKG_TOKEN` for cross-repo), install command, manual reinstall via bin, uninstall, what gets modified (`.cursor/skills/code-review/`, `AGENTS.md` sentinels, manifest).

### Success Criteria:

#### Automated Verification:

- Frontmatter parse: `name` in SKILL.md frontmatter equals directory name `code-review`
- `grep -q 'BEGIN @szymoniwacz/ai-toolkit' packages/ai-toolkit/rules/AGENTS.md` is false (sentinels belong in consumer AGENTS.md only, not in rules source file)
- `npm pack --dry-run` includes `skills/code-review/SKILL.md` and `rules/AGENTS.md`

#### Manual Verification:

- Skill reads coherently for a Rails repo without safelog-ai domain leakage in review categories
- Rules snippet is self-contained and reasonable length (not full safelog-ai README)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 4: Publish CI and Installer Smoke Test

### Overview

Add `.github/workflows/publish-ai-toolkit.yml` with validate (including smoke install) and path-filtered publish jobs.

### Changes Required:

#### 1. Smoke test script

**File**: `packages/ai-toolkit/scripts/smoke-install.mjs` (or `.js`)

**Intent**: Automate end-to-end install/uninstall verification in CI without mutating the publisher repo.

**Contract**:
- Create temp directory with minimal `package.json`
- Run `npm pack` in parent package dir; install tarball into temp consumer via `npm install /path/to/tgz`
- Assert: `.cursor/skills/code-review/SKILL.md` exists; `AGENTS.md` contains sentinels; `.cursor/.ai-toolkit-manifest.json` exists with expected `package` and `version`
- Run bin uninstall (or `node uninstall.js` with cwd in temp dir); assert skill and manifest removed; AGENTS.md lacks sentinels
- Exit non-zero on assertion failure
- Invoked from workflow validate job

#### 2. Publish workflow

**File**: `.github/workflows/publish-ai-toolkit.yml`

**Intent**: Validate package on every PR touching the package; publish to GitHub Packages on push to `main` only when package paths change.

**Contract**:
- Triggers: `push` and `pull_request` to `main`; `paths: ['packages/ai-toolkit/**', '.github/workflows/publish-ai-toolkit.yml']`
- Permissions: `contents: read`, `packages: write`
- `validate` job: `checkout@v6`, `setup-node@v4` with `node-version: 22`, `registry-url: https://npm.pkg.github.com`, `scope: '@szymoniwacz'`, `working-directory: packages/ai-toolkit`, `npm ci`
- Validation steps: assert `package.json` fields; assert skill frontmatter; `npm pack --dry-run`; run smoke script
- `publish` job: `needs: validate`, `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`, same Node setup, `npm publish` with `NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`
- No changes to existing workflows

#### 3. Workflow path filter on publish job

**File**: `.github/workflows/publish-ai-toolkit.yml`

**Intent**: Avoid no-op publishes when unrelated repo files change on main.

**Contract**: Publish job additionally gated with `paths-filter` or equivalent check that `packages/ai-toolkit/**` changed in the push commit range; validate still runs on PRs per paths trigger.

### Success Criteria:

#### Automated Verification:

- `actionlint` or manual YAML review: valid workflow syntax
- Opening a PR with only `packages/ai-toolkit/` changes triggers validate (after merge/push simulation locally: `npm pack --dry-run` + smoke script pass)

#### Manual Verification:

- Workflow file uses `@szymoniwacz` scope and `packages/ai-toolkit` working directory throughout
- Publish job does not run on PR events (`if: github.event_name == 'push'`)

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 5: Consumer Documentation and First Publish

### Overview

Finalize consumer auth documentation, bump version if needed, merge to main, and verify the package on GitHub Packages.

### Changes Required:

#### 1. Consumer npmrc template

**File**: `packages/ai-toolkit/docs/consumer.npmrc.example` (or section in README only)

**Intent**: Give copy-paste scope mapping without committing tokens.

**Contract**: Single line `@szymoniwacz:registry=https://npm.pkg.github.com`; comment block explaining tokens belong in user-level `.npmrc` or CI secrets only.

#### 2. Publish checklist in README

**File**: `packages/ai-toolkit/README.md`

**Intent**: Document maintainer flow for releasing new skill/rules versions.

**Contract**: Steps: edit content → bump `version` in `package.json` → PR (validate runs) → merge to main → confirm package version on GitHub Packages → consumer runs `npm update @szymoniwacz/ai-toolkit` or reinstall via bin.

#### 3. First publish verification

**File**: (no code — operational step)

**Intent**: Confirm end-to-end delivery after merge.

**Contract**: After first successful publish workflow on main, verify `@szymoniwacz/ai-toolkit@0.1.0` visible under repo Packages tab; optional manual install into a second `szymoniwacz/*` repo.

### Success Criteria:

#### Automated Verification:

- Publish workflow completes successfully on push to main with version bump
- Smoke script continued to pass in same workflow run

#### Manual Verification:

- Package appears on GitHub Packages as private, linked to `szymoniwacz/safelog-ai`
- Install into a consumer test repo (local or spare `szymoniwacz/*` repo) succeeds with documented `.npmrc` + auth
- `ai-toolkit uninstall` removes managed files cleanly

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Testing Strategy

### Unit Tests:

- No formal unit test framework in v1 — installer logic verified via smoke script (intentional: zero-deps package)
- Smoke script assertions cover: skill copy, sentinel append/update, manifest write, uninstall cleanup

### Integration Tests:

- CI validate job: `npm pack --dry-run` + smoke install/uninstall in ephemeral temp dir
- Optional local: pack tarball → install in `/tmp/consumer-test-*` → uninstall

### Manual Testing Steps:

1. Create temp Rails-like dir with `package.json` and empty `AGENTS.md` with custom content above where sentinels will append
2. `npm install` tarball or linked package; confirm skill + sentinels at end + manifest
3. Reinstall same version; confirm no duplicate sentinels
4. Bump package version locally; reinstall; confirm skill updated and manifest version updated
5. Uninstall; confirm custom AGENTS.md content preserved
6. After publish: repeat in a real consumer repo with GitHub Packages auth

## Performance Considerations

Negligible — small static files, no network at install time beyond npm fetch. Postinstall copies one skill directory and appends one markdown block; should complete in under one second.

## Migration Notes

No migration — greenfield package. Existing repos without the package are unchanged until they opt in via `npm install`. If a consumer previously hand-copied a `code-review` skill, reinstall overwrites `.cursor/skills/code-review/` (document in README).

## References

- Related research: `context/changes/ai-toolkit-registry/research.md`
- Distribution decision: `context/team/m5l4-distribution-decision.md`
- Pack spec: `.cursor/prompts/m5l4-github-packages-spec-pack.md`
- CI/CD spec: `.cursor/prompts/m5l4-github-packages-spec-cicd.md`
- Skill spec: `.cursor/prompts/m5l4-shared-spec-skill.md`
- Conventions input: `.cursor/prompts/m5l4-shared-conventions.md`
- Rules source: `AGENTS.md:5-40`
- Adjacent CI agent: `packages/code-reviewer/` (not in scope)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands.

### Phase 1: Package Skeleton

#### Automated

- [x] 1.1 `cd packages/ai-toolkit && npm pack --dry-run` lists only whitelisted files — 4c5b97d
- [x] 1.2 `node -e "JSON.parse(require('fs').readFileSync('packages/ai-toolkit/package.json','utf8'))"` succeeds — 4c5b97d
- [x] 1.3 `test -f packages/ai-toolkit/package-lock.json` — 4c5b97d

#### Manual

- [x] 1.4 `package.json` fields match M5L4 spec; no secrets in committed files — 4c5b97d

### Phase 2: Install and Uninstall Scripts

#### Automated

- [x] 2.1 `node --check packages/ai-toolkit/install.js` — 4c5b97d
- [x] 2.2 `node --check packages/ai-toolkit/uninstall.js` — 4c5b97d
- [x] 2.3 `node --check packages/ai-toolkit/bin/ai-toolkit.js` — 4c5b97d

#### Manual

- [x] 2.4 Temp-dir install/reinstall/uninstall behaves per contract — 4c5b97d

### Phase 3: Skill and Rules Content

#### Automated

- [x] 3.1 SKILL.md frontmatter `name` matches directory `code-review` — 4c5b97d
- [x] 3.2 Rules source file has no consumer sentinel markers — 4c5b97d
- [x] 3.3 `npm pack --dry-run` includes skill and rules — 4c5b97d

#### Manual

- [x] 3.4 Skill and rules content reviewed for Rails portability — 4c5b97d

### Phase 4: Publish CI and Installer Smoke Test

#### Automated

- [x] 4.1 Smoke script passes locally from `packages/ai-toolkit` — 4c5b97d
- [x] 4.2 Publish workflow YAML valid; validate job runs smoke + pack dry-run — 4c5b97d

#### Manual

- [x] 4.3 Workflow uses Node 22, checkout@v6, `@szymoniwacz` scope, path filters — 4c5b97d

### Phase 5: Consumer Documentation and First Publish

#### Automated

- [x] 5.1 Publish workflow green on main after version bump — 4c5b97d

#### Manual

- [x] 5.2 Package visible on GitHub Packages; consumer install verified — 33bd57d
