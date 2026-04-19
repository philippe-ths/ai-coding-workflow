"""
Polls Loki for a log stream carrying the spike_run_id written by the most
recent `inspect eval task.py` run. Exits 0 on hit, 1 on no match within the
polling window, 2 on misconfiguration.

Usage: .venv/bin/python assert_tags.py
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

SPIKE_DIR = Path(__file__).parent
LOKI = "http://localhost:3100"
SERVICE = "d0-sandbox-spike"
POLL_SECONDS = 30
POLL_INTERVAL = 2


def main() -> int:
    run_id_file = SPIKE_DIR / "run_id.txt"
    if not run_id_file.exists():
        print("ERROR: run_id.txt missing. Run task.py via inspect first.", file=sys.stderr)
        return 2
    run_id = run_id_file.read_text().strip()
    if not run_id:
        print("ERROR: run_id.txt empty.", file=sys.stderr)
        return 2

    query = '{service_name="' + SERVICE + '"} | spike_run_id="' + run_id + '"'
    deadline = time.time() + POLL_SECONDS
    last_result = None

    while time.time() < deadline:
        params = {
            "query": query,
            "limit": "5",
            "start": str(int((time.time() - 600) * 1e9)),
        }
        url = LOKI + "/loki/api/v1/query_range?" + urllib.parse.urlencode(params)
        try:
            with urllib.request.urlopen(url, timeout=5) as resp:
                data = json.loads(resp.read().decode())
        except Exception as exc:
            print(f"WARN: Loki query failed: {exc}", file=sys.stderr)
            time.sleep(POLL_INTERVAL)
            continue

        results = data.get("data", {}).get("result", [])
        entries = sum(len(s.get("values", [])) for s in results)
        last_result = results
        if entries > 0:
            print(f"PASS: {entries} log entr{'y' if entries == 1 else 'ies'} for spike_run_id={run_id}")
            print(json.dumps(results, indent=2))
            return 0
        time.sleep(POLL_INTERVAL)

    print(f"FAIL: no log entries found for spike_run_id={run_id} within {POLL_SECONDS}s")
    print(f"Last Loki result: {last_result}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
