#!/usr/bin/env bash
set -eu

# Tests for the SessionStart context-drift reminder hook.
# Builds throwaway git repositories in known states and asserts what the hook
# prints on stdout. The hook always exits 0, so behaviour is judged by output:
# a reminder when the context file is at/over the commit threshold, silence otherwise.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/check-context-drift.sh"

PASS=0
FAIL=0

assert_reminder() {
  local label="$1" out="$2"
  if printf '%s' "$out" | grep -q "project-context.md"; then
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

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# init_repo <dir> — a fresh git repo with identity configured.
init_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q .
  git -C "$d" checkout -q -b main 2>/dev/null || git -C "$d" symbolic-ref HEAD refs/heads/main
  git -C "$d" config user.email "test@example.invalid"
  git -C "$d" config user.name "Drift Hook Test"
  git -C "$d" config commit.gpgsign false
}

# run_hook <dir> — invoke the hook from inside <dir> with threshold 3.
run_hook() {
  ( cd "$1" && CONTEXT_DRIFT_THRESHOLD=3 bash "$HOOK" 2>/dev/null )
}

# 1. Context file at/over threshold -> reminder.
R="$SANDBOX/over"; init_repo "$R"
echo "context" > "$R/project-context.md"
git -C "$R" add project-context.md && git -C "$R" commit -q -m "add context"
for i in 1 2 3; do
  echo "$i" > "$R/file-$i.txt"
  git -C "$R" add "file-$i.txt" && git -C "$R" commit -q -m "work $i"
done
assert_reminder "3 commits behind, threshold 3 -> reminder" "$(run_hook "$R")"

# 2. Context file within threshold -> silent.
R="$SANDBOX/under"; init_repo "$R"
echo "context" > "$R/project-context.md"
git -C "$R" add project-context.md && git -C "$R" commit -q -m "add context"
echo "x" > "$R/file.txt"
git -C "$R" add file.txt && git -C "$R" commit -q -m "one commit of work"
assert_silent "1 commit behind, threshold 3 -> silent" "$(run_hook "$R")"

# 3. No context file -> silent.
R="$SANDBOX/absent"; init_repo "$R"
echo "x" > "$R/file.txt"
git -C "$R" add file.txt && git -C "$R" commit -q -m "no context file here"
assert_silent "context file absent -> silent" "$(run_hook "$R")"

# 4. Context file present but never committed -> silent (drift is unmeasurable).
R="$SANDBOX/uncommitted"; init_repo "$R"
echo "seed" > "$R/seed.txt"
git -C "$R" add seed.txt && git -C "$R" commit -q -m "seed"
echo "context" > "$R/project-context.md"   # left untracked
for i in 1 2 3; do
  echo "$i" > "$R/file-$i.txt"
  git -C "$R" add "file-$i.txt" && git -C "$R" commit -q -m "work $i"
done
assert_silent "context file never committed -> silent" "$(run_hook "$R")"

# 5. Not a git repository -> silent.
R="$SANDBOX/nogit"; mkdir -p "$R"
echo "context" > "$R/project-context.md"
assert_silent "non-git directory -> silent" "$(run_hook "$R")"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
