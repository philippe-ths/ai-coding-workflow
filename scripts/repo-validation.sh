#!/usr/bin/env bash
# Repo-specific validation for ai-coding-workflow.
# Invoked by ./.ai-policy/scripts/project-validation.sh when this file exists and is executable.
# Target repos should supply their own scripts/repo-validation.sh (tests, linters, etc.).
#
# This repo's only runtime code is the session-observation tooling under ./observation
# (see docs/adr/0001 and docs/adr/0002). Each check below is guarded so the validator
# stays green whether or not a given surface is present.
set -eu

# --- shell syntax: any shell scripts shipped with the observation tooling ---
shell_targets=()
while IFS= read -r f; do shell_targets+=("$f"); done < <(
  find ./observation -name '*.sh' -type f 2>/dev/null
)
if [ "${#shell_targets[@]}" -gt 0 ]; then
  bash -n "${shell_targets[@]}"
fi

# --- python: byte-compile the observation tooling ---
if command -v python3 >/dev/null 2>&1; then
  py_targets=()
  while IFS= read -r f; do py_targets+=("$f"); done < <(
    find ./observation -name '*.py' -type f 2>/dev/null
  )
  if [ "${#py_targets[@]}" -gt 0 ]; then
    python3 -m py_compile "${py_targets[@]}"
  fi
fi

# --- lite parity: the lite-monolithic version must track the canonical version ---
# A lagging lite Version: header is the documented drift signal that the lite
# condensation was not re-synced when the canonical workflow changed
# (design/decisions/maintenance.md). Fail loudly so the gap cannot stay silent.
if [ -f ./ai-workflow.md ] && [ -f ./lite-monolithic/ai-workflow.md ]; then
  canon_ver="$(awk '/^Version:[[:space:]]*/ { print $2; exit }' ./ai-workflow.md)"
  lite_ver="$(awk '/^Version:[[:space:]]*/ { print $2; exit }' ./lite-monolithic/ai-workflow.md)"
  if [ "$canon_ver" != "$lite_ver" ]; then
    echo "error: lite-monolithic/ai-workflow.md Version ($lite_ver) does not match canonical ai-workflow.md Version ($canon_ver)." >&2
    echo "       Re-condense the lite file to absorb the canonical change, then set its Version header equal to $canon_ver." >&2
    exit 1
  fi
fi

# --- manifest integrity: the product/factory boundary must stay honest ---
if [ -x ./scripts/check-manifest.sh ]; then
  ./scripts/check-manifest.sh
fi

# --- install: sandbox test of the installer against throwaway target repos ---
if [ -x ./scripts/test-install.sh ]; then
  ./scripts/test-install.sh
fi

# --- changelog removals: enforce the leading-path convention (factory-only) ---
if [ -x ./scripts/check-changelog-removals.sh ]; then
  ./scripts/check-changelog-removals.sh
fi
if [ -x ./scripts/test-changelog-removals.sh ]; then
  ./scripts/test-changelog-removals.sh
fi

# --- update: sandbox test of the update path against a real historical version pair ---
if [ -x ./scripts/test-update.sh ]; then
  ./scripts/test-update.sh
fi

# --- observation capture: install/uninstall against a sandbox CLAUDE_HOME ---
if [ -x ./scripts/test-observation-install.sh ]; then
  ./scripts/test-observation-install.sh
fi

# --- parser regression test: guards the one place the transcript format lives ---
if command -v python3 >/dev/null 2>&1 && [ -f ./observation/test_parse.py ]; then
  python3 ./observation/test_parse.py
fi

# --- the checked-in transcript fixture must be valid JSONL ---
if command -v python3 >/dev/null 2>&1 && [ -f ./observation/fixtures/sample-transcript.jsonl ]; then
  python3 - <<'PY'
import json, sys
path = "./observation/fixtures/sample-transcript.jsonl"
with open(path) as fh:
    for n, line in enumerate(fh, 1):
        line = line.strip()
        if not line:
            continue
        try:
            json.loads(line)
        except json.JSONDecodeError as e:
            print(f"Invalid JSONL in {path} line {n}: {e}", file=sys.stderr)
            sys.exit(1)
PY
fi
