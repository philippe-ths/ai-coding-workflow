#!/bin/bash
# Installs the AIW telemetry stack launchd autostart.
# Idempotent: safe to re-run after moving the repo or updating the plist template.
#
# Effect: ~/Library/LaunchAgents/com.aiw.telemetry.plist is created/refreshed
# and loaded. On every login (and every 5 minutes), launchd runs
# ensure-stack-up.sh which calls `docker compose up -d` in telemetry/.
#
# To uninstall: launchctl unload ~/Library/LaunchAgents/com.aiw.telemetry.plist
#               rm    ~/Library/LaunchAgents/com.aiw.telemetry.plist

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/telemetry/launchd/com.aiw.telemetry.plist.template"
WRAPPER="$REPO_ROOT/telemetry/launchd/ensure-stack-up.sh"
TARGET="$HOME/Library/LaunchAgents/com.aiw.telemetry.plist"
LABEL="com.aiw.telemetry"

if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: template not found at $TEMPLATE" >&2
    exit 1
fi
if [ ! -f "$WRAPPER" ]; then
    echo "ERROR: wrapper not found at $WRAPPER" >&2
    exit 1
fi

chmod +x "$WRAPPER"

mkdir -p "$HOME/Library/LaunchAgents"

# Unload any previously installed agent. Tolerate absence.
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    echo "Unloading existing $LABEL"
    launchctl unload "$TARGET" 2>/dev/null || true
fi

sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$TEMPLATE" > "$TARGET"
echo "Wrote $TARGET"

launchctl load "$TARGET"
echo "Loaded $LABEL"

# Kick off the first run immediately rather than waiting for the 5-minute tick.
launchctl start "$LABEL" 2>/dev/null || true

echo
echo "Verify:"
echo "  launchctl list | grep $LABEL"
echo "  docker ps --filter 'name=aiw-'"
echo "  tail -f $REPO_ROOT/telemetry/launchd/stdout.log"
