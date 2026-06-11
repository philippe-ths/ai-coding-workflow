#!/usr/bin/env bash
# Print the product/factory classification straight from install-manifest.json.
#
# install-manifest.json is the single source of truth for the boundary; this is
# a human-readable view of it. scripts/check-manifest.sh guarantees the manifest
# classifies every git-tracked file, so this listing can never silently omit one.
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
MANIFEST="$ROOT_DIR/install-manifest.json"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "error: manifest not found: $MANIFEST" >&2; exit 1; }

echo "Source of truth: install-manifest.json (validated by scripts/check-manifest.sh)"
echo

echo "PRODUCT — copied into a target repo on install"
echo "  full profile, shared (every tool):"
jq -r '.profiles.full.shared[] | "    " + .' "$MANIFEST"
for t in $(jq -r '.profiles.full.tools | keys[]' "$MANIFEST"); do
  printf '  full profile, %s:\n' "$t"
  jq -r --arg t "$t" '.profiles.full.tools[$t][] | "    " + .' "$MANIFEST"
done
echo "  lite profile:"
jq -r '.profiles.lite.shared[] | "    " + .' "$MANIFEST"
echo

echo "AUTHORED IN TARGET — created fresh per target, never copied"
jq -r '.authored_in_target[] | "  " + .' "$MANIFEST"
echo

echo "FACTORY — this repo's own machinery, never installed"
jq -r '.factory_only[] | "  " + .' "$MANIFEST"
