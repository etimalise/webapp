#!/usr/bin/env bash
set -euo pipefail

# ==== knobs ===================================================================
PNPM_VER="${PNPM_VER:-10.15.0}"
TEMPLATE="${VITE_TEMPLATE:-vue}"            # vue | vue-ts | react | react-ts | ...
CREATE_VITE_VER="${CREATE_VITE_VER:-5.4.1}" # pin create-vite for reproducibility
WORKDIR="${WORKDIR:-/workspace}"
PNPM_STORE_DEFAULT="/home/node/.pnpm-store"
DISABLE_SCAFFOLD="${DISABLE_SCAFFOLD:-0}"   # 1 => skip all scaffolding
PNPM_PRUNE="${PNPM_PRUNE:-1}"               # 1 => pnpm store prune
# ==============================================================================

echo ">> corepack / pnpm"
corepack enable || true
corepack prepare "pnpm@${PNPM_VER}" --activate
pnpm config set store-dir "${PNPM_STORE_DIR:-$PNPM_STORE_DEFAULT}"

[ "$DISABLE_SCAFFOLD" = "1" ] && { echo ">> scaffold disabled"; exit 0; }

echo ">> scaffold (create-only if no package.json)"
if [ ! -f "$WORKDIR/package.json" ]; then
  SCAFF="$(mktemp -d)"
  ( cd "$SCAFF" && CI=1 pnpm dlx create-vite@"$CREATE_VITE_VER" app --template "$TEMPLATE" )
  cp -an "$SCAFF/app"/. "$WORKDIR"/   # keep existing files intact if any
  rm -rf "$SCAFF"
fi
cd "$WORKDIR"

echo ">> pin package manager"
if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"; jq '.packageManager="pnpm@'"$PNPM_VER"'"' package.json >"$tmp" && mv "$tmp" package.json
else
  node -e "const fs=require('fs'),p=require('./package.json');p.packageManager='pnpm@${PNPM_VER}';fs.writeFileSync('package.json',JSON.stringify(p,null,2));"
fi

echo ">> install deps"
if [ -f pnpm-lock.yaml ]; then
  pnpm install --frozen-lockfile
else
  pnpm install
fi

echo ">> tailwind / postcss (v4) — add only if missing"
node -e "const p=require('./package.json');const d={...(p.dependencies||{}),...(p.devDependencies||{})};process.exit(d.tailwindcss&&d['@tailwindcss/postcss']&&d.postcss?0:1)" \
|| pnpm add -D tailwindcss @tailwindcss/postcss postcss

# postcss.config.js (create-only)
if [ ! -f postcss.config.js ]; then
  cat > postcss.config.js <<'EOF'
export default { plugins: { "@tailwindcss/postcss": {} } };
EOF
fi

# src/assets/tailwind.css (create-only)
mkdir -p src/assets
[ -f src/assets/tailwind.css ] || printf '@import "tailwindcss";\n' > src/assets/tailwind.css

# tailwind.config.js (create-only; optional)
[ -f tailwind.config.js ] || cat > tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html","./src/**/*.{vue,js,ts,tsx}"],
  theme: { extend: {} },
  plugins: []
};
EOF

# tokens + safe imports (idempotent)
[ -f src/assets/tokens.css ] || printf ':root{}\n' > src/assets/tokens.css
main="src/main.ts"; [ -f "$main" ] || main="src/main.js"
if [ -f "$main" ]; then
  grep -q "assets/tokens.css"   "$main" || sed -i "1i import './assets/tokens.css';" "$main"
  grep -q "assets/tailwind.css" "$main" || sed -i "1i import './assets/tailwind.css';" "$main"
fi

echo ">> prettier / eslint (ESLint v9 flat) — create-only and framework-aware"
# Detect framework/TS
HAS_TS=0; [ -f tsconfig.json ] && HAS_TS=1
HAS_VUE=0; node -e "const p=require('./package.json');const d={...(p.dependencies||{}),...(p.devDependencies||{})};process.exit(d.vue?0:1)" && HAS_VUE=1 || true

