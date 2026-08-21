#!/usr/bin/env bash
# Asserts check-prose-integrity.sh fires on each defect it claims to catch, and
# stays silent on the normal path. A checker that never fails is a green bar.
set -uo pipefail

ROOT="${PROSE_TEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CHECK="${PROSE_CHECK_BIN:-$ROOT/scripts/check-prose-integrity.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

# A fresh copy of only the paths the checker reads.
fixture() {
  local d="$TMP/$1"; rm -rf "$d"; mkdir -p "$d/.github" "$d/lite-monolithic"
  cp -R "$ROOT/.agents" "$ROOT/.claude" "$d/" 2>/dev/null
  # keep only the skills; settings and caches are not read by the checker
  find "$d/.claude" -mindepth 1 -maxdepth 1 ! -name skills -exec rm -rf {} + 2>/dev/null
  find "$d/.agents" -mindepth 1 -maxdepth 1 ! -name skills -exec rm -rf {} + 2>/dev/null
  cp "$ROOT/ai-workflow.md" "$ROOT/project-context.md" "$ROOT/CLAUDE.md" \
     "$ROOT/AGENTS.md" "$ROOT/GEMINI.md" "$d/"
  cp "$ROOT/lite-monolithic/ai-workflow.md" "$d/lite-monolithic/"
  cp "$ROOT/.github/copilot-instructions.md" "$d/.github/"
  for required in ai-workflow.md project-context.md CLAUDE.md AGENTS.md GEMINI.md \
                  lite-monolithic/ai-workflow.md .github/copilot-instructions.md \
                  .claude/skills/aiw-init/SKILL.md .agents/skills/aiw-init/SKILL.md; do
    [ -e "$d/$required" ] || { echo "fixture $1 is missing $required (ROOT=$ROOT)" >&2; exit 2; }
  done
  echo "$d"
}

# expect <label> <pass|fail> <dir> [grep-pattern]
expect() {
  local label="$1" want="$2" dir="$3" pat="${4:-}" out rc
  out="$(PROSE_CHECK_ROOT="$dir" bash "$CHECK" 2>&1)"; rc=$?
  if [ "$want" = pass ] && [ "$rc" -ne 0 ]; then
    bad "$label: expected a pass, got exit $rc"; return
  fi
  if [ "$want" = fail ] && [ "$rc" -eq 0 ]; then
    bad "$label: expected a failure, checker passed"; return
  fi
  if [ -n "$pat" ] && ! printf '%s' "$out" | grep -qi -- "$pat"; then
    bad "$label: exited correctly but never mentioned '$pat'"; return
  fi
  ok "$label"
}

echo "normal path:"
D="$(fixture baseline)"
expect "an unmodified tree passes" pass "$D"
# Every later case reads a failure as proof the checker fired. If the baseline
# itself is not clean, those failures prove nothing, so stop here instead.
[ "$fail" -eq 0 ] || { echo "baseline is not clean; the rest would be meaningless" >&2; exit 2; }

echo "mirror parity:"
D="$(fixture diverged)"; printf '\nan edit made to one tree only\n' >> "$D/.claude/skills/aiw-init/SKILL.md"
expect "one tree edited alone is caught" fail "$D" "differs between"

D="$(fixture missing-skill)"; rm -rf "$D/.agents/skills/aiw-init"
expect "a skill present in one tree only is caught" fail "$D" "skill trees differ"

echo "frontmatter:"
D="$(fixture name-mismatch)"
sed -i '' 's/^name: aiw-init$/name: aiw-not-init/' "$D/.claude/skills/aiw-init/SKILL.md"
sed -i '' 's/^name: aiw-init$/name: aiw-not-init/' "$D/.agents/skills/aiw-init/SKILL.md"
expect "a name not matching its directory is caught" fail "$D" "does not match its directory"

D="$(fixture empty-desc)"
for t in .claude .agents; do
  python3 - "$D/$t/skills/aiw-init/SKILL.md" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
open(p,'w').write(re.sub(r'^description:.*$','description:',s,count=1,flags=re.M))
PY
done
expect "an empty description is caught" fail "$D" "description is empty"

echo "reference resolution:"
D="$(fixture dangling-ref)"; printf '\nSee aiw-nonexistent for this.\n' >> "$D/ai-workflow.md"
expect "a reference to no such skill is caught" fail "$D" "not a skill"

D="$(fixture path-token)"
printf '\nThe store lives at `~/.claude/aiw-observation/sessions.jsonl`.\n' >> "$D/project-context.md"
expect "an aiw-* path segment is not read as a reference" pass "$D"

echo "documented skill set:"
D="$(fixture undocumented)"
cp -R "$D/.claude/skills/aiw-init" "$D/.claude/skills/aiw-brand-new"
cp -R "$D/.agents/skills/aiw-init" "$D/.agents/skills/aiw-brand-new"
sed -i '' 's/^name: aiw-init$/name: aiw-brand-new/' "$D/.claude/skills/aiw-brand-new/SKILL.md"
sed -i '' 's/^name: aiw-init$/name: aiw-brand-new/' "$D/.agents/skills/aiw-brand-new/SKILL.md"
expect "a skill absent from project-context.md is caught" fail "$D" "never names it"

echo "version headers:"
D="$(fixture no-version)"
grep -v '^Version:' "$D/project-context.md" > "$D/pc.tmp" && mv "$D/pc.tmp" "$D/project-context.md"
expect "a missing Version header is caught" fail "$D" "no Version header"

echo "size budget:"
D="$(fixture oversize)"
for i in $(seq 1 400); do echo "- filler line $i" >> "$D/project-context.md"; done
expect "project-context.md over its 300-line budget is caught" fail "$D" "budget"

echo "entry-point parity:"
D="$(fixture entry-drift)"
grep -v 'project-context.md' "$D/AGENTS.md" > "$D/AGENTS.tmp" && mv "$D/AGENTS.tmp" "$D/AGENTS.md"
expect "an entry point that stops pointing at the context is caught" fail "$D" "does not reference"

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
