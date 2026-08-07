#!/usr/bin/env bash
# Prints a fingerprint of the current working tree's content.
#
# The validation gate records this alongside a passing result so that the pass
# can be tied to the content it was computed against. Two runs over an identical
# tree must print the same value, and any change to a file the project would
# validate must change it — an unstable fingerprint blocks every commit, and one
# that misses a change lets a stale pass through.
#
# Covers tracked files plus untracked files git would not ignore. Ignored files
# are excluded deliberately: validation does not read them, so changing one is
# not a reason to revalidate.
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"
cd "$ROOT_DIR"

STATE_REL="$VALIDATION_STATE_FILE"

# The state file is excluded from every part of the stream below. The fingerprint
# is written into it, so including it would make each recorded result invalidate
# itself on the next read. It is gitignored in this repository, but an adopting
# project may not have ignored it, so the exclusion is explicit rather than
# relying on the ignore rules.
ALL_PATHS="$(
  git -c core.quotePath=false ls-files --cached --others --exclude-standard |
    LC_ALL=C sort -u |
    while IFS= read -r p; do
      if [ -n "$p" ] && [ "$p" != "$STATE_REL" ]; then
        printf '%s\n' "$p"
      fi
    done
)"

# git emits a path containing a quote, a backslash, or a control character in
# quoted form ("weird\nname.txt"), which no longer names a file on disk. Such a
# path would drop out of the content hashing below while still appearing in the
# path list, so edits to that file would not move the fingerprint — the same
# fail-open shape this script exists to close. Refuse to produce a fingerprint at
# all rather than produce one that silently covers less than it appears to.
# Paths containing spaces are not quoted and are handled normally.
QUOTED_PATHS="$(
  printf '%s\n' "$ALL_PATHS" |
    while IFS= read -r p; do
      case "$p" in
        '"'*) printf '%s\n' "$p" ;;
      esac
    done
)"

if [ -n "$QUOTED_PATHS" ]; then
  echo "tree-fingerprint: cannot fingerprint a tree containing these paths:" >&2
  printf '%s\n' "$QUOTED_PATHS" >&2
  echo "Their names contain a quote, backslash, or control character, so their" >&2
  echo "contents cannot be hashed reliably and a fingerprint would understate" >&2
  echo "what changed. Rename or remove them." >&2
  exit 1
fi

# Only existing regular files can be hashed. A tracked file deleted from the
# working tree is carried by the porcelain status line instead, so a deletion
# still moves the fingerprint rather than aborting the run.
EXISTING_PATHS="$(
  printf '%s\n' "$ALL_PATHS" |
    while IFS= read -r p; do
      if [ -n "$p" ] && [ -f "$p" ]; then
        printf '%s\n' "$p"
      fi
    done
)"

# What the fingerprint covers is the content validation actually read: the paths
# on disk and their contents. It deliberately excludes two things that move
# during an ordinary commit without changing that content.
#
# Index state is excluded: `git add` changes whether a modification is staged,
# not what any file contains. Including it blocked the commit that immediately
# followed a passing validation run.
#
# HEAD is excluded: committing moves it while leaving every file on disk
# identical. Including it blocked the push that followed a commit, so every
# commit would have demanded a second validation run before it could be pushed.
# A gate that fires on the normal path trains people to route around it.
{
  # Path names, so a rename that preserves content still moves the fingerprint.
  printf '%s\n' "$ALL_PATHS"

  # Tracked files missing from the working tree. These carry no content hash
  # below, and naming them keeps a deletion unambiguous rather than inferred
  # from the hash list being one line shorter.
  git -c core.quotePath=false ls-files --deleted | LC_ALL=C sort -u

  # Content, hashed by git itself so the format needs no external checksum tool.
  if [ -n "$EXISTING_PATHS" ]; then
    printf '%s\n' "$EXISTING_PATHS" | git hash-object --stdin-paths
  fi
} | git hash-object --stdin
