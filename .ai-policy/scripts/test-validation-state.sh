#!/usr/bin/env bash
set -eu

# Tests for the validation gate: check-validation.sh, run-validation.sh,
# mark-validation-pass.sh, and tree-fingerprint.sh.
#
# The case this suite exists for is the stale pass: a result computed against an
# earlier working tree must not satisfy the gate for a later one. The gate fails
# in the reporting-green direction when it does, so the negative paths matter
# more here than the happy one.
#
# Runs in a sandbox repository so the real repository's state file is never
# touched.

ROOT_DIR="$(git rev-parse --show-toplevel)"
SRC="$ROOT_DIR/.ai-policy"
PASS=0
FAIL=0

assert_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected exit $expected, got $actual)"
  fi
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected '$expected', got '$actual')"
  fi
}

assert_ne() {
  local label="$1"
  local a="$2"
  local b="$3"
  if [ "$a" != "$b" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (both values were '$a')"
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  case "$haystack" in
    *"$needle"*)
      PASS=$((PASS + 1))
      echo "  PASS: $label"
      ;;
    *)
      FAIL=$((FAIL + 1))
      echo "  FAIL: $label (output did not mention '$needle')"
      ;;
  esac
}

SANDBOX="$(mktemp -d)"
# Kept outside SANDBOX: a nested repository inside it would break `git add -A`.
EMPTY_REPO="$(mktemp -d)"
trap 'rm -rf "$SANDBOX" "$EMPTY_REPO"' EXIT

cd "$SANDBOX"
git init -q -b feature/work .
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p .ai-policy/scripts .ai-policy/hooks .githooks

for s in check-validation.sh run-validation.sh mark-validation-pass.sh \
  mark-validation-fail.sh tree-fingerprint.sh check-protected-branch.sh \
  current-branch.sh; do
  cp "$SRC/scripts/$s" ".ai-policy/scripts/$s"
  chmod +x ".ai-policy/scripts/$s"
done

cp "$ROOT_DIR/.githooks/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit

cat > .ai-policy/policy.env <<'ENV'
PROTECTED_BRANCHES="main master"
REQUIRE_VALIDATION_BEFORE_COMMIT="true"
REQUIRE_VALIDATION_BEFORE_PUSH="true"
VALIDATION_STATE_FILE=".ai-policy/state/validation.status"
VALIDATION_COMMAND="true"
ENV

cat > .gitignore <<'IGN'
.ai-policy/state/validation.status
build-output.txt
IGN

echo "original" > source.txt
git add -A
git commit -qm "initial"

STATE=".ai-policy/state/validation.status"
CHECK=".ai-policy/scripts/check-validation.sh"
RUN=".ai-policy/scripts/run-validation.sh"
MARK_PASS=".ai-policy/scripts/mark-validation-pass.sh"
MARK_FAIL=".ai-policy/scripts/mark-validation-fail.sh"
FINGERPRINT=".ai-policy/scripts/tree-fingerprint.sh"

echo "Validation gate tests:"

# ── Fingerprint properties ──
# An unstable fingerprint would block every commit in every repository that
# installs this, so stability is checked before anything that depends on it.

fp1="$("$FINGERPRINT")"
fp2="$("$FINGERPRINT")"
assert_eq "fingerprint is stable across runs on an unchanged tree" "$fp1" "$fp2"

echo "changed" > source.txt
fp_modified="$("$FINGERPRINT")"
assert_ne "modifying a tracked file changes the fingerprint" "$fp1" "$fp_modified"

echo "original" > source.txt
assert_eq "reverting a modification restores the fingerprint" "$fp1" "$("$FINGERPRINT")"

echo "new" > untracked.txt
assert_ne "adding an untracked file changes the fingerprint" "$fp1" "$("$FINGERPRINT")"
rm untracked.txt

rm source.txt
assert_ne "deleting a tracked file changes the fingerprint" "$fp1" "$("$FINGERPRINT")"
git checkout -q -- source.txt

echo "noise" > build-output.txt
assert_eq "changing a gitignored file leaves the fingerprint alone" "$fp1" "$("$FINGERPRINT")"
rm build-output.txt

git mv source.txt renamed.txt
assert_ne "renaming a file changes the fingerprint" "$fp1" "$("$FINGERPRINT")"
git mv renamed.txt source.txt
git add -A

# ── Fingerprint boundaries ──

printf 'one' > "spaced name.txt"
fp_spaced="$("$FINGERPRINT")"
assert_ne "a filename with a space is covered" "$fp1" "$fp_spaced"
printf 'two' > "spaced name.txt"
assert_ne "editing a spaced filename moves the fingerprint" "$fp_spaced" "$("$FINGERPRINT")"
rm "spaced name.txt"

# git reports a path containing a control character in quoted form, which cannot
# be hashed. Producing a fingerprint anyway would silently omit that file's
# contents, so the script must refuse rather than understate the tree.
printf 'hostile' > "$(printf 'weird\nname.txt')"
rc=0
out="$("$FINGERPRINT" 2>&1)" || rc=$?
assert_ne "an unhashable filename fails closed rather than being skipped" "0" "$rc"
assert_contains "the refusal names the offending path" "weird" "$out"
rm "$(printf 'weird\nname.txt')"
assert_eq "removing it restores the fingerprint" "$fp1" "$("$FINGERPRINT")"

