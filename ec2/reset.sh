#!/usr/bin/env bash
# Reset between candidates: discard all changes, clear history, restart.
# Runs on the EC2 HOST (not inside the container) because the container
# masks /workspace/.git and /workspace/ec2 to keep them hidden from the
# candidate. Triggered by `aws-setup.sh reset`.
set -euo pipefail

CONTAINER=code-server
WORKSPACE=/workspace

echo "[reset] discarding candidate edits in $WORKSPACE (host)"
cd "$WORKSPACE"
sudo git reset --hard HEAD
# Keep .venv to avoid a re-sync. Also keep ec2/ (operator stack on host).
sudo git clean -fdx -e .venv -e ec2

echo "[reset] wiping code-server per-user state inside $CONTAINER"
docker exec "$CONTAINER" bash -lc '
    : > /root/.bash_history 2>/dev/null || true
    rm -rf /root/.local/share/code-server/User/workspaceStorage/* || true
    rm -rf /root/.local/share/code-server/User/History/* || true
'

echo "[reset] restarting $CONTAINER"
docker restart "$CONTAINER" >/dev/null

echo "[reset] done. Same URL + password as before."
