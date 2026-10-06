#!/usr/bin/env bash
# Update an already-installed AI workflow copy in a target repository.
#
#   scripts/update.sh --target <dir> [--tool <name>] [--source <dir>]
#
# Updates EVERY tool installed in the target, plus --tool if given, so no
# installed tool is left at an older version. A tool counts as installed when
# the installer's managed .gitignore block lists a path only that tool ships;
# without a block, entry-point files are used and several of them need --tool.
# --tool is otherwise only needed to add a tool not yet installed.
#
# Reconciles an installed (vendored) copy to the source's current version:
#   1. Reads the installed version (target ai-workflow.md `Version:`) and the
#      source version; refuses to downgrade and no-ops if already current.
#   2. Re-copies the current product set (adds new, overwrites changed; seeded
#      files are kept and only gain settings they lack) by delegating to
#      install.sh, once per tool.
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

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: update.sh --target <dir> [--tool <name>] [--source <dir>]"; echo "Updates every tool installed in the target, plus --tool if given."; exit 0 ;;
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

# The tool set is every tool installed in the target, plus --tool if given, so
# naming one tool never leaves another installed tool at an older version.
# Installed means the installer's managed .gitignore block lists a path only
# that tool ships: a repo's own CLAUDE.md or AGENTS.md is not evidence of an
# install, and a deleted entry point does not hide one.
case "$TOOL" in ""|claude|codex|copilot) ;; *) echo "error: --tool must be claude|codex|copilot" >&2; exit 2 ;; esac
BEGIN_MARK="# >>> ai-workflow (vendored, managed by installer) >>>"
END_MARK="# <<< ai-workflow <<<"
TOOLS=""
if [ -f "$TARGET/.gitignore" ] && grep -Fxq -- "$BEGIN_MARK" "$TARGET/.gitignore"; then
  block_entries="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b { inb=1; next }
    $0==e { inb=0; next }
    inb==1 { k=$0; sub(/^[ \t]+/,"",k); sub(/[ \t]+$/,"",k); sub(/\/+$/,"",k); if (k != "") print k }
  ' "$TARGET/.gitignore" > "$block_entries"
  for t in claude codex copilot; do
    while IFS= read -r own; do
      [ -z "$own" ] && continue
      if grep -Fxq -- "$own" "$block_entries"; then TOOLS="$TOOLS $t"; break; fi
    done < <(jq -r --arg t "$t" '[.profiles.full.tools[$t][]] - [.profiles.full.tools | to_entries[] | select(.key != $t) | .value[]] | .[] | sub("/+$"; "")' "$MANIFEST")
  done
  rm -f "$block_entries"
  if [ -n "$TOOL" ]; then
    case " $TOOLS " in *" $TOOL "*) ;; *) TOOLS="$TOOLS $TOOL" ;; esac
  fi
  # An entry point the block does not account for is either the repo's own file
  # or a tool whose paths an older installer dropped from the block. Neither is
  # safe to guess, so name it rather than install over it or skip it silently.
  for pair in "claude:CLAUDE.md" "codex:AGENTS.md" "copilot:.github/copilot-instructions.md"; do
    t="${pair%%:*}" ep="${pair#*:}"
    case " $TOOLS " in *" $t "*) continue ;; esac
    if [ -f "$TARGET/$ep" ]; then
      echo "note: $ep exists but the installer's .gitignore block has no record of $t, so $t was not updated. If it is the repository's own file, nothing is needed; only if the installer put $t here, rerun with --tool $t, which overwrites $ep."
    fi
  done
else
  # No managed block (installed before it existed): fall back to entry points,
  # and ask for --tool when they are ambiguous.
  if [ -n "$TOOL" ]; then
    TOOLS="$TOOL"
  else
    [ -f "$TARGET/CLAUDE.md" ] && TOOLS="$TOOLS claude"
    [ -f "$TARGET/AGENTS.md" ] && TOOLS="$TOOLS codex"
    [ -f "$TARGET/.github/copilot-instructions.md" ] && TOOLS="$TOOLS copilot"
    case "$(echo $TOOLS)" in *" "*) echo "error: multiple tools installed ($(echo $TOOLS)); pass --tool to choose" >&2; exit 2 ;; esac
  fi
