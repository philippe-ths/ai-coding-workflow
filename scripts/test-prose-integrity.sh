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
mkdir -p "$PRISTINE/.github" \
         "$PRISTINE/.claude" "$PRISTINE/.agents" \
         "$PRISTINE/scripts" "$PRISTINE/design/decisions"
cp -R "$ROOT/.claude/skills" "$PRISTINE/.claude/skills"
cp -R "$ROOT/.agents/skills" "$PRISTINE/.agents/skills"
cp "$ROOT/ai-workflow.md" "$ROOT/project-context.md" "$ROOT/CLAUDE.md" \
   "$ROOT/AGENTS.md" "$ROOT/install-manifest.json" "$PRISTINE/"
cp "$ROOT/.github/copilot-instructions.md" "$PRISTINE/.github/"
# The factory-path check expands scripts/, design/ and docs/ from the files found
# there, so the fixture carries one file and one subdirectory of each kind it needs.
cp "$ROOT/scripts/check-manifest.sh" "$PRISTINE/scripts/"
cp "$ROOT/design/decisions/maintenance.md" "$PRISTINE/design/decisions/"
for required in ai-workflow.md project-context.md CLAUDE.md AGENTS.md install-manifest.json \
                .github/copilot-instructions.md scripts/check-manifest.sh design/decisions/maintenance.md \
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

D="$(fixture oversize-desc)"
long="$(printf 'x%.0s' $(seq 601))"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-init/SKILL.md" "s/^description:.*\$/description: \"$long\"/"
done
expect "a description over the size cap is caught" fail "$D" "description is over"

D="$(fixture cap-boundary)"
long="$(printf 'x%.0s' $(seq 600))"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-init/SKILL.md" "s/^description:.*\$/description: \"$long\"/"
done
expect "a description exactly at the size cap passes" pass "$D"

D="$(fixture block-desc)"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-init/SKILL.md" 's/^description:.*$/description: >\
  folded text the one-line read cannot measure/'
done
expect "a block-scalar description is caught" fail "$D" "block scalar"

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

echo "done-gate enumerations:"
# aiw-github lists the done gate's three skills; dropping one is the hand-propagation
# miss #260 kept making. Both trees are edited so mirror parity is not what fires.
D="$(fixture gate-dropped-member)"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-github/SKILL.md" 's/(aiw-verification, aiw-validation, aiw-housekeeping)/(aiw-verification, aiw-validation)/'
done
expect "a done-gate list that drops a member is caught" fail "$D" "done-gate list omits"

# The other direction: ai-workflow.md drops a member, the skills still list it.
D="$(fixture gate-member-removed-upstream)"
edit "$D/ai-workflow.md" '/Done gate:/s/aiw-housekeeping/housekeeping/'
expect "a skill list naming a member ai-workflow.md dropped is caught" fail "$D" "does not put in the gate"

# The hyphenated spelling is a done-gate enumeration too.
D="$(fixture gate-hyphenated)"
for t in .claude .agents; do
  printf '\nRun the done-gate: aiw-verification and aiw-validation.\n' >> "$D/$t/skills/aiw-init/SKILL.md"
done
expect "a hyphenated done-gate short list is caught" fail "$D" "done-gate list omits"

echo "Task Flow step numbers:"
D="$(fixture step-number-drift)"
for t in .claude .agents; do
  edit "$D/$t/skills/aiw-planning/SKILL.md" 's/owns Task Flow step [0-9]*/owns Task Flow step 9/'
done
expect "a skill claiming a different step than Task Flow gives it is caught" fail "$D" "Task Flow makes"

# A skill that is not the first one on its Task Flow line is compared too.
D="$(fixture step-number-drift-second-skill)"
for t in .claude .agents; do
  printf '\nValidation is step 2 of the Task Flow.\n' >> "$D/$t/skills/aiw-validation/SKILL.md"
done
expect "a claim by a skill that is not first on its Task Flow line is caught" fail "$D" "Task Flow makes"

# "step 2 of the audit" is a skill's own numbering, not a Task Flow claim.
D="$(fixture step-private-numbering)"
for t in .claude .agents; do
  printf '\nForming a hypothesis is step 2 of the audit below.\n' >> "$D/$t/skills/aiw-failure-analysis/SKILL.md"
