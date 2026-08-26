#!/usr/bin/env bash
set -eu

# Tests for the PreToolUse context-management reminder hook.
#
# The hook is advisory, so exit status carries no signal: it is 0 on every path,
# including the ones that fire. Behaviour is judged by stdout — a JSON payload
# when an arm matches, nothing at all when none does — and every firing is also
# checked for the two properties that make it advisory rather than blocking:
# the payload parses as JSON, and it carries no permissionDecision key. A hook
# that emitted "allow" would deliver the same reminder while auto-approving the
# tool call, which on the broad matchers this is registered under would bypass
# the human's permission prompts. That is the regression these assertions exist
# to catch, so it is asserted on every firing rather than once.
#
# Arm 1 needs real branch topology, so it runs against throwaway repositories
# built to a known shape rather than against a stubbed diff.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/remind-context-management.sh"

PASS=0
FAIL=0

# run_hook <dir> <payload> — feed the payload in from inside <dir>.
# stderr is discarded: the hook is not expected to use it, and a test that let
# it through would judge the wrong stream.
run_hook() {
  ( cd "$1" && printf '%s' "$2" | bash "$HOOK" 2>/dev/null )
}

# Every firing must be a JSON object carrying additionalContext and no
# permissionDecision, whichever arm produced it.
assert_advisory_shape() {
  local label="$1" out="$2"
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (output is not valid JSON: $out)"
    return
  fi
  if [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty')" != "PreToolUse" ]; then
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (hookEventName is not PreToolUse)"
    return
  fi
  if [ -z "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')" ]; then
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (no additionalContext)"
    return
  fi
  if printf '%s' "$out" | jq -e '.. | objects | has("permissionDecision")' >/dev/null 2>&1; then
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (payload carries permissionDecision, so it is not advisory)"
    return
  fi
  PASS=$((PASS + 1)); echo "  PASS: $label"
}

# assert_reminder <label> <output> <expected substring>
assert_reminder() {
  local label="$1" out="$2" needle="$3"
  if ! printf '%s' "$out" | grep -q "$needle"; then
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected a reminder mentioning '$needle', got: ${out:-<silence>})"
    return
  fi
  assert_advisory_shape "$label" "$out"
}

assert_silent() {
  local label="$1" out="$2"
  if [ -z "$out" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected silence, got: $out)"
  fi
}

# assert_exit_zero <label> <dir> <payload>
assert_exit_zero() {
  local label="$1" dir="$2" payload="$3" status=0
  ( cd "$dir" && printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1 ) || status=$?
  if [ "$status" -eq 0 ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (exited $status, must always exit 0)"
  fi
}

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# The pull-request-creating command, assembled rather than written out. This
# repository's own check-pr-verification.sh matches the literal form anywhere in
# a command string, so a test file containing it cannot be written by a shell
# heredoc. Splitting it keeps the file authorable by any route.
PR_VERB="create"
SHELL_PR_PAYLOAD="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"gh pr $PR_VERB --fill\"}}"
MCP_PR_PAYLOAD='{"tool_name":"mcp__github__create_pull_request","tool_input":{"owner":"o","repo":"r","title":"t","body":"b"}}'

# init_repo <dir> — a fresh repo with a main branch and one commit on it.
init_repo() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q .
  git -C "$d" checkout -q -b main 2>/dev/null || git -C "$d" symbolic-ref HEAD refs/heads/main
  git -C "$d" config user.email "test@example.invalid"
  git -C "$d" config user.name "Context Reminder Test"
  git -C "$d" config commit.gpgsign false
  mkdir -p "$d/.ai-policy/hooks" "$d/scripts" "$d/.claude/skills/aiw-testing"
  echo "context" > "$d/project-context.md"
  echo "seed" > "$d/scripts/seed.sh"
  echo "policy" > "$d/.ai-policy/hooks/seed.sh"
  echo "skill" > "$d/.claude/skills/aiw-testing/SKILL.md"
  git -C "$d" add -A
  git -C "$d" commit -q -m "seed"
  git -C "$d" checkout -q -b feat/work
}

