#!/usr/bin/env bash
# Checks the invariants of this repository's agent-facing prose that a script can
# judge without making an editorial call. It does not read for meaning: see the
# "cannot check" block it prints, and issue #227 for why that boundary is drawn
# where it is. A gate that fires on the normal path gets routed around, so every
# check here is one whose failure is unambiguously a defect.
set -uo pipefail

ROOT="${PROSE_CHECK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

fails=0
ok()   { echo "  PASS: $1"; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }

AGENT_DIR=".agents/skills"
CLAUDE_DIR=".claude/skills"
ENTRY_POINTS=("CLAUDE.md" "AGENTS.md" "GEMINI.md" ".github/copilot-instructions.md")
PROSE=("ai-workflow.md" "project-context.md" "${ENTRY_POINTS[@]}")

echo "Skill mirror parity:"
a_list="$(ls "$AGENT_DIR" 2>/dev/null | sort)"
c_list="$(ls "$CLAUDE_DIR" 2>/dev/null | sort)"
if [ "$a_list" = "$c_list" ]; then
  ok "both skill trees define the same skills"
else
  bad "skill trees differ: $(diff <(echo "$a_list") <(echo "$c_list") | tr '\n' ' ')"
fi

for s in $c_list; do
  [ -d "$AGENT_DIR/$s" ] || continue
  if diff -q "$AGENT_DIR/$s/SKILL.md" "$CLAUDE_DIR/$s/SKILL.md" >/dev/null 2>&1; then
    ok "$s identical across both trees"
  else
    bad "$s differs between $AGENT_DIR and $CLAUDE_DIR (agents on different tools would read different rules)"
  fi
done

echo "Skill frontmatter:"
for s in $c_list; do
  f="$CLAUDE_DIR/$s/SKILL.md"
  head -1 "$f" | grep -qx -- '---' || { bad "$s: no YAML frontmatter opening"; continue; }
  name="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")"
  desc="$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")"
  [ "$name" = "$s" ] || bad "$s: frontmatter name '$name' does not match its directory"
  [ -n "$desc" ] || bad "$s: frontmatter description is empty (nothing would load this skill)"
  [ "$name" = "$s" ] && [ -n "$desc" ] && ok "$s: name matches directory, description present"
done

echo "Skill references resolve:"
# A token is a reference only when it is not a path segment: `aiw-observation`
# inside ~/.claude/aiw-observation/sessions.jsonl names a directory, not a skill.
ref_fails=0
for f in "${PROSE[@]}" "$CLAUDE_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  while read -r ref; do
    [ -z "$ref" ] && continue
    [ -d "$CLAUDE_DIR/$ref" ] || { bad "$f references '$ref', which is not a skill in $CLAUDE_DIR"; ref_fails=$((ref_fails + 1)); }
  done < <(
    grep -oE '[^[:space:]]*aiw-[a-z]+(-[a-z]+)*[^[:space:]]*' "$f" \
      | grep -v '/' \
      | grep -oE 'aiw-[a-z]+(-[a-z]+)*' \
      | sort -u
  )
done
[ "$ref_fails" -eq 0 ] && ok "every aiw-* reference in prose and skills resolves to a real skill"

echo "Documented skill set matches the tree:"
doc_fails=0
for s in $c_list; do
  grep -qF "$s" project-context.md || { bad "skill '$s' exists but project-context.md never names it"; doc_fails=$((doc_fails + 1)); }
done
[ "$doc_fails" -eq 0 ] && ok "project-context.md names every skill in the tree"

echo "Version headers:"
# Equality between the lite condensation and the canonical version is enforced
# in scripts/repo-validation.sh, which runs before this and exits on drift.
for f in ai-workflow.md project-context.md lite-monolithic/ai-workflow.md; do
  if grep -qE '^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$f"; then
    ok "$f carries a Version header"
  else
    bad "$f has no Version header, so no session can be tied to a file state"
  fi
done

echo "Declared size budget:"
pc_lines="$(wc -l < project-context.md | tr -d ' ')"
if [ "$pc_lines" -le 300 ]; then
  ok "project-context.md is $pc_lines lines (budget 300)"
else
  bad "project-context.md is $pc_lines lines, over its declared 300-line budget"
fi

echo "Entry-point parity:"
for e in "${ENTRY_POINTS[@]}"; do
  [ -f "$e" ] || { bad "$e is missing"; continue; }
  miss=""
  grep -qF 'ai-workflow.md' "$e"     || miss="$miss ai-workflow.md"
  grep -qF 'project-context.md' "$e" || miss="$miss project-context.md"
  [ -z "$miss" ] && ok "$e points at the governance files" || bad "$e does not reference:$miss"
done

cat <<'LIMITS'

What this cannot check:
  - Whether two passages contradict each other. Meaning is not mechanically
    decidable, and the contradiction that prompted this check (#225, two
    adjacent paragraphs of aiw-verification) would still pass here.
  - Whether a skill's description matches what its body actually covers.
  - Whether a rule is good, needed, or reachable by the agent that must follow it.
  A pass means the prose is structurally coherent, never that it is correct.
LIMITS

if [ "$fails" -gt 0 ]; then
  echo "prose integrity: $fails check(s) failed" >&2
  exit 1
fi
echo "prose integrity: all checks passed"
