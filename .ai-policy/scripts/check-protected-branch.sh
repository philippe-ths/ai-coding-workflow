#!/usr/bin/env bash
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

CURRENT_BRANCH="$("$ROOT_DIR/.ai-policy/scripts/current-branch.sh")"

for branch in $PROTECTED_BRANCHES; do
  if [ "$CURRENT_BRANCH" = "$branch" ]; then
    echo "Blocked: branch '$CURRENT_BRANCH' is protected."
    echo "Create or switch to an issue-scoped branch before continuing."
    exit 2
  fi
done

exit 0
