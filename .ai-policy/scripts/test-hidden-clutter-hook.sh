#!/usr/bin/env bash
set -eu

# Tests for the SessionStart hidden-clutter reminder hook.
# Builds throwaway git repositories in known states and asserts what the hook prints.
# The hook always exits 0, so behaviour is judged by output: a reminder at or over the
# entry threshold, silence otherwise. The degenerate paths matter more than the happy
# one here: this hook runs at the start of every session in every installed repository,
# so a path that errors or chatters costs more than the clutter it reports.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/check-hidden-clutter.sh"

PASS=0
FAIL=0

assert_reminder() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -q "info/exclude"; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected a reminder, got none)"
  fi
}

assert_silent() {
  local label="$1" out="$2"
  if [ -z "$out" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected silence, got: $out)"
  fi
}

assert_exit_zero() {
  local label="$1" dir="$2"
  # Tested inside the `if` condition: `set -e` does not apply there, so a non-zero
  # exit is reported as a failure instead of aborting the run before the check.
  if ( cd "$dir" && bash "$HOOK" >/dev/null 2>&1 ); then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (hook exited non-zero)"
  fi
}

SANDBOX="$(mktemp -d)"
cleanup() { chmod -R u+rwX "$SANDBOX" 2>/dev/null || true; rm -rf "$SANDBOX"; }
trap cleanup EXIT

init_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test"
  echo seed > "$d/seed.txt"
  git -C "$d" add seed.txt
  git -C "$d" commit -q -m seed
}

# write_exclude <repo> <n> — n hidden paths, plus the comment header git ships.
write_exclude() {
  local d="$1" n="$2" i
  mkdir -p "$d/.git/info"
  printf '# git ls-files --others --exclude-from=.git/info/exclude\n# Lines that start with %s are comments.\n\n' '#' > "$d/.git/info/exclude"
  i=1
  while [ "$i" -le "$n" ]; do echo "hidden-$i.md" >> "$d/.git/info/exclude"; i=$((i + 1)); done
}

run_hook() { ( cd "$1" && HIDDEN_CLUTTER_THRESHOLD="${2:-5}" bash "$HOOK" 2>/dev/null ); }

echo "Hidden-clutter hook tests:"

# 1. Over the threshold -> reminder.
R="$SANDBOX/over"; init_repo "$R"; write_exclude "$R" 16
assert_reminder "16 entries over a threshold of 5 -> reminder" "$(run_hook "$R" 5)"

# 2. Under the threshold -> silent.
R="$SANDBOX/under"; init_repo "$R"; write_exclude "$R" 2
assert_silent "2 entries under a threshold of 5 -> silent" "$(run_hook "$R" 5)"

# 3. Exactly at the threshold -> reminder. The boundary is inclusive; a hook that
#    fires one late is a hook nobody notices is late.
R="$SANDBOX/exact"; init_repo "$R"; write_exclude "$R" 5
assert_reminder "5 entries at a threshold of 5 -> reminder" "$(run_hook "$R" 5)"

# 4. Comments and blank lines are not entries.
R="$SANDBOX/comments"; init_repo "$R"; mkdir -p "$R/.git/info"
printf '# a comment\n\n#another\n   \n' > "$R/.git/info/exclude"
assert_silent "comments and blanks only -> silent" "$(run_hook "$R" 1)"

# 5. No exclude file at all -> silent.
R="$SANDBOX/noexclude"; init_repo "$R"; rm -f "$R/.git/info/exclude"
assert_silent "no exclude file -> silent" "$(run_hook "$R" 1)"

# 6. Not a git repository -> silent, and still exits 0.
R="$SANDBOX/nogit"; mkdir -p "$R"
assert_silent "non-git directory -> silent" "$(run_hook "$R" 1)"
assert_exit_zero "non-git directory -> exit 0" "$R"

# 7. A non-numeric threshold must not make the comparison explode.
R="$SANDBOX/badthreshold"; init_repo "$R"; write_exclude "$R" 16
assert_silent "non-numeric threshold -> silent" "$( ( cd "$R" && HIDDEN_CLUTTER_THRESHOLD=many bash "$HOOK" 2>/dev/null ) )"

# 8. An unreadable exclude file -> silent, not an error. Skipped when running as a
#    user that can read it anyway, since the case cannot be constructed there.
R="$SANDBOX/unreadable"; init_repo "$R"; write_exclude "$R" 16
chmod 000 "$R/.git/info/exclude" 2>/dev/null || true
if [ -r "$R/.git/info/exclude" ]; then
  echo "  SKIP: unreadable exclude file (still readable by this user)"
else
  assert_silent "unreadable exclude file -> silent" "$(run_hook "$R" 5)"
  assert_exit_zero "unreadable exclude file -> exit 0" "$R"
fi
chmod 644 "$R/.git/info/exclude" 2>/dev/null || true

# 9. A linked worktree reads the common dir's exclude file, not a private one.
R="$SANDBOX/wt"; init_repo "$R"; write_exclude "$R" 16
git -C "$R" worktree add -q -b side "$SANDBOX/wt-linked" >/dev/null 2>&1 || true
if [ -d "$SANDBOX/wt-linked" ]; then
  assert_reminder "linked worktree sees the common exclude file" "$(run_hook "$SANDBOX/wt-linked" 5)"
else
  echo "  SKIP: linked worktree (git worktree unavailable)"
fi

# 10. The reporting path still exits 0. A SessionStart hook that fails takes the
#     session with it, so this is the case that matters most.
R="$SANDBOX/exitcode"; init_repo "$R"; write_exclude "$R" 16
assert_exit_zero "reminder path -> exit 0" "$R"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
