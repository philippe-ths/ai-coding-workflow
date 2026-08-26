#!/usr/bin/env bash
# PreToolUse hook: points the agent at aiw-project-context-management at the two
# moments project-context.md actually goes wrong.
#
#   Arm 1 — a pull request is about to open on a branch that changed something the
#           context file is contractually required to record, without touching it.
#   Arm 2 — a tool call is about to write the context file.
#
# Advisory, never blocking. It emits additionalContext with no permissionDecision
# key, which delivers text to the agent and leaves the tool call to the normal
# permission flow. Emitting "allow" would deliver the same text and also
# auto-approve the call; on the broad matchers this is registered under that
# would silently bypass the human's permission prompts for every tool call it
# fires on, so the key is omitted deliberately rather than left out by oversight.
#
# It is registered on broad matchers, and under VS Code Copilot every hook runs
# on every tool call, so silence on a non-match is the load-bearing behaviour:
# when neither arm matches this prints nothing at all and exits 0. Every failure
# path exits 0 too. No `set -eu`, config resolved relative to $0 before any cd —
# the same defensive shape as check-context-drift.sh, for the same reason: an
# advisory nudge that can break a session is worse than no nudge.
#
# Arm 1 deliberately omits two shapes that existing validation already catches.
# A new top-level tracked file fails scripts/check-manifest.sh, whose coverage
# check rejects any tracked file no manifest category claims. An added skill
# directory fails scripts/check-prose-integrity.sh, which asserts that
# project-context.md names every skill in the tree. Firing on either would put a
# second guard behind a gate that already holds, and every extra firing spends
# the credibility the real ones need.
#
# What it does fire on are the shapes nothing else sees. Prose integrity walks the
# skills that exist and checks the context file names them; it never walks the
# other way, so a skill deleted from both trees leaves the context file naming a
# skill that is gone and validation stays green. The manifest classifies by
# directory prefix, so a module added, removed or renamed inside .ai-policy/,
# .githooks/, scripts/ or observation/ is classified the moment it lands and no
# check asks whether the context file's account of that directory still holds.
# Nothing at all reads the context file against what the policy layer now
# enforces, or against what validation now covers.
#
# The signal is that the branch touched something the file is supposed to
# describe. That is not the same as the file being stale, and the message must
# not claim it is: a meaningful share of firings will be changes that altered
# nothing the file records, so proceeding has to read as an acceptable answer.

# ── config, resolved relative to this script before any directory change ──
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
POLICY_ENV="$SCRIPT_DIR/../policy.env"

if [ -f "$POLICY_ENV" ]; then
  # shellcheck disable=SC1090
  . "$POLICY_ENV" 2>/dev/null || true
fi
CONTEXT_FILE="${CONTEXT_FILE:-project-context.md}"
BASE_BRANCHES="${PROTECTED_BRANCHES:-main master}"

# additionalContext is a JSON string, so the payload has to be escaped rather
# than interpolated. Without jq there is no safe way to build it, and a
# malformed payload on a PreToolUse hook is a worse outcome than a missing
# reminder — so degrade to silence, as scripts/check-manifest.sh does.
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)" || exit 0
[ -n "$INPUT" ] || exit 0

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"

remind() {
  jq -n --arg c "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}' \
    2>/dev/null
  exit 0
}

# The context filename as a regex-safe token, for the shell-route matchers.
CTX_RE="$(printf '%s' "$CONTEXT_FILE" | sed 's/[.[\*^$]/\\&/g')"

# ── Arm 2: a tool call is about to write the context file ──
# Native route: the target path in the tool input. Tools disagree on the key
# name, so the first string among the known ones is taken.
TARGET="$(printf '%s' "$INPUT" | jq -r '
  (.tool_input // {})
  | [.file_path?, .path?, .filePath?, .notebook_path?, .filename?, .file?]
  | map(select(type == "string"))
  | .[0] // empty' 2>/dev/null)"

writes_context="no"
case "$TARGET" in
  "$CONTEXT_FILE"|*/"$CONTEXT_FILE") writes_context="yes" ;;
esac

# Shell route: only shapes that write. A command that merely reads or greps the
# file is not the moment this arm is for, and firing on one would train the
# reminder out.
if [ "$writes_context" = "no" ] && [ -n "$COMMAND" ]; then
  if printf '%s' "$COMMAND" | grep -Eq \
    ">>?[[:space:]]*[\"']?([^[:space:]\"']*/)?$CTX_RE([^[:alnum:]_.-]|$)"; then
    writes_context="yes"
  elif printf '%s' "$COMMAND" | grep -Eq \
    "(^|[^[:alnum:]_])tee[[:space:]]+(-a[[:space:]]+)?[\"']?([^[:space:]\"']*/)?$CTX_RE([^[:alnum:]_.-]|$)"; then
    writes_context="yes"
  elif printf '%s' "$COMMAND" | grep -Eq '(^|[^[:alnum:]_])sed[[:space:]]+(-[^[:space:]]*[[:space:]]+)*-i' \
    && printf '%s' "$COMMAND" | grep -Eq "([^[:alnum:]_.-]|^)$CTX_RE([^[:alnum:]_.-]|$)"; then
    writes_context="yes"
  fi
