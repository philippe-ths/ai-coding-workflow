#!/usr/bin/env bash
# Blocks a push whose content is not the content validation read.
#
# check-validation.sh answers "was a passing result recorded against the working
# tree as it stands?". That is the whole answer for a commit, because a commit
# writes the working tree. It is not the answer for a push, because a push writes
# a commit, and a commit can differ from the working tree by any amount.
#
# tree-fingerprint.sh excludes HEAD on purpose, so that committing does not
# invalidate the pass that the following push relies on. That exclusion is what
# leaves this gap: with HEAD out of the fingerprint, nothing at push time asks
# whether the commit being pushed carries the content that was validated.
#
# This script asks that question, in the one place git resolves it: the pre-push
# hook, which receives the refs actually being written.
#
# It refuses two shapes, both of which are "validated one artifact, published
# another":
#
#   dirty tree   — tracked content on disk differs from HEAD, so the commit being
#                  pushed is not the content that was fingerprinted.
#   foreign ref  — a ref is being pushed whose tip is not HEAD, so the working
#                  tree that was fingerprinted says nothing about it.
#
# It deliberately does not re-check the fingerprint; check-validation.sh owns
# that, and this runs after it.
#
# Reads git's pre-push stdin format, one line per ref:
#   <local_ref> <local_sha> <remote_ref> <remote_sha>
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"

# The validation state file is excluded from the comparison below, for the reason
# tree-fingerprint.sh excludes it: the pass is written into it, so a repository
# that has not ignored it has a dirty tree the moment validation succeeds, and
# every ordinary push would be refused. The exclusion is explicit rather than
# relying on the ignore rules, because an adopting project may track it.
#
# policy.env is sourced only if it is there, so the check can be exercised in a
# throwaway repository that carries no policy layer.
STATE_REL=""
if [ -f "$ROOT_DIR/.ai-policy/policy.env" ]; then
  # shellcheck disable=SC1091
  . "$ROOT_DIR/.ai-policy/policy.env"
  STATE_REL="${VALIDATION_STATE_FILE:-}"
fi

PUSH_REFS="$(cat || true)"

# Tag refs carry no working tree to compare against, and a deletion publishes no
# content at all. Both are skipped, as they are by the protected-branch check.
WRITING_SHAS=""
while IFS=' ' read -r _local_ref local_sha remote_ref _remote_sha; do
  [ -z "${remote_ref:-}" ] && continue
  case "$remote_ref" in
    refs/tags/*) continue ;;
  esac
  case "${local_sha:-}" in
    "") continue ;;
    *[!0]*) ;;
    *) continue ;;
  esac
  WRITING_SHAS="$WRITING_SHAS $local_sha"
done <<EOF
$PUSH_REFS
EOF

# Nothing is being written, so there is nothing to cover.
if [ -z "$WRITING_SHAS" ]; then
  exit 0
fi

# An unborn HEAD cannot be the tip of anything being pushed, and there is no tree
# to compare. Leave it to the checks that own those states.
if ! HEAD_SHA="$(git rev-parse --verify HEAD 2>/dev/null)"; then
  exit 0
fi

# Shape one: the tracked content on disk is not what HEAD holds. Validation read
# the disk; the push publishes HEAD. Untracked files are not asked about here —
# they are not published, and tree-fingerprint.sh already covers them for the
# question check-validation.sh asks.
if [ -n "$STATE_REL" ]; then
  set -- . ":(exclude)$STATE_REL"
else
  set -- .
fi
CHANGED="$(git -c color.ui=false status --porcelain --untracked-files=no -- "$@")"

if [ -n "$CHANGED" ]; then
  echo "Blocked: the commit being pushed is not the content that was validated."
  echo "Validation reads the working tree. A push publishes a commit. These have"
  echo "come apart: tracked files on disk differ from HEAD, so the changes below"
  echo "were validated and are not in what you are about to publish."
  echo ""
  printf '%s\n' "$CHANGED" | sed 's/^/  /'
  echo ""
  echo "Commit them, or stash them, then run"
  echo "./.ai-policy/scripts/run-validation.sh and push once it passes."
  exit 2
fi

# Shape two: a ref is being pushed that is not the commit the working tree
# corresponds to. The fingerprint can match perfectly and still say nothing about
# that ref's content.
for sha in $WRITING_SHAS; do
  if [ "$sha" != "$HEAD_SHA" ]; then
    echo "Blocked: a ref is being pushed that is not the commit that was validated."
    echo "Validation is recorded against the working tree, which corresponds to"
    echo "HEAD. This push writes a different commit, whose content nothing here"
    echo "has read."
    echo "  HEAD:           $HEAD_SHA"
    echo "  being pushed:   $sha"
    echo "Check out that branch, run ./.ai-policy/scripts/run-validation.sh, and"
    echo "push from there."
    exit 2
  fi
done

exit 0
