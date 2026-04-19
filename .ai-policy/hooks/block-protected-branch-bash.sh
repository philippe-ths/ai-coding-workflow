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
# The authoritative safety net is the pre-push git hook, which inspects the
# actual refs being pushed. This is a usability-layer heuristic.
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

CURRENT_BRANCH="$("$ROOT_DIR/.ai-policy/scripts/current-branch.sh")"

for protected in $PROTECTED_BRANCHES; do
  if [ "$CURRENT_BRANCH" = "$protected" ]; then
    echo "Blocked: '$COMMAND' on protected branch '$CURRENT_BRANCH'." >&2
    echo "Create or switch to an issue-scoped branch before continuing." >&2
    exit 2
  fi
done

exit 0
