#!/usr/bin/env node
"use strict";

const { runInstall } = require("../install.js");
const { runUninstall } = require("../uninstall.js");
const { PACKAGE_NAME } = require("../lib/shared.js");

const command = process.argv[2];

try {
  switch (command) {
    case "install":
      runInstall({ explicit: true });
      break;
    case "uninstall":
      runUninstall();
      break;
    default:
      console.log(`Usage: ai-toolkit <install|uninstall>`);
      process.exit(command ? 1 : 0);
  }
} catch (err) {
  console.error(`${PACKAGE_NAME}: ${command} failed: ${err.message}`);
  process.exit(1);
}
