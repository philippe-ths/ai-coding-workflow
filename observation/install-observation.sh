#!/usr/bin/env bash
# Install AI Workflow session observation into the GLOBAL Claude config (~/.claude).
#
# Observation is per-developer and cross-repo, so capture is installed once, globally,
# not copied into each repo (see docs/adr/0002). This installs:
#   - the SessionStart Manifest hook  -> wired into ~/.claude/settings.json
#   - the /rate skill                 -> ~/.claude/skills/rate/
#   - helper scripts + store dir      -> ~/.claude/aiw-observation/
#
# Re-running is safe (idempotent). Override the target with CLAUDE_HOME (used for testing).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
OBS_DIR="$CLAUDE_DIR/aiw-observation"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$OBS_DIR" "$SKILLS_DIR"

# Helper scripts live in the global store dir so the hook path is stable regardless
# of where this repo lives or whether it moves.
cp "$HERE/capture/manifest-hook.sh" "$OBS_DIR/manifest-hook.sh"
cp "$HERE/capture/record-rating.sh" "$OBS_DIR/record-rating.sh"
chmod +x "$OBS_DIR/manifest-hook.sh" "$OBS_DIR/record-rating.sh"

# The /rate skill.
rm -rf "$SKILLS_DIR/rate"
cp -R "$HERE/capture/rate" "$SKILLS_DIR/rate"

# Wire the SessionStart hook into settings.json without clobbering existing config.
HOOK_CMD="bash $OBS_DIR/manifest-hook.sh"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"

SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os

path = os.environ["SETTINGS"]
hook_cmd = os.environ["HOOK_CMD"]

data = {}
if os.path.exists(path):
    try:
        with open(path) as fh:
            data = json.load(fh)
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

already = any(
    isinstance(entry, dict)
    and any(isinstance(h, dict) and h.get("command") == hook_cmd for h in entry.get("hooks", []))
    for entry in session_start
)
if not already:
    session_start.append({"hooks": [{"type": "command", "command": hook_cmd}]})

with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print("ok" if not already else "already-present")
PY

echo ""
echo "Session observation installed into: $CLAUDE_DIR"
echo "  hook:   $OBS_DIR/manifest-hook.sh  (wired into settings.json SessionStart)"
echo "  /rate:  $SKILLS_DIR/rate/"
echo "  store:  $OBS_DIR/"
echo ""
echo "Next: start a new Claude Code session (the hook records it), optionally /rate 1-4,"
echo "then run 'make observe' in this repo to build the dashboard."
