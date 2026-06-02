#!/usr/bin/env bash
# Append a 1-4 session Rating to the global ratings store. Invoked by the /rate skill.
#
# The rating is matched to its session by repo + timestamp at collection time
# (see observation/collect.py). Records nothing but the rating: no prompt or code content.

N="$1"
case "$N" in
  1|2|3|4) ;;
  *) echo "Usage: record-rating.sh <1-4>"; exit 0 ;;
esac

OBS_DIR="${AIW_OBS_DIR:-$HOME/.claude/aiw-observation}"
mkdir -p "$OBS_DIR" 2>/dev/null

REPO="$(basename "$PWD")"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPO_JSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$REPO" 2>/dev/null || printf '"%s"' "$REPO")"

printf '{"repo":%s,"timestamp":"%s","rating":%s}\n' "$REPO_JSON" "$TS" "$N" >> "$OBS_DIR/ratings.jsonl"
echo "Recorded rating $N for '$REPO' at $TS"