# A repository with no commits, and so nothing in the index.
mkdir -p "$EMPTY_REPO/.ai-policy/scripts"
git init -q "$EMPTY_REPO"
cp .ai-policy/policy.env "$EMPTY_REPO/.ai-policy/policy.env"
cp "$FINGERPRINT" "$EMPTY_REPO/.ai-policy/scripts/tree-fingerprint.sh"
chmod +x "$EMPTY_REPO/.ai-policy/scripts/tree-fingerprint.sh"
rc=0
(cd "$EMPTY_REPO" && ./.ai-policy/scripts/tree-fingerprint.sh >/dev/null 2>&1) || rc=$?
assert_exit "a repository with no commits still fingerprints" 0 "$rc"

# ── Gate: states that carry no tree ──

rm -f "$STATE"
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "absent state file blocks" 2 "$rc"

mkdir -p "$(dirname "$STATE")"
"$MARK_FAIL" >/dev/null
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "failed state blocks" 2 "$rc"

: > "$STATE"
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "empty state file blocks" 2 "$rc"

printf 'passed' > "$STATE"
printf 'passed extra-token %s\n' "$("$FINGERPRINT")" > "$STATE"
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "a malformed passed line blocks" 2 "$rc"

printf 'running' > "$STATE"
rc=0
out="$("$CHECK" 2>&1)" || rc=$?
assert_exit "running state blocks" 2 "$rc"
assert_contains "running state keeps its own message" "still running" "$out"

# A state file written by a version of this policy layer that predated
# fingerprinting carries a bare word. It cannot be tied to any tree, so it must
# fail closed rather than being trusted.
printf 'passed' > "$STATE"
rc=0
out="$("$CHECK" 2>&1)" || rc=$?
assert_exit "legacy bare 'passed' blocks" 2 "$rc"
assert_contains "legacy state explains itself" "run-validation.sh" "$out"

# ── Gate: the stale pass ──

rc=0
"$RUN" >/dev/null 2>&1 || rc=$?
assert_exit "run-validation succeeds when the command passes" 0 "$rc"

rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "fresh pass on an unchanged tree allows" 0 "$rc"

rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "reading the gate twice does not invalidate it" 0 "$rc"

echo "edited after validation ran" > source.txt
rc=0
out="$("$CHECK" 2>&1)" || rc=$?
assert_exit "pass computed against an earlier tree blocks" 2 "$rc"
assert_contains "stale block names the cause" "changed since validation" "$out"
assert_contains "stale block names the remedy" "run-validation.sh" "$out"

echo "original" > source.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "restoring the validated content allows again" 0 "$rc"

echo "appeared after validation ran" > added-later.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "a new untracked file blocks" 2 "$rc"
rm added-later.txt

echo "noise" > build-output.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "a changed gitignored file does not block" 0 "$rc"
rm build-output.txt

# The ordinary sequence is edit, validate, stage, commit, push. Neither staging
# nor committing changes what any file contains, so neither may invalidate a
# fresh pass. A gate that fires on the normal path gets routed around.
echo "ready to be committed" > source.txt
"$RUN" >/dev/null 2>&1

git add source.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "staging a validated change does not block" 0 "$rc"

git -c core.hooksPath=/dev/null commit -qm "committed mid-suite"
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "committing does not block the push that follows" 0 "$rc"

git -c core.hooksPath=/dev/null commit -q --amend -m "amended" --allow-empty
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "rewriting history without touching files does not block" 0 "$rc"

git rm -q source.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "a staged deletion still blocks" 2 "$rc"
git checkout -q HEAD -- source.txt || printf 'original' > source.txt
git add -A
"$RUN" >/dev/null 2>&1

# ── Gate: the manual override ──

echo "override this" > source.txt
"$MARK_PASS" >/dev/null
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "manual override allows for the tree it was set on" 0 "$rc"

echo "moved on again" > source.txt
rc=0
"$CHECK" >/dev/null 2>&1 || rc=$?
assert_exit "manual override does not survive a later edit" 2 "$rc"

# ── Runtime: a real commit through the real hook ──
# Exit codes from the check script alone would not show that the gate actually
# stops a commit, so this drives git itself.

git config core.hooksPath .githooks

before="$(git rev-parse HEAD)"

echo "staged while state is stale" > source.txt
git add source.txt
rc=0
out="$(git commit -m "should be blocked" 2>&1)" || rc=$?
assert_ne "git commit is blocked by a stale pass" "0" "$rc"
assert_contains "the blocked commit explains why" "changed since validation" "$out"
assert_eq "no commit object was created" "$before" "$(git rev-parse HEAD)"

"$RUN" >/dev/null 2>&1
rc=0
git commit -qm "allowed after revalidating" 2>&1 || rc=$?
assert_exit "git commit succeeds once validation matches the tree" 0 "$rc"
assert_ne "the commit landed" "$before" "$(git rev-parse HEAD)"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
