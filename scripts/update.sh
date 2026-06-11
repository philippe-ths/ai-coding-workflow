#!/usr/bin/env bash
# Update an already-installed AI workflow copy in a target repository.
#
#   scripts/update.sh --target <dir> --tool <name> [--profile full|lite] [--source <dir>]
#
# Reconciles an installed (vendored) copy to the source's current version:
#   1. Reads the installed version (target ai-workflow.md `Version:`) and the
#      source version; refuses to downgrade and no-ops if already current.
#   2. Re-copies the current product set (adds new, overwrites changed) by
#      delegating to install.sh.
#   3. Removes files the source dropped between the two versions, learned from
#      the source CHANGELOG `### Removed` entries (leading-path convention).
#      A file is deleted only if it is BOTH named as removed AND absent from the
#      current product set; files under vendored paths that are not in the
#      current product and not named as removed are kept (local additions).
#
# The source CHANGELOG is read from the source repo (factory). The target's own
# changelog is never touched.
set -eu

SOURCE=""
TARGET=""
TOOL=""
PROFILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: update.sh --target <dir> --tool <name> [--profile full|lite] [--source <dir>]"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -n "$SOURCE" ] || SOURCE="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -n "$TARGET" ] || { echo "error: --target is required" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

MANIFEST="$SOURCE/install-manifest.json"
[ -f "$MANIFEST" ] || { echo "error: manifest not found at $MANIFEST" >&2; exit 1; }
git -C "$SOURCE" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "error: source is not a git work tree: $SOURCE" >&2; exit 1; }
git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "error: target is not a git repo: $TARGET" >&2; exit 1; }
SOURCE="$(cd "$SOURCE" && git rev-parse --show-toplevel)"
TARGET="$(cd "$TARGET" && git rev-parse --show-toplevel)"

read_version() { awk '/^Version:[[:space:]]*/ { print $2; exit }' "$1" 2>/dev/null; }

[ -f "$TARGET/ai-workflow.md" ] || { echo "error: no installed workflow found in target (ai-workflow.md missing); use install.sh" >&2; exit 1; }

# Auto-detect tool and profile from the installed target when not given.
if [ -z "$PROFILE" ]; then
  if [ -d "$TARGET/.ai-policy" ]; then PROFILE="full"; else PROFILE="lite"; fi
fi
if [ -z "$TOOL" ]; then
  detected=""
  [ -f "$TARGET/CLAUDE.md" ] && detected="$detected claude"
  [ -f "$TARGET/AGENTS.md" ] && detected="$detected codex"
  [ -f "$TARGET/GEMINI.md" ] && detected="$detected gemini"
  [ -f "$TARGET/.github/copilot-instructions.md" ] && detected="$detected copilot"
  detected="$(echo $detected | xargs)"
  case "$detected" in
    "")     echo "error: could not detect installed tool; pass --tool" >&2; exit 2 ;;
    *" "*)  echo "error: multiple tools installed ($detected); pass --tool to choose" >&2; exit 2 ;;
    *)      TOOL="$detected" ;;
  esac
fi
case "$TOOL" in claude|codex|gemini|copilot) ;; *) echo "error: --tool must be claude|codex|gemini|copilot" >&2; exit 2 ;; esac
case "$PROFILE" in full|lite) ;; *) echo "error: --profile must be full or lite" >&2; exit 2 ;; esac

installed_version="$(read_version "$TARGET/ai-workflow.md")"
source_version="$(read_version "$SOURCE/ai-workflow.md")"
[ -n "$installed_version" ] || { echo "error: target ai-workflow.md has no Version header" >&2; exit 1; }
[ -n "$source_version" ] || { echo "error: source ai-workflow.md has no Version header" >&2; exit 1; }

# --- version comparison (semver-ish, via sort -V) ---
ver_le() { [ "$1" = "$2" ] || [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }
ver_lt() { [ "$1" != "$2" ] && ver_le "$1" "$2"; }

if [ "$installed_version" = "$source_version" ]; then
  echo "Target already at $source_version. Re-syncing product files."
elif ver_lt "$source_version" "$installed_version"; then
  echo "Refusing to update: target is ahead (installed $installed_version > source $source_version)." >&2
  exit 1
else
  echo "Updating target from $installed_version to $source_version."
fi

# --- additive: re-copy the current product set (overwrites changed, adds new) ---
"$SCRIPT_DIR/install.sh" --source "$SOURCE" --target "$TARGET" --tool "$TOOL" --profile "$PROFILE" >/dev/null \
  || { echo "error: re-copy step failed" >&2; exit 1; }

# --- removal reconciliation (full profile; lite is a single file with nothing to reconcile) ---
removed_count=0
if [ "$PROFILE" = "full" ]; then
  current_product="$(mktemp)"
  trap 'rm -f "$current_product"' EXIT
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    git -C "$SOURCE" ls-files -- "${p%/}" >> "$current_product"
  done < <(jq -r --arg t "$TOOL" '[.profiles.full.shared[], .profiles.full.tools[$t][]] | .[]' "$MANIFEST")

  in_range() { # version, installed, source : installed < version <= source
    ver_lt "$2" "$1" && ver_le "$1" "$3"
  }

  # Collect removed paths named in CHANGELOG for versions in (installed, source].
  removed_paths="$(
    awk '
      /^## /      { match($0, /[0-9][0-9.]*/); ver=substr($0,RSTART,RLENGTH); inrem=0; next }
      /^### Removed/ { inrem=1; next }
      /^### /     { inrem=0; next }
      inrem==1 && /^- `/ {
        s=$0; sub(/^- `/,"",s); sub(/`.*/,"",s); print ver "\t" s
      }
    ' "$SOURCE/CHANGELOG.md"
  )"

  while IFS=$'\t' read -r ver rp; do
    [ -z "${ver:-}" ] && continue
    in_range "$ver" "$installed_version" "$source_version" || continue
    rp_stripped="${rp%/}"
    case "$rp" in
      */)  # directory removal: delete target files under it that are not current product
        if [ -d "$TARGET/$rp_stripped" ]; then
          while IFS= read -r f; do
            rel="${f#"$TARGET"/}"
            if ! grep -Fxq "$rel" "$current_product"; then
              rm -f "$f"; removed_count=$((removed_count + 1)); echo "  removed: $rel"
            fi
          done < <(find "$TARGET/$rp_stripped" -type f 2>/dev/null)
          find "$TARGET/$rp_stripped" -type d -empty -delete 2>/dev/null || true
        fi
        ;;
      *)   # file removal
        if [ -e "$TARGET/$rp_stripped" ] && ! grep -Fxq "$rp_stripped" "$current_product"; then
          rm -f "$TARGET/$rp_stripped"; removed_count=$((removed_count + 1)); echo "  removed: $rp_stripped"
        fi
        ;;
    esac
  done <<EOF
$removed_paths
EOF
fi

echo "Update complete: target now at $source_version (profile: $PROFILE, tool: $TOOL); $removed_count file(s) removed."
echo "Local additions under vendored paths were left in place."
