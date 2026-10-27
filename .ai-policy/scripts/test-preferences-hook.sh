#!/usr/bin/env bash
set -eu

# Tests for the SessionStart hook that loads the human's working preferences.
#
# The hook is advisory, so exit status carries no signal: it is 0 on every
# path. Behaviour is judged by stdout: the file's content, under a line naming
# where it came from, when the file has content, and nothing at all otherwise.
# Registration is checked too, because a hook that works and is not registered
# for a tool never runs there.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/load-preferences.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

run_hook() {
  AIW_PREFERENCES_FILE="$1" bash "$HOOK" </dev/null 2>/dev/null
}

echo "load-preferences hook:"
printf -- '- Always give the full pull request link.\n' > "$TMP/prefs.md"
out="$(run_hook "$TMP/prefs.md")"
if ! printf '%s' "$out" | grep -q 'Always give the full pull request link'; then
  fail "a preferences file has its content loaded (got: ${out:-<silence>})"
elif ! printf '%s' "$out" | grep -qF "$TMP/prefs.md"; then
  fail "the loaded content names the file it came from"
else
  pass "a preferences file has its content loaded, naming where it came from"
fi

out="$(run_hook "$TMP/absent.md")"
if [ -n "$out" ]; then fail "an absent file is silent (got: $out)"; else pass "an absent file is silent"; fi

printf '  \n\n' > "$TMP/blank.md"
out="$(run_hook "$TMP/blank.md")"
if [ -n "$out" ]; then fail "a blank file is silent (got: $out)"; else pass "a blank file is silent"; fi

mkdir -p "$TMP/home/.aiw" && printf -- '- default path works\n' > "$TMP/home/.aiw/preferences.md"
out="$(env -u AIW_PREFERENCES_FILE HOME="$TMP/home" bash "$HOOK" </dev/null 2>/dev/null)"
if printf '%s' "$out" | grep -q 'default path works'; then
  pass "with no override it reads ~/.aiw/preferences.md"
else
  fail "with no override it reads ~/.aiw/preferences.md (got: ${out:-<silence>})"
fi

echo "registration:"
for cfg in .claude/settings.json .codex/hooks.json; do
  if [ ! -f "$ROOT_DIR/$cfg" ]; then
    echo "  SKIP: $cfg not installed"
    continue
  fi
  # A matcher would skip some session starts, compaction among them.
  cmd="$(jq -r '[.hooks.SessionStart[]? | select(.matcher == null) | .hooks[]?.command | select(test("load-preferences\\.sh"))][0] // empty' "$ROOT_DIR/$cfg" 2>/dev/null)"
  if [ -z "$cmd" ]; then
    fail "$cfg does not register it under SessionStart for every source"
    continue
  fi
  # Run the registered command as the tool would, from the repository root.
  out="$( cd "$ROOT_DIR" && AIW_PREFERENCES_FILE="$TMP/prefs.md" bash -c "$cmd" </dev/null 2>/dev/null )"
  if printf '%s' "$out" | grep -q 'Always give the full pull request link'; then
    pass "$cfg registers it under SessionStart for every source, and the registered command runs"
  else
    fail "$cfg registered command loaded nothing: ${out:-<silence>}"
  fi
done

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
