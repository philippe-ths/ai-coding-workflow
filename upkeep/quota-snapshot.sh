# >>> aiw-upkeep quota snapshot >>>
# Saves the rate_limits block for the upkeep timer; never fails the status line.
( d="$HOME/.claude/aiw-upkeep"; t="$d/quota.json.$$"; mkdir -p "$d" && printf '%s' "$input" \
    | jq -ce 'select(.rate_limits.five_hour != null and .rate_limits.seven_day != null) | {saved_at: (now|floor), rate_limits}' > "$t" \
    && mv "$t" "$d/quota.json" || rm -f "$t" ) >/dev/null 2>&1 || true
# <<< aiw-upkeep quota snapshot <<<
