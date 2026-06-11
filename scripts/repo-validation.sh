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

# --- manifest integrity: the product/factory boundary must stay honest ---
if [ -x ./scripts/check-manifest.sh ]; then
  ./scripts/check-manifest.sh
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
