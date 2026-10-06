#!/usr/bin/env bash
# SessionStart hook: reminds the agent when project-context.md may have drifted.
#
# It cannot judge drift; that is the agent's job. Its message routes drift the way the
# rules do (ai-workflow.md, aiw-planning, aiw-project-context-management): drift that
# predates a task is a finding outside it, not an inline refresh.
# It emits a coarse commit-count signal: if the context file has not been touched in
# CONTEXT_DRIFT_THRESHOLD or more commits, print a reminder on stdout. Both Claude Code
# and Codex add SessionStart stdout to the agent's context.
#
# Advisory only. It must NEVER block or fail a session: every path exits 0, and it
# stays silent when it cannot measure drift (no git repo, file absent or never committed).

# Resolve config location relative to this script before changing directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
POLICY_ENV="$SCRIPT_DIR/../policy.env"

# An env override (set by the test, or by a caller) wins over policy.env defaults.
if [ -f "$POLICY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$POLICY_ENV" 2>/dev/null || true
fi
THRESHOLD="${CONTEXT_DRIFT_THRESHOLD:-10}"
CONTEXT_FILE="${CONTEXT_FILE:-project-context.md}"

# Only act inside a git work tree; operate from its root so paths are repo-relative.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0
cd "$ROOT" 2>/dev/null || exit 0

# Nothing to measure if the context file does not exist or was never committed.
[ -f "$CONTEXT_FILE" ] || exit 0
LAST="$(git log -1 --format=%H -- "$CONTEXT_FILE" 2>/dev/null)" || exit 0
[ -n "$LAST" ] || exit 0

# Commits landed since the context file was last updated.
N="$(git rev-list --count "$LAST"..HEAD 2>/dev/null)" || exit 0
case "$N" in
  ''|*[!0-9]*) exit 0 ;;
esac

if [ "$N" -ge "$THRESHOLD" ]; then
  cat <<EOF
NOTE: $CONTEXT_FILE has not been updated in $N commits and may have drifted from the codebase.
If you start a task, check it against the code the task touches. Drift that predates the task is a finding outside it: fix it with the aiw-project-context-management skill when the fix is smaller than the sentence describing it, otherwise file it with aiw-issue-creation, and do not refresh the file inline. Drift the task itself causes, or a refresh the human asks for as the task, goes through aiw-project-context-management.
EOF
fi

exit 0
