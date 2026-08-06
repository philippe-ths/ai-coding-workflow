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

# Does an explicit refspec name a protected branch as its target?
# `git push origin HEAD:main` writes to a protected branch while the current
# branch is unprotected, so the current-branch check below cannot see it.
targets_protected_branch() {
  local cmd="$1"
  case "$cmd" in
    git\ push*) ;;
    *) return 1 ;;
  esac

  local args
  args="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]*//')"

  local seen_remote=false target
  for token in $args; do
    # Skip flags. A flag taking a separate value can shift the positional
    # count and cause a miss; check-push-refs.sh is the backstop for that.
    case "$token" in
      -*) continue ;;
    esac

    # The first positional is the remote, not a refspec.
    if [ "$seen_remote" = false ]; then
      seen_remote=true
      continue
    fi

    # Refspec forms: <dst>, <src>:<dst>, :<dst> (delete), +<src>:<dst> (force).
    target="${token#+}"
    case "$target" in
      *:*) target="${target##*:}" ;;
    esac
    target="${target#refs/heads/}"

    for protected in $PROTECTED_BRANCHES; do
      if [ "$target" = "$protected" ]; then
        return 0
      fi
    done
  done

  return 1
}

if targets_protected_branch "$COMMAND"; then
  echo "Blocked: '$COMMAND' targets protected branch." >&2
  echo "The refspec writes to a protected branch even though the current branch is not one." >&2
  echo "Open a pull request instead; merging it is the human's decision." >&2
  exit 2
fi

# Does the command only delete refs? A deletion writes to no branch's contents,
# so the current-branch rule below does not apply to it. A delete naming a
# protected branch was already rejected above, so what reaches here removes
# unprotected refs only. Post-merge cleanup deletes the merged branch from the
# protected branch it just switched back to; without this it is always blocked.
# Like every heuristic in this file it reads a command string, so a flag taking
# a separate value can shift the positional count; check-push-refs.sh, which
# rejects deletions of protected refs from the resolved refs, is the backstop.
is_delete_push() {
  local cmd="$1"
  case "$cmd" in
    git\ push*) ;;
    *) return 1 ;;
  esac

  local args
  args="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]*//')"

  local delete_flag=false seen_remote=false refspecs=0 colon_forms=0
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

    refspecs=$((refspecs + 1))
    # `:<dst>` with an empty source is the refspec form of a deletion.
    case "$token" in
      :?*) colon_forms=$((colon_forms + 1)) ;;
    esac
  done

  # `git push --delete` with no ref names nothing; leave it to the rules below.
  [ "$refspecs" -eq 0 ] && return 1

  # With --delete, every listed ref is deleted.
  [ "$delete_flag" = true ] && return 0

  # Without it, only a push whose every refspec is a `:<dst>` deletion qualifies.
  [ "$colon_forms" -eq "$refspecs" ] && return 0

  return 1
}

if is_delete_push "$COMMAND"; then
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
