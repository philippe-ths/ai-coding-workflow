#!/usr/bin/env bash
set -eu

# Tests for the session-tags update + drift check.
# Builds a throwaway repo mirroring the rule-file layout, runs
# update-session-tags.sh, mutates a rule file, and verifies the
# --check mode detects drift.

ROOT_DIR="$(git rev-parse --show-toplevel)"
SRC_SCRIPT="$ROOT_DIR/.ai-policy/scripts/update-session-tags.sh"
SRC_HOOK="$ROOT_DIR/.ai-policy/hooks/check-session-tags.sh"

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
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

cd "$SANDBOX"
git init -q .
git checkout -q -b main 2>/dev/null || git symbolic-ref HEAD refs/heads/main
git config user.email "test@example.invalid"
git config user.name "Session Tags Hook Test"
git config commit.gpgsign false

mkdir -p .claude/skills/sample .ai-policy/hooks .ai-policy/scripts

cp "$SRC_SCRIPT" .ai-policy/scripts/update-session-tags.sh
cp "$SRC_HOOK" .ai-policy/hooks/check-session-tags.sh
chmod +x .ai-policy/scripts/update-session-tags.sh .ai-policy/hooks/check-session-tags.sh
SCRIPT="$SANDBOX/.ai-policy/scripts/update-session-tags.sh"
HOOK="$SANDBOX/.ai-policy/hooks/check-session-tags.sh"

cat > ai-workflow.md <<'EOF'
# AI Workflow

Version: 1.0.0

Body.
EOF

cat > CLAUDE.md <<'EOF'
Entry.
EOF

cat > .ai-policy/policy.env <<'EOF'
PROTECTED_BRANCHES="main"
EOF

cat > .ai-policy/hooks/sample.sh <<'EOF'
#!/usr/bin/env bash
true
EOF

cat > .claude/skills/sample/SKILL.md <<'EOF'
sample skill
EOF

cat > .claude/settings.json <<'EOF'
{
  "permissions": { "allow": [], "deny": [] }
}
EOF

git add -A
git commit -q -m "baseline"

echo "Session tags hook tests:"

# Case A: initial run populates OTEL_RESOURCE_ATTRIBUTES.
rc=0
"$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit "initial run writes tags" 0 "$rc"

attrs="$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES // ""' .claude/settings.json)"
if [ -n "$attrs" ] && echo "$attrs" | grep -Eq 'workflow_version=1\.0\.0,workflow_repo=ai-coding-workflow,ruleset_hash=[0-9a-f]{8}$'; then
  PASS=$((PASS + 1))
  echo "  PASS: tag format is correct ($attrs)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: tag format is wrong ($attrs)"
fi
FIRST_HASH="$(echo "$attrs" | sed -E 's/.*ruleset_hash=([0-9a-f]+)$/\1/')"

# Case B: post-write --check passes.
rc=0
"$SCRIPT" --check >/dev/null 2>&1 || rc=$?
assert_exit "check after write returns 0" 0 "$rc"

# Case C: --check via hook wrapper passes.
rc=0
"$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "hook wrapper returns 0 on clean tree" 0 "$rc"

# Case D: mutate a rule file without running update → --check fails.
cat > .ai-policy/hooks/sample.sh <<'EOF'
#!/usr/bin/env bash
# changed
true
EOF
rc=0
"$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "drift in rule file is blocked" 1 "$rc"

# Case E: re-run update, hash changes, --check passes again.
"$SCRIPT" >/dev/null 2>&1
new_attrs="$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES' .claude/settings.json)"
NEW_HASH="$(echo "$new_attrs" | sed -E 's/.*ruleset_hash=([0-9a-f]+)$/\1/')"
if [ "$NEW_HASH" != "$FIRST_HASH" ] && [ -n "$NEW_HASH" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: hash changed after rule-file change ($FIRST_HASH -> $NEW_HASH)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: hash did not change after rule-file change"
fi
rc=0
"$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "check after re-run returns 0" 0 "$rc"

# Case F: version bump without running update → --check fails.
sed -i.bak 's/Version: 1.0.0/Version: 1.1.0/' ai-workflow.md
rm -f ai-workflow.md.bak
rc=0
"$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "version bump without update is blocked" 1 "$rc"

# Case G: missing settings.json → exit 2.
rm .claude/settings.json
rc=0
"$SCRIPT" --check >/dev/null 2>&1 || rc=$?
assert_exit "missing settings.json returns 2" 2 "$rc"

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
