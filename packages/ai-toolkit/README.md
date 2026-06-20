# @szymoniwacz/ai-toolkit

Team AI artifacts (Cursor skills and agent rules) distributed through GitHub Packages.

Installs a `code-review` Cursor skill and appends team agent rules to your project's `AGENTS.md`.

## What it installs

| Artifact | Location |
| -------- | -------- |
| Code review skill | `.cursor/skills/code-review/SKILL.md` |
| Agent rules snippet | `AGENTS.md` (between sentinel markers) |
| Install manifest | `.cursor/.ai-toolkit-manifest.json` |

Sentinel markers:

```text
<!-- BEGIN @szymoniwacz/ai-toolkit -->
<!-- END @szymoniwacz/ai-toolkit -->
```

Reinstalling updates the skill directory and replaces content between sentinels without duplicating blocks.

## Requirements

- Node.js ≥ 20
- GitHub Packages read access for `@szymoniwacz` scope
- Consumer repo: Rails app at repository root with a `package.json`

## Consumer setup

### 1. Scope registry mapping

Add to the consumer repo `.npmrc` (committed — no tokens). See [`docs/consumer.npmrc.example`](docs/consumer.npmrc.example):

```text
@szymoniwacz:registry=https://npm.pkg.github.com
```

### 2. Authentication

**Local development:** authenticate with GitHub Packages via user-level `~/.npmrc` or `npm login --registry=https://npm.pkg.github.com`. Never commit `_authToken` to the repository.

**CI (cross-repo or third-party):** set `GH_PKG_TOKEN` with `read:packages` and append auth in the install step:

```bash
[ -n "$GH_PKG_TOKEN" ] && echo '//npm.pkg.github.com/:_authToken=${GH_PKG_TOKEN}' >> .npmrc || true
```

Same-org GitHub Actions may use repository permissions instead; do not assume every platform can read `GITHUB_TOKEN` for packages.

### 3. Install

```bash
npm install @szymoniwacz/ai-toolkit
```

`postinstall` runs automatically when the package is installed as a dependency.

### 4. Manual reinstall

After upgrading the package version, reinstall managed files without a full dependency refresh:

```bash
npx @szymoniwacz/ai-toolkit install
# or, if the bin is on PATH from a local install:
ai-toolkit install
```

### 5. Uninstall

```bash
npx @szymoniwacz/ai-toolkit uninstall
```

Removes manifest-tracked files, the skill directory, and the sentinel block from `AGENTS.md`. Content outside the sentinels is preserved.

## What gets modified

- **Created/overwritten:** `.cursor/skills/code-review/`
- **Appended or updated:** sentinel block at the end of `AGENTS.md`
- **Written:** `.cursor/.ai-toolkit-manifest.json`

If you previously hand-edited the managed skill, reinstall overwrites it — keep custom skills in a different directory name.

## Publishing (maintainers)

This package is published from [`szymoniwacz/safelog-ai`](https://github.com/szymoniwacz/safelog-ai) via [`.github/workflows/publish-ai-toolkit.yml`](../../.github/workflows/publish-ai-toolkit.yml).

### Release checklist

1. Edit skill or rules content under `packages/ai-toolkit/`.
2. Bump `version` in `packages/ai-toolkit/package.json` (manual — no auto-bump in v1).
3. Open a PR — the **Publish AI Toolkit** workflow runs `validate` (package checks, `npm pack --dry-run`, smoke install/uninstall).
4. Merge to `main` — `publish` runs only when `packages/ai-toolkit/**` changed on the push.
5. Confirm `@szymoniwacz/ai-toolkit@<version>` appears under the repo **Packages** tab (private, linked to this repository).
6. In consumer repos: `npm update @szymoniwacz/ai-toolkit` or `npx @szymoniwacz/ai-toolkit install` after upgrading.

### First publish verification

After the first successful publish workflow on `main`:

- [ ] Package `@szymoniwacz/ai-toolkit@0.1.0` visible on GitHub Packages
- [ ] Consumer install succeeds with `.npmrc` scope mapping + GitHub Packages auth
- [ ] `npx @szymoniwacz/ai-toolkit uninstall` removes managed files cleanly

Local pre-merge checks:

```bash
cd packages/ai-toolkit
npm run smoke
npm pack --dry-run
```

## License

UNLICENSED — private team package.
