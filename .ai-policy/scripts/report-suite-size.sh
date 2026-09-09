#!/usr/bin/env bash
set -eu

# Reports how large a repository's checks are. It reports and never gates.
#
# Two designs that gated on this number were built and rejected, both for the
# same reason: they blocked an unchanged tree. Gating on runtime fires on noise,
# since the same suite measured 70s and 121s here depending on machine load.
# Gating on bytes fires on symlinks, on clean/smudge filters such as autocrlf,
# and on git-lfs, because the working tree and the stored blob are then
# different units. Neither is recoverable by removing checks.
#
# A number the human reads has neither failure mode, so this exits 0 whatever it
# finds. What to do about a large suite is a judgement about the project, and it
# belongs to the human rather than to a threshold an agent picked.

if ! ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "checks: not measured (not inside a git work tree)"
  exit 0
fi
# shellcheck disable=SC1091
. "$ROOT_DIR/.ai-policy/policy.env"

# Globbing is off for the whole script. These are git pathspecs and must reach
# git intact; left on, the shell would expand them against the current directory
# and hand git a list of local filenames instead.
set -f

# Conventional test locations, used when the repository declares none. A git
# pathspec is anchored at the start of the path, so a pattern for files nested
# anywhere needs its own leading wildcard. Any repository whose checks do not
# follow these conventions should declare SUITE_PATHS; the count is only as
# honest as the patterns, and it says which set it used.
DEFAULT_SUITE_PATHS="test/* tests/* spec/* specs/* */test/* */tests/* */spec/* */specs/* test-* test_* */test-* */test_* *_test.* *.test.* *_spec.* *.spec.* *-test.*"
if [ -n "${SUITE_PATHS:-}" ]; then
  PATHS="$SUITE_PATHS"
  SOURCE="declared in policy.env"
else
  PATHS="$DEFAULT_SUITE_PATHS"
  SOURCE="conventional defaults"
fi

TOTAL=0
COUNT=0
# -z, and a null-delimited read, because git C-quotes any path containing
# non-ASCII or control characters. Read as plain lines, such a file fails the
# existence test and silently counts as nothing.
# Untracked-but-not-ignored files count: a check that has not been staged yet is
# still a check that exists in this tree.
# shellcheck disable=SC2086
while IFS= read -r -d '' f; do
  [ -f "$ROOT_DIR/$f" ] || continue
  TOTAL=$(( TOTAL + $(wc -c < "$ROOT_DIR/$f") ))
  COUNT=$(( COUNT + 1 ))
done < <(git -C "$ROOT_DIR" ls-files -z --cached --others --exclude-standard -- $PATHS)

echo "checks: ${COUNT} files, ${TOTAL} bytes (${SOURCE})"
exit 0
