#!/usr/bin/env bash
set -eu

# Tests that a push targeting a protected branch is blocked regardless of
# which branch the pusher is standing on.
#
# Two layers are covered:
#   check-push-refs.sh          — authoritative, reads resolved refs
#   block-protected-branch-bash — heuristic, reads the command string
#
# Runs in every repo; neither layer is tool-specific.

ROOT_DIR="$(git rev-parse --show-toplevel)"
REFS_CHECK="$ROOT_DIR/.ai-policy/scripts/check-push-refs.sh"
BASH_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-bash.sh"

PASS=0
FAIL=0

judge() { # label, expected, actual
  if [ "$3" -eq "$2" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected exit $2, got $3)"
  fi
}

refs_exit() {
  local rc=0
  printf '%s\n' "$1" | "$REFS_CHECK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

cmd_exit() {
  local rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)" \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# ── Layer 1: check-push-refs.sh, the authoritative check ──
#
# Every case here is evaluated with no reference to the current branch, which
# is the whole point: these must block from a feature branch.

echo "check-push-refs.sh — protected targets blocked:"

judge "push to refs/heads/main" 2 \
  "$(refs_exit 'HEAD abc refs/heads/main def')"

judge "push to refs/heads/master" 2 \
  "$(refs_exit 'refs/heads/feature abc refs/heads/master def')"

judge "force-push to main (same ref shape)" 2 \
  "$(refs_exit 'refs/heads/feature abc refs/heads/main def')"

judge "delete remote main (zero local sha)" 2 \
  "$(refs_exit '(delete) 0000000000000000000000000000000000000000 refs/heads/main abc')"

judge "mixed refs, one protected" 2 \
  "$(printf 'refs/heads/feature abc refs/heads/feature def\nrefs/heads/main abc refs/heads/main def' | { rc=0; "$REFS_CHECK" >/dev/null 2>&1 || rc=$?; echo "$rc"; })"

echo "check-push-refs.sh — everything else allowed:"

judge "push to a feature branch" 0 \
  "$(refs_exit 'refs/heads/feature/x abc refs/heads/feature/x def')"

judge "tag push" 0 \
  "$(refs_exit 'refs/tags/v1.0.0 abc refs/tags/v1.0.0 0000000000000000000000000000000000000000')"

judge "tag deletion" 0 \
  "$(refs_exit '(delete) 0000000000000000000000000000000000000000 refs/tags/v1.0.0 abc')"

judge "branch whose name merely contains a protected name" 0 \
  "$(refs_exit 'refs/heads/mainline abc refs/heads/mainline def')"

judge "empty input" 0 "$(refs_exit '')"

# ── Layer 2: the command-string heuristic ──
#
# These run on whatever branch the suite happens to be on. Assertions are
# written so they hold either way: a protected refspec must block regardless,
# and the allowed cases are only asserted when the current branch is not
# protected (on a protected branch the current-branch rule blocks them, which
# is correct and is covered by the enforcement suites).

echo "block-protected-branch-bash — protected refspec blocked from any branch:"

judge "git push origin HEAD:main" 2 "$(cmd_exit 'git push origin HEAD:main')"
judge "git push origin main" 2 "$(cmd_exit 'git push origin main')"
judge "git push origin feature:main" 2 "$(cmd_exit 'git push origin feature:main')"
judge "git push --force origin HEAD:refs/heads/main" 2 \
  "$(cmd_exit 'git push --force origin HEAD:refs/heads/main')"
judge "git push origin +HEAD:main (force refspec)" 2 \
  "$(cmd_exit 'git push origin +HEAD:main')"
judge "git push origin :main (delete remote main)" 2 \
  "$(cmd_exit 'git push origin :main')"
judge "git push origin HEAD:master" 2 "$(cmd_exit 'git push origin HEAD:master')"
judge "git push origin main:refs/heads/main" 2 \
  "$(cmd_exit 'git push origin main:refs/heads/main')"

CURRENT_BRANCH="$("$ROOT_DIR/.ai-policy/scripts/current-branch.sh")"
IS_PROTECTED=false
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"
for protected in $PROTECTED_BRANCHES; do
  [ "$CURRENT_BRANCH" = "$protected" ] && IS_PROTECTED=true
done

if [ "$IS_PROTECTED" = "true" ]; then
  echo "block-protected-branch-bash — non-protected targets (skipped: on $CURRENT_BRANCH)"
else
  echo "block-protected-branch-bash — non-protected targets allowed (on $CURRENT_BRANCH):"

  judge "git push origin feature/x" 0 "$(cmd_exit 'git push origin feature/x')"
  judge "git push -u origin feature/x" 0 "$(cmd_exit 'git push -u origin feature/x')"
  judge "git push (no refspec)" 0 "$(cmd_exit 'git push')"
  judge "git push origin (remote only)" 0 "$(cmd_exit 'git push origin')"
  judge "branch merely containing a protected name" 0 \
    "$(cmd_exit 'git push origin HEAD:mainline')"
  judge "tag push still allowed" 0 "$(cmd_exit 'git push origin --tags')"
  judge "tag refspec still allowed" 0 \
    "$(cmd_exit 'git push origin refs/tags/v1.0.0')"
  judge "git push origin tag v1.0.0 still allowed" 0 \
    "$(cmd_exit 'git push origin tag v1.0.0')"
  judge "git commit untouched" 0 "$(cmd_exit 'git commit -m test')"
  judge "non-git command untouched" 0 "$(cmd_exit 'ls -la')"
fi

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
