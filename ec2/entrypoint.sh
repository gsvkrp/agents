#!/usr/bin/env bash
# Sync deps and exec code-server. .git/ and ec2/ are masked from the
# candidate's view by anonymous volumes in docker-compose.yml — nothing
# to hide here at runtime.
set -euo pipefail

WORKSPACE=/workspace

cd "$WORKSPACE"
if [ ! -d .venv ]; then
    echo "[entrypoint] running uv sync"
    uv sync
fi

# Hide operator-only and noisy paths from the candidate's file explorer.
# Lives in /workspace/.vscode/ which docker-compose masks on the host so
# this never leaks back into the git repo.
mkdir -p .vscode
cat > .vscode/settings.json <<'JSON'
{
  "files.exclude": {
    "ec2": true,
    ".devcontainer": true,
    ".env.example": true,
    ".venv": true,
    "uv.lock": true,
    ".vscode": true
  }
}
JSON

# PASSWORD comes from compose/env.
exec code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth password \
    --disable-telemetry \
    --disable-update-check \
    "$WORKSPACE"
