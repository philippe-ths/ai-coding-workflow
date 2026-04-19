#!/usr/bin/env bash
set -eu

# Tests for the git-level pre-push hook's tag-vs-branch discrimination.
# Sets up a sandbox with stub dependency scripts so only .githooks/pre-push's
# own logic is exercised.

ROOT_DIR="$(git rev-parse --show-toplevel)"
SRC_PRE_PUSH="$ROOT_DIR/.githooks/pre-push"
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

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

cd "$SANDBOX"
git init -q .

mkdir -p .githooks .ai-policy/scripts .ai-policy/hooks

cp "$SRC_PRE_PUSH" .githooks/pre-push
chmod +x .githooks/pre-push

# Stub: check-protected-branch.sh simulates "on protected branch" by exiting 2.
# The pre-push hook MUST NOT invoke this for tag-only pushes.
cat > .ai-policy/scripts/check-protected-branch.sh <<'STUB'
#!/usr/bin/env bash
echo "STUB: check-protected-branch invoked" >&2
exit 2
STUB
chmod +x .ai-policy/scripts/check-protected-branch.sh

# Stub: check-validation.sh — not invoked because REQUIRE_VALIDATION_BEFORE_PUSH=false.
cat > .ai-policy/scripts/check-validation.sh <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x .ai-policy/scripts/check-validation.sh

# Stub: check-changelog.sh — always exits 0 for these tests.
cat > .ai-policy/hooks/check-changelog.sh <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
exit 0
STUB
chmod +x .ai-policy/hooks/check-changelog.sh

cat > .ai-policy/policy.env <<'ENV'
PROTECTED_BRANCHES="main master"
VALIDATION_STATE_FILE=".ai-policy/state/validation.status"
REQUIRE_VALIDATION_BEFORE_PUSH=false
VALIDATION_COMMAND="./.ai-policy/scripts/run-validation.sh"
ENV

HOOK="$SANDBOX/.githooks/pre-push"

echo "Pre-push hook tag vs branch tests:"

# 1. Tag-only push — must skip protected-branch check → exit 0.
rc=0
printf 'refs/tags/v1.0.0 abc refs/tags/v1.0.0 0000000000000000000000000000000000000000\n' \
  | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "tag-only push skips branch check" 0 "$rc"

# 2. Multiple tag refs — still tag-only → exit 0.
rc=0
{
  printf 'refs/tags/v1.0.0 abc refs/tags/v1.0.0 0000000000000000000000000000000000000000\n'
  printf 'refs/tags/v1.1.0 def refs/tags/v1.1.0 0000000000000000000000000000000000000000\n'
} | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "multiple tag refs skip branch check" 0 "$rc"

# 3. Branch push — must invoke branch check (stub exits 2) → exit 2.
rc=0
printf 'refs/heads/main abc refs/heads/main def\n' \
  | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "branch push invokes branch check" 2 "$rc"

# 4. Mixed tag and branch refs — must invoke branch check → exit 2.
rc=0
{
  printf 'refs/tags/v1.0.0 abc refs/tags/v1.0.0 0000000000000000000000000000000000000000\n'
  printf 'refs/heads/main abc refs/heads/main def\n'
} | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "mixed refs invoke branch check" 2 "$rc"

# 5. HEAD:refs/heads/main style refspec — treated as branch ref → exit 2.
rc=0
printf 'HEAD abc refs/heads/main def\n' \
  | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "HEAD:refs/heads/main invokes branch check" 2 "$rc"

# 6. Delete a tag remotely (local_ref empty, remote_ref is tag) — still tag-only.
rc=0
printf '(delete) 0000000000000000000000000000000000000000 refs/tags/v1.0.0 abc\n' \
  | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "tag deletion skips branch check" 0 "$rc"

# 7. Empty stdin — no refs → falls through to branch check → exit 2.
rc=0
printf '' | "$HOOK" origin git@example:foo.git >/dev/null 2>&1 || rc=$?
assert_exit "empty stdin invokes branch check" 2 "$rc"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
