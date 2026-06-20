#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");
const {
  PACKAGE_NAME,
  SENTINEL_BEGIN,
  SENTINEL_END,
  MANIFEST_REL,
  SKILL_REL,
  AGENTS_REL,
  getPackageRoot,
} = require("../lib/shared.js");

function assert(condition, message) {
  if (!condition) {
    console.error(`smoke-install: ${message}`);
    process.exit(1);
  }
}

function run(command, options = {}) {
  execSync(command, {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "inherit"],
    ...options,
  });
}

const packageRoot = getPackageRoot();
const packageMeta = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf8"));
const consumerDir = fs.mkdtempSync(path.join(os.tmpdir(), "ai-toolkit-smoke-"));
let tarballPath = null;

console.log(`smoke-install: consumer dir ${consumerDir}`);

try {
  fs.writeFileSync(
    path.join(consumerDir, "package.json"),
    `${JSON.stringify({ name: "ai-toolkit-smoke-consumer", version: "1.0.0", private: true }, null, 2)}\n`,
    "utf8",
  );
  fs.writeFileSync(
    path.join(consumerDir, AGENTS_REL),
    "# Consumer rules\n\nKeep this line.\n",
    "utf8",
  );

  const packJson = execSync("npm pack --json", {
    cwd: packageRoot,
    encoding: "utf8",
  }).trim();
  const packResult = JSON.parse(packJson);
  assert(Array.isArray(packResult) && packResult.length > 0, "npm pack --json returned no tarball metadata");

  tarballPath = path.join(packageRoot, packResult[0].filename);
  assert(fs.existsSync(tarballPath), `tarball missing: ${tarballPath}`);

  run(`npm install "${tarballPath}"`, { cwd: consumerDir });

  const skillPath = path.join(consumerDir, SKILL_REL, "SKILL.md");
  assert(fs.existsSync(skillPath), "skill file not installed");

  const agentsPath = path.join(consumerDir, AGENTS_REL);
  assert(fs.existsSync(agentsPath), "AGENTS.md not created");
  const agentsContent = fs.readFileSync(agentsPath, "utf8");
  assert(agentsContent.includes(SENTINEL_BEGIN), "AGENTS.md missing begin sentinel");
  assert(agentsContent.includes(SENTINEL_END), "AGENTS.md missing end sentinel");

  const manifestPath = path.join(consumerDir, MANIFEST_REL);
  assert(fs.existsSync(manifestPath), "manifest not written");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  assert(manifest.package === PACKAGE_NAME, "manifest package name mismatch");
  assert(manifest.version === packageMeta.version, "manifest version mismatch");

  run("npx ai-toolkit uninstall", { cwd: consumerDir });

  assert(!fs.existsSync(skillPath), "skill file not removed");
  assert(!fs.existsSync(manifestPath), "manifest not removed");
  assert(fs.existsSync(agentsPath), "AGENTS.md removed but pre-existing content should remain");
  const agentsAfter = fs.readFileSync(agentsPath, "utf8");
  assert(agentsAfter.includes("Keep this line."), "AGENTS.md pre-existing content not preserved");
  assert(!agentsAfter.includes(SENTINEL_BEGIN), "AGENTS.md still contains sentinels after uninstall");
  assert(!agentsAfter.includes(SENTINEL_END), "AGENTS.md still contains end sentinel after uninstall");

  console.log("smoke-install: passed");
} finally {
  if (tarballPath && fs.existsSync(tarballPath)) {
    fs.unlinkSync(tarballPath);
  }
  fs.rmSync(consumerDir, { recursive: true, force: true });
}
