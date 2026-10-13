#!/usr/bin/env bash
# Fast commit check for ai-coding-workflow.
# Invoked by .githooks/pre-commit, in place of full validation, with the paths
# the commit changes on stdin, one per line. Full validation still gates push.
#
# Runs the cheap structural checks every time, then only the tests that touch
# what changed: a test file that changed, or one that names a changed file.
set -eu

CHANGED=()
while IFS= read -r p; do
  [ -n "$p" ] && CHANGED+=("$p")
done

if [ "${#CHANGED[@]}" -eq 0 ]; then
  exit 0
fi

bash -n ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/*

./scripts/check-manifest.sh
./scripts/check-prose-integrity.sh >/dev/null

py_targets=()
for p in "${CHANGED[@]}"; do
  case "$p" in
    *.py) [ -f "$p" ] && py_targets+=("$p") ;;
  esac
done
if [ "${#py_targets[@]}" -gt 0 ] && command -v python3 >/dev/null 2>&1; then
  python3 -m py_compile "${py_targets[@]}"
fi

ran=0
for t in ./.ai-policy/scripts/test-*.sh ./scripts/test-*.sh; do
  [ -x "$t" ] || continue
  run=false
  for p in "${CHANGED[@]}"; do
    if [ "./$p" = "$t" ] || grep -qF "$(basename "$p")" "$t"; then
      run=true
      break
    fi
  done
  if [ "$run" = "true" ]; then
    echo "commit-check: $t"
    "$t" >/dev/null || { echo "commit-check: $t failed; run it directly to see why."; exit 1; }
    ran=$((ran + 1))
  fi
done

echo "commit-check: structural checks and $ran touched test(s) passed."