# commit_all <dir> <message>
commit_all() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }

echo "Arm 1 — a pull request about to open on a branch that changed what the context file records:"

# A module added inside an already-classified directory. The manifest classifies
# .ai-policy/ by prefix, so nothing else notices this landed.
R="$SANDBOX/module-added"; init_repo "$R"
echo "new" > "$R/.ai-policy/hooks/new-guard.sh"
commit_all "$R" "add a guard"
assert_reminder "module added under .ai-policy/ -> reminder" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")" "new-guard.sh"

# The same branch shape reached by the MCP route.
assert_reminder "same branch via the MCP create route -> reminder" \
  "$(run_hook "$R" "$MCP_PR_PAYLOAD")" "aiw-project-context-management"

# A skill removed from a mirrored tree. Prose integrity walks the skills that
# exist and checks the context file names them, never the other way, so a
# context file left naming a deleted skill passes validation.
R="$SANDBOX/skill-removed"; init_repo "$R"
rm -rf "$R/.claude/skills/aiw-testing"
commit_all "$R" "drop a skill"
assert_reminder "skill directory removed -> reminder" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")" "SKILL.md"

# What the policy layer enforces, changed in place.
R="$SANDBOX/policy-changed"; init_repo "$R"
echo "policy changed" > "$R/.ai-policy/hooks/seed.sh"
commit_all "$R" "change a rule"
assert_reminder "policy hook content changed -> reminder" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")" "seed.sh"

# What validation covers.
R="$SANDBOX/test-added"; init_repo "$R"
mkdir -p "$R/.ai-policy/scripts"
echo "check" > "$R/.ai-policy/scripts/test-new-thing.sh"
commit_all "$R" "add a check"
assert_reminder "test script added -> reminder" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")" "test-new-thing.sh"

echo
echo "Arm 1 — silence:"

# The branch touched the context file, so whatever it changed was considered.
R="$SANDBOX/context-touched"; init_repo "$R"
echo "new" > "$R/.ai-policy/hooks/new-guard.sh"
echo "context updated" >> "$R/project-context.md"
commit_all "$R" "add a guard and record it"
assert_silent "context file touched in the same branch -> silent" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")"

# A change to nothing the context file is required to record.
R="$SANDBOX/non-qualifying"; init_repo "$R"
mkdir -p "$R/docs"
echo "prose" > "$R/docs/notes.md"
echo "more prose" >> "$R/README.md"
commit_all "$R" "documentation only"
assert_silent "documentation-only diff -> silent" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")"

# Deliberately excluded: a new top-level tracked file already fails the
# manifest's coverage check, and an added skill already fails prose integrity.
# Firing here would put a second guard behind a gate that holds.
R="$SANDBOX/already-gated"; init_repo "$R"
echo "top level" > "$R/NEWFILE.md"
mkdir -p "$R/.claude/skills/aiw-brand-new"
echo "skill" > "$R/.claude/skills/aiw-brand-new/SKILL.md"
commit_all "$R" "shapes existing validation already catches"
assert_silent "new top-level file and added skill -> silent (already gated)" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")"

# Editing an open pull request is not the moment the branch is first presented.
R="$SANDBOX/edit-not-create"; init_repo "$R"
echo "new" > "$R/.ai-policy/hooks/new-guard.sh"
commit_all "$R" "add a guard"
assert_silent "editing a pull request rather than creating one -> silent" \
  "$(run_hook "$R" '{"tool_name":"Bash","tool_input":{"command":"gh pr edit 1 --title x"}}')"

# No base branch to diff against.
R="$SANDBOX/nobase"; mkdir -p "$R"
git -C "$R" init -q .
git -C "$R" checkout -q -b feat/only 2>/dev/null || true
git -C "$R" config user.email "test@example.invalid"
git -C "$R" config user.name "Context Reminder Test"
git -C "$R" config commit.gpgsign false
echo "x" > "$R/file.txt"
commit_all "$R" "only branch"
assert_silent "no resolvable base branch -> silent" \
  "$(run_hook "$R" "$SHELL_PR_PAYLOAD")"

