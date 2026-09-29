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
ENTRY_POINTS=("CLAUDE.md" "AGENTS.md" ".github/copilot-instructions.md")

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

head_ "Done-gate enumerations agree:"
# ai-workflow.md's Task Flow names the done gate's members; every other line that
# enumerates the gate must name the same set, in both directions: a list that omits
# a member is stale, and a list that names a skill the Task Flow no longer puts in
# the gate is stale the other way (ai-workflow.md dropped it, the copy did not).
# #260 was four review rounds of one rule hand-propagated with a copy missed. A
# line counts as an enumeration only when it says "done gate" (or "done-gate") and
# names at least two of the members, so a passing mention of one skill is not read
# as a list. The skill the file belongs to counts as named on its own lines
# ("third after aiw-verification and aiw-validation" is a complete list from
# aiw-housekeeping). Extra names are only read among skills that exist in the tree,
# so a placeholder or example name is not read as a member. A check that compares
# no list has compared nothing, so that fails rather than passes.
gate_line="$(grep -m1 -E '^[0-9]+\. \*\*Done gate:\*\*' ai-workflow.md 2>/dev/null || true)"
gate_set="$(printf '%s\n' "$gate_line" | grep -oE 'aiw-[a-z]+(-[a-z]+)*' | sort -u | tr '\n' ' ')"
if [ -z "$gate_set" ]; then
  bad "ai-workflow.md has no 'Done gate:' Task Flow step naming skills, so the done-gate lists elsewhere have nothing to agree with"
else
  gate_fails=0; gate_seen=0
  for s in $c_list; do
    f="$CLAUDE_DIR/$s/SKILL.md"
    out="$(awk -v set="$gate_set" -v all="$(printf '%s ' $c_list)" -v self="$s" -v f="$f" '
      BEGIN { n = split(set, S, " "); for (i = 1; i <= n; i++) want[S[i]] = 1
              m = split(all, A, " "); for (i = 1; i <= m; i++) real[A[i]] = 1 }
      function joined(gap) { return gap ~ /^(, | and |, and | then |, then | \+ | \/ )$/ }
      tolower($0) ~ /done[- ]gate/ {
        delete got; delete extra; delete tok; delete beg; delete fin; c = 0; nt = 0; line = $0; pos = 0
        while (match(line, /aiw-[a-z]+(-[a-z]+)*/)) {
          nt++; tok[nt] = substr(line, RSTART, RLENGTH); beg[nt] = pos + RSTART; fin[nt] = pos + RSTART + RLENGTH
          pos += RSTART + RLENGTH - 1
          line = substr(line, RSTART + RLENGTH)
          if ((tok[nt] in want) && !(tok[nt] in got)) { got[tok[nt]] = 1; c++ }
        }
        if (c >= 2) {
          seen++
          # A non-member counts as listed only when a list connector joins it to a
          # neighbouring skill name, so "aiw-ground-truth owns the oracle" in the
          # same sentence is not read as a gate member.
          for (i = 1; i <= nt; i++) {
            if ((tok[i] in want) || !(tok[i] in real)) continue
            if ((i > 1 && joined(substr($0, fin[i-1], beg[i] - fin[i-1]))) || (i < nt && joined(substr($0, fin[i], beg[i+1] - fin[i])))) extra[tok[i]] = 1
          }
          if ((self in want) && !(self in got)) { got[self] = 1; c++ }
          miss = ""; for (k in want) if (!(k in got)) miss = miss " " k
          more = ""; for (k in extra) more = more " " k
          if (miss != "") print f ":" NR ": done-gate list omits" miss
          if (more != "") print f ":" NR ": done-gate list names" more ", which the Task Flow does not put in the gate"
        }
      }
      END { print "SEEN " seen + 0 }' "$f")"
    gate_n="$(printf '%s\n' "$out" | sed -n 's/^SEEN //p')"
    gate_seen=$((gate_seen + ${gate_n:-0}))
    out="$(printf '%s\n' "$out" | grep -v '^SEEN ')"
    [ -n "$out" ] && { bad "$out (ai-workflow.md Done gate step names: $gate_set)"; gate_fails=$((gate_fails + 1)); }
  done
  if [ "$gate_seen" -eq 0 ]; then
    bad "no skill line enumerates the done gate, so nothing was compared against ai-workflow.md (the matching shape changed, or the lists were removed)"
  elif [ "$gate_fails" -eq 0 ]; then
    ok "every done-gate enumeration in the skills names the same set as ai-workflow.md ($gate_seen checked)"
  fi
