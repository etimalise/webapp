/* eslint flat config (ESLint v9) */
import js from "@eslint/js";
import prettier from "eslint-config-prettier";

const cfg = [
  { ignores: ["dist/**","node_modules/**","coverage/**"] },
  {
    files: ["**/*.{js,ts,vue}"],
    languageOptions: { ecmaVersion: "latest", sourceType: "module" },
    rules: { ...js.configs.recommended.rules }
  },
  // keep Prettier last to disable formatting-related ESLint rules
  prettier
];

// Add Vue rules if plugin exists
try {
  const vue = await import("eslint-plugin-vue");
  cfg.push({
    files: ["**/*.vue","**/*.{js,ts}"],
    plugins: { vue: vue.default || vue },
    rules: { ...(vue.configs["vue3-recommended"]?.rules || {}) }
  });
} catch {}

// Add TS rules if parser/plugin exist
try {
  const ts = await import("@typescript-eslint/eslint-plugin");
  const parser = await import("@typescript-eslint/parser");
  cfg.push({
    files: ["**/*.ts","**/*.vue"],
    languageOptions: { parser: parser.default || parser },
    plugins: { "@typescript-eslint": ts.default || ts },
    rules: { ...((ts.configs.recommended?.rules) || {}) }
  });
} catch {}

export default cfg;
