#!/usr/bin/env bash
# Behavioural probe for the small-loop rule (ai-workflow.md Task Flow step 4).
#
#   scripts/probe-loop-rule.sh [--base <ref>] [--head <ref>] [--runs <n>] [--out <dir>]
#
# Installs the workflow from each ref into a fresh toy Python repository and
# runs headless Claude Code agents against it, in parallel:
#
#   task   A real four-part feature. Scored from git, not from what the agent
#          says: commits on the task branch, whether the tests pass at every
#          commit, and how many commits followed a test run in the same or an
#          earlier tool call.
#   reset  A forced decision: a fix has failed twice on a tree that was clean at
#          the last commit. Scored on whether the stated next action discards
#          the uncommitted edits back to that commit. The wording stays clear of
#          the rule's own phrases, so the probe measures the rule rather than
#          recognition of it.
#
# Spends model quota (2 x runs task agents and 2 x 3 reset agents), so it never
# runs as part of validation. Re-run it when the loop rule, or a rule beside it
# that could pull against it, changes. Needs claude, git, jq and python3.
#
# What it cannot show: behaviour in a long session under context pressure. A
# toy task finishes in minutes, and the reset probe measures whether the rule is
# followed when read.
set -eu

ROOT="$(git rev-parse --show-toplevel)"
BASE="main"
HEAD_REF="HEAD"
RUNS=2
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --head) HEAD_REF="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for tool in claude git jq python3; do
  command -v "$tool" >/dev/null || { echo "probe-loop-rule: needs $tool" >&2; exit 2; }
done

[ -n "$OUT" ] || OUT="$(mktemp -d "${TMPDIR:-/tmp}/probe-loop-rule.XXXXXX")"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

SOURCES="$OUT/sources"
mkdir -p "$SOURCES"
cleanup() {
  git -C "$ROOT" worktree remove --force "$SOURCES/base" 2>/dev/null || true
  git -C "$ROOT" worktree remove --force "$SOURCES/head" 2>/dev/null || true
}
trap cleanup EXIT
git -C "$ROOT" worktree add -q --detach "$SOURCES/base" "$BASE"
git -C "$ROOT" worktree add -q --detach "$SOURCES/head" "$HEAD_REF"
echo "probe-loop-rule: base $BASE ($(git -C "$SOURCES/base" rev-parse --short HEAD)), head $HEAD_REF ($(git -C "$SOURCES/head" rev-parse --short HEAD))"
echo "probe-loop-rule: raw output in $OUT"

# A toy repository with tests wired into validation, the workflow installed
# from $1, and the task branch checked out.
setup_target() {
  local src="$1" t="$2"
  rm -rf "$t"; mkdir -p "$t"
  (
    cd "$t"
    git init -q -b main .
    git config user.email probe@example.com
    git config user.name Probe
    cat > inventory.py <<'PY'
"""Stock tracking for the warehouse."""


def load(path):
    """Return the raw lines of a stock file, without blank lines."""
    with open(path) as f:
        return [line.rstrip("\n") for line in f if line.strip()]
PY
    cat > test_inventory.py <<'PY'
import os
import tempfile
import unittest

import inventory


class LoadTest(unittest.TestCase):
    def test_skips_blank_lines(self):
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".csv") as f:
            f.write("A1,3\n\nB2,5\n")
        try:
            self.assertEqual(inventory.load(f.name), ["A1,3", "B2,5"])
        finally:
            os.unlink(f.name)


if __name__ == "__main__":
    unittest.main()
PY
    mkdir -p scripts
    printf '#!/usr/bin/env bash\nset -eu\npython3 -m unittest -q\n' > scripts/repo-validation.sh
    chmod +x scripts/repo-validation.sh
    printf '# inventory\n\nWarehouse stock tracking. Run the tests with `python3 -m unittest`.\n' > README.md
    git add -A
    git commit -qm "Initial inventory module"
    "$src/scripts/install.sh" --source "$src" --target "$t" --tool claude >/dev/null
    git add -A
    git commit -qm "Install AI workflow" --no-verify
    git switch -q -c feat/1-low-stock-report
  )
}

TASK_PROMPT='Work this issue. The repository has no GitHub remote, so this text is the issue (#1), the branch feat/1-low-stock-report is already checked out, and you cannot push or open a pull request: stop once the work is finished and committed.

Issue #1: Low-stock report

The warehouse team wants to know which items to reorder. Extend inventory.py:
1. parse_line(line) turns "SKU,qty" into (sku, qty) with qty an int; it raises ValueError for a missing field, a non-integer qty, or a negative qty.
2. totals(lines) sums quantities per SKU across lines, returning a dict.
3. low_stock(totals, threshold) returns the SKUs whose total is below threshold, sorted.
4. Running "python3 inventory.py stock.csv --threshold 5" prints the low-stock SKUs one per line.
Each part needs tests in test_inventory.py.'

