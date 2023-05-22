/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  clearMocks: true,
  collectCoverage: true,
  coverageDirectory: "coverage",
  coveragePathIgnorePatterns: ["/node_modules/", "/helm-k8/"],
  preset: "ts-jest",
  testEnvironment: "node",
  moduleFileExtensions: ["js", "json", "ts", "node"],
  testMatch: ["**/__tests__/**/*.[jt]s?(x)", "**/?(*.)+(spec|test).[tj]s?(x)"],
  transform: {
    "^.+\\.(t|j)s$": "ts-jest",
  },
};
