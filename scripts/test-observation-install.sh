#!/usr/bin/env bash
set -eu

# Sandbox tests for the observation capture install/uninstall pair.
#
# Capture installs itself into the developer's global ~/.claude, outside this
# repository, so an uninstall that half-worked would leave a SessionStart hook
# firing against a deleted path — the failure in #204. The cases that matter are
# the destructive ones: the uninstall shares a settings file and a skills
# directory with everything else the developer has configured, and it shares a
# directory with recorded data that cannot be rebuilt.
#
# Both scripts honour CLAUDE_HOME, so nothing here touches the real ~/.claude.

ROOT_DIR="$(git rev-parse --show-toplevel)"
INSTALL="$ROOT_DIR/observation/install-observation.sh"
UNINSTALL="$ROOT_DIR/observation/uninstall-observation.sh"
PASS=0
FAIL=0

ok() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

no() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $1"
}

assert_absent() {
  if [ ! -e "$2" ]; then ok "$1"; else no "$1 ($2 still exists)"; fi
}

assert_present() {
  if [ -e "$2" ]; then ok "$1"; else no "$1 ($2 is missing)"; fi
}

assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (expected '$2', got '$3')"; fi
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

CH="$SANDBOX/claude"
export CLAUDE_HOME="$CH"

# Seed the global config with unrelated state the uninstall must not disturb:
# another skill, another SessionStart hook, another hooks event, and a top-level
# key of the developer's own.
mkdir -p "$CH/skills/some-other-skill"
echo "not ours" > "$CH/skills/some-other-skill/SKILL.md"
cat > "$CH/settings.json" <<'JSON'
{
  "model": "opusplan",
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash /somewhere/else.sh" } ] }
    ],
    "PreToolUse": [
      { "hooks": [ { "type": "command", "command": "bash /guard.sh" } ] }
    ]
  }
}
JSON

echo "Observation install/uninstall tests:"

# ── Install ──

"$INSTALL" >/dev/null 2>&1
assert_present "install writes the manifest hook" "$CH/aiw-observation/manifest-hook.sh"
assert_present "install writes the rating recorder" "$CH/aiw-observation/record-rating.sh"
assert_present "install writes the /rate skill" "$CH/skills/rate/SKILL.md"

hook_count="$(python3 -c "
import json
d = json.load(open('$CH/settings.json'))
cmds = [h.get('command','') for e in d['hooks']['SessionStart'] for h in e.get('hooks',[])]
print(sum(1 for c in cmds if 'manifest-hook.sh' in c))
")"
assert_eq "install wires exactly one SessionStart hook" "1" "$hook_count"

# Stand in for data accumulated over months of sessions.
printf '{"session":"a"}\n' > "$CH/aiw-observation/sessions.jsonl"
printf '{"session":"a","workflow_version":"3.16.0"}\n' > "$CH/aiw-observation/manifest.jsonl"
printf '{"session":"a","rating":4}\n' > "$CH/aiw-observation/ratings.jsonl"
printf '<html></html>\n' > "$CH/aiw-observation/dashboard.html"

# ── Uninstall, default ──

"$UNINSTALL" >/dev/null 2>&1

assert_absent "uninstall removes the manifest hook script" "$CH/aiw-observation/manifest-hook.sh"
assert_absent "uninstall removes the rating recorder" "$CH/aiw-observation/record-rating.sh"
assert_absent "uninstall removes the /rate skill" "$CH/skills/rate"

assert_present "an unrelated skill survives" "$CH/skills/some-other-skill/SKILL.md"
assert_present "the Session Store survives by default" "$CH/aiw-observation/sessions.jsonl"
assert_present "the Manifest survives by default" "$CH/aiw-observation/manifest.jsonl"
assert_present "the Ratings survive by default" "$CH/aiw-observation/ratings.jsonl"
assert_present "the dashboard survives by default" "$CH/aiw-observation/dashboard.html"

python3 -c "import json; json.load(open('$CH/settings.json'))" 2>/dev/null &&
  ok "settings.json is still valid JSON" ||
  no "settings.json is still valid JSON"

