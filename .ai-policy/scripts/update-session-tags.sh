#!/usr/bin/env bash
set -eu

# Updates this repo's .envrc to carry an OTEL_RESOURCE_ATTRIBUTES export line
# that matches the current ai-workflow.md version and a ruleset hash computed
# from the rule-defining files.
#
# Usage:
#   update-session-tags.sh
#
# Scope:
#   This script exists to keep the ai-coding-workflow upstream repository's own
#   Claude Code session telemetry tags in sync with its current ruleset. It is
#   not intended for downstream repositories — the aiw-telemetry-setup skill
#   owns downstream .envrc content.
#
# Target file:
#   .envrc  (gitignored; maintainer-local).
#
# The script inserts or replaces a block delimited by these sentinels:
#   # >>> aiw session tags (managed, do not edit) >>>
#   export OTEL_RESOURCE_ATTRIBUTES="..."
#   # <<< aiw session tags <<<
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
ENVRC_FILE=".envrc"
REPO_NAME="ai-coding-workflow"
BEGIN_SENTINEL="# >>> aiw session tags (managed, do not edit) >>>"
END_SENTINEL="# <<< aiw session tags <<<"

# Self-scope: only run in the upstream ai-coding-workflow repo itself.
# Downstream repos use the aiw-telemetry-setup skill to populate .envrc.
if [ ! -f "$WORKFLOW_FILE" ] || ! grep -q "^# AI Workflow" "$WORKFLOW_FILE" 2>/dev/null; then
  exit 0
fi
repo_basename="$(basename "$ROOT_DIR")"
if [ "$repo_basename" != "$REPO_NAME" ]; then
  exit 0
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

tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT

while IFS= read -r f; do
  printf '===%s===\n' "$f" >> "$tmp_input"
  cat "$f" >> "$tmp_input"
  printf '\n' >> "$tmp_input"
done < <(collect_rule_files)

ruleset_hash="$(sha256_hex < "$tmp_input" | cut -c1-8)"
new_attrs="workflow_version=${version},workflow_repo=${REPO_NAME},ruleset_hash=${ruleset_hash}"

export_line="export OTEL_RESOURCE_ATTRIBUTES=\"${new_attrs}\""

write_block() {
  local target="$1"
  printf '%s\n%s\n%s\n' "$BEGIN_SENTINEL" "$export_line" "$END_SENTINEL" >> "$target"
}

if [ ! -f "$ENVRC_FILE" ]; then
  : > "$ENVRC_FILE"
  write_block "$ENVRC_FILE"
  echo "update-session-tags: created $ENVRC_FILE with $new_attrs"
  exit 0
fi

if grep -qF "$BEGIN_SENTINEL" "$ENVRC_FILE"; then
  # Check whether the existing block already matches.
  current_export="$(awk -v b="$BEGIN_SENTINEL" -v e="$END_SENTINEL" '
    $0 == b { inblock = 1; next }
    $0 == e { inblock = 0; next }
    inblock { print }
  ' "$ENVRC_FILE")"
  if [ "$current_export" = "$export_line" ]; then
    exit 0
  fi
  tmp_out="$(mktemp)"
  awk -v b="$BEGIN_SENTINEL" -v e="$END_SENTINEL" '
    $0 == b { skip = 1; next }
    skip && $0 == e { skip = 0; next }
    skip { next }
    { print }
  ' "$ENVRC_FILE" > "$tmp_out"
  # Strip trailing blank lines from the kept content, then append fresh block.
  awk 'NF { n = NR } { lines[NR] = $0 } END { for (i = 1; i <= n; i++) print lines[i] }' "$tmp_out" > "$tmp_out.trim"
  mv "$tmp_out.trim" "$ENVRC_FILE"
  rm -f "$tmp_out"
  printf '\n' >> "$ENVRC_FILE"
  write_block "$ENVRC_FILE"
  echo "update-session-tags: updated $ENVRC_FILE to $new_attrs"
else
  printf '\n' >> "$ENVRC_FILE"
  write_block "$ENVRC_FILE"
  echo "update-session-tags: appended managed block to $ENVRC_FILE with $new_attrs"
fi
