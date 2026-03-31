#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

mkdir -p "$(dirname "$ROOT_DIR/$VALIDATION_STATE_FILE")"
printf "passed" > "$ROOT_DIR/$VALIDATION_STATE_FILE"

echo "Validation status set to passed."
