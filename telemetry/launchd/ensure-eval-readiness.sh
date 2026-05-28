#!/bin/bash
# Runs scripts/eval-preflight.sh on the AIW eval-readiness launchd schedule
# (hourly). On a green->red transition, fires a macOS notification naming the
# failing condition. Persistent-red and Docker-down ticks are silent.
#
# State file: telemetry/launchd/eval-readiness.state
#   Single line containing "pass" or "fail". Inconclusive ticks (Loki
#   unreachable, Docker down) do not update the file, so the last
#   definitive answer survives transient outages.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

STATE_FILE="telemetry/launchd/eval-readiness.state"
PREFLIGHT="scripts/eval-preflight.sh"
LOG_PREFIX="$(date -u +%FT%TZ) eval-readiness"

# Skip silently when Docker is not running. Same convention as
# telemetry/launchd/ensure-stack-up.sh.
if ! docker info >/dev/null 2>&1; then
    echo "$LOG_PREFIX: docker daemon not reachable, skipping" >&2
    exit 0
fi

if [ ! -x "$PREFLIGHT" ]; then
    echo "$LOG_PREFIX: $PREFLIGHT not found or not executable" >&2
    exit 0
fi

set +e
"$PREFLIGHT" >/dev/null
rc=$?
set -e

case "$rc" in
    0) current="pass" ;;
    1) current="fail" ;;
    2)
        echo "$LOG_PREFIX: preflight inconclusive (Loki unreachable), not updating state" >&2
        exit 0
        ;;
    3)
        echo "$LOG_PREFIX: preflight misconfigured (exit 3), not updating state" >&2
        exit 0
        ;;
    *)
        echo "$LOG_PREFIX: preflight returned unexpected exit $rc, not updating state" >&2
        exit 0
        ;;
esac

previous=""
if [ -f "$STATE_FILE" ]; then
    previous="$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')"
fi

if [ "$previous" != "$current" ]; then
    printf '%s\n' "$current" > "$STATE_FILE"
fi

echo "$LOG_PREFIX: preflight=$current (previous=${previous:-<none>})"

# Notify on both transitions. First-run (no previous) and steady-state ticks
# are silent.
if [ "$previous" = "pass" ] && [ "$current" = "fail" ]; then
    detail=""
    if [ -f telemetry/eval-readiness.json ] && command -v jq >/dev/null 2>&1; then
        detail="$(jq -r '
            [.conditions | to_entries[] | select(.value.status == "fail") | .key]
            | join(", ")
        ' telemetry/eval-readiness.json 2>/dev/null || true)"
    fi
    msg="Eval readiness went red"
    if [ -n "$detail" ]; then
        msg="$msg: $detail"
    fi
    osascript -e "display notification \"$msg\" with title \"AIW Eval Readiness\"" 2>/dev/null || \
        echo "$LOG_PREFIX: osascript notification failed (non-fatal)" >&2
    echo "$LOG_PREFIX: notified (green->red transition)"
elif [ "$previous" = "fail" ] && [ "$current" = "pass" ]; then
    msg="Eval readiness gate is GREEN. Periodic review is unblocked."
    osascript -e "display notification \"$msg\" with title \"AIW Eval Readiness\"" 2>/dev/null || \
        echo "$LOG_PREFIX: osascript notification failed (non-fatal)" >&2
    echo "$LOG_PREFIX: notified (red->green transition)"
fi
