#!/usr/bin/env bash
set -eu

# Tests for the PreToolUse hook that blocks a write to a file later agents read
# as instructions unless aiw-prompt-smith was loaded since the human's last
# message.
#
# Exit 2 is a block and exit 0 an allow. Transcripts are built line by line in
# the shapes Claude Code and Codex write, and HOME points at a scratch
# directory so the files outside every repository can be named safely.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/block-unsmithed-prose.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

REPO="$TMP/repo"
FAKE_HOME="$TMP/home"
mkdir -p "$REPO/docs" "$FAKE_HOME"
git -C "$REPO" init -q
printf '@docs/rules.md\n' > "$REPO/CLAUDE.md"
printf 'Rules.\n' > "$REPO/docs/rules.md"
printf 'Readme.\n' > "$REPO/README.md"

# Transcript lines.
HUMAN='{"type":"user","message":{"role":"user","content":"please update the rules"}}'
SLASH='{"type":"user","message":{"role":"user","content":"<command-name>/aiw-prompt-smith</command-name>"}}'
COMPACT='{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"This session is being continued from a previous conversation."}}'
QUEUED='{"type":"attachment","attachment":{"type":"queued_command","prompt":"what are you doing?"}}'
SKILL='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"aiw-prompt-smith"}}]}}'
OTHER_SKILL='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"aiw-github"}}]}}'
SKILL_BODY='{"type":"user","isMeta":true,"message":{"content":[{"type":"text","text":"Base directory for this skill: .../aiw-prompt-smith"}]}}'
READ_SKILL='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/r/.claude/skills/aiw-prompt-smith/SKILL.md"}}]}}'
MENTION='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/r/x.sh","content":"see aiw-prompt-smith/SKILL.md"}}]}}'
RESULT='{"type":"user","message":{"content":[{"type":"tool_result","content":"ok"}]}}'
CODEX_HUMAN='{"type":"event_msg","payload":{"type":"user_message","message":"update AGENTS.md"}}'
CODEX_READ='{"type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"cat\",\".agents/skills/aiw-prompt-smith/SKILL.md\"]}"}}'

transcript() { local f="$TMP/t-$RANDOM.jsonl"; printf '%s\n' "$@" > "$f"; printf '%s' "$f"; }

# hook <transcript> <tool_name> <tool_input json> [extra json]
hook() {
  local input
  input="$(jq -nc --arg t "$1" --arg n "$2" --argjson i "$3" --arg c "$REPO" --argjson x "${4:-{\}}" \
    '{cwd: $c, transcript_path: $t, tool_name: $n, tool_input: $i} + $x')"
  printf '%s' "$input" | HOME="$FAKE_HOME" bash "$HOOK" >/dev/null 2>&1 && echo 0 || echo $?
}
write_to() { jq -nc --arg p "$1" '{file_path: $p}'; }
shell() { jq -nc --arg c "$1" '{command: $c}'; }

expect() { # expect <code> <description> <actual>
  if [ "$3" = "$1" ]; then pass "$2"; else fail "$2 (exit $3, wanted $1)"; fi
}

echo "block-unsmithed-prose hook, transcript evidence:"
T="$(transcript "$HUMAN" "$SKILL" "$SKILL_BODY" "$RESULT")"
expect 0 "the skill loaded since the human's last message allows the write" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN")"
expect 2 "no skill load blocks the write" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$SKILL" "$HUMAN" "$RESULT")"
expect 2 "a load before the human's last message blocks" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN" "$SKILL" "$COMPACT")"
expect 2 "a compaction summary after the load blocks" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN" "$SKILL" "$QUEUED")"
expect 2 "a message sent mid-turn after the load blocks" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN" "$OTHER_SKILL")"
expect 2 "loading a different skill blocks" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN" "$MENTION")"
expect 2 "a tool call that merely mentions the skill file blocks" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$SLASH" "$SKILL_BODY")"
expect 0 "the human invoking the skill allows" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$HUMAN" "$READ_SKILL")"
expect 0 "reading the skill file allows" "$(hook "$T" Write "$(write_to "$REPO/CLAUDE.md")")"
T="$(transcript "$CODEX_HUMAN" "$CODEX_READ")"
expect 0 "a Codex session that read the skill since the human spoke allows" "$(hook "$T" Bash "$(shell "printf x > AGENTS.md")")"
T="$(transcript "$CODEX_READ" "$CODEX_HUMAN")"
expect 2 "a Codex read before the human spoke blocks" "$(hook "$T" Bash "$(shell "printf x > AGENTS.md")")"
expect 0 "an unreadable transcript allows, since nothing can be judged" "$(hook "$TMP/absent.jsonl" Write "$(write_to "$REPO/CLAUDE.md")")"

