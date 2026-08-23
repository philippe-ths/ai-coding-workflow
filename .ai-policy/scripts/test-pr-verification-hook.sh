#!/usr/bin/env bash
set -eu

# Tests for check-pr-verification.sh.
# Runs in every repo regardless of which agent entry points are installed,
# because the hook is wired into all four and is not tool-specific.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/check-pr-verification.sh"

PASS=0
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

body_file() {
  local path="$TMP/$1"; shift
  printf '%s\n' "$@" > "$path"
  echo "$path"
}

# ── Bodies that must pass ──
#
# These are excerpts from pull requests merged into this repository, kept as
# real captures rather than invented examples: the hook's whole risk is firing
# on the normal path, and only real bodies establish what the normal path looks
# like. Provenance: PRs #206, #219 and #222 of philippe-ths/ai-coding-workflow,
# captured 2026-08-21. The full run of twenty merged bodies was checked against
# the hook when it was written; these three are the shapes that matter.

echo "Real merged pull request bodies pass:"

REAL_206="$(body_file real206.md \
  "Closes #205." "" \
  "The state file recorded a bare 'passed' with nothing tying it to the content that" \
  "produced it, so an hour-old result satisfied the commit and push gates." "" \
  "Covered by test-validation-state.sh, which drives a real git commit through the real" \
  "hook rather than asserting on exit codes alone.")"
assert_allowed "a body describing tests and coverage" \
  "$(bash_payload "gh pr create --title x --body-file $REAL_206")"

REAL_219="$(body_file real219.md \
  "Closes #211." "" \
  "## Verification — and the honest result" "" \
  "Policy-layer and repo validation pass: 29/29 enforcement, 26/26 observation install." "" \
  "**The behavioural A/B did not detect an effect.** Two scenarios, two runs per arm." "" \
  "**Also not verified:** no automated test covers skill prose, so nothing will catch a" \
  "future edit that undoes this.")"
assert_allowed "a body declaring an unverified surface with no issue number" \
  "$(bash_payload "gh pr create --title x --body-file $REAL_219")"

REAL_222="$(body_file real222.md \
  "Closes #208." "" \
  "**Not verified:** N=2 per arm on one discriminating scenario. Nothing enforces this." "" \
  "A second subsection separates a surface that was not checked from a surface that does" \
  "not exist, and one pull request in the dataset reads 'Not verified: nothing'.")"
assert_allowed "a body quoting the bare form while discussing it" \
  "$(bash_payload "gh pr create --title x --body-file $REAL_222")"

# ── Bodies that must block ──

echo "Bodies without a justification are blocked:"

assert_blocked "no verification content at all" \
  "$(bash_payload 'gh pr create --title x --body "Fixes the typo in the header."')"

assert_blocked "an empty body" \
  "$(bash_payload 'gh pr create --title x --body ""')"

echo "A bare assertion under a heading is blocked (#235):"
# Every one of the twenty-five most recent merged bodies here that declares an
# unverified surface puts it under a heading or a bold lead-in, so matching only
# the single-line form caught the shape nobody writes.
assert_blocked "a heading with the bare word beneath it" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h1.md 'Tests pass.' '' '## What was not checked' '' 'Nothing.')")"
assert_blocked "a bold lead-in with the bare word beneath it" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h2.md 'Tests pass.' '' '**Not verified:**' '' 'None')")"
assert_blocked "a numbered heading ending in punctuation" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h3.md 'Tests pass.' '' '**3. What was not checked.**' '' 'Nothing.')")"
assert_blocked "a heading separated by several blank lines" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h4.md 'Tests pass.' '' '## Still not checked' '' '' '' 'n/a')")"

# Folding a line onto the next cannot invent a match: the pattern anchors the
# bare word to the end of the line, so a real declaration that merely opens
# with one of those words still has content after it.
assert_allowed "a section opening with None but continuing" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h5.md 'Tests pass.' '' '## What was not checked' '' 'None of the sync paths were exercised, so a regression there would not be caught.')")"
assert_allowed "a section opening with Nothing but continuing" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h6.md 'Tests pass.' '' '## What was not checked' '' 'Nothing changed at runtime, so there is no path to exercise.')")"
assert_allowed "a real declaration under a heading" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h7.md 'Tests pass.' '' '## What was not checked' '' 'The four tools were not driven; only configuration was asserted.')")"

echo "A bare assertion in place of part 3 is blocked:"

