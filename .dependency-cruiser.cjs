/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: "no-circular",
      severity: "error",
      comment:
        "Circular dependencies make modules harder to refactor and test in isolation.",
      from: {},
      to: { circular: true },
    },
    {
      name: "e2e-no-rails-imports",
      severity: "error",
      comment: "E2E TypeScript must not import Rails runtime (app/, config/, spec/).",
      from: { path: "^e2e/" },
      to: { path: "^(app|config|spec)/" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: "tsconfig.json" },
    enhancedResolveOptions: {
      exportsFields: ["exports"],
      conditionNames: ["import", "require", "node", "default"],
    },
  },
};
