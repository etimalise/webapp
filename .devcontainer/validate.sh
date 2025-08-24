#!/usr/bin/env bash
set -euo pipefail
check () { local l="$1"; shift; local c="$*";
  echo "${l}: { cmd: \"$c\" }"; if out=$(eval "$c" 2>&1); then
    echo "$out" | sed 's/^/  out: /'; echo "  exit: 0"
  else rc=$?; echo "$out" | sed 's/^/  out: /'; echo "  exit: $rc"; fi; echo; }

check "node"                  "node -v"
check "pnpm"                  "pnpm -v"
check "pnpm store"            "pnpm config get store-dir"
check "vite"                  "pnpm exec vite --version"

check "tailwind (pkg ver)"    "node -p \"require('tailwindcss/package.json').version\""
check "postcss plugin (list)" "pnpm list @tailwindcss/postcss --depth 0 || true"
check "postcss config uses @tailwindcss/postcss" "grep -q '@tailwindcss/postcss' postcss.config.js && echo OK"
check "tailwind.css uses @import" "grep -q '@import \"tailwindcss\"' src/assets/tailwind.css && echo OK"

check "main (tokens import)"  "grep -n 'assets/tokens.css' src/main.* || true"
check "main (tailwind import)" "grep -n 'assets/tailwind.css' src/main.* || true"

check "build"                 "pnpm -s build && echo build OK"
check "dist exists"           "test -d dist && (ls -1 dist | sed 's/^/  - /' || true; echo OK)"