for bare in "Not verified: nothing" "**Not verified:** none" "- not checked: n/a" "Unverified: nil" "Not verified: -"; do
  P="$(body_file "bare$(printf '%s' "$bare" | tr -cd '[:alnum:]').md" "Ran the suite, all green." "" "$bare")"
  assert_blocked "$bare" "$(bash_payload "gh pr create --title x --body-file $P")"
done

echo "A justified empty part 3 is allowed:"

OK_EMPTY="$(body_file okempty.md "Fixed a typo in a code comment." "" \
  "Not verified: nothing, because this changes no runtime path and there is nothing to exercise.")"
assert_allowed "nothing to check, with the reason given" \
  "$(bash_payload "gh pr create --title x --body-file $OK_EMPTY")"

# ── Reading the body ──

echo "A body the hook cannot read is blocked, not passed over:"

assert_blocked "no body flag at all (editor session)" \
  "$(bash_payload 'gh pr create --title x')"

assert_blocked "--fill, body derived from commit messages" \
  "$(bash_payload 'gh pr create --title x --fill')"

assert_blocked "--body-file naming a path that does not exist" \
  "$(bash_payload "gh pr create --title x --body-file $TMP/absent.md")"

# This hook runs before the command does, so a path it cannot resolve is not a
# path it may assume is fine. Both shapes below look like working commands, and
# both were found by running the hook against this repository's own workflow
# rather than by imagining what might go wrong.

assert_blocked "--body-file built from a shell variable the hook cannot expand" \
  "$(bash_payload 'gh pr create --title x --body-file $SCRATCH/body.md')"

assert_blocked "--body-file naming a file the same command is about to write" \
  "$(bash_payload "printf 'Ran the suite, green.' > $TMP/later.md
gh pr create --title x --body-file $TMP/later.md")"

# ── Scope ──

echo "Actions that carry no pull request body are untouched:"

OK_BODY="$(body_file okbody.md "Ran the full suite; green. Not verified: the mobile layout, no device to hand.")"

assert_allowed "gh pr edit that does not touch the body" \
  "$(bash_payload 'gh pr edit 12 --add-label chore')"
assert_allowed "gh pr list" "$(bash_payload 'gh pr list --state open')"
assert_allowed "an unrelated git command" "$(bash_payload 'git push origin feature/x')"
assert_allowed "gh pr edit replacing the body with a justified one" \
  "$(bash_payload "gh pr edit 12 --body-file $OK_BODY")"
assert_blocked "gh pr edit replacing the body with an unjustified one" \
  "$(bash_payload 'gh pr edit 12 --body "Tidied the wording."')"

# ── MCP route ──

echo "MCP route:"

mcp_payload() {
  printf '{"tool_name":"%s","tool_input":{"owner":"x","repo":"y","title":"t","body":%s}}' \
    "$1" "$(printf '%s' "$2" | jq -Rs .)"
}

assert_allowed "create_pull_request with a justification" \
  "$(mcp_payload "mcp__github__create_pull_request" "Ran the suite, green. Not verified: the mobile layout.")"
assert_blocked "create_pull_request with no justification" \
  "$(mcp_payload "mcp__github__create_pull_request" "Fixes the typo.")"
assert_blocked "create_pull_request under a third-party server prefix" \
  "$(mcp_payload "mcp__acme_forge__create_pull_request" "Fixes the typo.")"
assert_blocked "create_pull_request with a bare assertion" \
  "$(mcp_payload "mcp__github__create_pull_request" "Did it. Not verified: none")"
assert_allowed "update_pull_request that does not carry a body" \
  '{"tool_name":"mcp__github__update_pull_request","tool_input":{"owner":"x","repo":"y","pullNumber":1,"state":"closed"}}'
assert_blocked "update_pull_request replacing the body with an unjustified one" \
  "$(mcp_payload "mcp__github__update_pull_request" "Tidied the wording.")"

# ── Wiring ──
#
# Behaviour tests pass just as happily when nothing invokes the hook, so assert
# it is actually reachable from every agent entry point installed here.

echo "The hook is wired into each installed agent entry point:"

for cfg in ".claude/settings.json" ".codex/hooks.json" ".gemini/settings.json" ".github/hooks/block-protected-branch.json"; do
  [ -f "$ROOT_DIR/$cfg" ] || continue
  if grep -q "check-pr-verification.sh" "$ROOT_DIR/$cfg"; then
    PASS=$((PASS + 1)); echo "  PASS: $cfg"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $cfg does not invoke the hook"
  fi
done

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
