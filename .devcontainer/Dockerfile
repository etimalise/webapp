#.devcontainer/Dockerfile (remove this line)

FROM node:lts

# Minimal OS deps (git optional), keep image lean
RUN apt-get update && apt-get install -y --no-install-recommends \
    git jq ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Prepare bind/volumes and grant ownership to 'node' (uid 1000)
RUN mkdir -p /workspace/node_modules /home/node/.pnpm-store \
  && chown -R node:node /workspace /home/node \
  && corepack enable
