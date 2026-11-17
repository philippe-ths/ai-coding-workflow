#!/usr/bin/env bash
# PreToolUse hook for Claude Code and Codex: blocks a write to a file another
# agent reads later as instructions, unless aiw-prompt-smith was loaded since
# the human's last message.
#
# Such a file is a prompt whatever it is named, and written as a note it
# carries the incident that prompted it: a preference recorded as "when the human
# asks for a new method (e.g. pricing)", with their quoted words, was read by
# every later session as a pricing rule (#430). The skill's own description
# covered the file and was skipped, and a sentence in ai-workflow.md naming it
# would be more prose of the kind that was skipped, so the check is made here.
#
# The files are the in-repository prose lib-agent-read-paths.sh finds, the
# repository's own record files, any file named as an entry point or skill
# wherever it sits, and the human's files outside every repository that agents
# load: preferences, user-level instructions, memory, skills.
#
# "Since the human's last message" is read from the session transcript, newest
# line first: a skill load before the human last spoke shaped a different
# request, and a compaction summary counts as a message because the skill's
# text did not survive it. A sub-agent is judged by its own transcript.
#
# The shell route matches the command string, as the other hooks here do: a
# redirect, tee, sed -i or perl -i, the destination of cp, mv or install, or a
# quoted string in inline interpreter code that writes files, naming one of
# these files. A command can be written so it is missed, and one that merely
# mentions such a file where a write could be is caught; loading the skill is
# the cost of the second.
#
# When the evidence cannot be read (no jq, no transcript), it allows: a check
# that cannot be evaluated is skipped, not failed.

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
# shellcheck source=lib-agent-read-paths.sh
. "$SCRIPT_DIR/lib-agent-read-paths.sh" 2>/dev/null || exit 0
CONTEXT_FILE="project-context.md"
if [ -f "$SCRIPT_DIR/../policy.env" ]; then
  CONTEXT_FILE="$( ( set +eu; . "$SCRIPT_DIR/../policy.env" >/dev/null 2>&1; printf '%s' "${CONTEXT_FILE:-project-context.md}" ) 2>/dev/null || printf 'project-context.md' )"
fi

command -v jq >/dev/null 2>&1 || exit 0
INPUT="$(cat)" || exit 0
[ -n "$INPUT" ] || exit 0