PARENT="$(transcript "$HUMAN")"
mkdir -p "${PARENT%.jsonl}/subagents"
printf '%s\n' "$HUMAN" "$SKILL" > "${PARENT%.jsonl}/subagents/agent-abc.jsonl"
expect 0 "a sub-agent is judged by its own transcript" "$(hook "$PARENT" Write "$(write_to "$REPO/CLAUDE.md")" '{"agent_id":"abc"}')"

echo "block-unsmithed-prose hook, which files:"
T="$(transcript "$HUMAN")"
for p in "$REPO/docs/rules.md" "$REPO/.claude/skills/new/SKILL.md" "$REPO/.claude/agents/a.md" \
         "$REPO/project-context.md" "$REPO/north-star.md" "$REPO/sub/AGENTS.md" \
         "$FAKE_HOME/.aiw/preferences.md" "$FAKE_HOME/.claude/CLAUDE.md" \
         "$FAKE_HOME/.claude/projects/p/memory/note.md" "$FAKE_HOME/.claude/skills/s/ref.md"; do
  expect 2 "a write to ${p#"$TMP"/} is checked" "$(hook "$T" Write "$(write_to "$p")")"
done
expect 2 "a relative path resolves against the session directory" "$(hook "$T" Edit "$(write_to "docs/rules.md")")"
expect 0 "a file no agent loads is never checked" "$(hook "$T" Write "$(write_to "$REPO/README.md")")"
expect 0 "a file outside any repository is never checked" "$(hook "$T" Write "$(write_to "$TMP/notes.md")")"

echo "block-unsmithed-prose hook, shell route:"
expect 2 "a redirect to an agent-read file is checked" "$(hook "$T" Bash "$(shell "cat > ~/.aiw/preferences.md <<'EOF'
- x
EOF")")"
expect 2 "an append is checked" "$(hook "$T" Bash "$(shell "echo x >> docs/rules.md")")"
expect 2 "tee is checked" "$(hook "$T" Bash "$(shell "echo x | tee -a CLAUDE.md")")"
expect 2 "sed -i is checked" "$(hook "$T" Bash "$(shell "sed -i '' 's/a/b/' docs/rules.md")")"
expect 2 "the destination of cp is checked" "$(hook "$T" Bash "$(shell "cp /tmp/x.md CLAUDE.md")")"
expect 0 "the source of cp is not" "$(hook "$T" Bash "$(shell "cp CLAUDE.md /tmp/x.md")")"
expect 0 "reading an agent-read file is not" "$(hook "$T" Bash "$(shell "grep -n rule CLAUDE.md docs/rules.md")")"
expect 2 "inline python that writes the file is checked" "$(hook "$T" Bash "$(shell "python3 - <<'EOF'
p='docs/rules.md'; s=open(p).read()
open(p,'w').write(s.replace('a','b'))
EOF")")"
expect 2 "a relative path follows the command's cd" "$(hook "$T" Bash "$(shell "cd $FAKE_HOME/.aiw && python3 - <<'EOF'
p='preferences.md'; s=open(p).read(); open(p,'w').write(s)
EOF")")"
expect 2 "the destination after a cd is checked" "$(hook "$T" Bash "$(shell "cd docs && printf x > rules.md")")"
expect 0 "inline python that only reads the file is not" "$(hook "$T" Bash "$(shell "python3 -c 'print(open(\"CLAUDE.md\").read())'")")"

echo "block-unsmithed-prose hook, registration:"
if jq -e '.hooks.PreToolUse[] | select(.matcher == "Write|Edit|MultiEdit|NotebookEdit") | .hooks[] | select(.command | contains("block-unsmithed-prose.sh"))' "$ROOT_DIR/.claude/settings.json" >/dev/null \
  && jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("block-unsmithed-prose.sh"))' "$ROOT_DIR/.claude/settings.json" >/dev/null; then
  pass "Claude Code registers it on file tools and Bash"
else
  fail "Claude Code registers it on file tools and Bash"
fi
if jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("block-unsmithed-prose.sh"))' "$ROOT_DIR/.codex/hooks.json" >/dev/null; then
  pass "Codex registers it on Bash"
else
  fail "Codex registers it on Bash"
fi

echo
echo "Results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
