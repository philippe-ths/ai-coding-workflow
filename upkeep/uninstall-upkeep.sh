#!/usr/bin/env bash
# Reverse install-upkeep.sh: unload and remove both launchd agents, remove the
# scheduler copy and the status line's quota snapshot block. The decision and deploy
# logs (runs.jsonl, deploys.jsonl) and the human's lists (excluded-projects,
# deploy-projects) are kept unless --purge-data is passed.
#
# Overrides, for testing: CLAUDE_HOME, LAUNCH_AGENTS_DIR, AIW_UPKEEP_NO_LAUNCHCTL=1.
set -eu
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
STATE="$CLAUDE_DIR/aiw-upkeep"
AGENTS="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LABEL="com.aiw.upkeep"
PLIST="$AGENTS/$LABEL.plist"
DEPLOY_LABEL="com.aiw.upkeep-deploy"
DEPLOY_PLIST="$AGENTS/$DEPLOY_LABEL.plist"

if [ "${AIW_UPKEEP_NO_LAUNCHCTL:-}" != 1 ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootout "gui/$(id -u)/$DEPLOY_LABEL" 2>/dev/null || true
fi
rm -f "$PLIST" "$DEPLOY_PLIST" "$STATE/scheduler.py" "$STATE/launchd.log" "$STATE/quota.json" "$STATE/run.lock" \
  "$STATE/deploy-launchd.log" "$STATE/deploy-state.json" "$STATE/deploy-state.tmp" "$STATE/deploy.lock"

STATUSLINE="$CLAUDE_DIR/statusline.sh"
# Only with both markers present: one missing would delete to the end of the file.
if [ -f "$STATUSLINE" ] && grep -q '# >>> aiw-upkeep quota snapshot >>>' "$STATUSLINE" \
   && grep -q '# <<< aiw-upkeep quota snapshot <<<' "$STATUSLINE"; then
  sed -i.bak '/# >>> aiw-upkeep quota snapshot >>>/,/# <<< aiw-upkeep quota snapshot <<</d' "$STATUSLINE"
  rm -f "$STATUSLINE.bak"
fi

if [ "${1:-}" = "--purge-data" ]; then
  rm -rf "$STATE"
else
  rmdir "$STATE" 2>/dev/null || true
fi
if [ -f "$STATUSLINE" ] && grep -q 'aiw-upkeep quota snapshot' "$STATUSLINE"; then
  echo "warning: $STATUSLINE still holds part of the quota snapshot block; remove it by hand" >&2
fi
echo "uninstalled: launchd agents, scheduler, status line block"
[ "${1:-}" = "--purge-data" ] && echo "removed the decision log"
exit 0
