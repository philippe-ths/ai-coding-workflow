#!/usr/bin/env bash
# Sandbox test of upkeep/install-upkeep.sh and upkeep/uninstall-upkeep.sh against a
# throwaway CLAUDE_HOME and LaunchAgents dir, with launchctl never called.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export CLAUDE_HOME="$SANDBOX/claude" LAUNCH_AGENTS_DIR="$SANDBOX/agents" AIW_UPKEEP_NO_LAUNCHCTL=1
fail() { echo "upkeep install test: FAIL: $1" >&2; exit 1; }

mkdir -p "$CLAUDE_HOME"
printf '#!/usr/bin/env bash\ninput=$(cat)\necho line\n' > "$CLAUDE_HOME/statusline.sh"
ORIGINAL="$(cat "$CLAUDE_HOME/statusline.sh")"

"$ROOT/upkeep/install-upkeep.sh" >/dev/null 2>&1 || fail "install exited non-zero"
PLIST="$LAUNCH_AGENTS_DIR/com.aiw.upkeep.plist"
[ -f "$CLAUDE_HOME/aiw-upkeep/scheduler.py" ] || fail "scheduler not copied"
plutil -lint "$PLIST" >/dev/null 2>&1 || fail "plist is not valid"
[ "$(grep -c '<key>Hour</key><integer>22</integer>' "$PLIST")" = 5 ] || fail "plist does not fire on five weekdays at 22"
grep -q -- '--scheduled' "$PLIST" || fail "plist does not run the scheduled mode"
grep -q 'quota snapshot >>>' "$CLAUDE_HOME/statusline.sh" || fail "install did not add the snapshot block"
bash -n "$CLAUDE_HOME/statusline.sh" || fail "status line no longer parses"
"$ROOT/upkeep/install-upkeep.sh" >/dev/null 2>&1 || fail "re-install exited non-zero"
[ "$(grep -c 'quota snapshot >>>' "$CLAUDE_HOME/statusline.sh")" = 1 ] || fail "re-install duplicated the snapshot block"

echo '{"at":"x"}' > "$CLAUDE_HOME/aiw-upkeep/runs.jsonl"
"$ROOT/upkeep/uninstall-upkeep.sh" >/dev/null || fail "uninstall exited non-zero"
[ ! -e "$PLIST" ] || fail "plist left behind"
[ ! -e "$CLAUDE_HOME/aiw-upkeep/scheduler.py" ] || fail "scheduler left behind"
grep -q 'aiw-upkeep' "$CLAUDE_HOME/statusline.sh" && fail "status line block left behind"
[ "$(cat "$CLAUDE_HOME/statusline.sh")" = "$ORIGINAL" ] || fail "uninstall did not restore the status line exactly"
[ -f "$CLAUDE_HOME/aiw-upkeep/runs.jsonl" ] || fail "decision log removed without --purge-data"

"$ROOT/upkeep/uninstall-upkeep.sh" --purge-data >/dev/null || fail "purge exited non-zero"
[ ! -e "$CLAUDE_HOME/aiw-upkeep" ] || fail "--purge-data left the state dir"

# A block missing its end marker is left alone rather than deleted to the end of the file.
printf 'input=$(cat)\n# >>> aiw-upkeep quota snapshot >>>\nsave\necho line\n' > "$CLAUDE_HOME/statusline.sh"
"$ROOT/upkeep/uninstall-upkeep.sh" >/dev/null 2>&1 || fail "uninstall with a broken block exited non-zero"
grep -q 'echo line' "$CLAUDE_HOME/statusline.sh" || fail "uninstall deleted past a block missing its end marker"

python3 -m unittest discover -s "$ROOT/upkeep" -p 'test_*.py' -q 2>/dev/null || fail "scheduler tests"
echo "upkeep install test: OK"
