#!/usr/bin/env bash
# UserPromptSubmit hook for Claude Code and Codex: puts the Reactive Rules'
# question in front of the agent on every message the human sends.
#
# The rule that a contradicted "done" claim stops the work for
# aiw-failure-analysis has lived in prose since the start. Strengthening the
# human-report trigger in prose (#98) did not hold: a field review of 5.35.0
# (#370) labelled 32 of 608 human messages as contradicting delivered work,
# phrased every way from "Wheres km?" to asking whether a change works at all,
# and the skill loaded after 1 of them. The labels came from a model asked the
# question of each message in turn, so they say the question can be answered
# from the message, not how often an agent would answer it; the agents in those
# sessions were never asked it. This asks.
#
# It asks on every message rather than on a keyword match, because the same
# review measured a keyword matcher at 62% recall and 31% precision: it missed
# the contradictions phrased as questions and fired on messages like "try
# again". The note is short and tells the agent to stay silent when the answer
# is no, so a message that contradicts nothing costs a few tokens and nothing
# the human sees.
#
# Advisory and fail-open: every path exits 0, and a payload it cannot read
# produces no output rather than an error, since a nudge that can break a
# session is worse than no nudge.

INPUT="$(cat 2>/dev/null)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
[ -n "$(printf '%s' "$PROMPT" | tr -d '[:space:]')" ] || exit 0

NOTE='If this message says work you delivered, or a result you said was done, is wrong, still broken, unchecked, or not what was asked, that is a contradicted "done" claim: load aiw-failure-analysis before any other step, including a fix or an explanation. If it does not, carry on and do not mention this note.'

jq -n --arg note "$NOTE" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $note}}' 2>/dev/null
exit 0
