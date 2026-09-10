#!/usr/bin/env bash
set -eu

# Tests that a push publishing content validation never read is blocked.
#
# check-validation.sh asks whether a pass was recorded against the working tree.
# check-push-content.sh asks whether that working tree is what the push
# publishes. This suite covers the second question only; the first has its own
# suite in test-validation-state.sh.
#
# Every case runs against a throwaway repository, so the suite never depends on
# the state of the repository it is run from.
#
# Runs in every repo; the layer is not tool-specific.

ROOT_DIR="$(git rev-parse --show-toplevel)"
CHECK="$ROOT_DIR/.ai-policy/scripts/check-push-content.sh"
HOOK="$ROOT_DIR/.githooks/pre-push"

PASS=0
FAIL=0

judge() { # label, expected, actual
  if [ "$3" -eq "$2" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected exit $2, got $3)"
  fi
}

judge_says() { # label, needle, haystack
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); echo "  PASS: $1" ;;
    *) FAIL=$((FAIL + 1)); echo "  FAIL: $1 (output did not mention '$2')" ;;
  esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REPO="$WORK/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name Test
echo one > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
git -C "$REPO" commit -qm first

HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
OTHER_SHA="$(printf 'x' | git -C "$REPO" hash-object -w --stdin)"
ZERO=0000000000000000000000000000000000000000

check_exit() { # refs
  local rc=0
  ( cd "$REPO" && printf '%s\n' "$1" | "$CHECK" >/dev/null 2>&1 ) || rc=$?
  echo "$rc"
}

check_out() { # refs
  ( cd "$REPO" && printf '%s\n' "$1" | "$CHECK" 2>&1 ) || true
}

clean_tree() {
  git -C "$REPO" reset -q --hard HEAD
  git -C "$REPO" clean -qfd
}

PUSH_HEAD="refs/heads/main $HEAD_SHA refs/heads/main $ZERO"

# ── The normal path must not fire ──
#
# A gate that blocks the ordinary commit-then-push sequence gets routed around,
# so these matter as much as the refusals.

echo "check-push-content.sh — a clean tree pushing its own HEAD is allowed:"

clean_tree
judge "push HEAD from a clean tree" 0 "$(check_exit "$PUSH_HEAD")"

judge "empty input" 0 "$(check_exit '')"

# An untracked file is not published by the push, so it is not this check's
# business. tree-fingerprint.sh already covers it for the question
# check-validation.sh asks, and refusing here would fire on every stray file.
echo scratch > "$REPO/untracked.txt"
judge "untracked file present" 0 "$(check_exit "$PUSH_HEAD")"
clean_tree

echo "check-push-content.sh — pushes publishing no content are unaffected:"

echo two > "$REPO/tracked.txt"
judge "tag-only push with a dirty tree" 0 \
  "$(check_exit "refs/tags/v1 $HEAD_SHA refs/tags/v1 $ZERO")"
judge "delete-only push with a dirty tree" 0 \
  "$(check_exit "(delete) $ZERO refs/heads/gone $HEAD_SHA")"
clean_tree

# ── Shape one: the tree has come apart from the commit ──
#
# This is the incident. Validation read the fix; the push published the commit
# that did not carry it.

echo "check-push-content.sh — a tree that is not the commit is blocked:"

echo two > "$REPO/tracked.txt"
judge "unstaged change to a tracked file" 2 "$(check_exit "$PUSH_HEAD")"

git -C "$REPO" add tracked.txt
judge "staged change to a tracked file (the recorded incident)" 2 \
  "$(check_exit "$PUSH_HEAD")"
judge_says "names the path that was left behind" "tracked.txt" \
  "$(check_out "$PUSH_HEAD")"
clean_tree

git -C "$REPO" rm -q tracked.txt
judge "tracked file deleted from the tree" 2 "$(check_exit "$PUSH_HEAD")"
clean_tree

# ── Shape two: the ref is not the commit that was validated ──
#
# The fingerprint can match perfectly and still say nothing about the content of
# a branch that is not checked out.

echo "check-push-content.sh — a ref that is not HEAD is blocked:"

judge "clean tree, pushing some other commit" 2 \
  "$(check_exit "refs/heads/other $OTHER_SHA refs/heads/other $ZERO")"
judge_says "names both shas" "$OTHER_SHA" \
  "$(check_out "refs/heads/other $OTHER_SHA refs/heads/other $ZERO")"

judge "a tag alongside HEAD is still allowed" 0 \
  "$(check_exit "$(printf 'refs/tags/v1 %s refs/tags/v1 %s\n%s' "$HEAD_SHA" "$ZERO" "$PUSH_HEAD")")"

judge "a tag alongside a foreign ref is blocked" 2 \
  "$(check_exit "$(printf 'refs/tags/v1 %s refs/tags/v1 %s\nrefs/heads/other %s refs/heads/other %s' "$HEAD_SHA" "$ZERO" "$OTHER_SHA" "$ZERO")")"

# ── The state file is not a change ──
#
# A repository that has not gitignored the validation state file has a dirty
# tree the instant validation passes, because the pass is written into it. If
# that counted, the gate would refuse every ordinary push. tree-fingerprint.sh
# excludes it for the same reason.

echo "check-push-content.sh — a tracked validation state file is not a change:"

POLICY_REPO="$WORK/policy-repo"
mkdir -p "$POLICY_REPO/.ai-policy/state"
git -C "$POLICY_REPO" init -q
git -C "$POLICY_REPO" config user.email test@example.com
git -C "$POLICY_REPO" config user.name Test
printf 'VALIDATION_STATE_FILE=".ai-policy/state/validation.status"\n' \
  > "$POLICY_REPO/.ai-policy/policy.env"
echo one > "$POLICY_REPO/tracked.txt"
echo "passed abc" > "$POLICY_REPO/.ai-policy/state/validation.status"
git -C "$POLICY_REPO" add -A
git -C "$POLICY_REPO" commit -qm first
POLICY_HEAD="$(git -C "$POLICY_REPO" rev-parse HEAD)"
POLICY_PUSH="refs/heads/main $POLICY_HEAD refs/heads/main $ZERO"

policy_exit() {
  local rc=0
  ( cd "$POLICY_REPO" && printf '%s\n' "$1" | "$CHECK" >/dev/null 2>&1 ) || rc=$?
  echo "$rc"
}

echo "passed def" > "$POLICY_REPO/.ai-policy/state/validation.status"
judge "the state file alone moved" 0 "$(policy_exit "$POLICY_PUSH")"

echo two > "$POLICY_REPO/tracked.txt"
judge "a real change alongside it is still blocked" 2 "$(policy_exit "$POLICY_PUSH")"

# ── Wiring ──
#
# The check is only worth anything if the hook runs it, and runs it with the
# refs. Asserted against the hook's text: standing up a whole policy install in
# a throwaway repo to drive the real hook is what test-pre-push-hook.sh does,
# and this only needs to know the call exists and is fed.

echo "pre-push wiring:"

WIRED=1
grep -q 'check-push-content.sh' "$HOOK" && WIRED=0
judge "pre-push invokes check-push-content.sh" 0 "$WIRED"

FED=1
grep -q 'PUSH_REFS" | "\$ROOT_DIR/.ai-policy/scripts/check-push-content.sh"' "$HOOK" && FED=0
judge "pre-push feeds it the pushed refs" 0 "$FED"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
