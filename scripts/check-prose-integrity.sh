#!/usr/bin/env bash
# Checks the invariants of this repository's agent-facing prose that a script can
# judge without making an editorial call. It does not read for meaning: see the
# "cannot check" block it prints on failure, and issue #227 for why that boundary
# is drawn where it is. A gate that fires on the normal path gets routed around,
# so every check here is one whose failure is unambiguously a defect.
#
# It runs on every commit and every push, so a clean tree prints one summary line
# and nothing else. Pass --verbose (or set PROSE_CHECK_VERBOSE=1) for the
# per-check detail and the limits block.
set -uo pipefail

VERBOSE="${PROSE_CHECK_VERBOSE:-0}"
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
  esac
done

ROOT="${PROSE_CHECK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

fails=0
passes=0
ok()   { passes=$((passes + 1)); [ "$VERBOSE" = 1 ] && echo "  PASS: $1"; return 0; }
bad()  { echo "  FAIL: $1" >&2; fails=$((fails + 1)); }
head_() { [ "$VERBOSE" = 1 ] && echo "$1"; return 0; }

AGENT_DIR=".agents/skills"
CLAUDE_DIR=".claude/skills"
ENTRY_POINTS=("CLAUDE.md" "AGENTS.md" "GEMINI.md" ".github/copilot-instructions.md")

head_ "Skill mirror parity:"
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

head_ "Skill frontmatter:"
# One awk per skill, not four processes: this runs on every commit, and the
# per-skill loops are where the wall clock goes.
for s in $c_list; do
  f="$CLAUDE_DIR/$s/SKILL.md"
  info="$(awk '
    NR==1 && $0 != "---" { print "!"; exit }
    /^---$/ { n++; if (n==2) exit; next }
    n==1 && /^name:/ && !gotn { sub(/^name:[[:space:]]*/,""); print "N" $0; gotn=1; next }
    n==1 && /^description:/ && !gotd { sub(/^description:[[:space:]]*/,""); print "D" $0; gotd=1; next }
  ' "$f")"
  name=""; desc=""; nofm=0
  while IFS= read -r line; do
    case "$line" in
      "!") nofm=1 ;;
      N*)  name="${line#N}" ;;
      D*)  desc="${line#D}" ;;
    esac
  done <<< "$info"
  [ "$nofm" -eq 1 ] && { bad "$s: no YAML frontmatter opening"; continue; }
  # A description of whitespace, or of quotes wrapping whitespace, loads nothing.
  # Trim outside-in: space, then one matching quote pair, then space again.
  desc="${desc#"${desc%%[![:space:]]*}"}"; desc="${desc%"${desc##*[![:space:]]}"}"
  case "$desc" in
    \"*\") desc="${desc#\"}"; desc="${desc%\"}" ;;
    \'*\') desc="${desc#\'}"; desc="${desc%\'}" ;;
  esac
  desc="${desc#"${desc%%[![:space:]]*}"}"; desc="${desc%"${desc##*[![:space:]]}"}"
  [ "$name" = "$s" ] || bad "$s: frontmatter name '$name' does not match its directory"
  [ -n "$desc" ] || bad "$s: frontmatter description is empty (nothing would load this skill)"
  [ "$name" = "$s" ] && [ -n "$desc" ] && ok "$s: name matches directory, description present"
done

# There is deliberately no "every aiw-* token resolves to a real skill" check.
# Over free prose a reference cannot be told apart from a placeholder in a
# template (aiw-prompt-smith authors skills, so its SKILL.md carries
# `name: aiw-your-skill`), from an illustrative example, from a compound built on
# a skill name, or from a project noun that is not a skill at all. Every one of
# those blocked a legitimate commit. A gate that fires on the normal path gets
# routed around, which costs more than the dangling reference it would catch.

head_ "Documented skill set matches the tree:"
doc_fails=0
pc="$(<project-context.md)"
for s in $c_list; do
  # Word boundary, hyphen included: `aiw-testing` must not satisfy `aiw-test`.
  # Newline is outside the boundary class, so it separates tokens like any space.
  [[ $pc =~ (^|[^A-Za-z0-9_-])${s}([^A-Za-z0-9_-]|$) ]] \
    || { bad "skill '$s' exists but project-context.md never names it"; doc_fails=$((doc_fails + 1)); }
done
[ "$doc_fails" -eq 0 ] && ok "project-context.md names every skill in the tree"

head_ "Version headers:"
# Equality between the lite condensation and the canonical version is enforced
# in scripts/repo-validation.sh, which runs before this and exits on drift.
for f in ai-workflow.md project-context.md lite-monolithic/ai-workflow.md; do
  if grep -qE '^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$f"; then
    ok "$f carries a Version header"
  else
    bad "$f has no Version header, so no session can be tied to a file state"
  fi
done

head_ "Declared size budget:"
pc_lines="$(wc -l < project-context.md | tr -d ' ')"
if [ "$pc_lines" -le 300 ]; then
  ok "project-context.md is $pc_lines lines (budget 300)"
else
  bad "project-context.md is $pc_lines lines, over its declared 300-line budget"
fi

head_ "Entry-point parity:"
for e in "${ENTRY_POINTS[@]}"; do
  [ -f "$e" ] || { bad "$e is missing"; continue; }
  body="$(<"$e")"; miss=""
  [[ $body == *ai-workflow.md* ]]     || miss="$miss ai-workflow.md"
  [[ $body == *project-context.md* ]] || miss="$miss project-context.md"
  [ -z "$miss" ] && ok "$e points at the governance files" || bad "$e does not reference:$miss"
done

# The limits block exists so a pass is not over-read. A silent pass says nothing
# to over-read, so it prints only when there is a failure on screen, or when the
# reader asked for detail.
if [ "$fails" -gt 0 ] || [ "$VERBOSE" = 1 ]; then
  cat <<'LIMITS'

What this cannot check:
  - Whether two passages contradict each other. Meaning is not mechanically
    decidable, and the contradiction that prompted this check (#225, two
    adjacent paragraphs of aiw-verification) would still pass here.
  - Whether a skill's description matches what its body actually covers.
  - Whether a rule is good, needed, or reachable by the agent that must follow it.
  A pass means the prose is structurally coherent, never that it is correct.
LIMITS
fi

if [ "$fails" -gt 0 ]; then
  echo "prose integrity: $fails check(s) failed" >&2
  exit 1
fi
echo "prose integrity: $passes checks passed"
