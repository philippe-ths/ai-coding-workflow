#!/usr/bin/env bash
set -eu

bash -n ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/* ./telemetry/*.sh ./scripts/run-baseline.sh

# Python syntax check on harness, scripts, tasks, and spikes.
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

# YAML syntax check on telemetry configs (skipped if python3 or pyyaml missing).
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

# JSON syntax check on Grafana dashboards.
for dash in ./telemetry/grafana/dashboards/*.json; do
  python3 -c "import json; json.load(open('$dash'))" 2>/dev/null || {
    if command -v jq >/dev/null 2>&1; then
      jq empty "$dash" || { echo "JSON syntax error in $dash" >&2; exit 1; }
    else
      echo "Cannot validate $dash (no python3 or jq)" >&2
    fi
  }
done

# Optional: docker compose config dry-run when docker is available.
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  (cd ./telemetry && docker compose config -q) || { echo "docker compose config failed" >&2; exit 1; }
fi

./.ai-policy/scripts/test-claude-code-enforcement.sh
./.ai-policy/scripts/test-codex-enforcement.sh
./.ai-policy/scripts/test-vscode-copilot-enforcement.sh
./.ai-policy/scripts/test-gemini-enforcement.sh
./.ai-policy/scripts/test-changelog-hook.sh
./.ai-policy/scripts/test-session-tags-hook.sh
./.ai-policy/scripts/test-pre-push-hook.sh
