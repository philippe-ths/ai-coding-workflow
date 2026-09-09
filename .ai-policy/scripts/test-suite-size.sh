#!/usr/bin/env bash
set -eu

# Tests for report-suite-size.sh.
#
# It reports and never gates, so the risk is not a wrong verdict but a wrong
# number: a count that quietly misses files reads as a healthy repository. The
# cases here are the ways the count can be silently short.

ROOT_DIR="$(git rev-parse --show-toplevel)"
PASS=0
FAIL=0

assert_contains() {
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); echo "  PASS: $1" ;;
    *) FAIL=$((FAIL + 1)); echo "  FAIL: $1 (output was '$3')" ;;
  esac
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
cd "$SANDBOX"
git init -q -b main .
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p .ai-policy/scripts tests
cp "$ROOT_DIR/.ai-policy/scripts/report-suite-size.sh" .ai-policy/scripts/
chmod +x .ai-policy/scripts/report-suite-size.sh
REPORT=".ai-policy/scripts/report-suite-size.sh"
printf 'PROTECTED_BRANCHES="main"\n' > .ai-policy/policy.env

# 100 bytes per file, so every total below is arithmetic rather than luck.
make_file() { local i=0; : > "$1"; while [ "$i" -lt 10 ]; do printf '0123456789\n' >> "$1"; i=$((i + 1)); done; }

echo "Suite size report tests:"

make_file tests/a.sh
assert_contains "counts a tracked check" "1 files, 110 bytes" "$("$REPORT")"
assert_contains "says which pattern set it used" "conventional defaults" "$("$REPORT")"

git add -A && git commit -qm base
assert_contains "committing does not change the count" "1 files, 110 bytes" "$("$REPORT")"

# An unstaged check is still a check in this tree.
make_file tests/b.sh
assert_contains "counts an untracked check" "2 files, 220 bytes" "$("$REPORT")"

printf 'tests/ignored_test.sh\n' > .gitignore
make_file tests/ignored_test.sh
assert_contains "an ignored file is not counted" "2 files, 220 bytes" "$("$REPORT")"

# git C-quotes this path, which a line-based reader drops without a word.
make_file "tests/café_test.sh"
assert_contains "a filename git quotes is still counted" "3 files, 330 bytes" "$("$REPORT")"

make_file "tests/two words_test.sh"
assert_contains "a filename with a space is counted" "4 files, 440 bytes" "$("$REPORT")"

# A symlink is why the byte count cannot be gated on: it measures as its target
# here and as the link string in git. Counting it once is all that is claimed.
ln -s a.sh tests/link_test.sh
assert_contains "a symlinked check does not crash the count" "5 files" "$("$REPORT")"

mkdir -p checks
make_file checks/custom.sh
assert_contains "a path outside the conventions is not counted by default" "5 files" "$("$REPORT")"

printf 'PROTECTED_BRANCHES="main"\nSUITE_PATHS="checks/*"\n' > .ai-policy/policy.env
assert_contains "a declared path is counted instead" "1 files, 110 bytes" "$("$REPORT")"
assert_contains "declared paths are named as the source" "declared in policy.env" "$("$REPORT")"

printf 'PROTECTED_BRANCHES="main"\nSUITE_PATHS="no-such-dir/*"\n' > .ai-policy/policy.env
assert_contains "patterns matching nothing report zero rather than failing" "0 files, 0 bytes" "$("$REPORT")"

# Validation must not die because the check cannot ask its question.
NOGIT="$(mktemp -d)"
REPORT_ABS="$SANDBOX/$REPORT"
cd "$NOGIT"
assert_contains "outside a git work tree it says so and exits 0" "not measured" "$("$REPORT_ABS" 2>&1)"
cd "$SANDBOX"
rm -rf "$NOGIT"

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."
[ "$FAIL" -gt 0 ] && exit 1
exit 0
