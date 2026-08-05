#!/usr/bin/env bash
set -eu

# Tests for block-pr-approve.sh.
# Runs in every repo; the hook is wired into all four entry points and is not
# tool-specific.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/block-pr-approve.sh"

PASS=0
FAIL=0

run_hook() {
  local rc=0
  printf '%s' "$1" | "$HOOK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

assert_blocked() {
  local rc; rc="$(run_hook "$2")"
  if [ "$rc" -eq 2 ]; then PASS=$((PASS + 1)); echo "  PASS: $1"
  else FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected exit 2, got $rc)"; fi
}

assert_allowed() {
  local rc; rc="$(run_hook "$2")"
  if [ "$rc" -eq 0 ]; then PASS=$((PASS + 1)); echo "  PASS: $1"
  else FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected exit 0, got $rc)"; fi
}

bash_payload() {
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"
}

# ── Shell route: blocked ──

echo "Shell route — approvals blocked:"

assert_blocked "gh pr review --approve" "$(bash_payload 'gh pr review --approve')"
assert_blocked "gh pr review 12 --approve" "$(bash_payload 'gh pr review 12 --approve')"
assert_blocked "approve with a body" \
  "$(bash_payload 'gh pr review 12 --approve --body "lgtm"')"
assert_blocked "bare gh pr review (interactive)" "$(bash_payload 'gh pr review')"
assert_blocked "bare review with a PR number" "$(bash_payload 'gh pr review 12')"
assert_blocked "irregular spacing" "$(bash_payload 'gh   pr    review  --approve')"
assert_blocked "compound command" \
  "$(bash_payload 'gh pr checks 12 && gh pr review 12 --approve')"
assert_blocked "absolute path to gh" \
  "$(bash_payload '/opt/homebrew/bin/gh pr review 4 --approve')"
assert_blocked "quoted wrapper" \
  "$(bash_payload 'bash -c "gh pr review 1 --approve"')"
assert_blocked "gh api POST to reviews endpoint" \
  "$(bash_payload 'gh api --method POST repos/o/n/pulls/12/reviews -f event=APPROVE')"

# ── Shell route: allowed ──
#
# Non-approving review types are not this hook's business. Neither is
# auto-approved in the permission defaults, so both still prompt.

echo "Shell route — non-approving review types allowed:"

assert_allowed "gh pr review --comment" \
  "$(bash_payload 'gh pr review 12 --comment --body "a note"')"
assert_allowed "gh pr review --request-changes" \
  "$(bash_payload 'gh pr review 12 --request-changes --body "please fix"')"

echo "Shell route — unrelated commands allowed:"

assert_allowed "gh pr view" "$(bash_payload 'gh pr view 12')"
assert_allowed "gh pr list" "$(bash_payload 'gh pr list')"
assert_allowed "gh pr create" "$(bash_payload 'gh pr create --title t --body b')"
assert_allowed "gh pr checks" "$(bash_payload 'gh pr checks 12')"
assert_allowed "gh api on a non-review endpoint" \
  "$(bash_payload 'gh api repos/o/n/pulls/12')"
assert_allowed "word ending in gh" "$(bash_payload 'highgh pr review --approve')"
assert_allowed "git commit" "$(bash_payload 'git commit -m test')"
assert_allowed "empty command" '{"tool_name":"Bash","tool_input":{}}'

# ── MCP route ──
#
# Fails closed: an absent or unrecognised event is treated as an approval.
# Guessing the other way is exactly how merge_pull_request passed the branch
# guards before it was gated.

echo "MCP route — approvals and unreadable events blocked:"

assert_blocked "create_pull_request_review event=APPROVE" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"APPROVE"}}'

assert_blocked "lowercase event" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"approve"}}'

assert_blocked "event absent (fails closed)" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1}}'

assert_blocked "unrecognised event (fails closed)" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"SIGN_OFF"}}'

assert_blocked "submit_pending_pull_request_review APPROVE" \
  '{"tool_name":"mcp__github__submit_pending_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"APPROVE"}}'

assert_blocked "Gemini single-underscore naming" \
  '{"tool_name":"mcp_github_create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"APPROVE"}}'

assert_blocked "third-party server prefix" \
  '{"tool_name":"mcp__acme_forge__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"APPROVE"}}'

echo "MCP route — non-approving reviews and other tools allowed:"

assert_allowed "create_pull_request_review event=COMMENT" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"COMMENT"}}'

assert_allowed "create_pull_request_review event=REQUEST_CHANGES" \
  '{"tool_name":"mcp__github__create_pull_request_review","tool_input":{"owner":"x","repo":"y","pullNumber":1,"event":"REQUEST_CHANGES"}}'

assert_allowed "create_pull_request" \
  '{"tool_name":"mcp__github__create_pull_request","tool_input":{"owner":"x","repo":"y","title":"t"}}'

assert_allowed "get_pull_request" \
  '{"tool_name":"mcp__github__get_pull_request","tool_input":{"owner":"x","repo":"y","pullNumber":1}}'

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
