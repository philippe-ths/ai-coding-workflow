#!/usr/bin/env bash
# Manifest integrity check for install-manifest.json.
#
# Validates the product/factory boundary against the repository's git-tracked
# files. The boundary is the source of truth for what the installer copies into
# a target repo (product) and what it must never copy (factory). This check
# guarantees the boundary stays honest as the repo changes:
#
#   1. Existence  — every path listed in the manifest exists on disk.
#   2. Non-overlap — no path is claimed by more than one category.
#   3. Coverage   — every git-tracked file is classified by exactly one category
#                   (zero = unclassified new file; >1 = ambiguous/overlapping).
#
# Universe is git-tracked files only; untracked artifacts (.envrc, .DS_Store,
# .ai-policy/state/) are out of scope by design, since the boundary governs what ships.
#
# Categories: product (union of every profile's shared + per-tool paths),
# authored_in_target, and factory_only. lite entry_filenames are target
# filenames the installer generates, not source paths, so they are not checked.
set -eu

ROOT_DIR="$(git rev-parse --show-toplevel)"
MANIFEST="$ROOT_DIR/install-manifest.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "manifest integrity: SKIPPED (jq not available)" >&2
  exit 0
fi

if [ ! -f "$MANIFEST" ]; then
  echo "manifest integrity: FAIL — $MANIFEST not found" >&2
  exit 1
fi

# --- read the three category lists from the manifest ---
product_paths=()
while IFS= read -r p; do [ -n "$p" ] && product_paths+=("$p"); done < <(
  jq -r '[.profiles[].shared[]?, .profiles[].tools[]?[]?] | unique[]' "$MANIFEST"
)
authored_paths=()
while IFS= read -r p; do [ -n "$p" ] && authored_paths+=("$p"); done < <(
  jq -r '.authored_in_target[]?' "$MANIFEST"
)
factory_paths=()
while IFS= read -r p; do [ -n "$p" ] && factory_paths+=("$p"); done < <(
  jq -r '.factory_only[]?' "$MANIFEST"
)

errors=0

# matches PATH_ENTRY against tracked file F.
# Directory entries end with '/' and match by prefix; file entries match exactly.
path_matches() {
  local entry="$1" file="$2"
  case "$entry" in
    */) [ "${file#"$entry"}" != "$file" ] ;;   # file starts with dir prefix
    *)  [ "$file" = "$entry" ] ;;
  esac
}

# --- 1. existence ---
for entry in "${product_paths[@]}" "${authored_paths[@]}" "${factory_paths[@]}"; do
  stripped="${entry%/}"
  if [ ! -e "$ROOT_DIR/$stripped" ]; then
    echo "manifest integrity: FAIL — listed path does not exist: $entry" >&2
    errors=$((errors + 1))
  fi
done

# --- 2. non-overlap: no entry appears in more than one category ---
# Build a combined "path<TAB>category" list and look for any path in 2+ categories.
combined="$(
  { for p in "${product_paths[@]:-}";  do [ -n "$p" ] && printf '%s\tproduct\n'  "${p%/}"; done
    for p in "${authored_paths[@]:-}"; do [ -n "$p" ] && printf '%s\tauthored\n' "${p%/}"; done
    for p in "${factory_paths[@]:-}";  do [ -n "$p" ] && printf '%s\tfactory\n'  "${p%/}"; done
  } | sort
)"
dupes="$(printf '%s\n' "$combined" | cut -f1 | sort | uniq -d)"
if [ -n "$dupes" ]; then
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    cats="$(printf '%s\n' "$combined" | awk -F'\t' -v p="$d" '$1==p {print $2}' | paste -sd, -)"
    echo "manifest integrity: FAIL — path claimed by multiple categories ($cats): $d" >&2
    errors=$((errors + 1))
  done <<EOF
$dupes
EOF
fi

# --- 3. coverage: every tracked file classified by exactly one category ---
while IFS= read -r f; do
  [ -z "$f" ] && continue
  count=0
  for entry in "${product_paths[@]}" "${authored_paths[@]}" "${factory_paths[@]}"; do
    if path_matches "$entry" "$f"; then
      count=$((count + 1))
    fi
  done
  if [ "$count" -eq 0 ]; then
    echo "manifest integrity: FAIL — tracked file is unclassified: $f" >&2
    errors=$((errors + 1))
  elif [ "$count" -gt 1 ]; then
    echo "manifest integrity: FAIL — tracked file matched by $count categories: $f" >&2
    errors=$((errors + 1))
  fi
done < <(git -C "$ROOT_DIR" ls-files)

if [ "$errors" -gt 0 ]; then
  echo "manifest integrity: FAIL ($errors problem(s))" >&2
  exit 1
fi

echo "manifest integrity: OK"
