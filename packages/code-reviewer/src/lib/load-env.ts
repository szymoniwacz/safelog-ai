import { existsSync } from "node:fs";
import { config } from "dotenv";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const repoRoot = resolve(packageRoot, "../..");

const repoEnvPath = resolve(repoRoot, ".env");
const packageEnvPath = resolve(packageRoot, ".env");

// App defaults first; package .env overrides only keys it defines.
if (existsSync(repoEnvPath)) {
  config({ path: repoEnvPath });
}

if (existsSync(packageEnvPath)) {
  config({ path: packageEnvPath, override: true });
}
