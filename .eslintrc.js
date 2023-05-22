module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true,
  },
  extends: "standard-with-typescript",
  // plugins: ["@typescript-eslint", "jest"],
  overrides: [],
  parserOptions: {
    project: ["./tsconfig.json"], // Specify it only for TypeScript files
    ecmaVersion: "latest",
    sourceType: "module",
  },
  ignorePatterns: [
    "helm-k8",
    "helm-k8/**/*",
    "node_modules",
    "build",
    "coverage",
  ],
  rules: {},
};
