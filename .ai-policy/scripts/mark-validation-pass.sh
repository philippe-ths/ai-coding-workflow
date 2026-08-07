#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

mkdir -p "$(dirname "$ROOT_DIR/$VALIDATION_STATE_FILE")"

# The override still records the tree it was set on. It remains an escape hatch
# from running validation, not from the requirement that the result belong to the
# content being committed.
printf 'passed %s\n' "$("$ROOT_DIR/.ai-policy/scripts/tree-fingerprint.sh")" \
  > "$ROOT_DIR/$VALIDATION_STATE_FILE"

echo "Validation status set to passed for the current working tree."
echo "Editing any file after this point will block the gate until validation is re-run."