fi

head_ "Task Flow step numbers agree:"
# A skill that says which Task Flow step it owns must say the number ai-workflow.md
# gives it. Only claims that name the Task Flow are read: "is step N of the Task
# Flow", "owns Task Flow step N", and a numbered list item marked "(this skill)".
# A bare "is step 2 of the audit below" is a skill's own private numbering and is
# not compared. Every skill named on a Task Flow line maps to that step (the first
# step naming a skill wins: aiw-github is named again at step 6). A check that
# parses no steps, or finds no claim to compare, has verified nothing and fails.
step_fails=0; step_seen=0; steps_parsed=0; seen_skills=" "
while IFS= read -r line; do
  [[ $line =~ ^([0-9]+)\.\ \*\*[^*]+\*\*\ (.*)$ ]] || continue
  n="${BASH_REMATCH[1]}"; rest="${BASH_REMATCH[2]}"
  steps_parsed=$((steps_parsed + 1))
  for sk in $(printf '%s\n' "$rest" | grep -oE 'aiw-[a-z]+(-[a-z]+)*'); do
    f="$CLAUDE_DIR/$sk/SKILL.md"
    [ -f "$f" ] || continue
    case "$seen_skills" in *" $sk "*) continue ;; esac
    seen_skills="$seen_skills$sk "
    while IFS= read -r m; do
      step_seen=$((step_seen + 1))
      [ "$m" = "$n" ] || { bad "$f says it is step $m, but ai-workflow.md Task Flow makes $sk step $n"; step_fails=$((step_fails + 1)); }
    done < <(grep -oE "(is|owns) step [0-9]+ of the Task Flow|owns Task Flow step [0-9]+|^[0-9]+\. \*\*$sk\*\* \(this skill\)" "$f" | grep -oE '[0-9]+' | head -20)
  done
done < <(sed -n '/^## Task Flow/,/^## /p' ai-workflow.md)
if [ "$steps_parsed" -eq 0 ]; then
  bad "ai-workflow.md has no parseable '## Task Flow' numbered steps, so no step claim in the skills has anything to agree with"
elif [ "$step_seen" -eq 0 ]; then
  bad "no skill makes a Task Flow step claim of a shape this check reads, so nothing was compared (the phrasing changed, or the claims were removed)"
elif [ "$step_fails" -eq 0 ]; then
  ok "step-position claims in skills match Task Flow ($step_seen checked)"
fi

head_ "Product prose asserts nothing true only of this repository:"
# install-manifest.json is factory-only, so it is absent from a target; there the
# question has no answer and nothing is compared. Here, a product file that names a
# factory-only path claims a fact that is false in every repository that installs it.
# The tokens are read from the manifest, minus names any target may own for itself:
# README.md, LICENSE, .gitignore, Makefile, CHANGELOG.md, CONTEXT.md and INSTALL.md
# are ordinary files a skill may legitimately tell the agent to read in the target
# (any repository may own an INSTALL.md of its own). scripts/, design/ and docs/ are
# ordinary directory names for the same reason, so they are expanded to the files
# and the subdirectories this repository actually has there (a skill naming
# scripts/check-manifest.sh or design/decisions/ is asserting this repo, a skill
# saying "scripts/" is not). Everything else in factory_only (observation/,
# field-notes/, install-manifest.json) is specific enough to match as written. A
# path is matched only at a boundary, so .ai-policy/scripts/x.sh is not read as
# scripts/x.sh.
if [ ! -f install-manifest.json ]; then
  ok "no install-manifest.json here (target repository): nothing to compare"
