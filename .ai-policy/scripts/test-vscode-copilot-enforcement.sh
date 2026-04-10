#!/usr/bin/env bash
set -eu

# Tests for VS Code Copilot agent-level protected branch enforcement.
# Covers Path 1 (Shell/Bash via PreToolUse → bash hook) and
# Path 2 (MCP via PreToolUse → mcp hook).

ROOT_DIR="$(git rev-parse --show-toplevel)"
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

assert_contains() {
  local label="$1"
  local file="$2"
  local expected="$3"
  if grep -qF "$expected" "$file"; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected '$expected' in $file)"
  fi
}

HOOK_JSON="$ROOT_DIR/.github/hooks/block-protected-branch.json"
MCP_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-mcp.sh"
BASH_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-bash.sh"

# ── Prerequisite: config file exists and is valid JSON ──

echo "Prerequisite checks:"

if [ -f "$HOOK_JSON" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: .github/hooks/block-protected-branch.json exists"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: .github/hooks/block-protected-branch.json missing"
fi

if jq empty "$HOOK_JSON" 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  PASS: hook config is valid JSON"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: hook config is not valid JSON"
fi

assert_contains "hook config references PreToolUse" "$HOOK_JSON" '"PreToolUse"'
assert_contains "hook config references MCP hook script" "$HOOK_JSON" "block-protected-branch-mcp.sh"
assert_contains "hook config references bash hook script" "$HOOK_JSON" "block-protected-branch-bash.sh"

# ── Path 2: MCP tool blocking via PreToolUse → mcp hook ──

echo "Path 2 — MCP tool blocking (PreToolUse → mcp hook):"

# Test: push_files targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"main","owner":"x","repo":"y","files":[],"message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "push_files to main" "$rc"

# Test: create_or_update_file targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__create_or_update_file","tool_input":{"branch":"master","owner":"x","repo":"y","path":"f","content":"c","message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "create_or_update_file to master" "$rc"

# Test: delete_file targeting protected branch → blocked
rc=0
printf '{"tool_name":"mcp__github__delete_file","tool_input":{"branch":"main","owner":"x","repo":"y","path":"f","message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "delete_file on main" "$rc"

# Test: create_pull_request with base=main → blocked
rc=0
printf '{"tool_name":"mcp__github__create_pull_request","tool_input":{"base":"main","head":"feature/x","owner":"x","repo":"y","title":"t"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "create_pull_request base=main" "$rc"

# Test: push_files targeting non-protected branch → allowed
rc=0
printf '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"feature/foo","owner":"x","repo":"y","files":[],"message":"m"}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "push_files to feature/foo" "$rc"

# Test: merge_pull_request (no branch field) → allowed (known limitation)
rc=0
printf '{"tool_name":"mcp__github__merge_pull_request","tool_input":{"owner":"x","repo":"y","pullNumber":1}}' \
  | "$MCP_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "merge_pull_request (no branch — known limitation)" "$rc"

# ── Path 1: Shell/Bash blocking via PreToolUse → bash hook ──

echo "Path 1 — Shell/Bash blocking (PreToolUse → bash hook):"

# Use simulated branch to test both protected and non-protected scenarios.
TMPDIR_TEST="$(mktemp -d)"
REAL_SCRIPT="$ROOT_DIR/.ai-policy/scripts/current-branch.sh"
cp "$REAL_SCRIPT" "$TMPDIR_TEST/current-branch-backup.sh"

# Override to return "main".
cat > "$TMPDIR_TEST/current-branch-fake-main.sh" <<'FAKE'
#!/usr/bin/env bash
echo "main"
FAKE
chmod +x "$TMPDIR_TEST/current-branch-fake-main.sh"

# Override to return a feature branch.
cat > "$TMPDIR_TEST/current-branch-fake-feature.sh" <<'FAKE'
#!/usr/bin/env bash
echo "feature/test"
FAKE
chmod +x "$TMPDIR_TEST/current-branch-fake-feature.sh"

# --- Tests on protected branch ---
cp "$TMPDIR_TEST/current-branch-fake-main.sh" "$REAL_SCRIPT"

rc=0
printf '{"tool_name":"run_in_terminal","tool_input":{"command":"git commit -m test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "git commit on main (simulated)" "$rc"

rc=0
printf '{"tool_name":"run_in_terminal","tool_input":{"command":"git push origin main"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "git push on main (simulated)" "$rc"

rc=0
printf '{"tool_name":"run_in_terminal","tool_input":{"command":"ls -la"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "ls on main (simulated)" "$rc"

# --- Tests on feature branch ---
cp "$TMPDIR_TEST/current-branch-fake-feature.sh" "$REAL_SCRIPT"

rc=0
printf '{"tool_name":"run_in_terminal","tool_input":{"command":"git commit -m test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "git commit on feature/test (simulated)" "$rc"

rc=0
printf '{"tool_name":"run_in_terminal","tool_input":{"command":"git push origin feature/test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "git push on feature/test (simulated)" "$rc"

# Restore real script.
cp "$TMPDIR_TEST/current-branch-backup.sh" "$REAL_SCRIPT"
rm -rf "$TMPDIR_TEST"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
