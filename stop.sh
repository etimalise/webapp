#!/usr/bin/env bash
set -euo pipefail

NAME="${NAME:-webapp-dev}"

if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "== stopping container =="
  docker stop "$NAME" >/dev/null && echo "stopped: $NAME"
else
  echo "container '$NAME' not running"
fi
