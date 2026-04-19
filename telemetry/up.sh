#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed." >&2
  exit 1
fi

docker compose up -d "$@"

echo
echo "Telemetry stack up."
echo "  Grafana:    http://localhost:3000  (anonymous Viewer, or admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Loki:       http://localhost:3100"
echo "  OTLP gRPC:  localhost:4317"
echo "  OTLP HTTP:  localhost:4318"
