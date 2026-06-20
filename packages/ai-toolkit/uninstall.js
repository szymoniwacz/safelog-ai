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
  findConsumerRoot,
  rmRecursive,
} = require("./lib/shared.js");

function stripSentinelBlock(content) {
  const beginIdx = content.indexOf(SENTINEL_BEGIN);
  const endIdx = content.indexOf(SENTINEL_END);

  if (beginIdx === -1 || endIdx === -1 || endIdx < beginIdx) {
    return content;
  }

  const before = content.slice(0, beginIdx);
  const after = content.slice(endIdx + SENTINEL_END.length);
  return `${before}${after}`.replace(/\n{3,}/g, "\n\n").trimEnd();
}

function runUninstall() {
  const consumerRoot = findConsumerRoot();
  const manifestPath = path.join(consumerRoot, MANIFEST_REL);

  if (!fs.existsSync(manifestPath)) {
    console.warn(`${PACKAGE_NAME}: no manifest at ${MANIFEST_REL}; nothing to uninstall`);
    return;
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const agentsPath = path.join(consumerRoot, AGENTS_REL);

  if (fs.existsSync(agentsPath)) {
    const content = fs.readFileSync(agentsPath, "utf8");
    const stripped = stripSentinelBlock(content);
    if (stripped.length === 0) {
      fs.unlinkSync(agentsPath);
    } else {
      fs.writeFileSync(agentsPath, `${stripped}\n`, "utf8");
    }
  }

  rmRecursive(path.join(consumerRoot, SKILL_REL));

  for (const relPath of manifest.files || []) {
    if (relPath === AGENTS_REL || relPath.startsWith(`${SKILL_REL}/`) || relPath === SKILL_REL) {
      continue;
    }
    rmRecursive(path.join(consumerRoot, relPath));
  }

  rmRecursive(manifestPath);

  console.log(`${PACKAGE_NAME} uninstalled from ${consumerRoot}`);
}

module.exports = { runUninstall };

if (require.main === module) {
  try {
    runUninstall();
  } catch (err) {
    console.error(`${PACKAGE_NAME}: uninstall failed: ${err.message}`);
    process.exit(1);
  }
}
