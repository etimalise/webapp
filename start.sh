#!/usr/bin/env bash
set -euo pipefail

NAME="${NAME:-webapp-dev}"
WF="."

# Create or start container
if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "== creating container =="
  devcontainer up --workspace-folder "$WF" --remove-existing-container
elif ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "== starting existing container =="
  docker start "$NAME" >/dev/null
else
  echo "container '$NAME' already running"
fi