# Add devDeps only if missing
need_dep () { node -e "const p=require('./package.json');const d={...(p.dependencies||{}),...(p.devDependencies||{})};process.exit(d['$1']?0:1)"; }
DEPS=()
need_dep prettier || DEPS+=(prettier)
need_dep eslint   || DEPS+=(eslint)
need_dep "@eslint/js" || DEPS+=(@eslint/js)
need_dep "eslint-config-prettier" || DEPS+=(eslint-config-prettier)
[ $HAS_VUE -eq 1 ] && ( need_dep "eslint-plugin-vue" || DEPS+=(eslint-plugin-vue) )
if [ $HAS_TS -eq 1 ]; then
  need_dep "@typescript-eslint/parser" || DEPS+=(@typescript-eslint/parser)
  need_dep "@typescript-eslint/eslint-plugin" || DEPS+=(@typescript-eslint/eslint-plugin)
  need_dep typescript || DEPS+=(typescript)
fi
[ ${#DEPS[@]} -gt 0 ] && pnpm add -D "${DEPS[@]}"

# .prettierrc (create-only)
[ -f .prettierrc.json ] || cat > .prettierrc.json <<'EOF'
{ "semi": true, "singleQuote": false, "trailingComma": "all", "printWidth": 100 }
EOF

# .prettierignore (create-only; avoid formatting non-source config)
if [ ! -f .prettierignore ]; then
  cat > .prettierignore <<'EOF'
node_modules
dist
coverage
.vite
.idea
.vscode
.devcontainer/devcontainer.json
EOF
fi

# eslint.config.js (flat config, create-only)
if [ ! -f eslint.config.js ]; then
  cat > eslint.config.js <<'EOF'
/* ESLint v9 flat config */
import js from "@eslint/js";
import prettier from "eslint-config-prettier";

const config = [
  { ignores: ["dist/**","node_modules/**","coverage/**"] },
  {
    files: ["**/*.{js,ts,vue}"],
    languageOptions: { ecmaVersion: "latest", sourceType: "module" },
    rules: { ...js.configs.recommended.rules }
  },
  // keep Prettier last to disable conflicting rules
  prettier
];

try {
  const vue = await import("eslint-plugin-vue");
  config.push({
    files: ["**/*.vue","**/*.{js,ts}"],
    plugins: { vue: vue.default || vue },
    rules: { ...(vue.configs["vue3-recommended"]?.rules || {}) }
  });
} catch {}

try {
  const ts = await import("@typescript-eslint/eslint-plugin");
  const parser = await import("@typescript-eslint/parser");
  config.push({
    files: ["**/*.ts","**/*.vue"],
    languageOptions: { parser: parser.default || parser },
    plugins: { "@typescript-eslint": ts.default || ts },
    rules: { ...((ts.configs.recommended?.rules) || {}) }
  });
} catch {}

export default config;
EOF
fi

# package.json scripts (merge-only; never overwrite if present)
node - <<'EOF'
const fs = require('fs');
const p = JSON.parse(fs.readFileSync('package.json','utf8'));
p.scripts = p.scripts || {};
p.scripts.dev = p.scripts.dev || "vite --host";
p.scripts.build = p.scripts.build || "vite build";
p.scripts.preview = p.scripts.preview || "vite preview --host";
p.scripts.lint = p.scripts.lint || "eslint .";
p.scripts.format = p.scripts.format || "prettier -w .";
p.scripts["format:check"] = p.scripts["format:check"] || "prettier -c .";
fs.writeFileSync('package.json', JSON.stringify(p, null, 2));
EOF

# README (create-only)
[ -f README.md ] || cat > README.md <<'MD'
# webapp (Layer 0)
- Dev server: `pnpm dev --host` (http://localhost:5173)
- Build: `pnpm build` → `dist/`
- Styles: Tailwind v4 via @tailwindcss/postcss; CSS entry at `src/assets/tailwind.css`
- Lint: `pnpm lint`
- Format: `pnpm format` / `pnpm format:check`
MD

echo ">> optimizing space"
[ "$PNPM_PRUNE" = "1" ] && pnpm store prune || true

echo ">> sanity (non-fatal)"
set +e
node -v
pnpm -v
pnpm exec vite --version || true
set -e

echo ">> validation"
bash .devcontainer/validate.sh |& tee -a /workspace/validate.log || true

echo ">> done"
