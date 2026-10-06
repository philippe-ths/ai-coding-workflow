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
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
set_version "$T/ai-workflow.md" 2.14.0
# stale product files that 3.3.0 removed (real removed paths):
mkdir -p "$T/.claude/skills/aiw-evaluation";     echo stale > "$T/.claude/skills/aiw-evaluation/SKILL.md"
mkdir -p "$T/.claude/skills/aiw-telemetry-setup"; echo stale > "$T/.claude/skills/aiw-telemetry-setup/SKILL.md"
echo stale > "$T/.ai-policy/scripts/update-session-tags.sh"
# a genuine local addition under a vendored path:
mkdir -p "$T/.claude/skills/my-local-skill";      echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"

"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1 || bad "update exited non-zero"

absent  "$T" .claude/skills/aiw-evaluation
absent  "$T" .claude/skills/aiw-telemetry-setup
absent  "$T" .ai-policy/scripts/update-session-tags.sh
present "$T" .claude/skills/my-local-skill/SKILL.md
present "$T" .ai-policy/scripts/project-validation.sh
v="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$T/ai-workflow.md")"
if [ "$v" = "$SRC_VERSION" ]; then ok "version bumped to $SRC_VERSION"; else bad "version is '$v', expected $SRC_VERSION"; fi

echo "pre-prefix update (installed 1.0.0 -> $SRC_VERSION, drops un-prefixed skills):"
T="$(new_target preprefix)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
set_version "$T/ai-workflow.md" 1.0.0
# simulate the superseded un-prefixed skill dirs an old install left behind:
for s in planning testing failure-analysis issue-creation project-spec-management logging-and-observability; do
  mkdir -p "$T/.claude/skills/$s" "$T/.agents/skills/$s"
  echo old > "$T/.claude/skills/$s/SKILL.md"
  echo old > "$T/.agents/skills/$s/SKILL.md"
done
# a genuine local addition under the same vendored path must survive:
mkdir -p "$T/.claude/skills/my-local-skill"; echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1 || bad "pre-prefix update exited non-zero"
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
"$INSTALL" --source "$FAKE_SRC" --target "$T" --tool claude >/dev/null 2>&1 || bad "fake-source install exited non-zero"
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

"$UPDATE" --source "$FAKE_SRC" --target "$T" --tool claude >/dev/null 2>&1 || bad "prune update exited non-zero"
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
"$INSTALL" --source "$FAKE_SRC2" --target "$T" --tool claude >/dev/null 2>&1 || bad "claude install exited non-zero"
"$INSTALL" --source "$FAKE_SRC2" --target "$T" --tool copilot >/dev/null 2>&1 || bad "copilot install exited non-zero"
if grep -qxF "legacy-thing/" "$T/.gitignore"; then ok "legacy-thing/ recorded before update"; else bad "legacy-thing/ not recorded before update"; fi

# The source names the path as removed; the claude tool set still ships it.
set_version "$FAKE_SRC2/ai-workflow.md" 90.1.0
tmp_changelog="$(mktemp)"
{
  printf '## 90.1.0\n\n### Removed\n\n- `legacy-thing/` no longer shipped for copilot.\n\n'
  cat "$FAKE_SRC2/CHANGELOG.md"
} > "$tmp_changelog" && mv "$tmp_changelog" "$FAKE_SRC2/CHANGELOG.md"
( cd "$FAKE_SRC2" && git add -A && git commit -qm drop ) >/dev/null 2>&1

"$UPDATE" --source "$FAKE_SRC2" --target "$T" --tool copilot >/dev/null 2>&1 || bad "multi-tool prune update exited non-zero"
if grep -qxF "legacy-thing/" "$T/.gitignore"; then
  ok "legacy-thing/ still ignored (the claude set still ships it)"
else
  bad "legacy-thing/ pruned from .gitignore though the claude set still ships it"
fi
for p in "ai-workflow.md" ".ai-policy/" ".githooks/" "CLAUDE.md" ".claude/" ".github/copilot-instructions.md" ".vscode/"; do
  if grep -qxF "$p" "$T/.gitignore"; then ok "still ignored: $p"; else bad "wrongly pruned: $p"; fi
done

echo "already up-to-date (no-op):"
T="$(new_target current)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
mkdir -p "$T/.claude/skills/my-local-skill"; echo mine > "$T/.claude/skills/my-local-skill/SKILL.md"
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
ec=$?
if [ "$ec" -eq 0 ]; then ok "up-to-date update exits 0"; else bad "up-to-date update exit=$ec"; fi
present "$T" .claude/skills/my-local-skill/SKILL.md
present "$T" CLAUDE.md