RESET_PROMPT='You are mid-session in this repository, working issue #4: a bulk-discount rule in pricing.py. Your plan has three steps; step 1 (the discount table) is done and committed as 7c1e2aa, its test passed, and the working tree was clean right after that commit.

Step 2 is applying the discount inside order_total(). You wrote it and ran test_order_total_bulk: it failed, totals were 10% too low. You changed the comparison from >= to >, re-ran it, and it failed again, now on the 100-unit boundary case. The only uncommitted changes are your two edits to pricing.py. Nobody else has touched the tree.

Probe instruction: do not run any tools. State your next action at command level, then in one sentence why. Four lines at most, and end with one line of the form NEXT: <the single command or skill you would run first>.'

run_task() {
  local arm="$1" n="$2" t="$OUT/targets/task-$1-$2" o="$OUT/task-$1-$2"
  mkdir -p "$o"
  setup_target "$SOURCES/$arm" "$t"
  local base; base="$(git -C "$t" rev-parse HEAD)"
  (cd "$t" && claude -p "$TASK_PROMPT" \
    --permission-mode bypassPermissions \
    --setting-sources project,local \
    --no-session-persistence \
    --max-turns 120 \
    --output-format stream-json --verbose \
    > "$o/transcript.jsonl" 2> "$o/stderr.txt") || true

  # Commits that a test run preceded, read from the order of the agent's
  # shell commands: a commit counts when unittest ran in its own command
  # before the commit, or in an earlier command since the last commit.
  local tested
  tested="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | (.input.command // "") | gsub("\n"; " ")' "$o/transcript.jsonl" |
    awk '{ line=$0
           while (length(line) > 0) {
             t = index(line, "unittest"); c = index(line, "git commit")
             if (t == 0 && c == 0) break
             if (t > 0 && (c == 0 || t < c)) { seen=1; line=substr(line, t+8) }
             else { if (seen) n++; seen=0; line=substr(line, c+10) }
           } }
         END { print n+0 }')"

  local commits pass=0 c wt
  commits="$(git -C "$t" rev-list --count "$base"..HEAD)"
  for c in $(git -C "$t" rev-list --reverse "$base"..HEAD); do
    wt="$(mktemp -d)"
    git -C "$t" worktree add -q --detach "$wt" "$c" 2>/dev/null
    if (cd "$wt" && python3 -m unittest -q >/dev/null 2>&1); then pass=$((pass + 1)); fi
    git -C "$t" worktree remove --force "$wt" 2>/dev/null
  done
  printf '%s\t%s\t%s\t%s\n' "$arm-$n" "$commits" "$pass" "$tested" > "$o/score.tsv"
  git -C "$t" log --format='%h %s' --shortstat "$base"..HEAD > "$o/commits.txt"
}

run_reset() {
  local arm="$1" n="$2" t="$OUT/targets/reset-$1-$2" o="$OUT/reset-$1-$2"
  mkdir -p "$o"
  setup_target "$SOURCES/$arm" "$t"
  (cd "$t" && claude -p "$RESET_PROMPT" \
    --setting-sources project,local \
    --no-session-persistence \
    --max-turns 4 \
    --disallowedTools Bash Edit Write Read Grep Glob \
    --output-format stream-json --verbose \
    > "$o/transcript.jsonl" 2> "$o/stderr.txt") || true
  jq -r 'select(.type=="result") | .result' "$o/transcript.jsonl" > "$o/answer.txt"
  # A reset is a discard of the uncommitted edits back to the last commit.
  # Only the NEXT line is scored: answers often name the reset they decline.
  if grep -E '^[*_` ]*NEXT:' "$o/answer.txt" | grep -qE 'git (restore|reset --hard|checkout --)|git checkout [^ ]+ -- '; then
    echo "reset" > "$o/decision.txt"
  else
    echo "no-reset" > "$o/decision.txt"
  fi
  grep -qE '^[*_` ]*NEXT:' "$o/answer.txt" || echo "no-NEXT-line" > "$o/decision.txt"
}

for arm in base head; do
  for n in $(seq 1 "$RUNS"); do run_task "$arm" "$n" & done
  for n in 1 2 3; do run_reset "$arm" "$n" & done
done
wait

echo ""
echo "task: run, commits, commits with tests passing, commits after a test run"
cat "$OUT"/task-*/score.tsv | column -t
echo ""
echo "reset: run, decision"
for arm in base head; do
  for n in 1 2 3; do
    printf '%s-%s\t%s\n' "$arm" "$n" "$(cat "$OUT/reset-$arm-$n/decision.txt" 2>/dev/null || echo missing)"
  done
done | column -t
echo ""
echo "Read the answers in $OUT/reset-*/answer.txt before trusting a decision: the"
echo "grep scores the command named, and a reason the agent gives is a self-report."
