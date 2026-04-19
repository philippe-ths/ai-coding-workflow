#!/usr/bin/env bash
# Runs the D0 sandbox OTEL spike end-to-end.
# Assumes the host telemetry stack is up (cd telemetry && ./up.sh).
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
./.venv/bin/pip install --quiet --upgrade pip
./.venv/bin/pip install --quiet -r requirements.txt

if ! curl -sf http://localhost:3100/ready >/dev/null; then
  echo "ERROR: Loki not reachable at http://localhost:3100." >&2
  echo "Start the telemetry stack first: (cd ../../../telemetry && ./up.sh)" >&2
  exit 2
fi

rm -f run_id.txt
./.venv/bin/inspect eval task.py --model mockllm/model

echo
echo "--- Asserting tags in Loki ---"
./.venv/bin/python assert_tags.py