echo "refuse downgrade (target ahead):"
T="$(new_target ahead)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
set_version "$T/ai-workflow.md" 99.0.0
"$UPDATE" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
if [ "$?" -ne 0 ]; then ok "refuses to downgrade"; else bad "should refuse downgrade"; fi
present "$T" ai-workflow.md

echo "auto-detect tool and profile (full/claude):"
T="$(new_target detect)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude >/dev/null 2>&1
set_version "$T/ai-workflow.md" 2.14.0
"$UPDATE" --source "$ROOT_DIR" --target "$T" >/dev/null 2>&1 || bad "auto-detect update exited non-zero"
v="$(awk '/^Version:[[:space:]]*/ {print $2; exit}' "$T/ai-workflow.md")"
if [ "$v" = "$SRC_VERSION" ]; then ok "auto-detected full/claude and updated"; else bad "auto-detect failed (v=$v)"; fi

echo "multi-tool target: every installed tool is brought current:"
FAKE_SRC3="$SANDBOX/fake-src-3"
mkdir -p "$FAKE_SRC3"
git -C "$ROOT_DIR" archive HEAD | tar -x -C "$FAKE_SRC3"
mkdir -p "$FAKE_SRC3/legacy-thing"
echo legacy > "$FAKE_SRC3/legacy-thing/note.md"
tmp_manifest="$(mktemp)"
jq '.profiles.full.shared += ["legacy-thing/"]' "$FAKE_SRC3/install-manifest.json" > "$tmp_manifest" \
  && mv "$tmp_manifest" "$FAKE_SRC3/install-manifest.json"
set_version "$FAKE_SRC3/ai-workflow.md" 90.0.0
( cd "$FAKE_SRC3" && git init -q && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init ) >/dev/null 2>&1

# The source then moves on: drops legacy-thing/ and changes a file each tool ships.
rm -rf "$FAKE_SRC3/legacy-thing"
tmp_manifest="$(mktemp)"
jq '.profiles.full.shared -= ["legacy-thing/"]' "$FAKE_SRC3/install-manifest.json" > "$tmp_manifest" \
  && mv "$tmp_manifest" "$FAKE_SRC3/install-manifest.json"
echo "# updated" >> "$FAKE_SRC3/AGENTS.md"
echo "# updated" >> "$FAKE_SRC3/CLAUDE.md"
set_version "$FAKE_SRC3/ai-workflow.md" 90.1.0
tmp_changelog="$(mktemp)"
{
  printf '## 90.1.0\n\n### Removed\n\n- `legacy-thing/` no longer shipped.\n\n'
  cat "$FAKE_SRC3/CHANGELOG.md"
} > "$tmp_changelog" && mv "$tmp_changelog" "$FAKE_SRC3/CHANGELOG.md"
( cd "$FAKE_SRC3" && git add -A && git commit -qm drop ) >/dev/null 2>&1

# Source state at 90.0.0 for installing the older copy: reinstall from a copy
# that still has legacy-thing/ and the unmodified entry points.
OLD_SRC="$SANDBOX/old-src"
mkdir -p "$OLD_SRC"
git -C "$FAKE_SRC3" archive HEAD~1 | tar -x -C "$OLD_SRC"
( cd "$OLD_SRC" && git init -q && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm old ) >/dev/null 2>&1

make_multi() { # name
  local t; t="$(new_target "$1")"
  "$INSTALL" --source "$OLD_SRC" --target "$t" --tool claude >/dev/null 2>&1
  "$INSTALL" --source "$OLD_SRC" --target "$t" --tool codex >/dev/null 2>&1
  mkdir -p "$t/.claude/skills/my-local-skill"; echo mine > "$t/.claude/skills/my-local-skill/SKILL.md"
  echo "$t"
}

echo "a target with no managed block keeps the old refusal when entry points are ambiguous:"
T="$(make_multi multi-noblock)"
awk '/^# >>> ai-workflow/{skip=1} !skip{print} /^# <<< ai-workflow/{skip=0}' "$T/.gitignore" > "$T/.gitignore.new" && mv "$T/.gitignore.new" "$T/.gitignore"
if "$UPDATE" --source "$FAKE_SRC3" --target "$T" >/dev/null 2>&1; then bad "no-block multi-tool target should ask for --tool"; else ok "no-block ambiguous target errors without --tool"; fi

T="$(make_multi multi-auto)"
"$UPDATE" --source "$FAKE_SRC3" --target "$T" >/dev/null 2>&1 || bad "multi-tool update without --tool exited non-zero"
if cmp -s "$FAKE_SRC3/CLAUDE.md" "$T/CLAUDE.md"; then ok "claude files refreshed (no --tool)"; else bad "claude files left stale (no --tool)"; fi
if cmp -s "$FAKE_SRC3/AGENTS.md" "$T/AGENTS.md"; then ok "codex files refreshed (no --tool)"; else bad "codex files left stale (no --tool)"; fi
absent  "$T" legacy-thing
present "$T" .claude/skills/my-local-skill/SKILL.md

