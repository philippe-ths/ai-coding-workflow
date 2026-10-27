#!/usr/bin/env bash
# SessionStart hook for Claude Code and Codex: puts the human's working
# preferences in front of the agent in every session in every repository.
#
# A preference the human states ("always link the pull request") used to live
# only in the session it was said in, or in one repository's agent memory. A
# field review of 5.35.0 (#419) found the same preference restated in
# two repositories, and one an agent had promised to follow "from now on"
# broken six days later, with no memory written in that repository.
# ai-workflow.md has the agent write each preference that is not tied to one
# repository to a single file outside them all; this hook reads it back, so
# the file is the one place the human looks to see them.
#
# It is registered with no matcher, so in Claude Code it also runs after
# compaction, since a summary does not carry the preferences forward.
#
# Advisory and fail-open: every path exits 0, and it stays silent when the
# file is absent, empty, or unreadable.

PREFS="${AIW_PREFERENCES_FILE:-$HOME/.aiw/preferences.md}"

[ -r "$PREFS" ] || exit 0
BODY="$(cat "$PREFS" 2>/dev/null)" || exit 0
[ -n "$(printf '%s' "$BODY" | tr -d '[:space:]')" ] || exit 0

printf 'Working preferences the human has stated, from %s:\n\n%s\n' "$PREFS" "$BODY"
exit 0
