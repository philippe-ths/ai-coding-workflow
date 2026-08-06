#!/usr/bin/env bash
# Install the AI coding workflow into a target repository.
#
#   scripts/install.sh --target <dir> --tool <claude|codex|gemini|copilot> [--profile full|lite] [--source <dir>]
#
# Copies the product file set for the chosen tool and profile into the target
# repo, records the vendored files in the target's .gitignore (the governance
# files are a local vendored copy, not committed into the target's history),
# and installs the git hooks. The product/factory boundary comes from
# install-manifest.json; only git-tracked files are copied, so source-side
# runtime state (.ai-policy/state/, .claude/*.lock) never ships.
#
# project-context.md is NOT created here: it is authored in the target by the
# aiw-project-context-management skill, since it must describe the target repo.
# project-checks.md is NOT created here either, for the same reason: the aiw-init
# skill scaffolds it from the target's own services, logs, and configuration.
#
# Update of an already-installed copy is a separate path (see --update, added
# in a later phase); this script performs a fresh install.
set -eu

usage() {
  cat <<'USAGE'
Usage: install.sh --target <dir> --tool <name> [--profile full|lite] [--source <dir>]

  --target <dir>    Repository to install into (must be a git work tree). Required.
  --tool <name>     One of: claude, codex, gemini, copilot. Required.
  --profile <name>  full (default) or lite.
  --source <dir>    Workflow source repo. Defaults to the repo containing this script.
USAGE
}

SOURCE=""
TARGET=""
TOOL=""
PROFILE="full"

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  SOURCE="$(cd "$script_dir/.." && pwd)"
fi

[ -n "$TARGET" ] || { echo "error: --target is required" >&2; usage >&2; exit 2; }
case "$TOOL" in
  claude|codex|gemini|copilot) ;;
  *) echo "error: --tool must be one of claude, codex, gemini, copilot" >&2; exit 2 ;;
esac
case "$PROFILE" in
  full|lite) ;;
  *) echo "error: --profile must be full or lite" >&2; exit 2 ;;
esac

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

MANIFEST="$SOURCE/install-manifest.json"
[ -f "$MANIFEST" ] || { echo "error: manifest not found at $MANIFEST" >&2; exit 1; }

git -C "$SOURCE" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "error: source is not a git work tree: $SOURCE" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "error: target directory does not exist: $TARGET" >&2; exit 1; }
git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "error: target is not a git repo (run 'git init' there first): $TARGET" >&2; exit 1; }

SOURCE="$(cd "$SOURCE" && git rev-parse --show-toplevel)"
TARGET="$(cd "$TARGET" && git rev-parse --show-toplevel)"

# Copy every git-tracked file under a product path, preserving structure.
copy_tracked() {
  local pathspec="${1%/}" f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    mkdir -p "$TARGET/$(dirname "$f")"
    cp "$SOURCE/$f" "$TARGET/$f"
  done < <(git -C "$SOURCE" ls-files -- "$pathspec")
}

# Rewrite the installer-managed block in the target .gitignore (idempotent).
write_gitignore_block() {
  local gi="$TARGET/.gitignore"
  local begin="# >>> ai-workflow (vendored, managed by installer) >>>"
  local end="# <<< ai-workflow <<<"
  touch "$gi"
  # Drop our previous managed block, and also any pre-existing unmarked lines
  # that exactly match a vendored path (ignoring trailing slashes). The latter
  # folds entries from an earlier manual install into the managed block instead
  # of leaving the same path listed twice.
  local joined; joined="$(printf '%s|' "$@")"
  awk -v b="$begin" -v e="$end" -v paths="$joined" '
    BEGIN {
      n = split(paths, parr, "|")
      for (i = 1; i <= n; i++) { k = parr[i]; sub(/\/+$/, "", k); if (k != "") drop[k] = 1 }
    }
    $0==b {skip=1}
    skip==0 {
      key = $0
      sub(/^[ \t]+/, "", key); sub(/[ \t]+$/, "", key); sub(/\/+$/, "", key)
      if (!(key in drop)) print
    }
    $0==e {skip=0}
  ' "$gi" > "$gi.tmp" && mv "$gi.tmp" "$gi"
  if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi" 2>/dev/null)" ]; then
    printf '\n' >> "$gi"
  fi
  {
    printf '%s\n' "$begin"
    local p
    for p in "$@"; do printf '%s\n' "$p"; done
    printf '%s\n' "$end"
  } >> "$gi"
}

ignore_paths=()

if [ "$PROFILE" = "full" ]; then
  product_paths=()
  while IFS= read -r p; do [ -n "$p" ] && product_paths+=("$p"); done < <(
    jq -r --arg t "$TOOL" '[.profiles.full.shared[], .profiles.full.tools[$t][]] | .[]' "$MANIFEST"
  )
  for p in "${product_paths[@]}"; do
    copy_tracked "$p"
  done
  ignore_paths=("${product_paths[@]}")

  # Install git hooks in the target (policy layer ships only with the full profile).
  ( cd "$TARGET" \
      && git config core.hooksPath .githooks \
      && chmod +x .githooks/* 2>/dev/null \
      && chmod +x .ai-policy/scripts/*.sh 2>/dev/null ) || true
else
  # lite: a single self-contained file plus a generated entry pointer.
  mkdir -p "$TARGET"
  cp "$SOURCE/lite-monolithic/ai-workflow.md" "$TARGET/ai-workflow.md"
  entry="$(jq -r --arg t "$TOOL" '.profiles.lite.entry_filenames[$t]' "$MANIFEST")"
  mkdir -p "$TARGET/$(dirname "$entry")"
  cat > "$TARGET/$entry" <<'ENTRY'
# AI Coding Workflow (lite)

Read `ai-workflow.md` at the repository root and follow the workflow it defines
for every task. The human reviews and approves at the checkpoints it describes.
ENTRY
  ignore_paths=("ai-workflow.md" "$entry")
fi

write_gitignore_block "${ignore_paths[@]}"

echo "Installed AI workflow (profile: $PROFILE, tool: $TOOL) into $TARGET"
echo "Vendored files recorded in $TARGET/.gitignore"
if [ "$PROFILE" = "full" ]; then
  echo "Git hooks installed (core.hooksPath = .githooks)"
fi
echo "Next: author project-context.md in the target via the aiw-project-context-management skill."
echo "Then: invoke the aiw-init skill in the target to scaffold its project-checks.md."
