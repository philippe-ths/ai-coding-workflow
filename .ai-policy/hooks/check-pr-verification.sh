#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code, Codex, Gemini CLI, and VS Code Copilot.
# Blocks opening or editing a pull request whose body carries no verification
# justification, or whose unverified-surface section is a bare assertion.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.
#
# aiw-github already requires the justification step to be complete before the
# first remote action, and aiw-verification already requires an empty part 3 to
# be an argument rather than an assertion. Both are asked of the agent at the
# moment it is least able to hear them: closing out, wanting to be done.
#
# What this hook deliberately does NOT check is whether each named gap carries
# an issue number. That rule reads well and is wrong: of the six pull requests
# that built these rules, every one declared an unverified surface and none of
# those declarations carried an issue, because they were limitations of the
# evidence ("two runs per arm is indicative, not conclusive") rather than gaps
# anyone should own. Only the author can tell those apart, so a guard that
# demanded an issue would fire on the normal path, and a guard that fires on
# the normal path gets routed around.
#
# The two checks below are the ones a script can make without that judgement.
#
# Like block-pr-merge.sh, this matches the command string rather than parsing
# the shell, so a command that merely quotes the pull-request-creating form —
# writing this file, say — is blocked too. That is the deliberate trade the
# other hooks in this directory make: knowing what is inside a heredoc means
# parsing shell, and a guard that parses shell is a guard with holes in it.
# Author such content with a file-writing tool rather than a shell heredoc.

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

deny() {
  echo "Blocked: $1" >&2
  echo "$2" >&2
  echo "See aiw-verification's justification step. Part 3 names what was not checked;" >&2
  echo "an empty part 3 is an argument in terms of what the change is, never a bare assertion." >&2
  exit 2
}

# Present the body to the checks with markdown emphasis and list markers gone,
# so that "**Not verified:** none" and "- Not verified: none" read the same as
# the bare form. Formatting is not the thing being judged.
normalise() {
  sed -e 's/[*_`]//g' -e 's/^[[:space:]]*[-+*][[:space:]]*//' -e 's/[[:space:]]*$//'
}

check_body() {
  local body="$1" source="$2" norm
  norm="$(printf '%s' "$body" | normalise)"

  if [ -z "$(printf '%s' "$norm" | tr -d '[:space:]')" ]; then
    deny "$source" "The pull request body is empty, so it cannot carry a verification justification."
  fi

  # 1. Some verification content must be present. This is deliberately broad:
  #    the hook checks that a justification was written, not that it was good.
  #    Judging its quality is the human's job at review, and a narrow matcher
  #    here would reject honest bodies that word it differently.
  if ! printf '%s' "$norm" | grep -qiE 'verif|not checked|evidence|justification|test|check|suite|covered by'; then
    deny "$source" "The pull request body carries no verification justification."
  fi

  # 2. A declared unverified surface must not be a bare assertion. "Not
  #    verified: nothing" is what part 3 looks like once it has become a box to
  #    tick, and it is the one shape a script can recognise with certainty.
  #    Quoted spans are blanked first. A sentence that quotes the bare form
  #    while discussing it — one pull request in the dataset reads
  #    "Not verified: nothing" — is not a declaration, and blocking it would
  #    fire the guard on prose about the rule itself; this repository's own
  #    pull request for that rule reads exactly that way. Blanking can also
  #    swallow a real declaration when apostrophes pair up across it, and that
  #    is the direction to err in: a missed box-tick costs a caveat, a false
  #    block costs the guard its credibility.
  #    A fenced code block is a demonstration, not a declaration. Backticks are
  #    stripped by normalise, so the fences have to go before it runs, and only
  #    this check uses the stripped text: a body that shows the bad form in order
  #    to discuss it is the same case as one that quotes it inline, and the
  #    pull request fixing this guard is necessarily written that way.
  local nofence unquoted folded
  nofence="$(printf '%s' "$body" | LC_ALL=C awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    !infence { print }
  ' | normalise)"
  unquoted="$(printf '%s' "$nofence" | sed -e 's/"[^"]*"/QUOTED/g' -e "s/'[^']*'/QUOTED/g")"
  #    The declaration is as often a heading with the bare word beneath it as it
  #    is one line, and of the twenty-five most recent merged bodies here, every
  #    one that declares a surface uses the heading form. Matching only the one
  #    line would catch the shape nobody writes. Rather than a second pattern to
  #    keep in step with the first, each line is also read joined to the next
  #    non-empty one, and the same matcher runs over that. Joining cannot invent
  #    a match: the pattern anchors the bare word to the end, so a following
  #    line that says anything further ("None of the sync paths were exercised")
  #    still has content after it and does not match.
  folded="$(printf '%s\n' "$unquoted" | LC_ALL=C awk '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        j = i + 1
        while (j <= NR && line[j] ~ /^[[:space:]]*$/) j++
        if (j <= NR) print line[i] " " line[j]; else print line[i]
      }
    }')"
  if printf '%s\n%s' "$unquoted" "$folded" | grep -qiE '(^|[^[:alnum:]])(not[[:space:]]+(verified|checked)|unverified|nothing[[:space:]]+unverified)[[:punct:][:space:]]*(nothing|none|n/?a|nil|-)[[:punct:][:space:]]*$'; then
    deny "$source" "The unverified-surface section is a bare assertion. Say why there is nothing to check, in terms of what the change is."
  fi
}

