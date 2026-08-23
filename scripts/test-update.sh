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

echo "pre-prefix update (installed 1.0.0 -> $SRC_VERSION, drops un-prefixed skills):"
T="$(new_target preprefix)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
set_version "$T/ai-workflow.md" 1.0.0
# simulate the superseded un-prefixed skill dirs an old install left behind:
for s in planning testing failure-analysis issue-creation project-spec-management logging-and-observability; do
  mkdir -p "$T/.claude/skills/$s" "$T/.agents/skills/$s"
  echo old > "$T/.claude/skills/$s/SKILL.md"
  echo old > "$T/.agents/skills/$s/SKILL.md"
done
# a genuine local addition under the same vendored path must survive:
mkdir -p "$T/.claude/skills/my-local-skill"; echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "pre-prefix update exited non-zero"
for s in planning testing failure-analysis issue-creation project-spec-management logging-and-observability; do
  absent "$T" ".claude/skills/$s"
  absent "$T" ".agents/skills/$s"
done
present "$T" .claude/skills/my-local-skill/SKILL.md
present "$T" .claude/skills/aiw-planning/SKILL.md

echo "removed path is pruned from the managed .gitignore block:"
# Fabricate a source repo carrying an extra top-level product path, install it,
# then drop that path from the source and name it in a `### Removed` bullet.
FAKE_SRC="$SANDBOX/fake-src"
mkdir -p "$FAKE_SRC"
git -C "$ROOT_DIR" archive HEAD | tar -x -C "$FAKE_SRC"
mkdir -p "$FAKE_SRC/legacy-thing"
echo legacy > "$FAKE_SRC/legacy-thing/note.md"
tmp_manifest="$(mktemp)"
jq '.profiles.full.shared += ["legacy-thing/"]' "$FAKE_SRC/install-manifest.json" > "$tmp_manifest" \
  && mv "$tmp_manifest" "$FAKE_SRC/install-manifest.json"
set_version "$FAKE_SRC/ai-workflow.md" 90.0.0
( cd "$FAKE_SRC" && git init -q && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init ) >/dev/null 2>&1

T="$(new_target pruned)"
"$INSTALL" --source "$FAKE_SRC" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "fake-source install exited non-zero"
if grep -qxF "legacy-thing/" "$T/.gitignore"; then ok "legacy-thing/ recorded in .gitignore before update"; else bad "legacy-thing/ not recorded before update"; fi

# The source drops the path and declares the removal.
rm -rf "$FAKE_SRC/legacy-thing"
tmp_manifest="$(mktemp)"
jq '.profiles.full.shared -= ["legacy-thing/"]' "$FAKE_SRC/install-manifest.json" > "$tmp_manifest" \
  && mv "$tmp_manifest" "$FAKE_SRC/install-manifest.json"
set_version "$FAKE_SRC/ai-workflow.md" 90.1.0
tmp_changelog="$(mktemp)"
{
  printf '## 90.1.0\n\n### Removed\n\n- `legacy-thing/` no longer shipped.\n\n'
  cat "$FAKE_SRC/CHANGELOG.md"
} > "$tmp_changelog" && mv "$tmp_changelog" "$FAKE_SRC/CHANGELOG.md"
( cd "$FAKE_SRC" && git add -A && git commit -qm drop ) >/dev/null 2>&1

"$UPDATE" --source "$FAKE_SRC" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "prune update exited non-zero"
absent "$T" legacy-thing
if grep -qxF "legacy-thing/" "$T/.gitignore"; then bad "legacy-thing/ still in .gitignore after update"; else ok "legacy-thing/ pruned from .gitignore"; fi
for p in "ai-workflow.md" ".ai-policy/" ".githooks/" "CLAUDE.md" ".claude/"; do
  if grep -qxF "$p" "$T/.gitignore"; then ok "still ignored: $p"; else bad "wrongly pruned: $p"; fi
done

# A removal bullet names a path by name, not by tool. When several tools are
# installed side by side, a path one tool dropped may still be shipped by
# another, and pruning it un-ignores that tool's vendored files (#229).
echo "a removal does not un-ignore a path another installed tool still ships:"
FAKE_SRC2="$SANDBOX/fake-src-2"
mkdir -p "$FAKE_SRC2"
git -C "$ROOT_DIR" archive HEAD | tar -x -C "$FAKE_SRC2"
mkdir -p "$FAKE_SRC2/legacy-thing"
echo legacy > "$FAKE_SRC2/legacy-thing/note.md"
tmp_manifest="$(mktemp)"
jq '.profiles.full.tools.claude += ["legacy-thing/"]' "$FAKE_SRC2/install-manifest.json" > "$tmp_manifest" \
  && mv "$tmp_manifest" "$FAKE_SRC2/install-manifest.json"
set_version "$FAKE_SRC2/ai-workflow.md" 90.0.0
( cd "$FAKE_SRC2" && git init -q && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init ) >/dev/null 2>&1

T="$(new_target multi-tool-prune)"
"$INSTALL" --source "$FAKE_SRC2" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "claude install exited non-zero"
"$INSTALL" --source "$FAKE_SRC2" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
if grep -qxF "legacy-thing/" "$T/.gitignore"; then ok "legacy-thing/ recorded before update"; else bad "legacy-thing/ not recorded before update"; fi

# The source names the path as removed; the claude tool set still ships it.
set_version "$FAKE_SRC2/ai-workflow.md" 90.1.0
tmp_changelog="$(mktemp)"
{
  printf '## 90.1.0\n\n### Removed\n\n- `legacy-thing/` no longer shipped for gemini.\n\n'
  cat "$FAKE_SRC2/CHANGELOG.md"
} > "$tmp_changelog" && mv "$tmp_changelog" "$FAKE_SRC2/CHANGELOG.md"
( cd "$FAKE_SRC2" && git add -A && git commit -qm drop ) >/dev/null 2>&1

"$UPDATE" --source "$FAKE_SRC2" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "multi-tool prune update exited non-zero"
if grep -qxF "legacy-thing/" "$T/.gitignore"; then
  ok "legacy-thing/ still ignored (the claude set still ships it)"
else
  bad "legacy-thing/ pruned from .gitignore though the claude set still ships it"
fi
for p in "ai-workflow.md" ".ai-policy/" ".githooks/" "CLAUDE.md" ".claude/" "GEMINI.md" ".gemini/"; do
  if grep -qxF "$p" "$T/.gitignore"; then ok "still ignored: $p"; else bad "wrongly pruned: $p"; fi
done

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
