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

# Wall time, because it is what the human waits. Reported and never gated on:
# measured on one machine this run varied between 70s and 121s with nothing
# changed, so the difference between two runs is not evidence of anything.
STARTED_AT="$(date +%s)"

if sh -c "$VALIDATION_COMMAND"; then
  echo "Validation took $(( $(date +%s) - STARTED_AT ))s."
  # Record which tree this result covers. Taken after the command returns, so it
  # describes the content the gate will compare against. If the fingerprint
  # cannot be computed, set -e aborts here with the state still "running" and the
  # trap turns it into "failed" — the gate blocks rather than trusting an
  # unattributed pass.
  printf 'passed %s\n' "$("$ROOT_DIR/.ai-policy/scripts/tree-fingerprint.sh")" > "$STATE_FILE"
  trap - EXIT INT TERM
  echo "Validation passed."
  exit 0
else
  printf "failed" > "$STATE_FILE"
  trap - EXIT INT TERM
  echo "Validation took $(( $(date +%s) - STARTED_AT ))s."
  echo "Validation failed."
  exit 1
fi
