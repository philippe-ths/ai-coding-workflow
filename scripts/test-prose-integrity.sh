#!/usr/bin/env bash
# Asserts check-prose-integrity.sh fires on each defect it claims to catch, and
# stays silent on the normal path. A checker that never fails is a green bar; a
# checker that prints 50 lines on every commit gets ignored, so the silence is
# asserted here too, not just claimed in the prose.
set -uo pipefail

ROOT="${PROSE_TEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CHECK="${PROSE_CHECK_BIN:-$ROOT/scripts/check-prose-integrity.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

# Portable in-place edit. GNU and BSD sed disagree about `sed -i`, so never use it.
edit() { local f="$1" e="$2"; sed "$e" "$f" > "$f.edit" && mv "$f.edit" "$f"; }
# Drop every line matching a pattern.
drop() { local f="$1" p="$2"; grep -v "$p" "$f" > "$f.edit"; mv "$f.edit" "$f"; }

# One pristine copy of exactly the paths the checker reads, built once. Each case
# copies from this rather than re-walking the repository, so the suite spends its
# time running the checker instead of running cp.
PRISTINE="$TMP/_pristine"
mkdir -p "$PRISTINE/.github" "$PRISTINE/lite-monolithic" \
         "$PRISTINE/.claude" "$PRISTINE/.agents"
cp -R "$ROOT/.claude/skills" "$PRISTINE/.claude/skills"
cp -R "$ROOT/.agents/skills" "$PRISTINE/.agents/skills"
cp "$ROOT/ai-workflow.md" "$ROOT/project-context.md" "$ROOT/CLAUDE.md" \
   "$ROOT/AGENTS.md" "$ROOT/GEMINI.md" "$PRISTINE/"
cp "$ROOT/lite-monolithic/ai-workflow.md" "$PRISTINE/lite-monolithic/"
cp "$ROOT/.github/copilot-instructions.md" "$PRISTINE/.github/"
for required in ai-workflow.md project-context.md CLAUDE.md AGENTS.md GEMINI.md \
                lite-monolithic/ai-workflow.md .github/copilot-instructions.md \
                .claude/skills/aiw-init/SKILL.md .agents/skills/aiw-init/SKILL.md; do
  [ -e "$PRISTINE/$required" ] || { echo "pristine fixture is missing $required (ROOT=$ROOT)" >&2; exit 2; }
done

fixture() { local d="$TMP/$1"; rm -rf "$d"; cp -R "$PRISTINE" "$d"; echo "$d"; }

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

# This runs on every commit and every push. Anything more than the summary line
# trains the reader to scroll past it.
out="$(PROSE_CHECK_ROOT="$D" bash "$CHECK" 2>/dev/null)"
lines="$(printf '%s\n' "$out" | grep -c '' )"
if [ "$lines" -gt 1 ]; then
  bad "a clean tree prints at most one line: got $lines"
elif ! printf '%s' "$out" | grep -qE '^prose integrity: [0-9]+ checks passed$'; then
  bad "a clean tree prints at most one line: the one line is not the summary ('$out')"
else
  ok "a clean tree prints at most one line, the summary"
fi

# --verbose restores the detail, including the block saying what a pass does not mean.
out="$(PROSE_CHECK_ROOT="$D" bash "$CHECK" --verbose 2>&1)"
if printf '%s' "$out" | grep -q 'PASS:' && printf '%s' "$out" | grep -q 'What this cannot check'; then
  ok "--verbose restores the per-check output and the limits block"
else
  bad "--verbose did not restore the per-check output and the limits block"
fi

echo "mirror parity:"
D="$(fixture diverged)"; printf '\nan edit made to one tree only\n' >> "$D/.claude/skills/aiw-init/SKILL.md"
expect "one tree edited alone is caught" fail "$D" "differs between"

D="$(fixture missing-skill)"; rm -rf "$D/.agents/skills/aiw-init"
expect "a skill present in one tree only is caught" fail "$D" "skill trees differ"

echo "frontmatter:"
D="$(fixture name-mismatch)"
edit "$D/.claude/skills/aiw-init/SKILL.md" 's/^name: aiw-init$/name: aiw-not-init/'
edit "$D/.agents/skills/aiw-init/SKILL.md" 's/^name: aiw-init$/name: aiw-not-init/'
expect "a name not matching its directory is caught" fail "$D" "does not match its directory"

D="$(fixture empty-desc)"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-init/SKILL.md" 's/^description:.*$/description:/'
done
expect "an empty description is caught" fail "$D" "description is empty"

D="$(fixture blank-desc)"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-init/SKILL.md" 's/^description:.*$/description: "   "/'
done
expect "a whitespace-only description is caught" fail "$D" "description is empty"

echo "documented skill set:"
D="$(fixture undocumented)"
for t in .claude .agents; do
  cp -R "$D/$t/skills/aiw-init" "$D/$t/skills/aiw-brand-new"
  edit "$D/$t/skills/aiw-brand-new/SKILL.md" 's/^name: aiw-init$/name: aiw-brand-new/'
done
expect "a skill absent from project-context.md is caught" fail "$D" "never names it"

# project-context.md names aiw-testing and never aiw-test, so a substring match
# would read the longer name as documenting the shorter one.
D="$(fixture substring-skill)"
for t in .claude .agents; do
  cp -R "$D/$t/skills/aiw-init" "$D/$t/skills/aiw-test"
  edit "$D/$t/skills/aiw-test/SKILL.md" 's/^name: aiw-init$/name: aiw-test/'
done
expect "a skill name that is a substring of a documented one is caught" fail "$D" "skill 'aiw-test' exists"

echo "version headers:"
D="$(fixture no-version)"
drop "$D/project-context.md" '^Version:'
expect "a missing Version header is caught" fail "$D" "no Version header"

echo "size budget:"
D="$(fixture oversize)"
for i in $(seq 1 400); do echo "- filler line $i"; done >> "$D/project-context.md"
expect "project-context.md over its 300-line budget is caught" fail "$D" "budget"

echo "entry-point parity:"
D="$(fixture entry-drift)"
drop "$D/AGENTS.md" 'project-context.md'
expect "an entry point that stops pointing at the context is caught" fail "$D" "does not reference"

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
