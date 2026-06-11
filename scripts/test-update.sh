#!/usr/bin/env bash
# Sandbox test for scripts/update.sh.
#
# Uses real ground truth: the removed paths come from this repo's real
# CHANGELOG `### Removed` entries, and the version range spans the real 2.15.0
# and 3.3.0 removals. Asserts genuinely-removed product files are deleted, a
# named-but-still-product file is kept, and a local addition survives.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT_DIR/scripts/install.sh"
UPDATE="$ROOT_DIR/scripts/update.sh"
SRC_VERSION="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$ROOT_DIR/ai-workflow.md")"

pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }
present() { if [ -e "$1/$2" ]; then ok "kept: $2"; else bad "should be kept: $2"; fi; }
absent()  { if [ -e "$1/$2" ]; then bad "should be removed: $2"; else ok "removed: $2"; fi; }

SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t aiw-update)"
trap 'rm -rf "$SANDBOX"' EXIT

new_target() {
  local d="$SANDBOX/$1"; mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  echo "$d"
}
set_version() {
  local f="$1" v="$2" tmp; tmp="$(mktemp)"
  awk -v v="$v" '!d && /^Version:[[:space:]]/ {print "Version: " v; d=1; next} {print}' "$f" > "$tmp" && mv "$tmp" "$f"
}

echo "real-history update (installed 2.14.0 -> $SRC_VERSION):"
T="$(new_target hist)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
set_version "$T/ai-workflow.md" 2.14.0
# stale product files that 3.3.0 removed (real removed paths):
mkdir -p "$T/.claude/skills/aiw-evaluation";     echo stale > "$T/.claude/skills/aiw-evaluation/SKILL.md"
mkdir -p "$T/.claude/skills/aiw-telemetry-setup"; echo stale > "$T/.claude/skills/aiw-telemetry-setup/SKILL.md"
echo stale > "$T/.ai-policy/scripts/update-session-tags.sh"
# a genuine local addition under a vendored path:
mkdir -p "$T/.claude/skills/my-local-skill";      echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"

"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "update exited non-zero"

absent  "$T" .claude/skills/aiw-evaluation
absent  "$T" .claude/skills/aiw-telemetry-setup
absent  "$T" .ai-policy/scripts/update-session-tags.sh
present "$T" .claude/skills/my-local-skill/SKILL.md
present "$T" .ai-policy/scripts/project-validation.sh
v="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$T/ai-workflow.md")"
if [ "$v" = "$SRC_VERSION" ]; then ok "version bumped to $SRC_VERSION"; else bad "version is '$v', expected $SRC_VERSION"; fi

echo "already up-to-date (no-op):"
T="$(new_target current)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
mkdir -p "$T/.claude/skills/my-local-skill"; echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
ec=$?
if [ "$ec" -eq 0 ]; then ok "up-to-date update exits 0"; else bad "up-to-date update exit=$ec"; fi
present "$T" .claude/skills/my-local-skill/SKILL.md
present "$T" CLAUDE.md

echo "refuse downgrade (target ahead):"
T="$(new_target ahead)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
set_version "$T/ai-workflow.md" 99.0.0
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok "refuses to downgrade"; else bad "should refuse downgrade"; fi
present "$T" ai-workflow.md

echo "auto-detect tool and profile (full/claude):"
T="$(new_target detect)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
set_version "$T/ai-workflow.md" 2.14.0
"$UPDATE" --source "$ROOT_DIR" --target "$T" >/dev/null 2>&1 || bad "auto-detect update exited non-zero"
v="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$T/ai-workflow.md")"
if [ "$v" = "$SRC_VERSION" ]; then ok "auto-detected full/claude and updated"; else bad "auto-detect failed (v=$v)"; fi

echo "ambiguous tool requires --tool:"
T="$(new_target ambig)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
touch "$T/AGENTS.md"
"$UPDATE" --source "$ROOT_DIR" --target "$T" >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok "ambiguous tool errors without --tool"; else bad "should error on ambiguous tool"; fi

echo "lite update (auto-detected):"
T="$(new_target lite)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile lite >/dev/null 2>&1
set_version "$T/ai-workflow.md" 2.14.0
"$UPDATE" --source "$ROOT_DIR" --target "$T" >/dev/null 2>&1 || bad "lite update exited non-zero"
present "$T" ai-workflow.md
present "$T" CLAUDE.md

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
