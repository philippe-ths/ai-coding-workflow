#!/usr/bin/env bash
# SessionStart hook: reminds the human when the repository is hiding working files
# from itself through .git/info/exclude.
#
# It cannot judge whether any hidden file earns its place — that is the human's call
# via aiw-housekeeping's audit. It emits a coarse count: at HIDDEN_CLUTTER_THRESHOLD
# or more entries, print a reminder on stdout. Both Claude Code and Codex add
# SessionStart stdout to the agent's context.
#
# Why this file and not .gitignore: a .gitignore rule is committed, reviewed and shared,
# so what it hides is a documented decision. A .git/info/exclude rule is local and
# uncommitted, so what it hides is invisible to review, to everyone else who clones the
# repository, and to every other check the workflow has. Hiding a file there is how mess
# escapes, and nothing else in a session will ever mention it.
#
# Advisory only. It must NEVER block or fail a session: every path exits 0, and it stays
# silent when it cannot measure (no git repo, no exclude file, nothing readable).

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
POLICY_ENV="$SCRIPT_DIR/../policy.env"

# An env override (set by the test, or by a caller) wins over policy.env defaults.
if [ -f "$POLICY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$POLICY_ENV" 2>/dev/null || true
fi
THRESHOLD="${HIDDEN_CLUTTER_THRESHOLD:-5}"

# A non-numeric or negative threshold would make the comparison below fail loudly.
case "$THRESHOLD" in
  ''|*[!0-9]*) exit 0 ;;
esac

# Only act inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# info/exclude lives in the common dir, so a linked worktree reads the same file the
# main one does. Fall back for git versions without --git-common-dir.
GITDIR="$(git rev-parse --git-common-dir 2>/dev/null)" || GITDIR=""
[ -n "$GITDIR" ] || GITDIR="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
[ -n "$GITDIR" ] || exit 0

EXCLUDE="$GITDIR/info/exclude"
[ -f "$EXCLUDE" ] || exit 0
[ -r "$EXCLUDE" ] || exit 0

# Count rules, not files: one line per deliberate act of hiding something. A single
# pattern covering hundreds of build artifacts is one decision; sixteen files added
# one at a time is sixteen, and that difference is the signal.
N="$(grep -cEv '^[[:space:]]*(#|$)' "$EXCLUDE" 2>/dev/null)" || N=""
case "$N" in
  ''|*[!0-9]*) exit 0 ;;
esac

if [ "$N" -ge "$THRESHOLD" ]; then
  cat <<EOF
NOTE: .git/info/exclude carries $N entries, so this repository is hiding at least that
many paths through a local rule that is not committed and that nobody else can see.
Run the aiw-housekeeping audit to find what is still on disk, what it costs, and what
should go. Report it to the human; do not act on it as part of whatever task starts now.
EOF
fi

exit 0
