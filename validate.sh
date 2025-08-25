#!/usr/bin/env bash
set -euo pipefail

NAME="${NAME:-webapp-dev}"
WF="."

echo "== validate =="
# ensure container is up
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "container '$NAME' is not running. start it with ./start.sh or ./recreate.sh"; exit 1
fi

# basic tool checks
devcontainer exec --workspace-folder "$WF" bash -lc 'node -v && pnpm -v && echo store=$(pnpm config get store-dir)'

# deps present?
devcontainer exec --workspace-folder "$WF" bash -lc '
  pnpm list --depth 0 | sed -n "1,50p"
  for pkg in vue vite tailwindcss @vitejs/plugin-vue eslint prettier typescript; do
    pnpm ls --depth 0 "$pkg" >/dev/null || { echo "missing: $pkg" >&2; exit 2; }
  done
  echo "✔ dependencies found"
'
echo "✔ validation passed"
