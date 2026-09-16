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

# The hook reads the branch diff for check 3, so every case runs inside a
# sandbox repository where the diff is controlled. This one has a base commit
# on main and a work branch touching only code, which is the normal path the
# first two checks were written against. Later sections make their own.
GIT="git -c user.email=t@example.com -c user.name=t"
make_repo() {
  local dir="$TMP/$1"
  mkdir -p "$dir/docs" "$dir/sites" "$dir/.claude/skills/tidy" "$dir/.claude/agents" "$dir/.github"
  ( cd "$dir" && git init -q -b main . \
    && printf 'x\n' > app.py \
    && printf '# Project\n@docs/METHOD.md\n' > CLAUDE.md \
    && printf '# Codex\n' > AGENTS.md \
    && printf '# Copilot\n' > .github/copilot-instructions.md \
    && printf '# Method\nRead sites/README.md for fields. See @../sites/README.md for every field.\n' > docs/METHOD.md \
    && mkdir -p .agents/skills/tidy && printf -- '---\nname: tidy\n---\n# Tidy\n' > .agents/skills/tidy/SKILL.md \
    && printf '# Reference\n' > sites/README.md \
    && printf -- '---\nname: tidy\n---\n# Tidy\n' > .claude/skills/tidy/SKILL.md \
    && printf '# Designer\n' > .claude/agents/designer.md \
    && $GIT add -A && $GIT commit -qm base && git checkout -q -b work )
  echo "$dir"
}
touch_commit() {  # repo file
  ( cd "$1" && printf 'changed\n' >> "$2" && $GIT add -A && $GIT commit -qm "touch $2" )
}
CODE_REPO="$(make_repo code)"
touch_commit "$CODE_REPO" app.py
cd "$CODE_REPO"

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

# A body that demonstrates the bad form inside a fenced code block is
# discussing the rule, not declaring a gap. This pull request is written
# that way, and blocked itself before the fences were excluded.
assert_allowed "a bare assertion shown inside a fenced code block" \
  "$(bash_payload "gh pr create --title x --body-file $(body_file h8.md 'Tests pass.' '' 'The guard misses this form:' '' '```' '## What was not checked' '' 'Nothing.' '```' '' '## What was not checked' '' 'The four tools were not driven.')")"

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

# ── Agent-facing prose (#295) ──
#
# A rule that lived only in prose and memory was skipped on three runs of pull
# requests. The hook now asks, by path, whether the branch changed anything an
# agent loads to learn what to do, and requires the body to record the pass.

echo "A branch that changed agent-facing prose must record an aiw-prompt-smith pass:"

PLAIN="$(body_file plain.md "Ran the suite, green. Not verified: the mobile layout, no device to hand.")"
WITH_PASS="$(body_file withpass.md "Ran the suite, green. Not verified: the mobile layout." "" \
  "aiw-prompt-smith pass over the diff: cut one line racing an existing rule; nothing else to change.")"

prose_case() {  # label file
  local repo
  repo="$(make_repo "prose_$(printf '%s' "$2" | tr -c '[:alnum:]' _)")"
  touch_commit "$repo" "$2"
  cd "$repo"
  assert_blocked "$1, body silent on the pass" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
  assert_allowed "$1, body recording the pass" "$(bash_payload "gh pr create --title x --body-file $WITH_PASS")"
  cd "$CODE_REPO"
}

prose_case "a skill, whatever its name" .claude/skills/tidy/SKILL.md
prose_case "a cross-platform skill" .agents/skills/tidy/SKILL.md
prose_case "an agent prompt file" .claude/agents/designer.md
prose_case "AGENTS.md" AGENTS.md
prose_case "the Copilot entry point" .github/copilot-instructions.md
prose_case "a file CLAUDE.md includes with an @ line" docs/METHOD.md
prose_case "a file reached through an inline, file-relative @ token" sites/README.md

echo "The check is for presence; what the record says is the human's to read:"
# A matcher for "skipped" was tried and dropped: it blocked honest bodies
# ("n/a for the test file") while catching four spellings of the lie.
WAIVED="$(body_file waived.md "Ran the suite, green. Not verified: the mobile layout." "" \
  "aiw-prompt-smith pass waived by the human: 'ship it as is, I have read the diff'.")"
HONEST_NA="$(body_file honestna.md "Ran the suite, green. Not verified: the mobile layout." "" \
  "aiw-prompt-smith pass: found nothing to change, n/a for the test file.")"
SK="$(make_repo record)"; touch_commit "$SK" AGENTS.md; cd "$SK"
assert_allowed "a waiver in the human's words" "$(bash_payload "gh pr create --title x --body-file $WAIVED")"
assert_allowed "an honest record that happens to say n/a" "$(bash_payload "gh pr create --title x --body-file $HONEST_NA")"
cd "$CODE_REPO"

echo "An include the branch deletes still counts:"
DEL="$(make_repo deleted)"; ( cd "$DEL" && git rm -q docs/METHOD.md && $GIT commit -qm "drop method" ); cd "$DEL"
assert_blocked "docs/METHOD.md deleted" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
cd "$CODE_REPO"

echo "A stale remote base does not fire on a code-only branch:"
# origin/main is behind local main, which carries a prose commit; the branch
# was cut from local main and touched only code. The newest merge-base wins.
STALE="$(make_repo stale)"; ( cd "$STALE" && git update-ref refs/remotes/origin/main main && git checkout -q main \
  && printf 'more\n' >> CLAUDE.md && $GIT commit -qam "prose on main" && git checkout -q work && $GIT rebase -q main )
