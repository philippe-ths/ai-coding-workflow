#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code (matcher: Skill).
# Blocks loading aiw-planning while the session stands on a protected branch or
# a detached HEAD, so planning happens on the task's own branch.
# Reads tool_input and cwd from JSON on stdin.
# Exit 2 = block, exit 0 = allow.
#
# Why: Task Flow puts the issue and branch (step 2) before planning (step 3),
# and the observation tool charges work to a task by the branch it ran on.
# Planning done on the default branch belongs to no task, and it cannot be
# recovered afterwards by reading which issue the work named.
#
# Codex and VS Code Copilot load a skill by reading its file, which a hook
# cannot tell apart from reading the file to edit it, so this covers Claude
# Code only.

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$POLICY_DIR/policy.env"

INPUT="$(cat)"
SKILL="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty')"

case "$SKILL" in
  aiw-planning|*:aiw-planning|/aiw-planning) ;;
  *) exit 0 ;;
esac

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
[ -n "$CWD" ] || CWD="$(pwd)"

# Outside a git repository there is no branch to put the task on.
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRANCH="$(git -C "$CWD" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

deny() {
  echo "Blocked: aiw-planning on $1." >&2
  echo "Planning is part of the task, so it runs on the task's branch (ai-workflow.md Task Flow, step 2 before step 3)." >&2
  echo "Find or file the task's issue (aiw-issue-creation), create its branch (aiw-github), then plan." >&2
  echo "If the conversation has not become a task, stay in discussion; it needs no plan." >&2
  exit 2
}

[ -n "$BRANCH" ] || deny "a detached HEAD"

for protected in $PROTECTED_BRANCHES; do
  [ "$BRANCH" = "$protected" ] && deny "'$BRANCH'"
done

exit 0
