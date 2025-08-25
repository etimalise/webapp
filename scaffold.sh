#!/usr/bin/env bash
set -euo pipefail

# One‑shot Layer‑0 scaffold runner
# Usage:
#   ./scaffold.sh            # create missing files only
#   FORCE_SCAFFOLD=1 ./scaffold.sh   # overwrite existing scaffolded files

if ! command -v node >/dev/null 2>&1; then
  echo "node is required (v18+)."; exit 1
fi

node .devcontainer/scaffold.mjs
echo "✔ scaffolding complete"
