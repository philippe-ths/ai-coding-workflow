#!/usr/bin/env bash
# Fast commit check for ai-coding-workflow.
# Invoked by .githooks/pre-commit, in place of full validation, with the paths
# the commit changes on stdin, one per line. Full validation still gates push.
#
# Runs the cheap structural checks every time, then only the tests that touch
# what changed: a test file that changed, or one that names a changed file.
# Checks with no file of their own to match on, such as the observation fixture
# check in repo-validation.sh, wait for the push gate.
set -eu

CHANGED=()
while IFS= read -r p; do
  [ -n "$p" ] && CHANGED+=("$p")
done

if [ "${#CHANGED[@]}" -eq 0 ]; then
  exit 0
fi

# One file per call: `bash -n a b` checks only a, reading b as an argument.
for f in ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/*; do
  if [ -f "$f" ]; then bash -n "$f"; fi
done
for p in "${CHANGED[@]}"; do
  case "$p" in
    *.sh) if [ -f "$p" ]; then bash -n "$p"; fi ;;
  esac
done

./scripts/check-manifest.sh
./scripts/check-prose-integrity.sh >/dev/null

py_targets=()
for p in "${CHANGED[@]}"; do
  case "$p" in
    *.py) if [ -f "$p" ]; then py_targets+=("$p"); fi ;;
  esac
done
if [ "${#py_targets[@]}" -gt 0 ] && command -v python3 >/dev/null 2>&1; then
  python3 -m py_compile "${py_targets[@]}"
fi

ran=0
for t in ./.ai-policy/scripts/test-*.sh ./scripts/test-*.sh ./scripts/test_*.py ./observation/test_*.py; do
  [ -f "$t" ] || continue
  case "$t" in
    *.py) command -v python3 >/dev/null 2>&1 || continue ;;
    *) [ -x "$t" ] || continue ;;
  esac
  run=false
  for p in "${CHANGED[@]}"; do
    if [ "./$p" = "$t" ]; then
      run=true
      break
    fi
    # Prose is covered by the prose and manifest checks above. The tests that
    # merely name a Markdown file mostly install or copy it, and would put the
    # slowest suites on every prose loop, so a Markdown file selects only a test
    # named for it: CHANGELOG.md selects test-changelog-*.
    case "$p" in
      *.md)
        stem="$(basename "$p" .md | tr '[:upper:]' '[:lower:]')"
        case "$(basename "$t")" in
          *"$stem"*) run=true; break ;;
        esac
        continue ;;
    esac
    if grep -qF "$(basename "$p")" "$t"; then
      run=true
      break
    fi
  done
  if [ "$run" = "true" ]; then
    echo "commit-check: $t"
    case "$t" in
      *.py) python3 "$t" >/dev/null 2>&1 ;;
      *) "$t" >/dev/null ;;
    esac || { echo "commit-check: $t failed; run it directly to see why."; exit 1; }
    ran=$((ran + 1))
  fi
done

echo "commit-check: structural checks and $ran touched test(s) passed."