touch_commit "$STALE" app.py; cd "$STALE"
assert_allowed "code change with origin/main behind main" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
( cd "$STALE" && git checkout -q main && printf 'x\n' >> AGENTS.md && $GIT commit -qam "agents on main" && git checkout -q work )
assert_allowed "prose committed on main after the branch, not on the branch" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
cd "$CODE_REPO"

echo "A remote-only base is used when no local one exists:"
REM="$(make_repo remote_only)"; ( cd "$REM" && git update-ref refs/remotes/origin/main main && git branch -D main >/dev/null ); touch_commit "$REM" AGENTS.md; cd "$REM"
assert_blocked "AGENTS.md changed against origin/main only" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
cd "$CODE_REPO"

echo "A hostile @ token is never run, followed outside the repository, or read unbounded:"
# The hostile entry point is on the base, so the branch itself is code-only.
HOST="$(make_repo hostile)"; ( cd "$HOST" && git checkout -q main \
  && printf '@../../etc/passwd @/etc/hosts @$(touch %s/pwned) @`touch %s/pwned2` @docs%%2F..%%2F..%%2Fetc/passwd @docs/../../outside.md @%s @docs/METHOD.md\n' "$TMP" "$TMP" "$(printf 'a%.0s' $(seq 1 5000))" >> CLAUDE.md \
  && ln -s /dev/zero docs/zero.md && printf '@docs/zero.md\n' >> CLAUDE.md \
  && $GIT add -A && $GIT commit -qm hostile && git checkout -q work && $GIT rebase -q main )
touch_commit "$HOST" app.py; cd "$HOST"
assert_allowed "code-only branch with a hostile CLAUDE.md" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
if [ ! -e "$TMP/pwned" ] && [ ! -e "$TMP/pwned2" ]; then
  PASS=$((PASS + 1)); echo "  PASS: no command from an @ token was executed"
else
  FAIL=$((FAIL + 1)); echo "  FAIL: an @ token executed a command"
fi
# The hostile line also carries a real include after the bad tokens, so a walk
# that gave up on the line would miss it. Touching that include must still fire.
touch_commit "$HOST" docs/METHOD.md
assert_blocked "the real include on the hostile line is still followed" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
cd "$CODE_REPO"

echo "A policy.env that fails to source falls back to main master:"
BADPOL="$(make_repo badpolicy)"; ( cd "$BADPOL" && mkdir -p .ai-policy && printf 'PROTECTED_BRANCHES="main"\nfalse\necho "$UNSET_VARIABLE_X"\n' > .ai-policy/policy.env && $GIT add -A && $GIT commit -qm policy ); touch_commit "$BADPOL" AGENTS.md; cd "$BADPOL"
assert_blocked "AGENTS.md changed with a policy.env that errors" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"
cd "$CODE_REPO"

echo "The refusal names the file that made it fire:"
NESTED="$(make_repo nested_msg)"; touch_commit "$NESTED" sites/README.md; cd "$NESTED"
ERR="$(printf '%s' "$(bash_payload "gh pr create --title x --body-file $PLAIN")" | "$HOOK" 2>&1 >/dev/null || true)"
if printf '%s' "$ERR" | grep -q 'sites/README.md' && printf '%s' "$ERR" | grep -qi 'prompt-smith'; then
  PASS=$((PASS + 1)); echo "  PASS: names sites/README.md and the skill to run"
else
  FAIL=$((FAIL + 1)); echo "  FAIL: refusal did not name the file or the skill: $ERR"
fi

echo "Prose that is only referred to in prose is outside a path rule:"
# docs/METHOD.md says "Read sites/README.md" but a sibling it does not @-include
# is not reached. This pins the limit rather than a wish: aiw-prompt-smith's
# Layer question owns that case at plan time.
SIB="$(make_repo sibling)"; ( cd "$SIB" && printf 'notes\n' > docs/NOTES.md ); touch_commit "$SIB" docs/NOTES.md; cd "$SIB"
assert_allowed "a docs file no entry point includes" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"

echo "Uncommitted prose changes count:"
DIRTY="$(make_repo dirty)"; ( cd "$DIRTY" && printf 'more\n' >> CLAUDE.md ); cd "$DIRTY"
assert_blocked "CLAUDE.md edited but not committed" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"

echo "A code-only branch never sees the check:"
cd "$CODE_REPO"
assert_allowed "code change, body silent on the pass" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"

echo "Where no protected base resolves, the check is skipped rather than failed:"
NOBASE="$TMP/nobase"; mkdir -p "$NOBASE" && ( cd "$NOBASE" && git init -q -b work . && printf 'x\n' > CLAUDE.md && $GIT add -A && $GIT commit -qm only && printf 'y\n' >> CLAUDE.md )
cd "$NOBASE"
assert_allowed "a repository with no main or master, prose dirty in the tree" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"

echo "The protected base comes from policy.env when present:"
POL="$(make_repo policy)"; ( cd "$POL" && git branch -m main trunk && mkdir -p .ai-policy && printf 'PROTECTED_BRANCHES="trunk"\n' > .ai-policy/policy.env && $GIT add -A && $GIT commit -qm policy ); touch_commit "$POL" AGENTS.md; cd "$POL"
assert_blocked "AGENTS.md changed against a trunk base" "$(bash_payload "gh pr create --title x --body-file $PLAIN")"

cd "$CODE_REPO"

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

for cfg in ".claude/settings.json" ".codex/hooks.json" ".github/hooks/block-protected-branch.json"; do
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