field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }
CWD="$(field .cwd)"; [ -n "$CWD" ] || CWD="$PWD"
TRANSCRIPT="$(field .transcript_path)"
AGENT_ID="$(field .agent_id)"
COMMAND="$(field .tool_input.command)"
TARGET="$(printf '%s' "$INPUT" | jq -r '
  (.tool_input // {})
  | [.file_path?, .path?, .filePath?, .notebook_path?, .filename?, .file?]
  | map(select(type == "string")) | .[0] // empty' 2>/dev/null)"

# Make a path absolute and drop . and .. segments, without touching the
# filesystem, since the file may not exist yet.
absolute() {
  local p="$1" IFS='/' seg out=""
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    /*) ;;
    *) p="$CWD/$p" ;;
  esac
  for seg in $p; do
    case "$seg" in
      ''|'.') ;;
      '..') out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  printf '%s' "${out:-/}"
}

# Succeed when an agent reads the file at this absolute path later as
# instructions.
agent_read() {
  local p="$1" dir tail root rel
  case "${p##*/}" in
    CLAUDE.md|CLAUDE.local.md|AGENTS.md|AGENT.md|SKILL.md|copilot-instructions.md) return 0 ;;
    *.instructions.md|*.prompt.md|*.agent.md) return 0 ;;
  esac
  case "$p" in
    "$HOME"/.aiw/*.md|"$HOME"/.claude/projects/*/memory/*.md) return 0 ;;
    "$HOME"/.claude/skills/*|"$HOME"/.claude/agents/*|"$HOME"/.claude/commands/*) return 0 ;;
    "$HOME"/.codex/skills/*|"$HOME"/.agents/skills/*|"$HOME"/.codex/prompts/*) return 0 ;;
  esac
  # The repository-relative path, from the nearest directory that exists, since
  # a new skill's directory does not yet.
  dir="${p%/*}"
  while [ -n "$dir" ] && [ ! -d "$dir" ]; do dir="${dir%/*}"; done
  tail="${p#"$dir"}"
  dir="$(cd "${dir:-/}" 2>/dev/null && pwd -P)" || return 1
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  root="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
  rel="${dir%/}$tail"
  case "$rel" in "$root"/*) rel="${rel#"$root"/}" ;; *) return 1 ;; esac
  case "$rel" in
    .claude/skills/*|.agents/skills/*|.claude/agents/*|.github/agents/*|.claude/commands/*) return 0 ;;
    .github/instructions/*|.github/prompts/*|ai-workflow.md|north-star.md|project-checks.md) return 0 ;;
    "$CONTEXT_FILE") return 0 ;;
  esac
  prose_includes "$root" HEAD 2>/dev/null | grep -qxF -- "$rel"
}

# Candidate written paths from a shell command, one per line. A relative path
# is taken from the directory the last `cd` in the command moved to.
shell_targets() {
  local interp="no" base="" seg out c
  # Inline code in an interpreter that writes files: every quoted string in the
  # command is a candidate, since the code names its target as a string. Agents
  # edit these files this way about as often as with sed.
  if printf '%s' "$1" | grep -Eq '(^|[^[:alnum:]_])(python3?|node|ruby|perl|php)([[:space:]]|$)' \
    && printf '%s' "$1" | grep -Eq "open\([^)]*['\"][wa]|write_text|\.write(lines)?\(|json\.dump|(write|append)File|File\.write"; then
    interp="yes"
  fi
  printf '%s\n' "$1" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }' | while IFS= read -r seg; do
    if printf '%s' "$seg" | grep -Eq '^[[:space:]]*cd[[:space:]]+[^[:space:]]'; then
      base="$(printf '%s' "$seg" | sed -E "s/^[[:space:]]*cd[[:space:]]+//; s/^[\"']//; s/[\"'][[:space:]]*\$//; s/[[:space:]]+\$//")"
      continue
    fi
    out="$(
      printf '%s\n' "$seg" | grep -oE '[0-9&]?>>?[[:space:]]*[^[:space:]<>&|;]+' | sed -E 's/^[0-9&]?>>?[[:space:]]*//'
      case " $seg " in
        *" tee "*) printf '%s\n' "${seg#*tee }" | tr ' ' '\n' | grep -v '^-' ;;
      esac
      if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(sed|perl)[[:space:]]+(-[^[:space:]]*[[:space:]]+)*-[[:alnum:]]*i'; then
        printf '%s\n' "$seg" | tr ' ' '\n' | grep -v '^-'
      fi
      if printf '%s' "$seg" | grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?(cp|mv|install)[[:space:]]'; then
        printf '%s\n' "$seg" | awk '{ print $NF }'
      fi
      if [ "$interp" = "yes" ]; then
        printf '%s\n' "$seg" | grep -oE "\"[^\"]+\"|'[^']+'"
      fi
    )"
    printf '%s\n' "$out" | sed -E "s/^[\"']+//; s/[\"')]+\$//" | grep -v '^$' | while IFS= read -r c; do
      case "$c" in
        /*|"~"*|"\$HOME"*) printf '%s\n' "$c" ;;
        *) printf '%s\n' "${base:+$base/}$c" ;;
      esac
    done
  done
}

hits=""
if [ -n "$TARGET" ]; then
  t="$(absolute "$TARGET")"
  agent_read "$t" && hits="$t"
fi
if [ -z "$hits" ] && [ -n "$COMMAND" ]; then
  while IFS= read -r c; do
    t="$(absolute "$c")"
    if agent_read "$t"; then hits="$t"; break; fi
  done <<EOF
$(shell_targets "$COMMAND")
EOF
fi
[ -n "$hits" ] || exit 0

# A sub-agent's own transcript sits beside the session's, under subagents/.
if [ -n "$AGENT_ID" ] && [ -n "$TRANSCRIPT" ]; then
  sub="${TRANSCRIPT%.jsonl}/subagents/agent-$AGENT_ID.jsonl"
  [ -r "$sub" ] && TRANSCRIPT="$sub"
fi
[ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] || exit 0

if command -v tac >/dev/null 2>&1; then reverse() { tac "$1"; }; else reverse() { tail -r "$1"; }; fi

# Newest line first: a skill load reached before the human's last message
# passes; that message reached first blocks, unless it invoked the skill.
verdict="$(reverse "$TRANSCRIPT" 2>/dev/null | jq -nrR '
  def loads: tostring | contains("aiw-prompt-smith/SKILL.md");
  def skill_load:
    (.type == "assistant" and any(.message.content[]?; .type == "tool_use"
       and ((.name == "Skill" and ((.input.skill // "") | test("(^|:)aiw-prompt-smith$")))
            or (.name == "Read" and ((.input.file_path // "") | endswith("aiw-prompt-smith/SKILL.md"))))))
    or (.type == "response_item" and (.payload.type // "" | test("call$")) and (.payload | loads));
  def human:
    (.type == "user" and .isMeta != true
       and ((.message.content | type) == "string" or all(.message.content[]?; .type != "tool_result")))
    or (.type == "attachment" and .attachment.type == "queued_command")
    or (.type == "event_msg" and .payload.type == "user_message");
  first(inputs | fromjson? | objects
        | if skill_load then "pass"
          elif human then (if tostring | contains("<command-name>/aiw-prompt-smith</command-name>") then "pass" else "block" end)
          else empty end) // "block"' 2>/dev/null)" || exit 0
[ "$verdict" = "block" ] || exit 0

echo "Blocked: $hits is read by later agents as instructions, and aiw-prompt-smith has not been loaded since the human's last message." >&2
echo "Load aiw-prompt-smith, then write the entry with it: the principle, worded to apply beyond the case that prompted it." >&2
exit 2
