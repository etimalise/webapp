#!/usr/bin/env bash
set -euo pipefail

NAME="${NAME:-webapp-dev}"
WF="."

# ensure container exists & is up (idempotent)
if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  devcontainer up --workspace-folder "$WF" --remove-existing-container
elif ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
fi

# run dev server in the container (foreground so you see logs)
echo "== starting Vite (Ctrl+C to stop the dev server; container stays up) =="
devcontainer exec --workspace-folder "$WF" pnpm dev
