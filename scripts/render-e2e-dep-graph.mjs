import fs from "fs";
import { execSync } from "child_process";
import { instance } from "@viz-js/viz";

const dotPath = "context/map/diagrams/e2e-helper-hub.dot";
const svgPath = "context/map/diagrams/e2e-helper-hub.svg";

const depcruiseCmd =
  "npx depcruise e2e/helpers.ts e2e/*.spec.ts " +
  "--config .dependency-cruiser.cjs --output-type dot";

execSync(`${depcruiseCmd} > ${dotPath}`, { stdio: "inherit", shell: true });

const viz = await instance();
const dot = fs.readFileSync(dotPath, "utf8");
const { status, output, errors } = viz.render(dot, { format: "svg", engine: "dot" });

if (status !== "success") {
  console.error(errors);
  process.exit(1);
}

fs.writeFileSync(svgPath, output);
console.log(`Wrote ${svgPath} (${output.length} bytes)`);
