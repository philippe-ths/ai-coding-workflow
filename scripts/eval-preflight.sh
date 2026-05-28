#!/usr/bin/env bash
# Between-review readiness check for the periodic evaluation process defined
# in design/decisions/evaluation.md. Runs the minimum-data gate and the
# emission-integrity checks deterministically.
#
# Outputs:
#   telemetry/eval-readiness.json  - machine-readable status
#   telemetry/eval-readiness.md    - human-readable summary
#
# Exit codes:
#   0 - gate would pass; periodic review safe to run
#   1 - gate would fail; specific conditions listed in eval-readiness.{json,md}
#   2 - cannot determine state (Loki unreachable / Docker down)
#   3 - misconfiguration (not run inside the ai-coding-workflow repo)
#
# Loki query window is 30 days (Loki's max query-range).

set -euo pipefail

LOKI_URL="${AIW_LOKI_URL:-http://localhost:3100}"
QUERY_WINDOW="${AIW_EVAL_WINDOW:-30d}"
SESSION_THRESHOLD="${AIW_EVAL_SESSION_THRESHOLD:-20}"
THIS_REPO="ai-coding-workflow"

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT_DIR" ] || [ ! -f "$ROOT_DIR/ai-workflow.md" ] \
   || [ "$(basename "$ROOT_DIR")" != "$THIS_REPO" ]; then
  echo "eval-preflight: must run inside the $THIS_REPO repo (got: ${ROOT_DIR:-<none>})" >&2
  exit 3
fi
cd "$ROOT_DIR"

OUT_JSON="telemetry/eval-readiness.json"
OUT_MD="telemetry/eval-readiness.md"
mkdir -p telemetry

NOW_ISO="$(date -u +%FT%TZ)"

# ---------- Loki helpers ----------

loki_ready() {
  curl -sf -m 5 "$LOKI_URL/ready" >/dev/null 2>&1
}

loki_query() {
  # Instant LogQL query. Echoes raw JSON response on stdout, or empty string on failure.
  local q="$1"
  curl -sf -m 30 -G "$LOKI_URL/loki/api/v1/query" \
    --data-urlencode "query=$q" \
    --data-urlencode "time=$(date -u +%s)000000000" 2>/dev/null || true
}

# Convert a count-vector Loki response into a jq object keyed by joined labels.
# Caller passes the label keys to use as the object key.
# Example: vector_to_kv '<json>' workflow_version
#   => {"2.15.0": 12, "2.16.0": 23}
vector_to_kv() {
  local json="$1"; shift
  local key_jq
  key_jq=$(printf '.metric."%s"' "$1"); shift
  while [ "$#" -gt 0 ]; do
    key_jq+=$(printf ' + "/" + .metric."%s"' "$1"); shift
  done
  echo "$json" | jq --argjson default '{}' \
    "if .status == \"success\" then [.data.result[] | { (${key_jq}): (.value[1] | tonumber) }] | add // \$default else \$default end"
}

# ---------- Condition 1: baseline versions on disk ----------

c1_versions=()
if [ -d telemetry/data/baseline ]; then
  while IFS= read -r d; do
    [ -d "$d" ] && c1_versions+=("$(basename "$d")")
  done < <(find telemetry/data/baseline -mindepth 1 -maxdepth 1 -type d | sort)
fi
c1_count="${#c1_versions[@]}"
if [ "$c1_count" -ge 2 ]; then c1_status="pass"; else c1_status="fail"; fi

# JSON-safe array literal of c1_versions (empty -> [])
if [ "$c1_count" -eq 0 ]; then
  c1_versions_json="[]"
else
  c1_versions_json="$(printf '%s\n' "${c1_versions[@]}" | jq -R . | jq -s .)"
fi

# ---------- Loki reachability gate ----------

if ! loki_ready; then
  cat > "$OUT_JSON" <<EOF
{
  "generated_at": "$NOW_ISO",
  "loki_reachable": false,
  "loki_url": "$LOKI_URL",
  "query_window": "$QUERY_WINDOW",
  "this_repo": "$THIS_REPO",
  "gate": {
    "overall": "inconclusive",
    "reason": "Loki unreachable at $LOKI_URL; cannot evaluate conditions 2-4"
  },
  "conditions": {
    "baseline_versions": {
      "status": "$c1_status",
      "versions": $c1_versions_json,
      "required_min": 2
    }
  }
}
EOF

  cat > "$OUT_MD" <<EOF
# Eval Readiness

**Generated:** $NOW_ISO
**Overall:** inconclusive (Loki unreachable)

