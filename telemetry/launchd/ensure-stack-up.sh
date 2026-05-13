#!/bin/bash
# Idempotent: brings the AIW telemetry stack up if it isn't already.
# Invoked by launchd at login and every 5 minutes thereafter.
# Exits 0 quietly when Docker isn't running (the next tick will retry).

set -euo pipefail

if ! docker info >/dev/null 2>&1; then
    echo "$(date -u +%FT%TZ) docker daemon not reachable, skipping" >&2
    exit 0
fi

cd "$(dirname "$0")/.."
docker compose up -d >/dev/null

echo "$(date -u +%FT%TZ) telemetry stack up"
