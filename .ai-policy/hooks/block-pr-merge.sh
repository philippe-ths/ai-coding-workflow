#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code, Codex, Gemini CLI, and VS Code Copilot.
# Blocks the agent from merging a pull request by any route.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.
#
# Why this is separate from block-protected-branch-*.sh:
# Those hooks ask "which branch does this write to?". A pull request merge has
# no answer to that question — it is server-side, touches no local ref, and
# names no branch in its arguments — so it passes a branch-shaped guard while
# reaching the identical end state: unreviewed code on the protected branch.
# This hook asks a different question: "is this a merge?". It is therefore
# unconditional and does not consult the current branch or PROTECTED_BRANCHES.
#
# Merging is listed under "The Human is Responsible For" in ai-workflow.md.
# The rule is flat — no PR merge, not "no merge to a protected branch" — so
# this hook deliberately does not look up the pull request's base branch.
# Doing so would require a network call inside a PreToolUse hook, which fails
# open on timeout and would reintroduce the gap it is meant to close.

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

deny() {
  echo "Blocked: $1" >&2
  echo "Merging a pull request is the human's decision, not the agent's." >&2
  echo "See 'The Human is Responsible For' in ai-workflow.md." >&2
  echo "Report that the PR is ready and let the human merge it." >&2
  exit 2
}

# ── MCP route ──
# Matches mcp__github__merge_pull_request (Claude Code, Copilot) and
# mcp_github_merge_pull_request (Gemini CLI), plus any other server prefix.
case "$TOOL_NAME" in
  *merge_pull_request) deny "MCP tool '$TOOL_NAME'" ;;
esac

# ── Shell route ──
# Nothing to check when the payload carries no command.
[ -n "$COMMAND" ] || exit 0

# `gh pr merge` in any spacing, and anywhere in a compound command
# (e.g. "git fetch && gh pr merge 12 --squash").
# The leading boundary is any non-word character, so an absolute path
# ("/usr/bin/gh pr merge") and a quoted wrapper ("bash -c \"gh pr merge 1\"")
# are both caught, while a longer word ending in "gh" is not.
if printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+merge([^[:alnum:]_-]|$)'; then
  deny "'$COMMAND'"
fi

# `gh api` against a pull request merge endpoint, e.g.
# gh api --method PUT repos/o/r/pulls/12/merge
if printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+api([^[:alnum:]_-]|$)'; then
  if printf '%s' "$COMMAND" | grep -Eq '/pulls/[0-9]+/merge'; then
    deny "'$COMMAND'"
  fi
fi

exit 0
