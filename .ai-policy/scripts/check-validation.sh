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

# A passing result is recorded as "passed <fingerprint>", where the fingerprint
# identifies the working tree the result was computed against. The other states
# imply no tree and stay bare.
STATE_LINE="$(head -n 1 "$STATE_FILE")"
STATUS="${STATE_LINE%% *}"
RECORDED_FINGERPRINT=""
case "$STATE_LINE" in
  *' '*) RECORDED_FINGERPRINT="${STATE_LINE#* }" ;;
esac

if [ "$STATUS" = "passed" ]; then
  # A bare "passed" was written by a policy layer that predated fingerprinting.
  # It cannot be tied to any tree, so it is not evidence that what is about to
  # be committed was validated.
  if [ -z "$RECORDED_FINGERPRINT" ]; then
    echo "Blocked: validation status records no working-tree fingerprint."
    echo "It was written before the gate started tying results to a tree, so"
    echo "there is no way to tell what content it passed against."
    echo "Run ./.ai-policy/scripts/run-validation.sh to record a current result."
    exit 2
  fi

  CURRENT_FINGERPRINT="$("$ROOT_DIR/.ai-policy/scripts/tree-fingerprint.sh")"

  if [ "$RECORDED_FINGERPRINT" = "$CURRENT_FINGERPRINT" ]; then
    exit 0
  fi

  echo "Blocked: the working tree has changed since validation passed."
  echo "The recorded pass was computed against different content, so it does not"
  echo "cover what is being committed or pushed."
  echo "  validated tree: $RECORDED_FINGERPRINT"
  echo "  current tree:   $CURRENT_FINGERPRINT"
  echo "Run ./.ai-policy/scripts/run-validation.sh and only continue once it passes."
  exit 2
fi

if [ "$STATUS" = "running" ]; then
  echo "Blocked: validation is still running."
  echo "Wait for it to finish or rerun ./.ai-policy/scripts/run-validation.sh."
  exit 2
fi

echo "Blocked: validation status is '$STATUS', not 'passed'."
echo "Run ./.ai-policy/scripts/run-validation.sh and only continue once it passes."
exit 2
