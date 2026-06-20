#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const {
  PACKAGE_NAME,
  SENTINEL_BEGIN,
  SENTINEL_END,
  MANIFEST_REL,
  SKILL_REL,
  AGENTS_REL,
  getPackageRoot,
  isDependencyInstall,
  findConsumerRoot,
  copyDirRecursive,
  listFilesRecursive,
} = require("./lib/shared.js");

function readPackageMeta() {
  const packageJsonPath = path.join(getPackageRoot(), "package.json");
  const pkg = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  return { name: pkg.name, version: pkg.version };
}

function buildRulesBlock(rulesContent) {
  return `${SENTINEL_BEGIN}\n${rulesContent.trim()}\n${SENTINEL_END}`;
}

function updateAgentsMd(agentsPath, rulesContent) {
  const block = buildRulesBlock(rulesContent);
  const rulesUpdated = AGENTS_REL;

  if (!fs.existsSync(agentsPath)) {
    fs.mkdirSync(path.dirname(agentsPath), { recursive: true });
    fs.writeFileSync(agentsPath, `${block}\n`, "utf8");
    return rulesUpdated;
  }

  let content = fs.readFileSync(agentsPath, "utf8");
  const beginIdx = content.indexOf(SENTINEL_BEGIN);
  const endIdx = content.indexOf(SENTINEL_END);

  if (beginIdx !== -1 && endIdx !== -1 && endIdx > beginIdx) {
    const before = content.slice(0, beginIdx);
    const after = content.slice(endIdx + SENTINEL_END.length);
    content = `${before}${block}${after}`;
  } else {
    const separator = content.length === 0 ? "" : content.endsWith("\n") ? "\n" : "\n\n";
    content = `${content}${separator}${block}\n`;
  }

  fs.writeFileSync(agentsPath, content, "utf8");
  return rulesUpdated;
}

function runInstall({ explicit = false } = {}) {
  if (!explicit && !isDependencyInstall()) {
    console.warn(
      `${PACKAGE_NAME}: skipping postinstall (not installed as a dependency; use "ai-toolkit install" to install explicitly)`,
    );
    return;
  }

  const consumerRoot = findConsumerRoot();
  const packageRoot = getPackageRoot();
  const { name, version } = readPackageMeta();

  const skillSrc = path.join(packageRoot, "skills", "code-review");
  const skillDest = path.join(consumerRoot, SKILL_REL);
  const rulesSrc = path.join(packageRoot, "rules", "AGENTS.md");
  const agentsPath = path.join(consumerRoot, AGENTS_REL);
  const manifestPath = path.join(consumerRoot, MANIFEST_REL);

  if (!fs.existsSync(skillSrc)) {
    throw new Error(`missing skill source: ${skillSrc}`);
  }
  if (!fs.existsSync(rulesSrc)) {
    throw new Error(`missing rules source: ${rulesSrc}`);
  }

  copyDirRecursive(skillSrc, skillDest);

  const rulesContent = fs.readFileSync(rulesSrc, "utf8");
  updateAgentsMd(agentsPath, rulesContent);

  const installedFiles = listFilesRecursive(skillDest, skillDest).map(
    (file) => `${SKILL_REL}/${file}`,
  );
  installedFiles.push(AGENTS_REL);

  const manifest = {
    package: name,
    version,
    installedAt: new Date().toISOString(),
    files: installedFiles,
  };

  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");

  console.log(`${PACKAGE_NAME}@${version} installed into ${consumerRoot}`);
}

module.exports = { runInstall };

if (require.main === module) {
  try {
    runInstall();
  } catch (err) {
    console.warn(`${PACKAGE_NAME}: install failed: ${err.message}`);
    process.exit(0);
  }
}
