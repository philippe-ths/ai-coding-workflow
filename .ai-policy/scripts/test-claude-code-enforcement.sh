#!/usr/bin/env bash
set -eu

# Tests for Claude Code agent-level protected branch enforcement.
# Covers Path 1 (Shell/Bash) and Path 2 (MCP).

ROOT_DIR="$(git rev-parse --show-toplevel)"
TMPDIR_TEST=""
REAL_SCRIPT="$ROOT_DIR/.ai-policy/scripts/current-branch.sh"

cleanup() {
  if [ -n "$TMPDIR_TEST" ] && [ -f "$TMPDIR_TEST/current-branch-backup.sh" ]; then
    cp "$TMPDIR_TEST/current-branch-backup.sh" "$REAL_SCRIPT"
  fi
  if [ -n "$TMPDIR_TEST" ] && [ -d "$TMPDIR_TEST" ]; then
    rm -rf "$TMPDIR_TEST"
  fi
}
trap cleanup EXIT
PASS=0
FAIL=0

assert_blocked() {
  local label="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 2 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected exit 2, got $exit_code)"
  fi
}

assert_allowed() {
  local label="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected exit 0, got $exit_code)"
  fi
}

MCP_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-mcp.sh"
BASH_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-bash.sh"

# ── Path 2: MCP tool blocking ──

echo "Path 2 — MCP tool blocking:"

# Test 1: push_files targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"main","owner":"x","repo":"y","files":[],"message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "push_files to main" "$rc"

# Test 2: create_or_update_file targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__create_or_update_file","tool_input":{"branch":"master","owner":"x","repo":"y","path":"f","content":"c","message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "create_or_update_file to master" "$rc"

# Test 3: delete_file targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__delete_file","tool_input":{"branch":"main","owner":"x","repo":"y","path":"f","message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "delete_file on main" "$rc"

# Test 4: create_pull_request with base=main → blocked
rc=0
printf '{"tool_name":"mcp__github__create_pull_request","tool_input":{"base":"main","head":"feature/x","owner":"x","repo":"y","title":"t"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "create_pull_request base=main" "$rc"

# Test 5: push_files targeting non-protected branch → allowed
rc=0
printf '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"feature/foo","owner":"x","repo":"y","files":[],"message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "push_files to feature/foo" "$rc"

# Test 6: merge_pull_request (no branch field) → allowed (limitation)
rc=0
printf '{"tool_name":"mcp__github__merge_pull_request","tool_input":{"owner":"x","repo":"y","pullNumber":1}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "merge_pull_request (no branch — known limitation)" "$rc"

# ── Path 1: Shell/Bash blocking ──

echo "Path 1 — Shell/Bash blocking:"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  # On a protected branch — commit and push should be blocked.

  # Test 7: git commit on protected branch → blocked
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_blocked "git commit on $CURRENT_BRANCH" "$rc"

  # Test 8: git push on protected branch → blocked
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_blocked "git push on $CURRENT_BRANCH" "$rc"

  # Test 9: non-git command on protected branch → allowed
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_allowed "ls on $CURRENT_BRANCH" "$rc"

else
  # On a non-protected branch — all should be allowed.

  # Test 7: git commit on non-protected branch → allowed
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_allowed "git commit on $CURRENT_BRANCH" "$rc"

  # Test 8: git push on non-protected branch → allowed
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"git push origin feature/x"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_allowed "git push on $CURRENT_BRANCH" "$rc"

  # Test 9: non-git command on non-protected branch → allowed
  rc=0
  printf '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
    | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
  assert_allowed "ls on $CURRENT_BRANCH" "$rc"
fi

# Test 10: Bash hook blocks git commit when current-branch.sh returns a protected name.
# We override the PATH to inject a fake current-branch.sh that returns "main".
TMPDIR_TEST="$(mktemp -d)"
cat > "$TMPDIR_TEST/current-branch.sh" <<'FAKE'
#!/usr/bin/env bash
echo "main"
FAKE
chmod +x "$TMPDIR_TEST/current-branch.sh"

# Temporarily replace the real script with the fake one.
cp "$REAL_SCRIPT" "$TMPDIR_TEST/current-branch-backup.sh"
cp "$TMPDIR_TEST/current-branch.sh" "$REAL_SCRIPT"

rc=0
printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?

assert_blocked "git commit when current-branch returns main (simulated)" "$rc"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
