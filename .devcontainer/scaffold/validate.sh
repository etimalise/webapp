#!/usr/bin/env bash
set -euo pipefail

check () {
  local l="$1"; shift; local c="$*"
  echo "${l}: { cmd: \"$c\" }"
  if out=$(eval "$c" 2>&1); then
    echo "$out" | sed 's/^/  out: /'; echo "  exit: 0"
  else
    rc=$?; echo "$out" | sed 's/^/  out: /'; echo "  exit: $rc"
  fi
  echo
}

# toolchain
check "node"                       "node -v"
check "pnpm"                       "pnpm -v"
check "pnpm store"                 "pnpm config get store-dir"
check "vite"                       "pnpm exec vite --version"

# packages / wiring
check "tailwind (pkg ver)"         "node -p \"require('tailwindcss/package.json').version\""
check "postcss plugin (list)"      "pnpm list @tailwindcss/postcss --depth 0 || true"
check "postcss config uses @tailwindcss/postcss" "grep -q '@tailwindcss/postcss' postcss.config.js && echo OK"
check "tailwind.css uses @import"  "grep -q '@import \"tailwindcss\"' src/assets/tailwind.css && echo OK"

# source imports
check "main (tokens import)"       "grep -n 'assets/tokens.css' src/main.* || true"
check "main (tailwind import)"     "grep -n 'assets/tailwind.css' src/main.* || true"

# existence of assets
check "tokens.css exists"          "test -f src/assets/tokens.css && echo OK"
check "tailwind.css exists"        "test -f src/assets/tailwind.css && echo OK"

# package manager pin + lockfile
check "packageManager pinned"      "node -p \"require('./package.json').packageManager || 'n/a'\""
check "lockfile exists"            "test -f pnpm-lock.yaml && echo yes || echo no"

# lint/format (optional; non-fatal if not configured)
check "prettier (pkg ver; optional)" "node -p \"require('prettier/package.json').version\" || true"
check "eslint (pkg ver; optional)"   "node -p \"require('eslint/package.json').version\" || true"
check "format:check (optional)"      "pnpm -s run format:check || true"
check "lint (optional)"              "pnpm -s run lint || true"

# build gates
check "build"                      "pnpm -s build && echo build OK"
check "dist exists"                "test -d dist && (ls -1 dist | sed 's/^/  - /' || true; echo OK)"

# diagnostics (non-fatal)
check "node_modules size"          "du -sh node_modules || true"
check "dist size"                  "du -sh dist || true"

# optional TS typecheck if tsconfig & tsc present (non-fatal)
check "ts typecheck (optional)"    "test -f tsconfig.json && pnpm -s exec tsc -v >/dev/null 2>&1 && pnpm -s exec tsc --noEmit || true"
