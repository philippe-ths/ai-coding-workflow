#!/usr/bin/env bash
# Remove AI Workflow session observation from the GLOBAL Claude config (~/.claude).
#
# The inverse of install-observation.sh. Capture installs itself outside this
# repository, so deleting the repository would leave the SessionStart hook firing
# against a path that no longer exists — the failure this script exists to make
# undoable (see #204).
#
# Removes the machinery:
#   - the SessionStart Manifest hook  <- unwired from ~/.claude/settings.json
#   - the /rate skill                 <- ~/.claude/skills/rate/
#   - helper scripts                  <- ~/.claude/aiw-observation/
#
# Keeps the data by default: manifest.jsonl and ratings.jsonl are append-only
# captures that cannot be rebuilt from transcripts, and sessions.jsonl and
# dashboard.html are derived but expensive. Pass --purge-data to remove those too.
#
# Re-running is safe (idempotent). Override the target with CLAUDE_HOME (used for testing).
set -eu

PURGE_DATA=false
for arg in "$@"; do
  case "$arg" in
    --purge-data) PURGE_DATA=true ;;
    -h | --help)
      echo "Usage: $0 [--purge-data]"
      echo "  --purge-data  also delete the Session Store, Manifest, Ratings, and dashboard."
      echo "                The Manifest and Ratings cannot be rebuilt from transcripts."
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--purge-data]" >&2
      exit 2
      ;;
  esac
done

CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
OBS_DIR="$CLAUDE_DIR/aiw-observation"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"

REMOVED_ANY=false

# Helper scripts. Named individually rather than removing the directory, which
# also holds the data files.
for f in manifest-hook.sh record-rating.sh; do
  if [ -e "$OBS_DIR/$f" ]; then
    rm -f "$OBS_DIR/$f"
    REMOVED_ANY=true
  fi
done

# The /rate skill only. Other skills share this directory.
if [ -e "$SKILLS_DIR/rate" ]; then
  rm -rf "$SKILLS_DIR/rate"
  REMOVED_ANY=true
fi

if [ "$PURGE_DATA" = "true" ]; then
  for f in sessions.jsonl manifest.jsonl ratings.jsonl dashboard.html; do
    if [ -e "$OBS_DIR/$f" ]; then
      rm -f "$OBS_DIR/$f"
      REMOVED_ANY=true
    fi
  done
fi

# Leave the directory only if nothing remains in it, so surviving data is never
# removed as a side effect of tidying up.
if [ -d "$OBS_DIR" ] && [ -z "$(ls -A "$OBS_DIR")" ]; then
  rmdir "$OBS_DIR"
fi

# Unwire the SessionStart hook, preserving every other setting and every other
# hook that happens to share the entry.
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak"

  HOOK_CMD="bash $OBS_DIR/manifest-hook.sh"
  SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os

path = os.environ["SETTINGS"]
hook_cmd = os.environ["HOOK_CMD"]

try:
    with open(path) as fh:
        data = json.load(fh)
except Exception:
    # An unreadable settings file is not ours to rewrite. Leaving it untouched is
    # safer than replacing a file we could not parse.
    print("unreadable")
    raise SystemExit(0)

if not isinstance(data, dict):
    print("unreadable")
    raise SystemExit(0)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    print("absent")
    raise SystemExit(0)

session_start = hooks.get("SessionStart")
if not isinstance(session_start, list):
    print("absent")
    raise SystemExit(0)

removed = False
kept_entries = []
for entry in session_start:
    if not isinstance(entry, dict):
        kept_entries.append(entry)
        continue
    inner = entry.get("hooks")
    if not isinstance(inner, list):
        kept_entries.append(entry)
        continue
    kept_inner = [
        h for h in inner
        if not (isinstance(h, dict) and h.get("command") == hook_cmd)
    ]
    if len(kept_inner) != len(inner):
        removed = True
    if kept_inner:
        entry["hooks"] = kept_inner
        kept_entries.append(entry)
    elif not inner:
        # An entry that was already empty is not ours to drop.
        kept_entries.append(entry)

# Prune containers that only existed to hold this hook, without disturbing any
# other key the user has set.
if kept_entries:
    hooks["SessionStart"] = kept_entries
else:
    hooks.pop("SessionStart", None)
if not hooks:
    data.pop("hooks", None)

with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

print("removed" if removed else "absent")
PY
fi

echo ""
if [ "$REMOVED_ANY" = "true" ]; then
  echo "Session observation removed from: $CLAUDE_DIR"
else
  echo "Nothing to remove in: $CLAUDE_DIR"
fi

if [ "$PURGE_DATA" = "false" ] && [ -d "$OBS_DIR" ]; then
  echo ""
  echo "Kept your recorded data in $OBS_DIR:"
  ls -1 "$OBS_DIR" | sed 's/^/  /'
  echo "Re-run with --purge-data to remove it. The Manifest and Ratings cannot be"
  echo "rebuilt from transcripts once deleted."
fi
