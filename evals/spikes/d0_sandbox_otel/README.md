# D0 sandbox OTEL spike

Minimal Inspect task that proves OTEL resource attributes set inside a Docker sandbox reach the host collector.

Findings: `docs/spikes/d0-sandbox-otel.md`.
Tracking: [#111](https://github.com/philippe-ths/ai-coding-workflow/issues/111).

## Prerequisites

- macOS or Linux with Docker.
- Python 3.11+ on the host.
- The host telemetry stack running:

  ```sh
  (cd ../../../telemetry && ./up.sh)
  ```

## Run

```sh
./run.sh
```

`run.sh` creates `.venv/` if missing, installs `inspect-ai` from `requirements.txt`, runs the Inspect task, and then calls `assert_tags.py`. Expected final output:

```
PASS: 1 log entry for spike_run_id=sbx-<uuid>
```

Exit code 0 means the resource attribute survived sandbox → collector → Loki.

## Files

| File | Purpose |
|---|---|
| `task.py` | Inspect task; solver copies `emit.py` into the sandbox and runs it with OTEL env vars. |
| `emit.py` | Stdlib-only OTLP/HTTP logs emitter. Reads `OTEL_RESOURCE_ATTRIBUTES` from the env. |
| `compose.yaml` | Inspect Docker sandbox definition. Declares `host.docker.internal` for cross-platform reach to the host collector. |
| `Dockerfile` | Alpine + python3 + bash. No third-party Python packages in the sandbox. |
| `assert_tags.py` | Polls Loki at `localhost:3100` for the emitted `spike_run_id`. |
| `run.sh` | Orchestrates venv → `inspect eval` → assertion. |
| `run_id.txt` | Written by `task.py`, read by `assert_tags.py`. Gitignored. |

## Cleanup

```sh
rm -rf .venv run_id.txt logs/
docker image prune -f  # removes the Inspect-built sandbox image
```
