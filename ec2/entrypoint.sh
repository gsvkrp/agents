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

# PASSWORD comes from compose/env.
exec code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth password \
    --disable-telemetry \
    --disable-update-check \
    "$WORKSPACE"