# ── MCP route ──
case "$TOOL_NAME" in
  *create_pull_request|*update_pull_request)
    HAS_BODY="$(printf '%s' "$INPUT" | jq -r 'if (.tool_input | has("body")) then "yes" else "no" end')"
    # update_pull_request that does not touch the body is not this hook's business.
    if [ "$TOOL_NAME" != "${TOOL_NAME%update_pull_request}" ] && [ "$HAS_BODY" = "no" ]; then
      exit 0
    fi
    BODY="$(printf '%s' "$INPUT" | jq -r '.tool_input.body // empty')"
    check_body "$BODY" "MCP tool '$TOOL_NAME'"
    exit 0
    ;;
esac

# ── Shell route ──
[ -n "$COMMAND" ] || exit 0

printf '%s' "$COMMAND" \
  | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+(create|edit)([^[:alnum:]_-]|$)' \
  || exit 0

# `gh pr edit` that does not touch the body leaves the body as it was.
if printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+edit([^[:alnum:]_-]|$)'; then
  printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])(--body|--body-file|-b|-F)([[:space:]=]|$)' || exit 0
fi

BODY=""
READ_IT="no"

# --body-file / -F: read the file the command names.
if printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])(--body-file|-F)([[:space:]=]|$)'; then
  BODY_PATH="$(printf '%s' "$COMMAND" \
    | sed -nE 's/.*(^|[[:space:]])(--body-file|-F)[[:space:]=]+("([^"]*)"|'"'"'([^'"'"']*)'"'"'|([^[:space:]]+)).*/\4\5\6/p' \
    | head -1)"
  # This hook runs before the command does, so it sees the path as written.
  # Two shapes it cannot resolve, both of which look like a working command:
  # a path built from a shell variable, which is not in this hook's
  # environment, and a path to a file the same command is about to create with
  # a heredoc. Both are named explicitly, because "could not read the file" is
  # a useless thing to tell someone whose command was about to work.
  case "$BODY_PATH" in
    "~"/*) BODY_PATH="$HOME/${BODY_PATH#\~/}" ;;
  esac
  if printf '%s' "$BODY_PATH" | grep -q '[$`]'; then
    deny "'$COMMAND'" "The body file path is built from a shell variable, which this hook cannot expand. Pass a literal path."
  fi
  if [ -z "$BODY_PATH" ] || [ ! -r "$BODY_PATH" ]; then
    deny "'$COMMAND'" "The body file does not exist yet. Write it in one step and open the pull request in the next, so the justification can be read before it is published."
  fi
  BODY="$(cat "$BODY_PATH")"
  READ_IT="yes"
# --body / -b: read the quoted string.
elif printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])(--body|-b)([[:space:]=]|$)'; then
  BODY="$(printf '%s' "$COMMAND" \
    | sed -nE 's/.*(^|[[:space:]])(--body|-b)[[:space:]=]+("([^"]*)"|'"'"'([^'"'"']*)'"'"'|([^[:space:]]+)).*/\4\5\6/p' \
    | head -1)"
  READ_IT="yes"
fi

if [ "$READ_IT" = "no" ]; then
  # No readable body: an editor session, --fill from commit messages, or a
  # template. Fail closed, because a body this hook cannot read is a body it
  # cannot vouch for, and reporting green on an unread input is the shape of
  # failure the validation-state gate was fixed for.
  deny "'$COMMAND'" "The body is not on the command line, so the justification could not be read. Write it to a file and pass --body-file."
fi

check_body "$BODY" "'$COMMAND'"
exit 0