done
expect "a skill's own internal step numbering is not read as a Task Flow claim" pass "$D"

# Renaming the heading must not turn the check into a green bar that compared nothing.
D="$(fixture task-flow-renamed)"
edit "$D/ai-workflow.md" 's/^## Task Flow/## Flow/'
expect "a Task Flow section that no longer parses fails rather than passing" fail "$D" "Task Flow"

echo "product prose and the factory boundary:"
D="$(fixture factory-path)"
for t in .claude .agents; do
  printf '\nSee observation/collect.py for the numbers.\n' >> "$D/$t/skills/aiw-init/SKILL.md"
done
expect "a product skill naming a factory-only path is caught" fail "$D" "factory-only path"

# scripts/ is an ordinary directory name, so it is checked by expansion: a named file
# under it is this repository's, a bare "scripts/" is not.
D="$(fixture factory-path-expanded)"
for t in .claude .agents; do
  printf '\nRun scripts/check-manifest.sh first.\n' >> "$D/$t/skills/aiw-init/SKILL.md"
done
expect "a skill naming a file under scripts/ is caught" fail "$D" "factory-only path"

D="$(fixture factory-subdir)"
for t in .claude .agents; do
  printf '\nSee design/decisions/ for the rationale.\n' >> "$D/$t/skills/aiw-init/SKILL.md"
done
expect "a skill naming a subdirectory under design/ is caught" fail "$D" "factory-only path"

# A target may own an INSTALL.md, and .ai-policy/scripts/ is not scripts/.
D="$(fixture ordinary-names)"
for t in .claude .agents; do
  printf '\nIf the target has an INSTALL.md, read it. Hooks live in .ai-policy/scripts/check-validation.sh.\n' >> "$D/$t/skills/aiw-init/SKILL.md"
done
expect "INSTALL.md and .ai-policy/scripts/ paths are not read as factory-only" pass "$D"

# Shipped scripts reach every target, so one naming a factory-only path fails unless
# the line carries the marker that declares its absence is handled on purpose. The
# path here is reached the way a hook does, as "$ROOT_DIR/<path>", from .githooks/.
D="$(fixture shipped-script)"
mkdir -p "$D/.githooks"
# Brace-form prefix and an escaped slash inside the path, so the scan must handle both to see it.
printf '%s\n' '#!/usr/bin/env bash' 'pgrep -fq "${ROOT_DIR}/observation\/collect.py"' > "$D/.githooks/pre-push"
expect "a shipped hook naming a factory-only path via \$ROOT_DIR is caught" fail "$D" "shipped script names"
printf '#!/usr/bin/env bash\npython3 "$ROOT_DIR/observation/collect.py" # factory-path-ok: skipped in a target\n' > "$D/.githooks/pre-push"
expect "a marked line in a shipped script is accepted" pass "$D"

echo "version headers:"
D="$(fixture no-version)"
drop "$D/project-context.md" '^Version:'
expect "a missing Version header is caught" fail "$D" "no Version header"

echo "size budget:"
D="$(fixture oversize)"
for i in $(seq 1 400); do echo "- filler line $i"; done >> "$D/project-context.md"
expect "project-context.md over its token budget is caught" fail "$D" "budget"

# The reason the budget is counted in tokens rather than lines: one fused line
# adds weight without adding a line, and walked straight past the old check.
D="$(fixture oversize-one-line)"
{ printf -- '- '; for i in $(seq 1 4000); do printf 'filler fact %s. ' "$i"; done; printf '\n'; } >> "$D/project-context.md"
expect "a single fused line over the token budget is caught" fail "$D" "budget"

D="$(fixture north-star-oversize)"
{ echo "# North Star"; for i in $(seq 1 200); do echo "Goal sentence $i."; done; } > "$D/north-star.md"
expect "north-star.md over its token budget is caught" fail "$D" "budget"

D="$(fixture no-north-star)"
rm -f "$D/north-star.md"
expect "an absent north-star.md is not a budget failure" pass "$D" ""

echo "entry-point parity:"
D="$(fixture entry-drift)"
drop "$D/AGENTS.md" 'project-context.md'
expect "an entry point that stops pointing at the context is caught" fail "$D" "does not reference"

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
