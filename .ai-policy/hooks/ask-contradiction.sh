#!/usr/bin/env bash
# UserPromptSubmit hook for Claude Code and Codex: puts the Reactive Rules'
# question in front of the agent on every message the human sends.
#
# The rule that a contradicted "done" claim stops the work for
# aiw-failure-analysis has lived in prose since the start, and four rounds of
# rewording it (#98, #213, #251, #370) did not make it fire on the human's own
# reports. A field review of 5.35.0 found 32 such messages in 608, phrased
# every way from "Wheres km?" to asking whether a change works at all, and the
# skill loaded after 1 of them. Those 32 were found by a model asked the
# question of each message in turn; the agents in the sessions were never asked
# it. Recognition is not what fails; asking is, so this asks.
#
# It asks on every message rather than on a keyword match, because the same
# review measured a keyword matcher at 62% recall and 31% precision: it missed
# the contradictions phrased as questions and fired on "try again". The note is
# short and tells the agent to stay silent when the answer is no, so a message
# that contradicts nothing costs a few tokens and nothing the human sees.
#
# Advisory and fail-open: every path exits 0, and a payload it cannot read
# produces no output rather than an error, since a nudge that can break a
# session is worse than no nudge.

INPUT="$(cat 2>/dev/null)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
[ -n "$(printf '%s' "$PROMPT" | tr -d '[:space:]')" ] || exit 0

NOTE='If this message says something you delivered or claimed is wrong, still broken, untested, or not what was asked, that is a contradicted "done" claim: load aiw-failure-analysis before any other step, including a fix or an explanation. If it does not, carry on and do not mention this note.'

jq -n --arg note "$NOTE" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $note}}' 2>/dev/null
exit 0
