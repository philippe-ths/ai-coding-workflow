#!/usr/bin/env bash
set -eu

# PreToolUse hook for Claude Code.
# Blocks Bash git commands (commit, push) when on a protected branch.
# Reads tool_input from JSON on stdin.
# Exit 2 = block, exit 0 = allow.

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"

# Only check git commit and git push commands.
case "$COMMAND" in
  git\ commit*|git\ push*) ;;
  *) exit 0 ;;
esac

# Tag-only pushes do not modify a branch and are allowed on protected branches.
# The authoritative safety net is check-push-refs.sh, invoked by the pre-push
# git hook, which inspects the resolved refs git is actually about to write.
# Everything in this file is a usability-layer heuristic working from a command
# string: it fires before the command runs, so it gives a better error, but it
# can be defeated by shell constructs it cannot parse. When the two disagree,
# the pre-push check is correct.
is_tag_push() {
  local cmd="$1"
  # git commit never creates a tag push; only applies to push commands.
  case "$cmd" in
    git\ push*) ;;
    *) return 1 ;;
  esac

  # --tags or --mirror-with-tags flags → tag push if not combined with branch refs.
  case " $cmd " in
    *\ --tags\ *|*\ --tags) return 0 ;;
  esac

  # Explicit refs/tags/ refspec anywhere in the command.
  case "$cmd" in
    *refs/tags/*) return 0 ;;
  esac

  # "git push <remote> tag <name>" form.
  if printf '%s' "$cmd" | grep -Eq '\bpush\b[^|;&]*\btag\b[[:space:]]+[^[:space:]]+'; then
    return 0
  fi

  # "git push <remote> <name>" where <name> is a tag in the current repo.
  # Strip git/push and known flag-words, then take the last positional token.
  local args
  args="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]*//')"
  # Remove flags (tokens starting with -) to find positional args.
  local positional last=""
  for token in $args; do
    case "$token" in
      -*) continue ;;
      *) positional="$token"; last="$token" ;;
    esac
  done
  if [ -n "$last" ] && [ "$last" != "$positional" ]; then
    : # unreachable; keep shellcheck happy
  fi
  if [ -n "$last" ]; then
    if git tag -l "$last" 2>/dev/null | grep -qx "$last"; then
      # Also ensure it is not simultaneously a branch name.
      if ! git rev-parse --verify --quiet "refs/heads/$last" >/dev/null 2>&1; then
        return 0
      fi
    fi
  fi

  return 1
}

if is_tag_push "$COMMAND"; then
  exit 0
fi

# One parse, two questions: what does this command write to, and is it only
# deleting? Both are read from the same tokens so they cannot drift apart or
# reach different conclusions about the same command.
#
# The parse works from a command string, so it is approximate: a flag taking a
# separate value shifts the positional count, and the remote and every target
# are then read one token out. The limitation belongs to the parse rather than
# to either question, which is why it is stated here once. check-push-refs.sh
# reads the refs git actually resolved and is unaffected by it; when the two
# disagree, it is correct.
#
# Sets, for a `git push` command:
#   PUSH_TARGETS    destination branch name per refspec, space-separated
#   PUSH_REFSPECS   how many refspecs were given
#   PUSH_DELETIONS  how many of those are deletions
# Anything that is not a push leaves the counts at zero and returns 1.
parse_push_command() {
  local cmd="$1"
  PUSH_TARGETS=""
  PUSH_REFSPECS=0
  PUSH_DELETIONS=0

  case "$cmd" in
    git\ push*) ;;
    *) return 1 ;;
  esac

  local args
  args="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]*//')"

  local delete_flag=false seen_remote=false target
  for token in $args; do
    case "$token" in
      --delete|-d) delete_flag=true; continue ;;
      -*) continue ;;
    esac

    # The first positional is the remote, not a refspec.
    if [ "$seen_remote" = false ]; then
      seen_remote=true
      continue
    fi

    PUSH_REFSPECS=$((PUSH_REFSPECS + 1))

    # Refspec forms: <dst>, <src>:<dst>, :<dst> (delete), +<src>:<dst> (force).
    target="${token#+}"
    case "$target" in
      *:*) target="${target##*:}" ;;
    esac
    PUSH_TARGETS="$PUSH_TARGETS ${target#refs/heads/}"

    # `:<dst>` with an empty source is the refspec form of a deletion.
    case "$token" in
      :?*) PUSH_DELETIONS=$((PUSH_DELETIONS + 1)) ;;
    esac
  done

  # --delete applies to the whole command, wherever in it the flag appears, so
  # it is settled after the loop rather than per token.
  if [ "$delete_flag" = true ]; then
    PUSH_DELETIONS="$PUSH_REFSPECS"
  fi

  return 0
}

# Non-push commands leave the counts at zero, so both questions below answer no
# and the command falls through to the current-branch rule, as it should.
parse_push_command "$COMMAND" || :

# Does an explicit refspec name a protected branch as its target?
# `git push origin HEAD:main` writes to a protected branch while the current
# branch is unprotected, so the current-branch check below cannot see it.
targets_protected_branch() {
  local target protected
  for target in $PUSH_TARGETS; do
    for protected in $PROTECTED_BRANCHES; do
      if [ "$target" = "$protected" ]; then
        return 0
      fi
    done
  done

  return 1
}

if targets_protected_branch; then
  echo "Blocked: '$COMMAND' targets protected branch." >&2
  echo "The refspec writes to a protected branch even though the current branch is not one." >&2
  echo "Open a pull request instead; merging it is the human's decision." >&2
  exit 2
fi

# Does the command only delete refs? A deletion writes to no branch's contents,
# so the current-branch rule below does not apply to it. A deletion naming a
# protected branch was already rejected above, so what reaches here removes
# unprotected refs only. Post-merge cleanup deletes the merged branch from the
# protected branch it just switched back to; without this it is always blocked.
#
# A command naming no refspec at all is not a deletion: `git push --delete` on
# its own names nothing, and plain `git push` implies its target from the
# current branch, which is exactly what the rule below is for.
is_delete_only_push() {
  [ "$PUSH_REFSPECS" -gt 0 ] && [ "$PUSH_DELETIONS" -eq "$PUSH_REFSPECS" ]
}

if is_delete_only_push; then
  exit 0
fi

CURRENT_BRANCH="$("$ROOT_DIR/.ai-policy/scripts/current-branch.sh")"

for protected in $PROTECTED_BRANCHES; do
  if [ "$CURRENT_BRANCH" = "$protected" ]; then
    echo "Blocked: '$COMMAND' on protected branch '$CURRENT_BRANCH'." >&2
    echo "Create or switch to an issue-scoped branch before continuing." >&2
    exit 2
  fi
done

exit 0
