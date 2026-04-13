#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code.
# Blocks MCP write tools that target a protected branch.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"

# Allow create_pull_request — PRs target a branch for review, not a direct write.
case "$TOOL_NAME" in
  *create_pull_request) exit 0 ;;
esac

# Extract the target branch from tool_input.
# push_files, create_or_update_file, delete_file use "branch".
BRANCH="$(printf '%s' "$INPUT" | jq -r '.tool_input.branch // empty')"

if [ -z "$BRANCH" ]; then
  # No branch info available (e.g. merge_pull_request) — cannot check, allow.
  exit 0
fi

for protected in $PROTECTED_BRANCHES; do
  if [ "$BRANCH" = "$protected" ]; then
    echo "Blocked: MCP tool '$TOOL_NAME' targets protected branch '$BRANCH'." >&2
    echo "Create or switch to an issue-scoped branch before continuing." >&2
    exit 2
  fi
done

exit 0
