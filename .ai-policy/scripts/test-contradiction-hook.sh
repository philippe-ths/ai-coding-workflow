#!/usr/bin/env bash
set -eu

# Tests for the UserPromptSubmit hook that asks whether the human's message
# contradicts delivered work.
#
# The hook is advisory, so exit status carries no signal: it is 0 on every
# path. Behaviour is judged by stdout: a UserPromptSubmit payload carrying the
# note for any message with content, and nothing at all for an empty message or
# a payload it cannot read. Registration is checked too, because a hook that
# works and is not registered for a tool never runs there.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/ask-contradiction.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

run_hook() {
  printf '%s' "$1" | bash "$HOOK" 2>/dev/null
}

# assert_note <label> <payload>
assert_note() {
  local out
  out="$(run_hook "$2")"
  if [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)" != "UserPromptSubmit" ]; then
    fail "$1 (expected a UserPromptSubmit payload, got: ${out:-<silence>})"
  elif ! printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'aiw-failure-analysis'; then
    fail "$1 (note does not name aiw-failure-analysis)"
  else
    pass "$1"
  fi
}

# assert_silent <label> <payload>
assert_silent() {
  local out
  out="$(run_hook "$2")"
  if [ -n "$out" ]; then fail "$1 (expected silence, got: $out)"; else pass "$1"; fi
}

echo "ask-contradiction hook:"
assert_note "a contradiction gets the note" '{"prompt":"it still just shows hours. Wheres km?"}'
assert_note "a new request gets the note too, since the agent decides" '{"prompt":"now add multiply"}'
assert_silent "an empty message is silent" '{"prompt":""}'
assert_silent "a whitespace-only message is silent" '{"prompt":"  \n "}'
assert_silent "a payload with no prompt is silent" '{"session_id":"x"}'
assert_silent "an unreadable payload is silent" 'not json'

echo "registration:"
for cfg in .claude/settings.json .codex/hooks.json; do
  if [ ! -f "$ROOT_DIR/$cfg" ]; then
    echo "  SKIP: $cfg not installed"
    continue
  fi
  if jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | select(test("ask-contradiction\\.sh"))' "$ROOT_DIR/$cfg" >/dev/null 2>&1; then
    pass "$cfg registers it under UserPromptSubmit"
  else
    fail "$cfg does not register it under UserPromptSubmit"
  fi
done

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
