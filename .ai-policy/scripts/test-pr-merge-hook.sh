#!/usr/bin/env bash
set -eu

# Tests for block-pr-merge.sh.
# Runs in every repo regardless of which agent entry points are installed,
# because the hook is wired into all four and is not tool-specific.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/block-pr-merge.sh"

PASS=0
FAIL=0

run_hook() {
  local rc=0
  printf '%s' "$1" | "$HOOK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

assert_blocked() {
  local label="$1" payload="$2" rc
  rc="$(run_hook "$payload")"
  if [ "$rc" -eq 2 ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected exit 2, got $rc)"
  fi
}

assert_allowed() {
  local label="$1" payload="$2" rc
  rc="$(run_hook "$payload")"
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected exit 0, got $rc)"
  fi
}

bash_payload() {
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"
}

mcp_payload() {
  printf '{"tool_name":"%s","tool_input":{"owner":"x","repo":"y","pullNumber":1}}' "$1"
}

# ── MCP route ──

echo "MCP route — merge tools blocked:"

assert_blocked "mcp__github__merge_pull_request" \
  "$(mcp_payload "mcp__github__merge_pull_request")"

# Gemini CLI normalises MCP tool names with single underscores.
assert_blocked "mcp_github_merge_pull_request (Gemini naming)" \
  "$(mcp_payload "mcp_github_merge_pull_request")"

assert_blocked "merge_pull_request under a third-party server prefix" \
  "$(mcp_payload "mcp__acme_forge__merge_pull_request")"

echo "MCP route — non-merge tools allowed:"

assert_allowed "mcp__github__create_pull_request" \
  "$(mcp_payload "mcp__github__create_pull_request")"

assert_allowed "mcp__github__get_pull_request" \
  "$(mcp_payload "mcp__github__get_pull_request")"

assert_allowed "mcp__github__push_files" \
  '{"tool_name":"mcp__github__push_files","tool_input":{"branch":"feature/x","owner":"x","repo":"y"}}'

# ── Shell route: blocked ──

echo "Shell route — merge commands blocked:"

assert_blocked "gh pr merge 773 --squash --delete-branch" \
  "$(bash_payload 'gh pr merge 773 --squash --delete-branch')"

assert_blocked "gh pr merge (bare)" \
  "$(bash_payload 'gh pr merge')"

assert_blocked "irregular spacing" \
  "$(bash_payload 'gh   pr    merge 1 --squash')"

assert_blocked "leading whitespace" \
  "$(bash_payload '   gh pr merge 5')"

assert_blocked "compound with &&" \
  "$(bash_payload 'git fetch origin && gh pr merge 12 --squash')"

assert_blocked "compound with ;" \
  "$(bash_payload 'echo start; gh pr merge 12')"

assert_blocked "piped into a subshell" \
  "$(bash_payload 'bash -c "gh pr merge 1 --squash"')"

assert_blocked "absolute path to gh" \
  "$(bash_payload '/opt/homebrew/bin/gh pr merge 4')"

assert_blocked "env prefix" \
  "$(bash_payload 'GH_TOKEN=abc gh pr merge 7 --merge')"

assert_blocked "gh api PUT to merge endpoint" \
  "$(bash_payload 'gh api --method PUT repos/owner/name/pulls/12/merge')"

assert_blocked "gh api -X PUT to merge endpoint" \
  "$(bash_payload 'gh api -X PUT /repos/owner/name/pulls/3/merge -f merge_method=squash')"

# ── Shell route: allowed ──

echo "Shell route — non-merge commands allowed:"

assert_allowed "gh pr view 1" "$(bash_payload 'gh pr view 1')"
assert_allowed "gh pr list" "$(bash_payload 'gh pr list --state open')"
assert_allowed "gh pr create" "$(bash_payload 'gh pr create --title t --body b')"
assert_allowed "gh pr diff" "$(bash_payload 'gh pr diff 3')"
assert_allowed "gh pr checkout" "$(bash_payload 'gh pr checkout 9')"
assert_allowed "gh pr status" "$(bash_payload 'gh pr status')"

# git's own merge is a local operation; the branch guard owns that path.
assert_allowed "git merge main" "$(bash_payload 'git merge main')"
assert_allowed "git commit" "$(bash_payload 'git commit -m test')"
assert_allowed "ls -la" "$(bash_payload 'ls -la')"

# gh api against a non-merge endpoint.
assert_allowed "gh api pulls/12 (no /merge)" \
  "$(bash_payload 'gh api repos/owner/name/pulls/12')"

# A longer word ending in "gh" must not trigger the boundary match.
assert_allowed "word ending in gh" \
  "$(bash_payload 'highgh pr merge')"

# Payload carrying no command at all.
assert_allowed "Bash payload with empty command" \
  '{"tool_name":"Bash","tool_input":{}}'

# ── Deliberate conservatism ──
#
# The shell match is textual, so a command that merely mentions the string is
# blocked too. This is an accepted false positive: the failure mode of letting
# a merge through is a production deploy, the failure mode of a false positive
# is a permission prompt. These assert the current behaviour so a future
# loosening of the pattern is a visible decision rather than a silent one.

echo "Conservative matches (accepted false positives):"

assert_blocked "grep for the literal string" \
  "$(bash_payload 'grep -r "gh pr merge" docs/')"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
