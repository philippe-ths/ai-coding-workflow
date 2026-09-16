#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code, Codex, and VS Code Copilot.
# Blocks opening or editing a pull request whose body carries no verification
# justification, or whose unverified-surface section is a bare assertion, or
# which changed agent-facing prose without recording an aiw-prompt-smith pass.
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
# The three checks below are the ones a script can make without that judgement.
#
# The third exists because a rule that lived only in prose and memory was
# skipped on three runs of pull requests (#218 to #223, #294, #302), and each
# time the pass, once asked for, cut real defects. Agent-facing prose is found by
# path: the skill and agent directories, the three entry points, and whatever
# those entry points pull in through an @ line, followed transitively, because
# the file that bit hardest was a README an entry point included and nobody
# thought of as a prompt. A file an agent reads because prose tells it to is
# outside what a path rule can see; aiw-prompt-smith's Layer question covers
# that at plan time.
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
  if [ "${3:-}" = "prose" ]; then
    echo "Invoke aiw-prompt-smith over those files, then record in the body what the pass found," >&2
    echo "even when it found nothing to change. The hook checks that it ran, not that it was good." >&2
  else
    echo "See aiw-verification's justification step. Part 3 names what was not checked;" >&2
    echo "an empty part 3 is an argument in terms of what the change is, never a bare assertion." >&2
  fi
  exit 2
}

# Print the agent-facing prose files this branch changed, one per line, or
# nothing. The branch is read against the protected branches from policy.env
# (else main master), local and remote, taking the newest merge-base so a
# stale origin does not drag the base back and fire on a code-only branch.
# Uncommitted changes count, since the body may be written before the last
# commit. When no base resolves or git is unavailable, print nothing: a check
# that cannot be evaluated is skipped, not failed, because blocking every pull
# request in a repository whose base is not fetched is the false block that
# gets a guard routed around.
#
# Agent-facing prose is found by path: the skill and agent directories, the
# entry points and ai-workflow.md, and whatever an entry point pulls in with an
# @ token, followed through further @ tokens, in the working tree and in the
# base so a deleted include still counts. An @ token is text from a file in the
# working tree, which a cloned repository can make hostile, so it is never
# handed to a shell: paths are restricted to a plain character set, may not
# leave the repository, may not themselves be symlinks, and are read with a
# size cap.
prose_files_changed() {
  local root branches b cand mb newest files entries f
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  branches="main master"
  if [ -r "$root/.ai-policy/policy.env" ]; then
    branches="$( ( set +eu; . "$root/.ai-policy/policy.env" >/dev/null 2>&1; printf '%s' "${PROTECTED_BRANCHES:-main master}" ) 2>/dev/null || printf 'main master' )"
  fi
  newest=""
  for b in $branches; do
    for cand in "origin/$b" "$b"; do
      git -C "$root" rev-parse --verify -q "$cand" >/dev/null 2>&1 || continue
      mb="$(git -C "$root" merge-base HEAD "$cand" 2>/dev/null)" || continue
      if [ -z "$newest" ] || git -C "$root" merge-base --is-ancestor "$newest" "$mb" 2>/dev/null; then
        newest="$mb"
      fi
    done
  done
  [ -n "$newest" ] || return 0
  mb="$newest"
  files="$( { git -C "$root" -c core.quotePath=false diff --name-only --no-renames "$mb" 2>/dev/null
              git -C "$root" -c core.quotePath=false status --porcelain --no-renames -uall 2>/dev/null | cut -c4-
            } | sort -u )"
  [ -n "$files" ] || return 0

  entries="$(prose_includes "$root" "$mb")"

  printf '%s\n' "$files" | while IFS= read -r f; do
    case "$f" in
      .claude/skills/*|.agents/skills/*|.claude/agents/*|.github/agents/*|ai-workflow.md) echo "$f"; continue ;;
    esac
    if printf '%s\n' "$entries" | grep -qxF -- "$f"; then echo "$f"; fi
  done
}

# Normalise a repository-relative path, resolving . and .., and print it; fail
# when the path climbs above the repository root. No filesystem access, so a
# symlink cannot redirect it, and no shell sees the text.
inside_repo() {
  local IFS='/' seg out=""
  case "$1" in /*) return 1 ;; esac
  for seg in $1; do
    case "$seg" in
      ''|'.') ;;
      '..') [ -n "$out" ] || return 1; case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

# The entry points and everything they include, transitively, read from the
# working tree and from the base commit. Prints one path per line.
prose_includes() {
  local root="$1" mb="$2" queue seen p tok dir cand src content
  queue="CLAUDE.md AGENTS.md .github/copilot-instructions.md"
  seen=""
  while [ -n "$queue" ]; do
    p="${queue%% *}"
    queue="${queue#"$p"}"; queue="${queue# }"
    case " $seen " in *" $p "*) continue ;; esac
    seen="$seen $p"
    dir="${p%/*}"; [ "$dir" = "$p" ] && dir=""
    for src in tree base; do
      if [ "$src" = tree ]; then
        [ -f "$root/$p" ] && [ ! -L "$root/$p" ] || continue
        content="$(head -c 1000000 -- "$root/$p" 2>/dev/null)" || continue
      else
        content="$(git -C "$root" show "$mb:$p" 2>/dev/null | head -c 1000000)" || continue
        [ -n "$content" ] || continue
      fi
      # Drop fenced code blocks (a demonstration is not an include), then take
      # every whitespace-delimited token that starts with @, less trailing
      # punctuation. Only plain paths are followed; anything else is ignored.
      for tok in $(printf '%s\n' "$content" | LC_ALL=C awk '/^[[:space:]]*```/ { f = !f; next } !f { print }' \
                    | grep -oE '(^|[[:space:](])@[^[:space:]]+' | sed -e 's/^[[:space:](]*@//' -e 's/[.,;:)]*$//' \
                    | grep -E '^[A-Za-z0-9._/-]+$' | sort -u); do
        [ "$(wc -w <<<"$seen $queue")" -lt 200 ] || break
        for cand in "${dir:+$dir/}$tok" "$tok"; do
          cand="$(inside_repo "$cand")" || continue
          if { [ -f "$root/$cand" ] && [ ! -L "$root/$cand" ]; } || git -C "$root" cat-file -e "$mb:$cand" 2>/dev/null; then
            case " $seen $queue " in *" $cand "*) ;; *) queue="$queue $cand" ;; esac
            break
          fi
        done
      done
    done
    queue="${queue# }"
  done
  printf '%s\n' $seen | grep -v '^$' || true
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

  # 3. A branch that changed agent-facing prose records an aiw-prompt-smith
  #    pass. Presence only, as in check 1: the body has to say the pass ran and
  #    what it found, and whether that was a good pass is the human's to judge.
  #    A body that names the pass only to say it was skipped passes this
  #    check, deliberately: every matcher tried for that shape blocked honest
  #    bodies ("n/a for the test file", "not run over the fixtures") while
  #    catching four spellings of the lie, which is the trade check 2 refuses
  #    in the other direction. A skipped pass reported in the body is in front
  #    of the human, which is where that decision belongs.
  local prose named
  prose="$(prose_files_changed)"
  if [ -n "$prose" ] && ! printf '%s' "$norm" | grep -qiE 'prompt[- ]?smith'; then
    named="$(printf '%s' "$prose" | tr '\n' ' ' | tr -cd '[:print:]' | sed 's/ $//')"
    deny "$source" "The branch changed agent-facing prose ($named) and the body records no aiw-prompt-smith pass." "prose"
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
