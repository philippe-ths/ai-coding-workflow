#!/usr/bin/env bash
# SessionStart hook: reminds the human when large files are still growing.
#
# Rot in a long-lived codebase is not produced at task granularity: each commit adds to
# the file already open, every one passes its own gate, and no task ever owns "this file
# is now too big". This hook is the cheap counter that notices, and its note has the agent
# file an upkeep issue per file, so the split becomes a task someone owns. It counts
# committed text files of at least FILE_GROWTH_LINES lines that grew by at least
# FILE_GROWTH_MIN lines over the last FILE_GROWTH_WINDOW commits, and names the largest.
#
# Growth, not size, is the trigger. A large file that has stopped growing is a known
# cost the audit can list; a note that fired on it every session would teach agents to
# ignore the note.
#
# A project whose north-star.md declares `Horizon: one-shot` will not be worked on long
# enough for this to matter, so the hook stays silent there. No declaration means the
# project is treated as long-lived.
#
# Advisory only. It must NEVER block or fail a session: every path exits 0, and it stays
# silent when it cannot measure (no git repo, too little history, nothing readable).

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
POLICY_ENV="$SCRIPT_DIR/../policy.env"

# An env override (set by the test, or by a caller) wins over policy.env defaults.
if [ -f "$POLICY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$POLICY_ENV" 2>/dev/null || true
fi
LINES_MIN="${FILE_GROWTH_LINES:-1000}"
GROWTH_MIN="${FILE_GROWTH_MIN:-50}"
WINDOW="${FILE_GROWTH_WINDOW:-50}"
# Files that grow by design, not by accretion. Space-separated git pathspec globs.
EXCLUDE="${FILE_GROWTH_EXCLUDE:-*.lock *-lock.json *-lock.yaml *.min.js *.min.css CHANGELOG*}"

for v in "$LINES_MIN" "$GROWTH_MIN" "$WINDOW"; do
  case "$v" in
    ''|*[!0-9]*) exit 0 ;;
  esac
done
[ "$WINDOW" -ge 1 ] || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

HORIZON_FILE="$TOP/north-star.md"
if [ -r "$HORIZON_FILE" ]; then
  # The value after the first `Horizon:` line, lowercased, with markdown emphasis,
  # spaces and dashes dropped, so "One-Shot" and "**Horizon:** one shot" both read.
  horizon="$(grep -iE '^[[:space:]*_]*horizon[*_]*:' "$HORIZON_FILE" 2>/dev/null | head -n 1 \
    | sed 's/^[^:]*://' | tr '[:upper:]' '[:lower:]' | tr -d ' \t*_-')"
  [ "$horizon" = "oneshot" ] && exit 0
fi

# A repository younger than the window has no "before" to compare against, and every
# file would look like growth from nothing.
BASE="$(git rev-list -n 1 --skip="$WINDOW" HEAD 2>/dev/null)" || exit 0
[ -n "$BASE" ] || exit 0

# Excludes are pathspec globs for git, so the shell must not expand them first.
set -f
SPECS=(.)
for p in $EXCLUDE; do SPECS+=(":(exclude,glob)**/$p"); done
set +f

# Line counts of committed text files at both ends of the window, one git grep each
# (-I skips binaries). quotePath=false leaves non-ASCII names raw; a name git still
# quotes (a quote, backslash, tab or newline in it) cannot be matched across the two
# lists, so it is skipped rather than reported as grown from nothing.
counts() {
  ( cd "$TOP" && git -c core.quotePath=false grep -I -c '' "$1" -- "${SPECS[@]}" 2>/dev/null )
}
HITS="$(
  { counts "$BASE" | sed "s/^$BASE:/B:/"; counts HEAD | sed 's/^HEAD:/H:/'; } \
  | awk -v min="$LINES_MIN" -v grow="$GROWTH_MIN" '
      {
        if (!match($0, /:[0-9]+$/)) next
        side = substr($0, 1, 1); path = substr($0, 3, RSTART - 3); n = substr($0, RSTART + 1) + 0
        if (substr(path, 1, 1) == "\"") next
        if (side == "B") { before[path] = n; next }
        if (n >= min && n - before[path] >= grow) printf "%d %d %s\n", n, before[path] + 0, path
      }' | sort -nr
)"
[ -n "$HITS" ] || exit 0
N="$(printf '%s\n' "$HITS" | wc -l | tr -d ' ')"

echo "NOTE: $N file(s) of $LINES_MIN+ lines grew by $GROWTH_MIN+ lines over the last $WINDOW commits:"
printf '%s\n' "$HITS" | head -n 10 | while read -r now was path; do
  echo "  $path: $was -> $now lines"
done
[ "$N" -le 10 ] || echo "  ...and $((N - 10)) more."
cat <<EOF
Each commit adds to the file already open and no single task owns its size. For each
file no open issue already covers, file an aiw:upkeep issue to split it without changing
behaviour (aiw-issue-creation), and name the issues in your next message. Do not split
anything as part of whatever task starts now.
EOF

exit 0
