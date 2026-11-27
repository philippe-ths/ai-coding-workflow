#!/usr/bin/env bash
# Deploy hook for this repository, run by `scheduler.py deploy` after it fast-forwards the
# main checkout: usage `scripts/deploy.sh <last-deployed-commit or ""> <new-commit>`.
#
# The upkeep scheduler and observation capture run from copies their install scripts make
# outside the repository, so a merge reaches them only through a reinstall. Each is
# reinstalled when its directory changed, and both on a first deploy (no last commit).
#
# launchctl is never called: reloading com.aiw.upkeep-deploy would kill this very run, and
# reloading com.aiw.upkeep would kill a nightly run in progress. A changed plist is written
# to disk and launchd loads it at the next login. CLAUDE_HOME and LAUNCH_AGENTS_DIR pass
# through to the install scripts, for testing.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAST="${1:-}"
NEW="${2:?usage: deploy.sh <last-commit> <new-commit>}"

changed() {
  [ -z "$LAST" ] && return 0
  ! git -C "$ROOT" diff --quiet "$LAST" "$NEW" -- "$1"
}

if changed upkeep/; then
  AIW_UPKEEP_NO_LAUNCHCTL=1 "$ROOT/upkeep/install-upkeep.sh" >/dev/null
  echo "reinstalled upkeep"
fi
if changed observation/; then
  "$ROOT/observation/install-observation.sh" >/dev/null
  echo "reinstalled observation"
fi
