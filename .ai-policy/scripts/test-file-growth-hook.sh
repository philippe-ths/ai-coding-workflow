#!/usr/bin/env bash
set -eu

# Tests for the SessionStart file-growth reminder hook.
# Builds throwaway git repositories with a known history and asserts what the hook
# prints. The hook always exits 0, so behaviour is judged by output: a note when a large
# file grew over the window, silence otherwise. Small thresholds keep the fixtures small;
# the comparison logic is the same at any size.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/check-file-growth.sh"

PASS=0
FAIL=0

assert_note() {
  local label="$1" out="$2" path="${3:-}"
  if printf '%s' "$out" | grep -q "^NOTE: .* grew by" && { [ -z "$path" ] || printf '%s' "$out" | grep -qF "  $path:"; }; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected a note${path:+ naming $path}, got: $out)"
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
  if ( cd "$dir" && bash "$HOOK" >/dev/null 2>&1 ); then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (hook exited non-zero)"
  fi
}

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

lines() { local n="$1" i=1; while [ "$i" -le "$n" ]; do echo "line $i"; i=$((i + 1)); done; }

# make_repo <dir> <path> <lines-before> <lines-after> [commits-between]
# Commits <path> at <lines-before>, then <commits-between> unrelated commits (the window
# defaults to 3 in run_hook), then rewrites <path> at <lines-after>.
make_repo() {
  local d="$1" path="$2" before="$3" after="$4" between="${5:-3}" i
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test"
  mkdir -p "$d/$(dirname "$path")"
  lines "$before" > "$d/$path"
  git -C "$d" add -A; git -C "$d" commit -q -m base
  i=1
  while [ "$i" -le "$between" ]; do
    echo "$i" > "$d/other.txt"; git -C "$d" add -A; git -C "$d" commit -q -m "other $i"
    i=$((i + 1))
  done
  lines "$after" > "$d/$path"
  git -C "$d" add -A; git -C "$d" commit -q --allow-empty -m grow
}

run_hook() {
  ( cd "$1" && FILE_GROWTH_LINES="${2:-100}" FILE_GROWTH_MIN="${3:-10}" FILE_GROWTH_WINDOW="${4:-3}" bash "$HOOK" 2>/dev/null )
}

echo "File-growth hook tests:"

# 1. Large and grown over the window -> note naming the file.
R="$SANDBOX/grown"; make_repo "$R" src/big.py 90 150
assert_note "150 lines, grew 60 -> note" "$(run_hook "$R")" "src/big.py"

# 2. Large but stable -> silent. Growth is the trigger, not size.
R="$SANDBOX/stable"; make_repo "$R" src/big.py 150 152
assert_silent "150 lines, grew 2 -> silent" "$(run_hook "$R")"

# 3. Grown but small -> silent.
R="$SANDBOX/small"; make_repo "$R" src/small.py 10 90
assert_silent "90 lines under 100 -> silent" "$(run_hook "$R")"

# 4. Both boundaries are inclusive.
R="$SANDBOX/exact"; make_repo "$R" src/edge.py 90 100
assert_note "exactly 100 lines, grew exactly 10 -> note" "$(run_hook "$R")" "src/edge.py"

# 5. A file born inside the window counts as grown from nothing.
R="$SANDBOX/born"; make_repo "$R" seed.txt 1 1
lines 200 > "$R/new.py"; git -C "$R" add -A; git -C "$R" commit -q -m new
assert_note "new 200-line file inside the window -> note" "$(run_hook "$R")" "new.py"

# 6. Too little history for the window -> silent rather than "everything grew".
R="$SANDBOX/young"; make_repo "$R" src/big.py 10 150 0
assert_silent "history shorter than the window -> silent" "$(run_hook "$R" 100 10 5)"

# 7. Horizon one-shot -> silent, however it is written.
R="$SANDBOX/oneshot"; make_repo "$R" src/big.py 90 150
printf '# North Star\n\nHorizon: one-shot\n\nShip it.\n' > "$R/north-star.md"
assert_silent "Horizon: one-shot -> silent" "$(run_hook "$R")"
printf '# North Star\n\nhorizon: One Shot\n' > "$R/north-star.md"
assert_silent "horizon: One Shot -> silent" "$(run_hook "$R")"

# 8. Horizon long-lived, or no horizon line -> note.
R="$SANDBOX/longlived"; make_repo "$R" src/big.py 90 150
printf '# North Star\n\nHorizon: long-lived\n' > "$R/north-star.md"
assert_note "Horizon: long-lived -> note" "$(run_hook "$R")"
printf '# North Star\n\nA goal that mentions a one-shot pass in passing.\n' > "$R/north-star.md"
assert_note "no Horizon line, one-shot in prose -> note" "$(run_hook "$R")"

# 9. Files that grow by design are excluded by default.
R="$SANDBOX/changelog"; make_repo "$R" CHANGELOG.md 90 150
assert_silent "CHANGELOG.md -> silent" "$(run_hook "$R")"
R="$SANDBOX/lock"; make_repo "$R" frontend/package-lock.json 90 150
assert_silent "nested package-lock.json -> silent" "$(run_hook "$R")"

# 10. Binary files are not counted.
R="$SANDBOX/binary"; make_repo "$R" seed.txt 1 1
{ lines 200; printf '\0'; } > "$R/blob.bin"; git -C "$R" add -A; git -C "$R" commit -q -m bin
assert_silent "binary file -> silent" "$(run_hook "$R")"

# 11. Uncommitted growth is not counted: the hook reads HEAD.
R="$SANDBOX/dirty"; make_repo "$R" src/big.py 90 92
lines 300 > "$R/src/big.py"
assert_silent "growth only in the working tree -> silent" "$(run_hook "$R")"

# 12. A path with a space survives the parsing.
R="$SANDBOX/space"; make_repo "$R" "src/my big.py" 90 150
assert_note "path with a space -> note naming it" "$(run_hook "$R")" "src/my big.py"

# 13. Run from a subdirectory -> still sees the whole repository.
R="$SANDBOX/subdir"; make_repo "$R" src/big.py 90 150; mkdir -p "$R/docs"
assert_note "run from a subdirectory -> note" "$(run_hook "$R/docs")" "src/big.py"

# 14. More than five hits -> the five largest are named.
R="$SANDBOX/many"; make_repo "$R" seed.txt 1 1
for n in 110 120 130 140 150 160; do lines "$n" > "$R/f$n.py"; done
git -C "$R" add -A; git -C "$R" commit -q -m many
out="$(run_hook "$R")"
assert_note "six hits -> note" "$out" "f160.py"
if printf '%s' "$out" | grep -q "^NOTE: 6 file" && ! printf '%s' "$out" | grep -qF "f110.py"; then
  PASS=$((PASS + 1)); echo "  PASS: six hits counted, smallest left unnamed"
else
  FAIL=$((FAIL + 1)); echo "  FAIL: six hits counted, smallest left unnamed (got: $out)"
fi

# 15. Not a git repository -> silent, exit 0.
R="$SANDBOX/nogit"; mkdir -p "$R"
assert_silent "non-git directory -> silent" "$(run_hook "$R")"
assert_exit_zero "non-git directory -> exit 0" "$R"

# 16. A non-numeric threshold must not make the comparison explode.
R="$SANDBOX/bad"; make_repo "$R" src/big.py 90 150
assert_silent "non-numeric threshold -> silent" "$( ( cd "$R" && FILE_GROWTH_LINES=many bash "$HOOK" 2>/dev/null ) )"

# 17. The reporting path still exits 0.
assert_exit_zero "note path -> exit 0" "$SANDBOX/grown"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