fi
TOOLS="$(echo $TOOLS | xargs)"
[ -n "$TOOLS" ] || { echo "error: could not detect installed tool; pass --tool" >&2; exit 2; }

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

# --- additive: re-copy the current product set (overwrites changed, adds new; seeded files are kept and only gain missing settings) ---
# Once per installed tool. Seeded files keep the target's copy; install.sh names
# each setting it appends or skips, printed once however many tools ran.
# If any run fails, ai-workflow.md is restored: the first run already copied the
# new version, and a re-run would otherwise take the "already current" path.
install_out=""
wf_backup="$(mktemp)"; cp "$TARGET/ai-workflow.md" "$wf_backup"
for TOOL in $TOOLS; do
  install_out="$install_out$("$SCRIPT_DIR/install.sh" --source "$SOURCE" --target "$TARGET" --tool "$TOOL")"$'\n' \
    || { cp "$wf_backup" "$TARGET/ai-workflow.md"; rm -f "$wf_backup"; echo "error: re-copy step failed" >&2; exit 1; }
done
rm -f "$wf_backup"
seeded_notes="$(printf '%s\n' "$install_out" | grep -E 'added new setting|did not add setting' | awk '!seen[$0]++' || true)"
if [ -n "$seeded_notes" ]; then printf '%s\n' "$seeded_notes"; else echo "Seeded files: the target already has every setting the source declares."; fi

# Drop paths from the installer-managed .gitignore block (the block is a union,
# so a path that left the product would otherwise linger forever). Nothing
# outside the managed block is touched.
prune_gitignore_block() {
  local gi="$TARGET/.gitignore" joined="$1"
  [ -f "$gi" ] || return 0
  [ -n "$joined" ] || return 0
  local begin="# >>> ai-workflow (vendored, managed by installer) >>>"
  local end="# <<< ai-workflow <<<"
  awk -v b="$begin" -v e="$end" -v paths="$joined" '
    BEGIN {
      n = split(paths, parr, "|")
      for (i = 1; i <= n; i++) { k = parr[i]; sub(/\/+$/, "", k); if (k != "") drop[k] = 1 }
    }
    $0==b { inblock=1; print; next }
    $0==e { inblock=0; print; next }
    inblock==1 {
      key = $0
      sub(/^[ \t]+/, "", key); sub(/[ \t]+$/, "", key); sub(/\/+$/, "", key)
      if (key in drop) next
    }
    { print }
  ' "$gi" > "$gi.tmp" && mv "$gi.tmp" "$gi"
}

# --- removal reconciliation ---
removed_count=0
prune_keys=""
current_product="$(mktemp)"
trap 'rm -f "$current_product"' EXIT
while IFS= read -r p; do
  [ -z "$p" ] && continue
  git -C "$SOURCE" ls-files -- "${p%/}" >> "$current_product"
  # Spans EVERY tool, not just the one being updated. A removal bullet names a
  # path, not a tool, so scoping this to $TOOL deletes from disk a file another
  # installed tool still ships (#229).
done < <(jq -r '[.profiles.full.shared[], (.profiles.full.tools[] | .[])] | unique | .[]' "$MANIFEST")

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
  prune_keys="$prune_keys$rp_stripped|"
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

# Prune the removed paths from the managed .gitignore block, but never a path
# the current product still ships. The keep set spans EVERY tool, not just the
# one being updated: a removal bullet names a path, not a tool, and several
# tools can be installed in one repo, so pruning a path another installed tool
# still ships would un-ignore that tool's vendored files (#229).
keep_file="$(mktemp)"
jq -r '[.profiles.full.shared[], (.profiles.full.tools[] | .[])] | unique | .[]' "$MANIFEST" \
  | sed 's#/*$##' > "$keep_file"
drop_keys=""
while IFS= read -r k; do
  [ -z "$k" ] && continue
  LC_ALL=C grep -Fxq -- "$k" "$keep_file" && continue
  drop_keys="$drop_keys$k|"
done <<EOF
$(printf '%s' "$prune_keys" | tr '|' '\n')
EOF
rm -f "$keep_file"
prune_gitignore_block "$drop_keys"

echo "Update complete: target now at $source_version (tools: $TOOLS); $removed_count file(s) removed."
echo "Local additions under vendored paths were left in place."
