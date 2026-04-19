#!/usr/bin/env bash
set -eu

# Pre-commit check. Fails if .claude/settings.json's
# env.OTEL_RESOURCE_ATTRIBUTES does not match the canonical
# workflow_version + ruleset_hash for the current tree.

ROOT_DIR="$(git rev-parse --show-toplevel)"
"$ROOT_DIR/.ai-policy/scripts/update-session-tags.sh" --check
