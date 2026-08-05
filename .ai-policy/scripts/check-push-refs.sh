#!/usr/bin/env bash
set -eu

# Authoritative protected-branch check for pushes.
# Reads git's pre-push stdin format, one line per ref:
#   <local_ref> <local_sha> <remote_ref> <remote_sha>
# Blocks when any remote_ref names a protected branch.
# Exit 2 = block, exit 0 = allow.
#
# This asks "what is being written to?" rather than "where am I standing?".
# check-protected-branch.sh asks the second question, which a refspec push
# answers incorrectly: `git push origin HEAD:main` from a feature branch
# writes to a protected branch while standing on an unprotected one.
# Only the pre-push hook receives the resolved refs, so this is the only
# place the real target can be checked rather than guessed from a command
# string.

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

BLOCKED=""

# The `|| [ -n ... ]` clause processes a final line with no trailing newline.
# Without it, `read` returns non-zero on that line and the loop body is
# skipped, silently allowing the very ref being checked.
while IFS=' ' read -r _local_ref _local_sha remote_ref _remote_sha \
  || [ -n "${remote_ref:-}" ]; do
  [ -z "${remote_ref:-}" ] && continue

  # Only branch refs can be a protected branch. Tags are handled by the caller.
  case "$remote_ref" in
    refs/heads/*) branch="${remote_ref#refs/heads/}" ;;
    *) continue ;;
  esac

  for protected in $PROTECTED_BRANCHES; do
    if [ "$branch" = "$protected" ]; then
      BLOCKED="$BLOCKED $branch"
    fi
  done
done

if [ -n "$BLOCKED" ]; then
  echo "Blocked: push targets protected branch(es):$BLOCKED" >&2
  echo "The ref being pushed, not the branch you are standing on, is what matters here." >&2
  echo "Open a pull request instead; merging it is the human's decision." >&2
  exit 2
fi

exit 0
