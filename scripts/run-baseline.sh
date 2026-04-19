#!/usr/bin/env bash
# Runs one or more baseline tasks repeatedly and writes per-session JSONs.
#
# Usage:
#   ./scripts/run-baseline.sh [--agent mock|claude-code] [--tasks t-001,t-002]
#                             [--repeats N] [--model MODEL] [--timeout SECS]
#
# Results land at telemetry/data/baseline/<workflow_version>/<ruleset_hash>/<task>/<run>.json
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

AGENT="mock"
TASKS=""
REPEATS=1
MODEL=""
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --tasks) TASKS="$2"; shift 2 ;;
    --repeats) REPEATS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

VENV="$ROOT_DIR/evals/.venv"
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r "$ROOT_DIR/evals/requirements.txt"

if [ -z "$TASKS" ]; then
  TASK_DIRS=$(find "$ROOT_DIR/evals/tasks" -mindepth 1 -maxdepth 1 -type d | sort)
else
  TASK_DIRS=""
  IFS=',' read -r -a NAMES <<< "$TASKS"
  for n in "${NAMES[@]}"; do
    d="$ROOT_DIR/evals/tasks/$n"
    [ -d "$d" ] || { echo "no such task: $n" >&2; exit 2; }
    TASK_DIRS+="$d"$'\n'
  done
fi

export PYTHONPATH="$ROOT_DIR"
export BASELINE_AGENT="$AGENT"
export BASELINE_TIMEOUT="$TIMEOUT"
export BASELINE_MODEL="$MODEL"

for TASK_DIR in $TASK_DIRS; do
  [ -z "$TASK_DIR" ] && continue
  TASK_ID="$(basename "$TASK_DIR")"
  for i in $(seq 1 "$REPEATS"); do
    echo "[run-baseline] agent=$AGENT task=$TASK_ID repeat=$i/$REPEATS" >&2
    BASELINE_TASK_DIR="$TASK_DIR" "$VENV/bin/python" -m evals.harness.cli
  done
done

echo "[run-baseline] done" >&2
