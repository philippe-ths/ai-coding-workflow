#!/usr/bin/env bash
# Repo-specific validation for ai-coding-workflow.
# Invoked by ./.ai-policy/scripts/project-validation.sh when this file exists and is executable.
# Target repos should supply their own scripts/repo-validation.sh (tests, linters, etc.).
set -eu

bash -n ./telemetry/*.sh ./scripts/run-baseline.sh

if command -v python3 >/dev/null 2>&1; then
  PY_TARGETS=""
  for d in ./evals/harness ./evals/tasks ./evals/spikes ./scripts; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do PY_TARGETS="$PY_TARGETS $f"; done < <(find "$d" -name '*.py' -type f)
  done
  if [ -n "$PY_TARGETS" ]; then
    # shellcheck disable=SC2086
    python3 -m py_compile $PY_TARGETS
  fi
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
  for yaml_file in \
    ./telemetry/docker-compose.yml \
    ./telemetry/otel-collector-config.yaml \
    ./telemetry/prometheus/prometheus.yml \
    ./telemetry/loki/loki-config.yaml \
    ./telemetry/grafana/provisioning/datasources/datasources.yml \
    ./telemetry/grafana/provisioning/dashboards/dashboards.yml; do
    python3 -c "import yaml,sys; yaml.safe_load(open('$yaml_file'))" || { echo "YAML syntax error in $yaml_file" >&2; exit 1; }
  done
fi

for dash in ./telemetry/grafana/dashboards/*.json; do
  python3 -c "import json; json.load(open('$dash'))" 2>/dev/null || {
    if command -v jq >/dev/null 2>&1; then
      jq empty "$dash" || { echo "JSON syntax error in $dash" >&2; exit 1; }
    else
      echo "Cannot validate $dash (no python3 or jq)" >&2
    fi
  }
done

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  (cd ./telemetry && docker compose config -q) || { echo "docker compose config failed" >&2; exit 1; }
fi
