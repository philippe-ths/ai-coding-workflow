# Local Telemetry Setup

Run a local OpenTelemetry stack that receives, redacts, stores, and visualises Claude Code session telemetry for this repository.

## What the stack contains

- **OTEL Collector** — receives OTLP on `:4317` (gRPC) and `:4318` (HTTP), applies redaction, forwards metrics to Prometheus and logs to Loki.
- **Prometheus** — stores metrics via remote-write. 30-day retention.
- **Loki** — stores log events (including `user_prompt`, `tool_result`, `api_request`). 30-day retention.
- **Grafana** — pre-provisioned with both datasources and four dashboards: **Session Overview**, **Tool Usage**, **Fix Cycles** (placeholder), **Version Comparison**.

All data stays on the machine running the stack. Nothing is sent to any external service.

## Prerequisites

- Docker 24+ with Compose plugin.
- ~1.5 GB free RAM.
- Free TCP ports: `3000` (Grafana), `9090` (Prometheus), `3100` (Loki), `4317`/`4318` (Collector).

## Start and stop

```bash
./telemetry/up.sh
./telemetry/down.sh
# Pass -v to down.sh to also wipe captured telemetry.
./telemetry/down.sh -v
```

Or use `docker compose` directly inside `telemetry/`.

## Enable Claude Code emission

The repository ships `.envrc.example` with the three shell variables Claude Code needs. Copy and activate it:

```bash
cp .envrc.example .envrc
direnv allow
```

The three variables that must be exported in the shell that runs `claude`:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

If your Collector is HTTP-only, use `http://localhost:4318` with `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`.

Open Grafana at <http://localhost:3000>. Dashboards live under the **AI Coding Workflow** folder.

## What Claude Code emits

The upstream list of metrics and events is maintained at [docs.claude.com/en/docs/claude-code/monitoring-usage](https://docs.claude.com/en/docs/claude-code/monitoring-usage). The pre-built dashboards query the following today:

**Metrics**

- `claude_code.session.count`
- `claude_code.cost.usage` (USD)
- `claude_code.token.usage` (input, output, cacheRead, cacheCreation)
- `claude_code.code_edit_tool.decision` (accept, reject)
- `claude_code.active_time.total`
- `claude_code.lines_of_code.count`
- `claude_code.commit.count`
- `claude_code.pull_request.count`

**Log events**

- `user_prompt`, `tool_result`, `tool_decision`, `api_request`, `api_error`, `skill_activated`, `plugin_installed`

Both metric names and event shapes are upstream-defined and may change. Treat the dashboards as starting points and refine as the upstream schema evolves.

## Redaction rules

Redaction runs inside the Collector, before anything reaches Prometheus or Loki. See `telemetry/otel-collector-config.yaml`.

**Resource-attribute redaction** (always on):

- `user.email` — deleted.
- `user.account_uuid`, `user.account_id` — deleted.
- `user.id` (anonymous device ID), `organization.id` — hashed.

**Log-body redaction** (applied to all log records):

- Email addresses → `<email>`
- Absolute home paths (`/Users/<name>`, `/home/<name>`) → `/Users/<user>`, `/home/<user>`
- API-key-looking strings (`sk-...`, `AKIA...`, `ghp_...`, `ghs_...`) → `<api-key>` / `<gh-token>`
- Bearer tokens → `bearer <token>`
- All log attributes truncated to 4096 characters.

**Upstream opt-in flags (left off by default by Claude Code).** The redaction processors are a safety net for when a user opts in. They do **not** replace the discipline of leaving these off unless needed:

| Flag | What it exposes |
|---|---|
| `OTEL_LOG_USER_PROMPTS=1` | Raw user prompt text in `user_prompt` events |
| `OTEL_LOG_TOOL_DETAILS=1` | Tool parameters and input args |
| `OTEL_LOG_TOOL_CONTENT=1` | Full tool input/output (60 KB truncated upstream) |
| `OTEL_LOG_RAW_API_BODIES=1` | Full Messages API request/response JSON; implies all above |

To loosen redaction, edit the `transform/redact-log-bodies` processor in `telemetry/otel-collector-config.yaml` and restart the Collector:

```bash
docker compose restart otel-collector
```

## Troubleshooting

- **No data in Grafana.** Confirm `CLAUDE_CODE_ENABLE_TELEMETRY=1` is set in the shell running `claude`. Check Collector logs: `docker logs aiw-otel-collector`.
- **Claude Code `-p` one-shot mode.** May not flush telemetry before exit. Use an interactive session for verification.
- **Port conflicts.** Create `telemetry/docker-compose.override.yml` (gitignored) to remap host ports without touching the committed config. Example remapping Grafana from 3000 to 3001:

  ```yaml
  services:
    grafana:
      ports:
        - "3001:3000"
  ```
- **Cumulative temporality required.** Some collectors need `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`. The included Collector does not, but set it if you swap backends.
- **Heavy footprint.** Prometheus + Loki + Grafana can consume 1–1.5 GB RAM. If that is too much, the docker-compose file can be trimmed to just the Collector; metrics and logs can then be exported to a lighter store (e.g. SQLite or DuckDB via a custom exporter). The current config assumes Grafana dashboards are the primary interface.

## Files

- `telemetry/docker-compose.yml` — stack definition.
- `telemetry/otel-collector-config.yaml` — receivers, redaction processors, exporters.
- `telemetry/prometheus/prometheus.yml` — Prometheus remote-write receiver config.
- `telemetry/loki/loki-config.yaml` — Loki storage and retention.
- `telemetry/grafana/provisioning/` — auto-wired datasources and dashboard provider.
- `telemetry/grafana/dashboards/` — the four dashboard JSONs.
- `telemetry/up.sh`, `telemetry/down.sh` — convenience wrappers.
- `telemetry/.gitignore` — blocks captured data from the repo.
