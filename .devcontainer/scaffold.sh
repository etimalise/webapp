#!/usr/bin/env bash
set -euo pipefail

# ---- knobs ---------------------------------------------------------------
PNPM_VER="10.15.0"
TEMPLATE="${VITE_TEMPLATE:-vue}"        # vue | vue-ts | react | react-ts | ...
WORKDIR="/workspace"
SCAFF="$HOME/.cache/webapp_scaffold"    # temp lives inside the container
PNPM_STORE_DEFAULT="/home/node/.pnpm-store"
# -------------------------------------------------------------------------

echo ">> corepack / pnpm"
corepack enable || true
corepack prepare "pnpm@${PNPM_VER}" --activate
pnpm config set store-dir "${PNPM_STORE_DIR:-$PNPM_STORE_DEFAULT}"

echo ">> scaffold (non-interactive, idempotent)"
if [ ! -f "$WORKDIR/package.json" ]; then
  rm -rf "$SCAFF" && mkdir -p "$SCAFF"
  ( cd "$SCAFF" && CI=1 pnpm dlx create-vite@latest app --template "$TEMPLATE" )
  cp -an "$SCAFF/app"/. "$WORKDIR"/
  rm -rf "$SCAFF"
fi
cd "$WORKDIR"

# pin package manager for reproducibility
if command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"; jq '.packageManager="pnpm@'"$PNPM_VER"'"' package.json >"$tmp" && mv "$tmp" package.json
else
  node -e "const fs=require('fs'),p=require('./package.json');p.packageManager='pnpm@${PNPM_VER}';fs.writeFileSync('package.json',JSON.stringify(p,null,2));"
fi

echo ">> install deps"
pnpm install

echo ">> tailwind / postcss (v4)"
pnpm add -D tailwindcss @tailwindcss/postcss postcss
# Always write v4 PostCSS config
cat > postcss.config.js <<'EOF'
export default { plugins: { "@tailwindcss/postcss": {} } };
EOF
# v4 CSS entry (overwrite any old v3 content)
mkdir -p src/assets
printf '@import "tailwindcss";\n' > src/assets/tailwind.css

# Optional: tailwind.config.js only if missing (remove if you don't need it)
[ -f tailwind.config.js ] || cat > tailwind.config.js <<'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html","./src/**/*.{vue,js,ts}"],
  theme: { extend: {} },
  plugins: []
};
EOF

# tokens and imports
[ -f src/assets/tokens.css ] || printf ':root{}\n' > src/assets/tokens.css
main="src/main.ts"; [ -f "$main" ] || main="src/main.js"
if [ -f "$main" ]; then
  grep -q "assets/tokens.css"   "$main" || sed -i "1i import './assets/tokens.css';" "$main"
  grep -q "assets/tailwind.css" "$main" || sed -i "1i import './assets/tailwind.css';" "$main"
fi

# one-time README
[ -f README.md ] || cat > README.md <<'MD'
# webapp (Layer 0)
- Dev server: `pnpm dev --host` (http://localhost:5173)
- Build: `pnpm build` → `dist/`
- Styles: Tailwind v4 via @tailwindcss/postcss; CSS entry at `src/assets/tailwind.css`
MD

echo ">> sanity (non-fatal)"
set +e
node -v
pnpm -v
pnpm exec vite --version || true
set -e

echo ">> validation"
bash .devcontainer/validate.sh |& tee -a /workspace/validate.log || true

echo ">> done"
