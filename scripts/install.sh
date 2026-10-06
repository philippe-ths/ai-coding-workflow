#!/usr/bin/env bash
# Install the AI coding workflow into a target repository.
#
#   scripts/install.sh --target <dir> --tool <claude|codex|copilot> [--source <dir>]
#
# Copies the product file set for the chosen tool into the target
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
Usage: install.sh --target <dir> --tool <name> [--source <dir>]

  --target <dir>    Repository to install into (must be a git work tree). Required.
  --tool <name>     One of: claude, codex, copilot. Required.
  --source <dir>    Workflow source repo. Defaults to the repo containing this script.
USAGE
}

SOURCE=""
TARGET=""
TOOL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
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
  claude|codex|copilot) ;;
  *) echo "error: --tool must be one of claude, codex, copilot" >&2; exit 2 ;;
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

# Files the manifest declares "seeded": shipped once with defaults, then owned by
# the target. An existing target copy is kept; only settings it lacks are added.
seeded_paths="$(jq -r '.seeded[]?' "$MANIFEST")"
is_seeded() { [ -n "$seeded_paths" ] && printf '%s\n' "$seeded_paths" | grep -Fxq -- "$1"; }

# Name of the setting a SOURCE line declares, or nothing. Accepts leading
# whitespace, an optional export/readonly/declare prefix, KEY=..., and the
# conditional form : "${KEY:=...}" quoted or not; a comment declares nothing.
setting_key() {
  local re_a='^[[:space:]]*((export|readonly|declare)[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)='
  local re_b='^[[:space:]]*:[[:space:]]+"?\$\{([A-Za-z_][A-Za-z0-9_]*):?='
  if [[ "$1" =~ $re_a ]]; then printf '%s' "${BASH_REMATCH[3]}"
  elif [[ "$1" =~ $re_b ]]; then printf '%s' "${BASH_REMATCH[1]}"
  fi
}

# Add to the target copy every setting the source declares and the target lacks,
# with its default and the comment block directly above it. Nothing else is
# touched; when nothing is missing the target is not rewritten at all.
#
# Presence in the TARGET is judged permissively: any non-comment line holding the
# key name as a whole word followed by = or := counts (indented, prefixed,
# mid-line after ';', or inside ${KEY:=}). The costs are asymmetric: a false
# "absent" appends a default that overrides the human's value when the file is
# sourced; a false "present" withholds a new key, which can break a script that
# reads it without a fallback. So a key judged present only from a line that
# does not plainly set it (a trailing comment, a value, a second assignment) is
# not added but is named, so the operator can check it is really set.
#
# Known limitation: a setting the target deliberately deleted is
# indistinguishable from a new upstream one without a recorded base, so it comes
# back with its default. The printed "added new setting" line tells the operator.
merge_seeded() {
  local rel="$1" src="$SOURCE/$1" dst="$TARGET/$1" live plain line key block="" add="" n=0
  live="$(grep -v '^[[:space:]]*#' "$dst" || true)"
  plain="$(printf '%s\n' "$live" | while IFS= read -r line; do setting_key "$line"; echo; done)"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "#"*) block="$block$line"$'\n'; continue ;;
    esac
    key="$(setting_key "$line")"
    if [ -n "$key" ] && ! printf '%s\n' "$live" | grep -Eq "(^|[^A-Za-z0-9_])$key:?="; then
      add="$add"$'\n'"$block$line"$'\n'
      live="$live"$'\n'"$line"
      n=$((n + 1))
      echo "  $rel: added new setting $key (default from source)"
    elif [ -n "$key" ] && ! printf '%s\n' "$plain" | grep -Fxq -- "$key"; then
      echo "  $rel: did not add setting $key; it appears only on a line that does not plainly set it, so check the target sets it"
    fi
    block=""
  done < "$src"
  [ "$n" -gt 0 ] || return 0
  [ -z "$(tail -c1 "$dst")" ] || printf '\n' >> "$dst"
  printf '%s' "$add" >> "$dst"
}

# Copy every git-tracked file under a product path, preserving structure.
copy_tracked() {
  local pathspec="${1%/}" f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    mkdir -p "$TARGET/$(dirname "$f")"
    if is_seeded "$f" && [ -e "$TARGET/$f" ]; then
      merge_seeded "$f"
    else
      cp "$SOURCE/$f" "$TARGET/$f"
    fi
  done < <(git -C "$SOURCE" ls-files -- "$pathspec")
}

