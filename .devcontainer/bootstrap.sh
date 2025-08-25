#!/usr/bin/env bash
set -euo pipefail

# --- Config (override via env if needed) --------------------------------------
USER_NAME="${USER:-$(id -un)}"
HOME_DIR="${HOME:-/home/$USER_NAME}"
PNPM_STORE_DIR="${PNPM_STORE_DIR:-/vol/pnpm-store}"

BOOTSTRAP_INSTALL_DEPS="${BOOTSTRAP_INSTALL_DEPS:-1}"     # 1=install deps, 0=skip
BOOTSTRAP_APPROVE_BUILDS="${BOOTSTRAP_APPROVE_BUILDS:-1}" # 1=pre-approve esbuild/oxide
# ------------------------------------------------------------------------------

echo "== bootstrap =="
echo " user: $USER_NAME"
echo " home: $HOME_DIR"
echo " pnpm store: $PNPM_STORE_DIR"

# 0) Ensure pnpm store exists & is writable (do NOT touch node_modules path)
mkdir -p "$PNPM_STORE_DIR"
if [ ! -w "$PNPM_STORE_DIR" ]; then
  command -v sudo >/dev/null 2>&1 && sudo chown -R "$USER_NAME:$USER_NAME" "$PNPM_STORE_DIR" || true
fi

# 1) Corepack / pnpm
command -v corepack >/dev/null 2>&1 && corepack enable || true
command -v pnpm >/dev/null 2>&1 || { echo "pnpm not found"; exit 1; }
pnpm config set store-dir "$PNPM_STORE_DIR"
pnpm -v

# 2) Exit early on empty repo (no package.json)
if [ ! -f package.json ]; then
  echo "No package.json found. Run the scaffolding first. Exiting."
  exit 0
fi

# 3) Pre‑approve native builds (optional; place --yes AFTER subcommand)
#if [ "$BOOTSTRAP_APPROVE_BUILDS" = "1" ]; then
#  pnpm approve-builds --yes esbuild @tailwindcss/oxide || true
#fi

# 4) Install project deps (try frozen, fallback if lockfile is stale)
if [ "$BOOTSTRAP_INSTALL_DEPS" = "1" ]; then
  if [ -f pnpm-lock.yaml ]; then
    pnpm fetch || true
    if ! pnpm install --prefer-offline --frozen-lockfile; then
      echo "Lockfile out of date; retrying without --frozen-lockfile…"
      pnpm install --prefer-offline
    fi
  else
    pnpm install --prefer-offline
  fi
fi

# 5) Diagnostics
echo "== diagnostics =="
echo " store dir -> $(pnpm config get store-dir)"
pnpm list --depth 0 || true
echo "✔ bootstrap done"
