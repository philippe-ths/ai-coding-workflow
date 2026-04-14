#!/usr/bin/env bash
set -eu

# Tests for Codex agent-level protected branch enforcement.
# Covers Path 1 (Shell/Bash via hooks.json → bash hook) and
# Path 2 (MCP via disabled_tools in config.toml).

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

BASH_HOOK="$ROOT_DIR/.ai-policy/hooks/block-protected-branch-bash.sh"
HOOKS_JSON="$ROOT_DIR/.codex/hooks.json"
CONFIG_TOML="$ROOT_DIR/.codex/config.toml"

# ── Prerequisite: config files exist ──

echo "Prerequisite checks:"

if [ -f "$HOOKS_JSON" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: .codex/hooks.json exists"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: .codex/hooks.json missing"
fi

if [ -f "$CONFIG_TOML" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: .codex/config.toml exists"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: .codex/config.toml missing"
fi

# ── Path 1: Shell/Bash blocking via hooks.json → bash hook ──

echo "Path 1 — Shell/Bash blocking (Codex PreToolUse → bash hook):"

# Verify hooks.json wires PreToolUse to the bash hook.
assert_contains "hooks.json references PreToolUse" "$HOOKS_JSON" '"PreToolUse"'
assert_contains "hooks.json references bash hook script" "$HOOKS_JSON" "block-protected-branch-bash.sh"

# Test the bash hook directly with Codex-format payloads.
# Simulate being on a protected branch by overriding current-branch.sh.
TMPDIR_TEST="$(mktemp -d)"
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
printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "git commit on main (simulated)" "$rc"

rc=0
printf '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_blocked "git push on main (simulated)" "$rc"

rc=0
printf '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "ls on main (simulated)" "$rc"

# --- Tests on feature branch ---
cp "$TMPDIR_TEST/current-branch-fake-feature.sh" "$REAL_SCRIPT"

rc=0
printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "git commit on feature/test (simulated)" "$rc"

rc=0
printf '{"tool_name":"Bash","tool_input":{"command":"git push origin feature/test"}}' \
  | "$BASH_HOOK" >/dev/null 2>&1 || rc=$?
assert_allowed "git push on feature/test (simulated)" "$rc"

# ── Path 2: MCP tool-blocking limitation warning via SessionStart hook ──

echo "Path 2 — MCP tool-blocking limitation (SessionStart warning hook):"

assert_contains "codex_hooks feature flag enabled" "$CONFIG_TOML" "codex_hooks = true"
assert_contains "hooks.json references SessionStart" "$HOOKS_JSON" '"SessionStart"'

WARNING_SCRIPT="$ROOT_DIR/.ai-policy/hooks/warn-codex-mcp-limitation.sh"
assert_contains "hooks.json references MCP warning script" "$HOOKS_JSON" "warn-codex-mcp-limitation.sh"

if [ -f "$WARNING_SCRIPT" ] && [ -x "$WARNING_SCRIPT" ]; then
  PASS=$((PASS + 1))
  echo "  PASS: MCP warning script exists and is executable"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: MCP warning script missing or not executable"
fi

WARNING_OUTPUT="$(bash "$WARNING_SCRIPT" 2>/dev/null)"
if echo "$WARNING_OUTPUT" | grep -qF "MCP tool blocking is NOT enforced"; then
  PASS=$((PASS + 1))
  echo "  PASS: warning script outputs MCP limitation message"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: warning script does not output expected message"
fi

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