# Rewrite the installer-managed block in the target .gitignore (idempotent).
# The block is a UNION across installs: entries already in it are kept in order
# and this run's paths are appended if absent, so installing a second tool does
# not un-ignore the first tool's paths (#216).
#
# A target's .gitignore is arbitrary bytes written by humans and other tools, so
# this function assumes nothing about its content (#229):
#   * the whole new file is built in one awk pass into $gi.tmp and moved into
#     place only on success, so a failure cannot leave the file truncated;
#   * text processing runs under LC_ALL=C, because a line that is not valid
#     UTF-8 makes BSD awk/grep/sed fail with "illegal byte sequence" under a
#     UTF-8 locale;
#   * this run's paths reach awk through a file, never a delimited string, so a
#     literal delimiter in a path or an existing line cannot mis-split;
#   * entries are compared AND re-emitted normalised, so an indented "  .claude/"
#     cannot shadow the real ".claude/" while git ignores nothing.
write_gitignore_block() {
  local gi="$TARGET/.gitignore"
  local begin="# >>> ai-workflow (vendored, managed by installer) >>>"
  local end="# <<< ai-workflow <<<"
  touch "$gi"

  local paths_file p
  paths_file="$(mktemp)" || { echo "error: could not create a temp file" >&2; return 1; }
  for p in "$@"; do
    [ -n "$p" ] && printf '%s\n' "$p"
  done > "$paths_file"

  # Existing block entries are kept in order and deduplicated by normalised key;
  # this run's unseen paths are appended verbatim, exactly as the manifest gives
  # them. Pre-existing unmarked lines matching a vendored path are folded into
  # the block on a FIRST install only (#166); once a managed block exists such a
  # line is hand-maintained and is left alone (#216). Exactly one marker pair is
  # emitted however many the input held.
  if LC_ALL=C LANG=C awk -v b="$begin" -v e="$end" -v pf="$paths_file" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function norm(s) { s = trim(s); sub(/\/+$/, "", s); return s }
    FILENAME == pf { raw[++np] = $0; runkey[norm($0)] = 1; next }
    { lines[++nl] = $0; if ($0 == b) hadblock = 1 }
    END {
      fold = (hadblock ? 0 : 1)
      skip = 0
      for (i = 1; i <= nl; i++) {
        line = lines[i]
        if (line == b) skip = 1
        if (skip == 0) {
          k = norm(line)
          if (!(fold && k != "" && (k in runkey))) out[++no] = line
        } else if (line != b && line != e) {
          k = norm(line)
          if (k != "" && !(k in seen)) { seen[k] = 1; keep[++nk] = trim(line) }
        }
        if (line == e) skip = 0
      }
      for (i = 1; i <= no; i++) print out[i]
      print b
      for (i = 1; i <= nk; i++) print keep[i]
      for (i = 1; i <= np; i++) {
        k = norm(raw[i])
        if (k == "" || (k in seen)) continue
        seen[k] = 1
        print raw[i]
      }
      print e
    }
  ' "$paths_file" "$gi" > "$gi.tmp"; then
    rm -f "$paths_file"
    mv "$gi.tmp" "$gi"
  else
    rm -f "$paths_file" "$gi.tmp"
    echo "error: could not rewrite $gi; it was left unchanged" >&2
    return 1
  fi
}
product_paths=()
while IFS= read -r p; do [ -n "$p" ] && product_paths+=("$p"); done < <(
  jq -r --arg t "$TOOL" '[.profiles.full.shared[], .profiles.full.tools[$t][]] | .[]' "$MANIFEST"
)
for p in "${product_paths[@]}"; do
  copy_tracked "$p"
done
ignore_paths=("${product_paths[@]}")

# Install git hooks in the target.
( cd "$TARGET" \
    && git config core.hooksPath .githooks \
    && chmod +x .githooks/* 2>/dev/null \
    && chmod +x .ai-policy/scripts/*.sh 2>/dev/null ) || true

write_gitignore_block "${ignore_paths[@]}"

echo "Installed AI workflow (tool: $TOOL) into $TARGET"
echo "Vendored files recorded in $TARGET/.gitignore"
echo "Git hooks installed (core.hooksPath = .githooks)"
echo "Next: author project-context.md in the target via the aiw-project-context-management skill."
echo "Then: invoke the aiw-init skill in the target to scaffold its project-checks.md."
