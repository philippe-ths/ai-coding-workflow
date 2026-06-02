#!/usr/bin/env bash
# SessionStart hook for AI Workflow session observation.
#
# Records {session_id, repo, workflow_version, started_at} to the global Manifest,
# which is the only reliable source of the workflow version active during a session
# (the transcript does not record it). See docs/adr/0001 and docs/adr/0002.
#
# This hook is installed globally and fires in EVERY repo. It must NEVER block or
# fail a session: all errors are swallowed and it always exits 0.

OBS_DIR="${AIW_OBS_DIR:-$HOME/.claude/aiw-observation}"
mkdir -p "$OBS_DIR" 2>/dev/null

input="$(cat 2>/dev/null)"

# Pass the code via -c and the hook input via env so neither competes for stdin.
OBS_DIR="$OBS_DIR" AIW_HOOK_INPUT="$input" python3 -c '
import os, json, re, datetime

obs_dir = os.environ["OBS_DIR"]
try:
    data = json.loads(os.environ.get("AIW_HOOK_INPUT") or "{}")
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

session_id = data.get("session_id")
cwd = data.get("cwd") or os.getcwd()
started_at = data.get("timestamp")
if not started_at:
    started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()

repo = os.path.basename(cwd.rstrip("/")) if cwd else None

workflow_version = None
try:
    with open(os.path.join(cwd, "ai-workflow.md"), "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = re.match(r"\s*Version:\s*(\S+)", line)
            if m:
                workflow_version = m.group(1)
                break
except Exception:
    pass

if session_id:
    row = {
        "session_id": session_id,
        "repo": repo,
        "workflow_version": workflow_version,
        "started_at": started_at,
    }
    try:
        with open(os.path.join(obs_dir, "manifest.jsonl"), "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception:
        pass
' 2>/dev/null

exit 0
