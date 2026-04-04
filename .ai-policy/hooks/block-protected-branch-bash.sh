#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code.
# Blocks Bash git commands (commit, push) when on a protected branch.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

# Only check git commit and git push commands.
case "$COMMAND" in
  git\ commit*|git\ push*) ;;
  *) exit 0 ;;
esac

CURRENT_BRANCH="$("$ROOT_DIR/.ai-policy/scripts/current-branch.sh")"

for protected in $PROTECTED_BRANCHES; do
  if [ "$CURRENT_BRANCH" = "$protected" ]; then
    echo "Blocked: '$COMMAND' on protected branch '$CURRENT_BRANCH'." >&2
    echo "Create or switch to an issue-scoped branch before continuing." >&2
    exit 2
  fi
done

exit 0
