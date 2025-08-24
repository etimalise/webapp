# enable PAT for packages
docker logout ghcr.io 2>/dev/null || true
export GHCR_USER="user_name"
export GHCR_PAT="your_pat_here"
echo "$GHCR_PAT" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
cat ~/.docker/config.json | grep -A2 '"ghcr.io"'
