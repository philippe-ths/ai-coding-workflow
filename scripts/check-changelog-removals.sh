#!/usr/bin/env bash
# Enforce the leading-path convention for CHANGELOG `### Removed` bullets.
#
# Every bullet inside a `### Removed` section must lead with the removed path as
# a backticked token, with no spaces inside it:
#
#   - `path/to/thing` — explanation
#
# The update path (scripts/update.sh) parses these to learn which installed
# files to delete from a target repo, so the format must stay machine-
# extractable. This is FACTORY-ONLY validation: it runs from scripts/
# (never shipped) and only governs this repo's own CHANGELOG, never a target's.
#
# Usage: check-changelog-removals.sh [changelog-file]   (defaults to repo CHANGELOG.md)
set -eu

if [ "${1:-}" != "" ]; then
  CHANGELOG="$1"
else
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
  CHANGELOG="$ROOT_DIR/CHANGELOG.md"
fi

[ -f "$CHANGELOG" ] || { echo "changelog removals: FAIL — file not found: $CHANGELOG" >&2; exit 1; }

bt='`'
# A compliant bullet: "- `<path>`..." with no space/backtick inside the token.
compliant_re="^- ${bt}[^${bt} ]+${bt}"

errors=0
in_removed=0
lineno=0

while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  case "$line" in
    "### Removed"*) in_removed=1; continue ;;
    "### "*)        in_removed=0; continue ;;   # any other ### subsection ends the block
    "## "*)         in_removed=0; continue ;;   # next version ends the block
  esac
  [ "$in_removed" -eq 1 ] || continue
  # Only top-level bullets are validated; blank lines and prose are ignored.
  case "$line" in
    "- "*)
      if ! [[ "$line" =~ $compliant_re ]]; then
        echo "changelog removals: FAIL — bullet does not lead with a backticked path (line $lineno): $line" >&2
        errors=$((errors + 1))
      fi
      ;;
  esac
done < "$CHANGELOG"

if [ "$errors" -gt 0 ]; then
  echo "changelog removals: FAIL ($errors problem(s))" >&2
  exit 1
fi

echo "changelog removals: OK"
