"use strict";

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const PACKAGE_NAME = "@szymoniwacz/ai-toolkit";
const SENTINEL_BEGIN = "<!-- BEGIN @szymoniwacz/ai-toolkit -->";
const SENTINEL_END = "<!-- END @szymoniwacz/ai-toolkit -->";
const MANIFEST_REL = ".cursor/.ai-toolkit-manifest.json";
const SKILL_REL = ".cursor/skills/code-review";
const AGENTS_REL = "AGENTS.md";

function getPackageRoot() {
  return path.resolve(__dirname, "..");
}

function isDependencyInstall() {
  const normalized = __dirname.split(path.sep).join(path.sep);
  return normalized.includes(`${path.sep}node_modules${path.sep}`);
}

function readPackageName(packageJsonPath) {
  const pkg = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  return pkg.name;
}

function findConsumerRoot(startDir = process.cwd()) {
  let dir = path.resolve(startDir);
  const fsRoot = path.parse(dir).root;

  while (dir !== fsRoot) {
    const packageJsonPath = path.join(dir, "package.json");
    if (fs.existsSync(packageJsonPath)) {
      try {
        if (readPackageName(packageJsonPath) !== PACKAGE_NAME) {
          return dir;
        }
      } catch {
        return dir;
      }
    }
    dir = path.dirname(dir);
  }

  try {
    const gitRoot = execSync("git rev-parse --show-toplevel", {
      cwd: startDir,
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
    const packageJsonPath = path.join(gitRoot, "package.json");
    if (gitRoot && fs.existsSync(packageJsonPath)) {
      if (readPackageName(packageJsonPath) !== PACKAGE_NAME) {
        return gitRoot;
      }
    }
  } catch {
    // not a git repo
  }

  return path.resolve(startDir);
}

function copyDirRecursive(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function rmRecursive(target) {
  if (!fs.existsSync(target)) {
    return;
  }
  fs.rmSync(target, { recursive: true, force: true });
}

function listFilesRecursive(dir, baseDir = dir) {
  const files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFilesRecursive(fullPath, baseDir));
    } else {
      files.push(path.relative(baseDir, fullPath).split(path.sep).join("/"));
    }
  }
  return files;
}

module.exports = {
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
  rmRecursive,
  listFilesRecursive,
};