echo "multi-tool target: --tool on one tool still refreshes the others:"
T="$(make_multi multi-named)"
"$UPDATE" --source "$FAKE_SRC3" --target "$T" --tool claude >/dev/null 2>&1 || bad "multi-tool update with --tool exited non-zero"
if cmp -s "$FAKE_SRC3/CLAUDE.md" "$T/CLAUDE.md"; then ok "claude files refreshed (--tool claude)"; else bad "claude files left stale (--tool claude)"; fi
if cmp -s "$FAKE_SRC3/AGENTS.md" "$T/AGENTS.md"; then ok "codex files refreshed by --tool claude"; else bad "codex files left stale by --tool claude"; fi
absent  "$T" legacy-thing
present "$T" .claude/skills/my-local-skill/SKILL.md

echo "multi-tool target: a deleted entry point is restored, not skipped:"
T="$(make_multi multi-deleted-entry)"
rm -f "$T/CLAUDE.md"
"$UPDATE" --source "$FAKE_SRC3" --target "$T" >/dev/null 2>&1 || bad "update with a deleted entry point exited non-zero"
if cmp -s "$FAKE_SRC3/CLAUDE.md" "$T/CLAUDE.md"; then ok "deleted CLAUDE.md restored to the new source content"; else bad "deleted CLAUDE.md not restored"; fi

echo "multi-tool target: a setting a seeded file lacks is reported once, not once per tool:"
T="$(make_multi multi-seeded-once)"
grep -v '^PROTECTED_BRANCHES=' "$T/.ai-policy/policy.env" > "$T/policy.tmp" && mv "$T/policy.tmp" "$T/.ai-policy/policy.env"
out="$("$UPDATE" --source "$FAKE_SRC3" --target "$T" 2>&1)" || bad "seeded multi-tool update exited non-zero"
n="$(printf '%s\n' "$out" | grep -c 'added new setting PROTECTED_BRANCHES')"
if [ "$n" -eq 1 ]; then ok "added new setting PROTECTED_BRANCHES printed exactly once"; else bad "added new setting PROTECTED_BRANCHES printed $n times"; fi

echo "a repo's own AGENTS.md is not an installed tool:"
T="$(new_target own-agents)"
"$INSTALL" --source "$OLD_SRC" --target "$T" --tool claude >/dev/null 2>&1
printf 'my own agent notes\n' > "$T/AGENTS.md"
cp "$T/AGENTS.md" "$SANDBOX/own-agents.orig"
own_out="$("$UPDATE" --source "$FAKE_SRC3" --target "$T" 2>&1)" || bad "update with an own AGENTS.md exited non-zero"
if printf '%s' "$own_out" | grep -q 'note: AGENTS.md exists .*rerun with --tool codex'; then ok "unaccounted AGENTS.md is named, not skipped silently"; else bad "unaccounted AGENTS.md passed silently"; fi
if cmp -s "$SANDBOX/own-agents.orig" "$T/AGENTS.md"; then ok "own AGENTS.md left byte-identical"; else bad "own AGENTS.md was overwritten"; fi
absent "$T" .codex
if cmp -s "$FAKE_SRC3/CLAUDE.md" "$T/CLAUDE.md"; then ok "claude still updated"; else bad "claude not updated beside an own AGENTS.md"; fi

echo "--tool adds a tool that is not yet installed and still updates the rest:"
T="$(new_target add-tool)"
"$INSTALL" --source "$OLD_SRC" --target "$T" --tool claude >/dev/null 2>&1
"$UPDATE" --source "$FAKE_SRC3" --target "$T" --tool copilot >/dev/null 2>&1 || bad "update --tool copilot exited non-zero"
present "$T" .github/copilot-instructions.md
if cmp -s "$FAKE_SRC3/CLAUDE.md" "$T/CLAUDE.md"; then ok "claude still updated when copilot is added"; else bad "claude left stale when copilot is added"; fi

echo "seeded policy.env (edited value survives, new setting arrives, untouched is unchanged):"
SEED_SRC="$SANDBOX/seed-src"
mkdir -p "$SEED_SRC"
git -C "$ROOT_DIR" archive HEAD | tar -x -C "$SEED_SRC"
cp "$ROOT_DIR/install-manifest.json" "$SEED_SRC/install-manifest.json"
( cd "$SEED_SRC" && git init -q && git config user.email t@t && git config user.name t \
  && git add -A && git commit -qm base ) >/dev/null 2>&1
