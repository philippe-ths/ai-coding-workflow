#!/usr/bin/env bash
# Portable policy-layer validation.
# Runs in any repo that has installed this policy layer.
# Validates only the policy layer itself: shell-script syntax plus enforcement tests
# that match the agent entry points actually installed in this repo.
# If ./scripts/repo-validation.sh exists and is executable, runs it afterwards for repo-specific checks.
# If it is absent, warns loudly that only the policy layer ran so a "passed" result is
# not mistaken for the host project's own tests/lint/type-checks having run.
set -eu

bash -n ./.ai-policy/scripts/*.sh ./.ai-policy/hooks/*.sh ./.githooks/*

for t in ./.ai-policy/scripts/test-*.sh; do
  [ -x "$t" ] || continue
  base="$(basename "$t" .sh)"
  case "$base" in
    test-claude-code-enforcement)
      [ -d ./.claude ] || { echo "Skipping $base (no ./.claude/ — Claude Code not installed)"; continue; }
      ;;
    test-codex-enforcement)
      [ -d ./.codex ] || { echo "Skipping $base (no ./.codex/ — Codex not installed)"; continue; }
      ;;
    test-gemini-enforcement)
      [ -d ./.gemini ] || { echo "Skipping $base (no ./.gemini/ — Gemini CLI not installed)"; continue; }
      ;;
    test-vscode-copilot-enforcement)
      [ -d ./.github/hooks ] || { echo "Skipping $base (no ./.github/hooks/ — VS Code Copilot not installed)"; continue; }
      ;;
  esac
  "$t"
done

if [ -x ./scripts/repo-validation.sh ]; then
  echo "Running repo-specific checks from ./scripts/repo-validation.sh ..."
  ./scripts/repo-validation.sh
else
  echo "WARNING: no ./scripts/repo-validation.sh found."
  echo "         Validation ran ONLY this workflow's policy-layer self-checks."
  echo "         Your project's own tests, linters, and type checks were NOT run,"
  echo "         so a \"passed\" result here does not mean your code is validated."
  echo "         Wire your checks in by creating an executable ./scripts/repo-validation.sh"
  echo "         (see README 'Post-install setup')."
fi
