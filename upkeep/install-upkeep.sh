#!/usr/bin/env bash
# Install the upkeep timer: weekdays at 22:00, run upkeep in one project; and every
# 15 minutes, deploy what was merged in the projects listed in deploy-projects.
#
# Machine-level, like observation capture. This installs:
#   - the scheduler          -> ~/.claude/aiw-upkeep/scheduler.py
#   - a launchd agent        -> ~/Library/LaunchAgents/com.aiw.upkeep.plist
#   - a launchd agent        -> ~/Library/LaunchAgents/com.aiw.upkeep-deploy.plist
#   - the deploy list, only if absent -> ~/.claude/aiw-upkeep/deploy-projects
# and checks that the status line saves the quota snapshot the scheduler reads.
# upkeep/uninstall-upkeep.sh reverses it.
#
# Re-running is safe. Overrides, for testing: CLAUDE_HOME, LAUNCH_AGENTS_DIR, and
# AIW_UPKEEP_NO_LAUNCHCTL=1 to write the plist without loading it.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
STATE="$CLAUDE_DIR/aiw-upkeep"
AGENTS="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LABEL="com.aiw.upkeep"
PLIST="$AGENTS/$LABEL.plist"
DEPLOY_LABEL="com.aiw.upkeep-deploy"
DEPLOY_PLIST="$AGENTS/$DEPLOY_LABEL.plist"

# launchd starts jobs with a bare PATH; carry the one that finds these tools now.
for tool in claude gh git python3; do
  command -v "$tool" >/dev/null || { echo "error: $tool not on PATH" >&2; exit 1; }
done

mkdir -p "$STATE" "$AGENTS"
cp "$HERE/scheduler.py" "$STATE/scheduler.py"
[ -e "$STATE/deploy-projects" ] || cat > "$STATE/deploy-projects" <<'LIST'
# Main checkouts that deploy on merge, one absolute path per line: the human's own tools,
# never a client project. Each is fast-forwarded to its default branch every 15 minutes,
# then its scripts/deploy.sh runs if it has one. See scheduler.py deploy.
LIST

{
  cat <<HEAD
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v python3)</string>
    <string>$STATE/scheduler.py</string>
    <string>run</string>
    <string>--scheduled</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$PATH</string></dict>
  <key>StartCalendarInterval</key>
  <array>
HEAD
  for day in 1 2 3 4 5; do
    echo "    <dict><key>Weekday</key><integer>$day</integer><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>"
  done
  cat <<TAIL
  </array>
  <key>StandardOutPath</key><string>$STATE/launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE/launchd.log</string>
</dict>
</plist>
TAIL
} > "$PLIST"

cat > "$DEPLOY_PLIST" <<DEPLOY
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$DEPLOY_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(command -v python3)</string>
    <string>$STATE/scheduler.py</string>
    <string>deploy</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$PATH</string></dict>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$STATE/deploy-launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE/deploy-launchd.log</string>
</dict>
</plist>
DEPLOY

if [ "${AIW_UPKEEP_NO_LAUNCHCTL:-}" != 1 ]; then
  for job in "$LABEL:$PLIST" "$DEPLOY_LABEL:$DEPLOY_PLIST"; do
    launchctl bootout "gui/$(id -u)/${job%%:*}" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "${job#*:}"
  done
fi

# The quota snapshot is saved by the status line, the only place Claude Code exposes it.
# Insert the block after the line that reads stdin into $input, or refresh it in place.
STATUSLINE="$CLAUDE_DIR/statusline.sh"
if ! STATUSLINE="$STATUSLINE" BLOCK="$HERE/quota-snapshot.sh" python3 - <<'PY'
import os, sys
path, block = os.environ["STATUSLINE"], open(os.environ["BLOCK"]).read()
start, end = "# >>> aiw-upkeep quota snapshot >>>", "# <<< aiw-upkeep quota snapshot <<<"
try:
    s = open(path).read()
except OSError:
    sys.exit(1)
if start in s and end in s:
    s = s[:s.index(start)] + block + s[s.index(end) + len(end) + 1:]
elif start in s or end in s:
    sys.exit(1)
elif "input=$(cat)\n" in s:
    s = s.replace("input=$(cat)\n", "input=$(cat)\n" + block, 1)
else:
    sys.exit(1)
open(path, "w").write(s)
PY
then
  echo "warning: could not add the quota snapshot to $STATUSLINE (no status line script reading stdin into \$input); every scheduled run will stop at the quota gate until it saves one" >&2
fi
echo "installed: $PLIST (weekdays 22:00), $DEPLOY_PLIST (every 15 min), scheduler at $STATE/scheduler.py"
