#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

STATE_FILE="$ROOT_DIR/$VALIDATION_STATE_FILE"

if [ ! -f "$STATE_FILE" ]; then
  echo "Blocked: no validation status found."
  echo "Run ./.ai-policy/scripts/run-validation.sh first."
  exit 2
fi

STATUS="$(cat "$STATE_FILE")"

if [ "$STATUS" = "passed" ]; then
  exit 0
fi

if [ "$STATUS" = "running" ]; then
  echo "Blocked: validation is still running."
  echo "Wait for it to finish or rerun ./.ai-policy/scripts/run-validation.sh."
  exit 2
fi

echo "Blocked: validation status is '$STATUS', not 'passed'."
echo "Run ./.ai-policy/scripts/run-validation.sh and only continue once it passes."
exit 2
