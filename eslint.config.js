
// 🧠 Universal ESLint + Prettier config for Bun projects
import js from "@eslint/js";
import globals from "globals";
import prettier from "eslint-config-prettier";

let tsPlugin;
try {
  tsPlugin = await import("@typescript-eslint/eslint-plugin");
} catch {}

const baseConfig = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.node,
        Bun: "readonly",
      },
    },
    rules: {
      eqeqeq: ["error", "always"],
      "no-var": "error",
      "prefer-const": "warn",
      "no-mixed-spaces-and-tabs": "error",
      "no-trailing-spaces": "warn",
      "object-curly-spacing": ["error", "always"],
      "no-unused-vars": "warn",
      "no-console": "off",
    },
  },
];

if (tsPlugin) {
  baseConfig.push({
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: (await import("@typescript-eslint/parser")).default,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        project: "./tsconfig.json",
      },
    },
    plugins: {
      "@typescript-eslint": tsPlugin.default,
    },
    rules: {
      ...tsPlugin.default.configs.recommended.rules,
      "@typescript-eslint/no-unused-vars": "warn",
    },
  });
}

baseConfig.push(
  {
    ignores: ["node_modules", "dist", "build", ".next", ".turbo"],
  },
  prettier
);

export default baseConfig;