fi

if [ "$writes_context" = "yes" ]; then
  remind "Read the aiw-project-context-management skill before editing $CONTEXT_FILE. It owns the file's form and content rules."
fi

# ── Arm 1: a pull request is about to be created ──
# Create only. An edit to an open pull request is not the moment the branch's
# contents are first presented, and check-pr-verification.sh already owns edits.
is_pr_create="no"
case "$TOOL_NAME" in
  *create_pull_request) is_pr_create="yes" ;;
esac
if [ "$is_pr_create" = "no" ] && [ -n "$COMMAND" ]; then
  if printf '%s' "$COMMAND" | grep -Eq \
    '(^|[^[:alnum:]_])gh[[:space:]]+pr[[:space:]]+create([^[:alnum:]_-]|$)'; then
    is_pr_create="yes"
  fi
fi
[ "$is_pr_create" = "yes" ] || exit 0

# Only measurable inside a git work tree; operate from the root so the diff
# paths are repo-relative and match the patterns below.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0
cd "$ROOT" 2>/dev/null || exit 0

# The remote-tracking ref is what the pull request will actually merge into, so
# it is preferred; the local branch covers a repo with no remote configured. If
# neither resolves there is no diff to reason about, and silence is the answer.
BASE=""
for b in $BASE_BRANCHES; do
  for ref in "origin/$b" "$b"; do
    if git rev-parse --verify --quiet "$ref" >/dev/null 2>&1; then
      BASE="$ref"
      break
    fi
  done
  [ -n "$BASE" ] && break
done
[ -n "$BASE" ] || exit 0

MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null)" || exit 0
[ -n "$MERGE_BASE" ] || exit 0

DIFF="$(git diff --name-status "$MERGE_BASE" HEAD 2>/dev/null)" || exit 0
[ -n "$DIFF" ] || exit 0

# Rename rows carry two paths, so every field after the status is a path.
ALL="$(printf '%s\n' "$DIFF" | cut -f2- | tr '\t' '\n' | grep -v '^$' | sort -u)"

# (b) The branch already touches the context file — whatever it changed, it was
# considered. Nothing to say.
printf '%s\n' "$ALL" | grep -qxF "$CONTEXT_FILE" && exit 0

# (a) Paths whose shape means the context file's account of the repo may no
# longer hold. Structural rows are adds, deletes and both ends of a rename;
# content-only edits qualify for the two shapes where what changed is the rule
# itself rather than the file inventory.
STRUCTURAL="$(printf '%s\n' "$DIFF" | awk -F'\t' '
  $1 ~ /^[AD]/ { print $2 }
  $1 ~ /^R/    { print $2; if (NF >= 3) print $3 }
' | grep -v '^$' | sort -u)"

# Paths that left the tree: deletions, and the vacated end of a rename.
REMOVED="$(printf '%s\n' "$DIFF" | awk -F'\t' '$1 ~ /^[DR]/ { print $2 }' \
  | grep -v '^$' | sort -u)"

hits=""

# A skill removed from either mirrored tree. Prose integrity checks that every
# skill that exists is named in the context file, never that every skill the
# context file names still exists, so this direction is uncovered — and only
# this direction. An added skill is already caught by that check, so removals
# alone qualify here.
hits="$hits$(printf '%s\n' "$REMOVED" | grep -E '^\.(claude|agents)/skills/[^/]+/')
"

# An implementation module added, removed or renamed inside a directory the
# manifest already classifies by prefix.
hits="$hits$(printf '%s\n' "$STRUCTURAL" | grep -E '^(\.ai-policy|\.githooks|scripts|observation)/')
"

# What the policy layer enforces, however it changed.
hits="$hits$(printf '%s\n' "$ALL" | grep -E '^(\.ai-policy/hooks/|\.githooks/|\.github/hooks/|\.ai-policy/policy\.env$|\.claude/settings\.json$|\.codex/hooks\.json$|\.gemini/settings\.json$)')
"

# What validation covers: a check added or removed, or the check set itself.
hits="$hits$(printf '%s\n' "$STRUCTURAL" | grep -E '(^|/)test-[^/]*\.sh$')
"
hits="$hits$(printf '%s\n' "$ALL" | grep -E '^(scripts/repo-validation\.sh|\.ai-policy/scripts/project-validation\.sh)$')
"

hits="$(printf '%s\n' "$hits" | grep -v '^$' | sort -u)"
[ -n "$hits" ] || exit 0

# Name what fired, not everything that changed. A long list reads as noise and
# buries the paths the agent needs to think about.
SHOWN="$(printf '%s\n' "$hits" | head -6 | paste -sd, - | sed 's/,/, /g')"
COUNT="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
if [ "$COUNT" -gt 6 ]; then
  SHOWN="$SHOWN, and $((COUNT - 6)) more"
fi

remind "This branch changes $SHOWN and does not touch $CONTEXT_FILE. If those changes altered what $CONTEXT_FILE records, refresh it with the aiw-project-context-management skill before opening the pull request. If they did not, proceed."
