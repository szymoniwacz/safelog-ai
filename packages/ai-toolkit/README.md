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

Add to the consumer repo `.npmrc` (committed — no tokens):

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

This package is published from `szymoniwacz/safelog-ai` via GitHub Actions when `packages/ai-toolkit/**` changes on `main` and `package.json` version is bumped.

## License

UNLICENSED — private team package.
