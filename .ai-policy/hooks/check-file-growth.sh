#!/usr/bin/env bash
# SessionStart hook: reminds the human when large files are still growing.
#
# Rot in a long-lived codebase is not produced at task granularity: each commit adds to
# the file already open, every one passes its own gate, and no task ever owns "this file
# is now too big". This hook is the cheap counter that notices. It cannot judge whether a
# file should be split; that is the human's call via aiw-housekeeping's audit. It counts
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
  horizon="$(grep -iE '^[[:space:]]*horizon:' "$HORIZON_FILE" 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]' | tr -d ' -')"
  case "$horizon" in
    *oneshot*) exit 0 ;;
  esac
fi

# A repository younger than the window has no "before" to compare against, and every
# file would look like growth from nothing.
BASE="$(git rev-list -n 1 --skip="$WINDOW" HEAD 2>/dev/null)" || exit 0
[ -n "$BASE" ] || exit 0

SPECS=(.)
for p in $EXCLUDE; do SPECS+=(":(exclude,glob)**/$p"); done

# Line counts of committed text files at HEAD; -I skips binaries.
HITS=""
N=0
while IFS= read -r row; do
  count="${row##*:}"
  path="${row#HEAD:}"
  path="${path%:*}"
  case "$count" in ''|*[!0-9]*) continue ;; esac
  [ "$count" -ge "$LINES_MIN" ] || continue
  before="$(git show "$BASE:$path" 2>/dev/null | wc -l | tr -d ' ')"
  case "$before" in ''|*[!0-9]*) before=0 ;; esac
  [ $((count - before)) -ge "$GROWTH_MIN" ] || continue
  N=$((N + 1))
  HITS="$HITS$count $before $path
"
done < <(cd "$TOP" && git grep -I -c '' HEAD -- "${SPECS[@]}" 2>/dev/null)

[ "$N" -ge 1 ] || exit 0

echo "NOTE: $N file(s) of $LINES_MIN+ lines grew by $GROWTH_MIN+ lines over the last $WINDOW commits:"
printf '%s' "$HITS" | sort -nr | head -n 5 | while read -r now was path; do
  echo "  $path: $was -> $now lines"
done
[ "$N" -le 5 ] || echo "  ...and $((N - 5)) more."
cat <<EOF
Each commit adds to the file already open and no single task owns its size. Run the
aiw-housekeeping audit to rank these with the rest of what has built up. Whether a file
should be split is the human's call. Report it to the human; do not act on it as part of
whatever task starts now.
EOF

exit 0
