#!/usr/bin/env bash
set -eu

# Updates .claude/settings.json's env.OTEL_RESOURCE_ATTRIBUTES to match
# the current ai-workflow.md version and a ruleset hash computed from
# the rule-defining files.
#
# Usage:
#   update-session-tags.sh          # writes if drift
#   update-session-tags.sh --check  # exits 1 on drift, does not write
#
# Tag format:
#   workflow_version=X.Y.Z,workflow_repo=ai-coding-workflow,ruleset_hash=<8hex>
#
# Ruleset-hash input (sorted, deterministic):
#   ai-workflow.md
#   CLAUDE.md
#   .ai-policy/policy.env
#   .ai-policy/hooks/*.sh
#   .claude/skills/*/SKILL.md

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

WORKFLOW_FILE="ai-workflow.md"
SETTINGS_FILE=".claude/settings.json"
REPO_NAME="ai-coding-workflow"

MODE="write"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
fi

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    shasum -a 256 | awk '{ print $1 }'
  fi
}

collect_rule_files() {
  {
    [ -f "$WORKFLOW_FILE" ] && echo "$WORKFLOW_FILE"
    [ -f "CLAUDE.md" ] && echo "CLAUDE.md"
    [ -f ".ai-policy/policy.env" ] && echo ".ai-policy/policy.env"
    for f in .ai-policy/hooks/*.sh; do
      [ -f "$f" ] && echo "$f"
    done
    for f in .claude/skills/*/SKILL.md; do
      [ -f "$f" ] && echo "$f"
    done
  } | LC_ALL=C sort -u
}

version="$(awk '/^Version:[[:space:]]*/ { print $2; exit }' "$WORKFLOW_FILE" 2>/dev/null || true)"
if [ -z "$version" ]; then
  echo "update-session-tags: could not read Version: from $WORKFLOW_FILE" >&2
  exit 2
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "update-session-tags: $SETTINGS_FILE not found" >&2
  exit 2
fi

# Self-scope to the ai-coding-workflow upstream repo. Downstream repos that
# copy .ai-policy/ wholesale set their own OTEL_RESOURCE_ATTRIBUTES via the
# aiw-telemetry-setup skill; their tag string does not carry
# workflow_repo=ai-coding-workflow and must not be overwritten or drift-checked
# against the upstream ruleset hash.
existing="$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES // ""' "$SETTINGS_FILE")"
if [ -n "$existing" ] && ! printf '%s' "$existing" | grep -q 'workflow_repo=ai-coding-workflow'; then
  exit 0
fi

tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT

while IFS= read -r f; do
  printf '===%s===\n' "$f" >> "$tmp_input"
  cat "$f" >> "$tmp_input"
  printf '\n' >> "$tmp_input"
done < <(collect_rule_files)

ruleset_hash="$(sha256_hex < "$tmp_input" | cut -c1-8)"

new_attrs="workflow_version=${version},workflow_repo=${REPO_NAME},ruleset_hash=${ruleset_hash}"

current="$(jq -r '.env.OTEL_RESOURCE_ATTRIBUTES // ""' "$SETTINGS_FILE")"

if [ "$current" = "$new_attrs" ]; then
  exit 0
fi

if [ "$MODE" = "check" ]; then
  echo "update-session-tags: drift detected in $SETTINGS_FILE" >&2
  echo "  current:  $current" >&2
  echo "  expected: $new_attrs" >&2
  echo "  run: ./.ai-policy/scripts/update-session-tags.sh" >&2
  exit 1
fi

tmp_out="$(mktemp)"
jq --arg v "$new_attrs" '.env.OTEL_RESOURCE_ATTRIBUTES = $v' "$SETTINGS_FILE" > "$tmp_out"
mv "$tmp_out" "$SETTINGS_FILE"
echo "update-session-tags: wrote $new_attrs to $SETTINGS_FILE"