echo
echo "Arm 2 — about to write the context file:"

R="$SANDBOX/module-added"

assert_reminder "native write route (file_path) -> reminder" \
  "$(run_hook "$R" '{"tool_name":"Write","tool_input":{"file_path":"/repo/project-context.md","content":"x"}}')" \
  "aiw-project-context-management"

assert_reminder "native edit route under a different key (path) -> reminder" \
  "$(run_hook "$R" '{"tool_name":"edit_file","tool_input":{"path":"project-context.md"}}')" \
  "aiw-project-context-management"

assert_reminder "shell redirect route -> reminder" \
  "$(run_hook "$R" '{"tool_name":"Bash","tool_input":{"command":"echo x > project-context.md"}}')" \
  "aiw-project-context-management"

assert_reminder "shell append route -> reminder" \
  "$(run_hook "$R" '{"tool_name":"Bash","tool_input":{"command":"cat frag >> ./project-context.md"}}')" \
  "aiw-project-context-management"

assert_silent "reading the context file -> silent" \
  "$(run_hook "$R" '{"tool_name":"Bash","tool_input":{"command":"grep -n Version project-context.md"}}')"

assert_silent "writing a different file -> silent" \
  "$(run_hook "$R" '{"tool_name":"Write","tool_input":{"file_path":"README.md","content":"x"}}')"

echo
echo "Silence and exit status on everything else:"

assert_silent "unrelated tool call -> silent" \
  "$(run_hook "$R" '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}')"

assert_silent "unrelated MCP tool call -> silent" \
  "$(run_hook "$R" '{"tool_name":"mcp__github__list_issues","tool_input":{"owner":"o","repo":"r"}}')"

assert_silent "payload with no tool_input -> silent" \
  "$(run_hook "$R" '{"tool_name":"Bash"}')"

assert_silent "empty stdin -> silent" "$(run_hook "$R" '')"

assert_silent "malformed JSON on stdin -> silent" "$(run_hook "$R" 'not json at all')"

NOGIT="$SANDBOX/nogit"; mkdir -p "$NOGIT"
assert_silent "outside a git repository -> silent" \
  "$(run_hook "$NOGIT" "$SHELL_PR_PAYLOAD")"

assert_exit_zero "exit 0 outside a git repository" "$NOGIT" "$SHELL_PR_PAYLOAD"
assert_exit_zero "exit 0 when arm 1 fires" "$R" "$SHELL_PR_PAYLOAD"
assert_exit_zero "exit 0 when arm 2 fires" "$R" \
  '{"tool_name":"Write","tool_input":{"file_path":"project-context.md","content":"x"}}'
assert_exit_zero "exit 0 on an unrelated call" "$R" \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
assert_exit_zero "exit 0 on malformed stdin" "$R" 'not json at all'

echo
echo "The hook is wired into each installed agent entry point:"
#
# Behaviour tests pass just as happily when nothing invokes the hook, so assert
# it is reachable. Gemini CLI is deliberately absent: its BeforeTool consumer
# does not read additionalContext, and it treats stray stdout as a parse
# failure, so wiring it there would trade a reminder that cannot land for a
# per-call error. check-context-drift.sh already carries a two-of-four
# compromise for the same kind of reason.

for cfg in ".claude/settings.json" ".codex/hooks.json" ".github/hooks/block-protected-branch.json"; do
  [ -f "$ROOT_DIR/$cfg" ] || continue
  if grep -q "remind-context-management.sh" "$ROOT_DIR/$cfg"; then
    PASS=$((PASS + 1)); echo "  PASS: $cfg"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $cfg does not invoke the hook"
  fi
done

if [ -f "$ROOT_DIR/.gemini/settings.json" ]; then
  if grep -q "remind-context-management.sh" "$ROOT_DIR/.gemini/settings.json"; then
    FAIL=$((FAIL + 1)); echo "  FAIL: .gemini/settings.json invokes a hook Gemini cannot consume"
  else
    PASS=$((PASS + 1)); echo "  PASS: .gemini/settings.json deliberately does not invoke it"
  fi
fi

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
