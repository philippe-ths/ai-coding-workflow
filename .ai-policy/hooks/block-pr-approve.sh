#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code, Codex, Gemini CLI, and VS Code Copilot.
# Blocks the agent from approving a pull request by any route.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.
#
# Approving review is a human judgement in the same category as merging, so
# this hook is shaped like block-pr-merge.sh: it asks "is this an approval?"
# and blocks unconditionally, rather than conditioning on any repository state.
#
# The failure this prevents is self-approval: an agent that opens a pull
# request and approves it has satisfied a human-shaped review requirement
# using only its own judgement. block-pr-merge.sh stops the loop completing,
# but the approval is a false signal recorded against a human process.
#
# Leaving a review comment and requesting changes are not approvals and are
# not blocked here. Neither is auto-approved in the permission defaults, so
# both still prompt.

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

deny() {
  echo "Blocked: $1" >&2
  echo "Approving a pull request is the human's decision, not the agent's." >&2
  echo "An agent approving its own work is not review." >&2
  echo "Report what you changed and what you verified, and let the human review it." >&2
  exit 2
}

# ── MCP route ──
# Review creation and submission tools, under any server prefix.
case "$TOOL_NAME" in
  *create_pull_request_review|*submit_pending_pull_request_review|*create_and_submit_pull_request_review)
    EVENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.event // empty' | tr '[:lower:]' '[:upper:]')"
    # Fail closed: block unless the payload positively identifies itself as a
    # non-approving review. An absent or unrecognised event is treated as an
    # approval, because guessing the other way is how merge_pull_request got
    # through the branch guards.
    case "$EVENT" in
      COMMENT|REQUEST_CHANGES) exit 0 ;;
      *) deny "MCP tool '$TOOL_NAME' (event: ${EVENT:-unspecified})" ;;
    esac
    ;;
esac

# ── Shell route ──
[ -n "$COMMAND" ] || exit 0

# `gh pr review` anywhere in the command, in any spacing.
if printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+review([^[:alnum:]_-]|$)'; then
  # An explicit non-approving review type is allowed through.
  if printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])--(comment|request-changes)([[:space:]=]|$)'; then
    exit 0
  fi
  # --approve, or no review type at all. The latter is interactive and offers
  # approval as an option, so it is blocked rather than gambled on.
  deny "'$COMMAND'"
fi

# `gh api` against the reviews endpoint. The event lives in the request body,
# which cannot be read reliably from a command string, so this blocks the
# endpoint rather than trying to parse intent out of it.
if printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+api([^[:alnum:]_-]|$)'; then
  if printf '%s' "$COMMAND" | grep -Eq '/pulls/[0-9]+/reviews'; then
    deny "'$COMMAND'"
  fi
fi

exit 0
