#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

STATE_FILE="$ROOT_DIR/$VALIDATION_STATE_FILE"

mkdir -p "$(dirname "$STATE_FILE")"
printf "running" > "$STATE_FILE"

cleanup() {
  if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "running" ]; then
    printf "failed" > "$STATE_FILE"
  fi
}

trap cleanup EXIT INT TERM

if sh -c "$VALIDATION_COMMAND"; then
  printf "passed" > "$STATE_FILE"
  trap - EXIT INT TERM
  echo "Validation passed."
  exit 0
else
  printf "failed" > "$STATE_FILE"
  trap - EXIT INT TERM
  echo "Validation failed."
  exit 1
fi