ours="$(python3 -c "
import json
d = json.load(open('$CH/settings.json'))
cmds = [h.get('command','') for e in d.get('hooks',{}).get('SessionStart',[]) for h in e.get('hooks',[])]
print(sum(1 for c in cmds if 'manifest-hook.sh' in c))
")"
assert_eq "the observation hook is unwired" "0" "$ours"

theirs="$(python3 -c "
import json
d = json.load(open('$CH/settings.json'))
cmds = [h.get('command','') for e in d.get('hooks',{}).get('SessionStart',[]) for h in e.get('hooks',[])]
print(sum(1 for c in cmds if 'else.sh' in c))
")"
assert_eq "an unrelated SessionStart hook survives" "1" "$theirs"

pretooluse="$(python3 -c "
import json
d = json.load(open('$CH/settings.json'))
print(len(d.get('hooks',{}).get('PreToolUse',[])))
")"
assert_eq "an unrelated hook event survives" "1" "$pretooluse"

model="$(python3 -c "
import json
print(json.load(open('$CH/settings.json')).get('model',''))
")"
assert_eq "an unrelated top-level setting survives" "opusplan" "$model"

# ── Idempotence ──

rc=0
"$UNINSTALL" >/dev/null 2>&1 || rc=$?
assert_eq "a second uninstall exits cleanly" "0" "$rc"

# ── Sharing an entry with another hook ──
# The installer appends its own entry, but a developer may hand-merge ours into an
# entry alongside another command. Removing the entry wholesale would take theirs
# with it.

"$INSTALL" >/dev/null 2>&1
python3 - "$CH/settings.json" "$CH/aiw-observation/manifest-hook.sh" <<'PY'
import json, sys
path, hook = sys.argv[1], sys.argv[2]
d = json.load(open(path))
cmd = "bash " + hook
ss = d["hooks"]["SessionStart"]
ss[:] = [e for e in ss if not any(h.get("command") == cmd for h in e.get("hooks", []))]
ss.append({"hooks": [
    {"type": "command", "command": "bash /their/own.sh"},
    {"type": "command", "command": cmd},
]})
json.dump(d, open(path, "w"), indent=2)
PY

"$UNINSTALL" >/dev/null 2>&1
shared="$(python3 -c "
import json
d = json.load(open('$CH/settings.json'))
cmds = [h.get('command','') for e in d.get('hooks',{}).get('SessionStart',[]) for h in e.get('hooks',[])]
print('%d,%d' % (
    sum(1 for c in cmds if 'manifest-hook.sh' in c),
    sum(1 for c in cmds if 'their/own.sh' in c),
))
")"
assert_eq "a co-located hook survives while ours is removed" "0,1" "$shared"

# ── Purge ──

"$INSTALL" >/dev/null 2>&1
"$UNINSTALL" --purge-data >/dev/null 2>&1
assert_absent "purge removes the Session Store" "$CH/aiw-observation/sessions.jsonl"
assert_absent "purge removes the Manifest" "$CH/aiw-observation/manifest.jsonl"
assert_absent "purge removes the Ratings" "$CH/aiw-observation/ratings.jsonl"
assert_absent "purge removes the empty store directory" "$CH/aiw-observation"

# ── Nothing installed ──

FRESH="$SANDBOX/fresh"
mkdir -p "$FRESH"
rc=0
CLAUDE_HOME="$FRESH" "$UNINSTALL" >/dev/null 2>&1 || rc=$?
assert_eq "uninstalling from a config with nothing installed exits cleanly" "0" "$rc"

# ── An unparseable settings file ──
# Rewriting a file we could not read would destroy configuration we cannot see.

BROKEN="$SANDBOX/broken"
mkdir -p "$BROKEN"
printf '{ this is not json' > "$BROKEN/settings.json"
rc=0
CLAUDE_HOME="$BROKEN" "$UNINSTALL" >/dev/null 2>&1 || rc=$?
assert_eq "an unparseable settings file does not fail the run" "0" "$rc"
assert_eq "an unparseable settings file is left untouched" \
  "{ this is not json" "$(cat "$BROKEN/settings.json")"

# ── Summary ──

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