T="$(new_target seeded)"
"$INSTALL" --source "$SEED_SRC" --target "$T" --tool claude >/dev/null 2>&1
if cmp -s "$T/.ai-policy/policy.env" "$SEED_SRC/.ai-policy/policy.env"; then ok "fresh install copies policy.env as shipped"; else bad "fresh install policy.env differs"; fi
# untouched target: update changes nothing (bytes and mtime)
touch -t 202001010000 "$T/.ai-policy/policy.env"
before="$(cksum < "$T/.ai-policy/policy.env")"; mt_before="$(ls -l "$T/.ai-policy/policy.env" | awk '{print $6,$7,$8}')"
"$UPDATE" --source "$SEED_SRC" --target "$T" --tool claude >/dev/null 2>&1 || bad "update on untouched target exited non-zero"
if [ "$before" = "$(cksum < "$T/.ai-policy/policy.env")" ] && [ "$mt_before" = "$(ls -l "$T/.ai-policy/policy.env" | awk '{print $6,$7,$8}')" ]; then ok "untouched policy.env unchanged (bytes and mtime)"; else bad "untouched policy.env was rewritten"; fi
# target edits a value; source gains a new setting
# indented, export-form edit; and two assignments on one line (own line removed)
sed -i.bak -e 's/^PROTECTED_BRANCHES=.*/  export PROTECTED_BRANCHES="main release"/' \
  -e 's/^REQUIRE_VALIDATION_BEFORE_COMMIT=.*/REQUIRE_VALIDATION_BEFORE_COMMIT="true"; REQUIRE_VALIDATION_BEFORE_PUSH="true"/' \
  -e '/^REQUIRE_VALIDATION_BEFORE_PUSH=/d' "$T/.ai-policy/policy.env" && rm -f "$T/.ai-policy/policy.env.bak"
# a longer name ending in the new key must not count as the new key being set
printf 'MY_NEW_SEEDED_SETTING=1\n' >> "$T/.ai-policy/policy.env"
printf '\n# Seconds a check may run.\n: "${NEW_SEEDED_SETTING:=42}"\n' >> "$SEED_SRC/.ai-policy/policy.env"
( cd "$SEED_SRC" && git add -A && git commit -qm newkey ) >/dev/null 2>&1
out="$("$UPDATE" --source "$SEED_SRC" --target "$T" --tool claude 2>&1)" || bad "update with edited policy.env exited non-zero"
if grep -qx '  export PROTECTED_BRANCHES="main release"' "$T/.ai-policy/policy.env"; then ok "edited PROTECTED_BRANCHES survived update"; else bad "edited PROTECTED_BRANCHES was reset"; fi
if [ "$(grep -c 'PROTECTED_BRANCHES=' "$T/.ai-policy/policy.env")" -eq 1 ]; then ok "indented export setting not re-appended"; else bad "PROTECTED_BRANCHES appended despite being present"; fi
if [ "$(grep -c 'REQUIRE_VALIDATION_BEFORE_PUSH=' "$T/.ai-policy/policy.env")" -eq 1 ]; then ok "two-assignments-on-a-line setting not re-appended"; else bad "REQUIRE_VALIDATION_BEFORE_PUSH re-appended"; fi
if grep -qxF ': "${NEW_SEEDED_SETTING:=42}"' "$T/.ai-policy/policy.env"; then ok "new setting arrived with its default"; else bad "new setting missing"; fi
if grep -qx '# Seconds a check may run.' "$T/.ai-policy/policy.env"; then ok "new setting arrived with its comment"; else bad "new setting's comment missing"; fi
if printf '%s' "$out" | grep -q 'added new setting NEW_SEEDED_SETTING'; then ok "update reported the appended key"; else bad "appended key not reported"; fi
if printf '%s' "$out" | grep -q 'did not add setting REQUIRE_VALIDATION_BEFORE_PUSH'; then ok "update named the key it judged present from a non-plain line"; else bad "key judged present from a non-plain line was skipped silently"; fi
# a second update adds nothing more
before="$(cksum < "$T/.ai-policy/policy.env")"
"$UPDATE" --source "$SEED_SRC" --target "$T" --tool claude >/dev/null 2>&1
if [ "$before" = "$(cksum < "$T/.ai-policy/policy.env")" ]; then ok "second update is idempotent"; else bad "second update changed policy.env"; fi
# a commented-out assignment in the target does not count as present
sed -i.bak '/NEW_SEEDED_SETTING:=/s/^/# /' "$T/.ai-policy/policy.env" && rm -f "$T/.ai-policy/policy.env.bak"
"$UPDATE" --source "$SEED_SRC" --target "$T" --tool claude >/dev/null 2>&1
if grep -qxF ': "${NEW_SEEDED_SETTING:=42}"' "$T/.ai-policy/policy.env"; then ok "commented-out assignment is re-added as a setting"; else bad "commented-out assignment counted as present"; fi
present "$T" .ai-policy/policy.env

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