elif ! command -v jq >/dev/null 2>&1; then
  bad "jq is required to read install-manifest.json and is not installed, so the product/factory check could not run"
else
  tokens=""
  while IFS= read -r t; do
    case "$t" in
      .gitignore|LICENSE|README.md|Makefile|CHANGELOG.md|CONTEXT.md|INSTALL.md) ;;
      scripts/|design/|docs/)
        tokens="$tokens"$'\n'"$(find "${t%/}" -type f 2>/dev/null)"
        tokens="$tokens"$'\n'"$(find "${t%/}" -mindepth 1 -type d 2>/dev/null | sed 's|$|/|')" ;;
      *) tokens="$tokens"$'\n'"$t" ;;
    esac
  done < <(jq -r '.factory_only[]' install-manifest.json)
  alt="$(printf '%s\n' "$tokens" | grep -v '^$' | sed 's/[][\.*^$/+?(){}|]/\\&/g' | paste -sd'|' -)"
  if [ -z "$alt" ]; then
    bad "install-manifest.json lists no factory-only paths to compare against"
  else
    prose=(ai-workflow.md "${ENTRY_POINTS[@]}")
    for s in $c_list; do prose+=("$CLAUDE_DIR/$s/SKILL.md" "$AGENT_DIR/$s/SKILL.md"); done
    hits="$(grep -HnoE "(^|[^A-Za-z0-9_./-])($alt)" "${prose[@]}" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
      while IFS= read -r h; do bad "product file names a factory-only path, false in an installed target: ${h}"; done <<< "$hits"
    else
      ok "no product prose file names a factory-only path"
    fi
  fi
fi

head_ "Version headers:"
for f in ai-workflow.md project-context.md; do
  if grep -qE '^Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$f"; then
    ok "$f carries a Version header"
  else
    bad "$f has no Version header, so no session can be tied to a file state"
  fi
done

head_ "Declared size budget:"
# Counted in tokens, not lines. A fact fused onto an existing line leaves the
# line count untouched while the file gets heavier, so a line budget cannot
# hold the thing it exists to hold. Tokens are estimated as bytes/4 rather than
# measured: a real tokenizer is a dependency this repository does not carry, and
# the estimate only has to be stable and roughly right to make growth visible.
check_budget() { # file, token budget
  [ -f "$1" ] || return 0   # both files are optional in a target repo
  _t=$(( $(wc -c < "$1") / 4 ))
  if [ "$_t" -le "$2" ]; then
    ok "$1 is ~$_t tokens (budget $2)"
  else
    bad "$1 is ~$_t tokens, over its declared $2-token budget; drop a line rather than raising the budget"
  fi
}
check_budget project-context.md 6000
check_budget north-star.md 400

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
  - Whether a rule kept in one authoritative file is restated elsewhere (#262):
    which file is authoritative for which rule is an editorial call.
  - Lists that enumerate the same members but that nothing ties together (the
    core-skills list in aiw-failure-analysis against the Task Flow steps it
    draws from): only the skill set, the done gate (both directions, among
    skills joined by a list connector) and step positions claimed against the
    Task Flow by name are compared. A done-gate list wrapped across lines, a
    list naming its own skill and one member, a step claim in other words
    ("sits at step N"), and a skill on two steps (only the first is compared)
    are not caught; a skill naming aiw-prompt-smith at the done gate is flagged,
    since the rules do not say whether it is a gate member.
  - Whether a product file states something true only of this repository in
    words rather than by naming a factory-only path, or names one of the
    ordinary names a target may own (README.md, INSTALL.md, a bare scripts/).
    A generic path that happens to share a factory-only prefix (docs/adr/,
    observation/...) is flagged although a target may own one.
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
