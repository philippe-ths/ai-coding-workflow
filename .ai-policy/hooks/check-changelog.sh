#!/usr/bin/env bash
set -eu

# Pre-push check. Rejects the push if any commit in the push range
# changes the Version: header in ai-workflow.md without CHANGELOG.md
# (at HEAD) containing a matching entry for the new version.
#
# Reads the standard pre-push stdin format:
#   <local_ref> <local_sha> <remote_ref> <remote_sha>
# Zero-sha on either side means "no such ref"; we handle new branches
# and deletions accordingly.

ROOT_DIR="$(git rev-parse --show-toplevel)"
WORKFLOW_FILE="ai-workflow.md"
CHANGELOG_FILE="CHANGELOG.md"
ZERO="0000000000000000000000000000000000000000"

# Fallback base to diff against when the remote ref does not yet exist.
DEFAULT_BASE="origin/main"

# Collect each (local_sha, remote_sha) pair from stdin. If stdin is empty
# (hook invoked outside git push), exit 0.
PAIRS="$(cat || true)"
if [ -z "$PAIRS" ]; then
  exit 0
fi

extract_version_from_blob() {
  git show "$1:$WORKFLOW_FILE" 2>/dev/null | awk '/^Version:[[:space:]]*/ { print $2; exit }'
}

changelog_has_entry() {
  local version="$1"
  # Accept "## 2.6.0" or "## [2.6.0]" at start of line.
  git show "HEAD:$CHANGELOG_FILE" 2>/dev/null \
    | grep -Eq "^##[[:space:]]+\[?${version}\]?([[:space:]]|$)"
}

fail=0

while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
  [ -z "${local_sha:-}" ] && continue

  # Branch being deleted — nothing to check.
  if [ "$local_sha" = "$ZERO" ]; then
    continue
  fi

  if [ "$remote_sha" = "$ZERO" ]; then
    if git rev-parse --verify --quiet "$DEFAULT_BASE" >/dev/null; then
      base="$DEFAULT_BASE"
    else
      # No base to compare against — skip.
      continue
    fi
    range="${base}..${local_sha}"
  else
    range="${remote_sha}..${local_sha}"
  fi

  # Commits in this push that touched the workflow file.
  commits="$(git rev-list "$range" -- "$WORKFLOW_FILE" 2>/dev/null || true)"
  [ -z "$commits" ] && continue

  for sha in $commits; do
    parent="$(git rev-parse "${sha}^" 2>/dev/null || echo "")"
    [ -z "$parent" ] && continue

    new_version="$(extract_version_from_blob "$sha")"
    old_version="$(extract_version_from_blob "$parent")"

    if [ -n "$new_version" ] && [ "$new_version" != "$old_version" ]; then
      if ! changelog_has_entry "$new_version"; then
        echo "Blocked: commit $sha bumps ${WORKFLOW_FILE} Version to ${new_version}" >&2
        echo "but ${CHANGELOG_FILE} has no matching '## ${new_version}' entry." >&2
        echo "Add a Common Changelog entry for ${new_version} and re-push." >&2
        fail=1
      fi
    fi
  done
done <<EOF
$PAIRS
EOF

exit "$fail"
