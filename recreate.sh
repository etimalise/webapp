#!/usr/bin/env bash
set -euo pipefail

# Recreate devcontainer for current repo
echo "== Recreating devcontainer for workspace $(pwd) =="
devcontainer up --workspace-folder . --remove-existing-container