Loki was not reachable at \`$LOKI_URL\`. Cannot evaluate gate conditions 2-4
(session counts, ruleset_hash emission, ruleset_hash poisoning). Bring the
telemetry stack up with \`./telemetry/up.sh\` (or wait for the launchd agent
to restart it) and re-run \`scripts/eval-preflight.sh\`.

## Condition 1 — baseline versions on disk

- **Status:** $c1_status
- **Required:** at least 2
- **Found:** $c1_count
EOF
  if [ "$c1_count" -gt 0 ]; then
    printf -- "- **Versions:** %s\n" "$(IFS=, ; echo "${c1_versions[*]}")" >> "$OUT_MD"
  fi
  exit 2
fi

# ---------- Condition 2: sessions per workflow_version (this repo only) ----------

c2_query='count by (workflow_version) (max by (workflow_version, session_id) (count_over_time({service_name="claude-code"} | workflow_repo="'"$THIS_REPO"'" | session_id!="" ['"$QUERY_WINDOW"'])))'
c2_raw="$(loki_query "$c2_query")"
c2_counts_json="$(vector_to_kv "$c2_raw" workflow_version)"
c2_versions_below=$(echo "$c2_counts_json" | jq --argjson t "$SESSION_THRESHOLD" \
  '[to_entries[] | select(.value < $t) | .key]')
c2_versions_present=$(echo "$c2_counts_json" | jq 'keys')
if [ "$(echo "$c2_versions_present" | jq 'length')" -ge 2 ] \
   && [ "$(echo "$c2_versions_below" | jq 'length')" -eq 0 ]; then
  c2_status="pass"
else
  c2_status="fail"
fi

# ---------- Condition 3: shared task set across baseline versions ----------
# Task IDs live at: telemetry/data/baseline/<version>/<ruleset_hash>/<task_id>/<run>.json
# Starting find at <version>, task_id dirs are at depth 2.

c3_status="skipped"
c3_ref_task_count=0
if [ "$c1_count" -ge 2 ]; then
  c3_status="pass"
  c3_ref_tasks="__UNSET__"
  for v in "${c1_versions[@]}"; do
    tasks="$(find "telemetry/data/baseline/$v" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
              | awk -F/ '{print $NF}' | sort -u)"
    if [ "$c3_ref_tasks" = "__UNSET__" ]; then
      c3_ref_tasks="$tasks"
      c3_ref_task_count=$(printf '%s\n' "$tasks" | grep -c . || true)
    elif [ "$tasks" != "$c3_ref_tasks" ]; then
      c3_status="fail"
    fi
  done
fi

# ---------- Condition 4a: ruleset_hash emitted on this-repo sessions ----------

c4a_query='count by (workflow_version, ruleset_hash) (max by (workflow_version, ruleset_hash, session_id) (count_over_time({service_name="claude-code"} | workflow_repo="'"$THIS_REPO"'" | session_id!="" ['"$QUERY_WINDOW"'])))'
c4a_raw="$(loki_query "$c4a_query")"
# Build {workflow_version: [hashes]} from result rows
c4a_hashes_json="$(echo "$c4a_raw" | jq '
  if .status == "success" then
    reduce .data.result[] as $r ({};
      .[$r.metric.workflow_version] += [($r.metric.ruleset_hash // "")]
    ) | with_entries(.value |= unique)
  else {} end')"
# Pass if every version present has exactly one non-empty hash
c4a_status=$(echo "$c4a_hashes_json" | jq -r '
  if length == 0 then "fail"
  else
    [to_entries[] | (.value | length == 1 and .[0] != "")] | all
    | if . then "pass" else "fail" end
  end')

# ---------- Condition 4b: external-repo sessions must NOT carry ruleset_hash ----------

c4b_query='count by (workflow_repo, ruleset_hash) (max by (workflow_repo, ruleset_hash, session_id) (count_over_time({service_name="claude-code"} | workflow_repo!="'"$THIS_REPO"'" | session_id!="" ['"$QUERY_WINDOW"'])))'
c4b_raw="$(loki_query "$c4b_query")"
c4b_poisoned_json="$(echo "$c4b_raw" | jq '
  if .status == "success" then
    [.data.result[] | select(.metric.ruleset_hash != null and .metric.ruleset_hash != "")
                    | .metric.workflow_repo] | unique
  else [] end')"
c4b_status=$(echo "$c4b_poisoned_json" | jq -r 'if length == 0 then "pass" else "fail" end')

# ---------- Overall ----------

if [ "$c1_status" = "pass" ] && [ "$c2_status" = "pass" ] \
   && [ "$c3_status" = "pass" ] && [ "$c4a_status" = "pass" ] \
   && [ "$c4b_status" = "pass" ]; then
  overall="pass"
  exit_code=0
else
  overall="fail"
  exit_code=1
fi

# ---------- Write JSON ----------

jq -n \
  --arg now "$NOW_ISO" \
  --arg loki "$LOKI_URL" \
  --arg window "$QUERY_WINDOW" \
  --arg this_repo "$THIS_REPO" \
  --argjson threshold "$SESSION_THRESHOLD" \
  --arg overall "$overall" \
  --argjson c1_count "$c1_count" \
  --arg c1_status "$c1_status" \
  --argjson c1_versions "$c1_versions_json" \
  --arg c2_status "$c2_status" \
  --argjson c2_counts "$c2_counts_json" \
  --argjson c2_below "$c2_versions_below" \
  --arg c3_status "$c3_status" \
  --argjson c3_ref_task_count "$c3_ref_task_count" \
  --arg c4a_status "$c4a_status" \
  --argjson c4a_hashes "$c4a_hashes_json" \
  --arg c4b_status "$c4b_status" \
  --argjson c4b_poisoned "$c4b_poisoned_json" \
  '{
    generated_at: $now,
    loki_reachable: true,
    loki_url: $loki,
    query_window: $window,
    this_repo: $this_repo,
    session_threshold: $threshold,
    gate: { overall: $overall },
    conditions: {
      baseline_versions: {
        status: $c1_status,
        versions: $c1_versions,
        required_min: 2
      },
      sessions_per_version: {
        status: $c2_status,
        counts: $c2_counts,
        threshold: $threshold,
        versions_below_threshold: $c2_below,
        scope: ("workflow_repo=\($this_repo) only")
      },
      baseline_task_overlap: {
        status: $c3_status,
        task_count_in_first_version: $c3_ref_task_count,
        note: "task_count is the count in the lexicographically-first version; meaningful only when status=pass"
      },
      ruleset_hash_this_repo: {
        status: $c4a_status,
        hashes_per_version: $c4a_hashes,
        rule: "each version emits exactly one non-empty ruleset_hash"
      },
      ruleset_hash_external_repos: {
        status: $c4b_status,
        poisoned_repos: $c4b_poisoned,
        rule: "external repos must not emit ruleset_hash (scoped to this repo only)"
      }
    }
  }' > "$OUT_JSON"

# ---------- Write Markdown ----------

{
  echo "# Eval Readiness"
  echo
  echo "**Generated:** $NOW_ISO"
  echo "**Overall:** $overall"
  echo "**Loki:** $LOKI_URL (reachable)"
  echo "**Window:** $QUERY_WINDOW"
  echo
  echo "## Gate"
  echo
  echo "| Condition | Status | Detail |"
  echo "|---|---|---|"
  echo "| 1. baseline versions on disk (≥2) | $c1_status | found $c1_count: $(IFS=, ; echo "${c1_versions[*]:-<none>}") |"

  c2_counts_str="$(echo "$c2_counts_json" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(", ")')"
  c2_below_str="$(echo "$c2_versions_below" | jq -r 'join(", ")')"
  echo "| 2. ≥$SESSION_THRESHOLD sessions per version in Loki (this repo only) | $c2_status | $c2_counts_str${c2_below_str:+ — below threshold: $c2_below_str} |"

  echo "| 3. shared task set across baseline versions | $c3_status | $c3_ref_task_count task(s) in first version |"

  c4a_str="$(echo "$c4a_hashes_json" | jq -r 'if length == 0 then "no data" else to_entries | map("\(.key)=[\(.value | join(","))]" ) | join("; ") end')"
  echo "| 4a. ruleset_hash emitted on this-repo sessions | $c4a_status | $c4a_str |"

  c4b_str="$(echo "$c4b_poisoned_json" | jq -r 'if length == 0 then "no poisoned repos" else "poisoned: " + join(", ") end')"
  echo "| 4b. external repos do NOT emit ruleset_hash | $c4b_status | $c4b_str |"

  echo
  if [ "$overall" = "pass" ]; then
    echo "Gate would pass. The periodic review process in \`design/decisions/evaluation.md\` is safe to invoke."
  else
    echo "Gate would fail. Do not produce proposals; the \`aiw-evaluation\` skill will write a thin-data report instead."
  fi
} > "$OUT_MD"

exit "$exit_code"
