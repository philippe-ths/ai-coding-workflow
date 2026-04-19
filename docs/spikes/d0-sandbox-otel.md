# D0 — Sandbox OTEL spike

Tracking issue: [#111](https://github.com/philippe-ths/ai-coding-workflow/issues/111)
Parent issue: [#112](https://github.com/philippe-ths/ai-coding-workflow/issues/112) — Sub-issue D, baseline task harness.

## Question

Do OTEL resource attributes set via `OTEL_RESOURCE_ATTRIBUTES` inside an Inspect Docker sandbox reach the host collector intact?

The rest of Sub-issue D assumes they do. This spike proves it with a minimal demo before D commits to the design.

## Result

**Yes — with caveats documented below.** A trivial OTLP/HTTP emitter running inside an Inspect Docker sandbox, launched with `OTEL_RESOURCE_ATTRIBUTES` set via `sandbox().exec(env=...)`, lands in the host's Loki with the resource attributes preserved.

Evidence is reproducible via `evals/spikes/d0_sandbox_otel/run.sh`. Observed Loki stream after a successful run:

```json
{
  "scope_name": "d0-sandbox-spike-emit",
  "service_name": "d0-sandbox-spike",
  "severity_text": "INFO",
  "spike_run_id": "sbx-8d174e68-b05b-4beb-869c-f01bb2641c27"
}
```

## Method

1. Brought up the existing `telemetry/` stack (OTEL Collector + Prometheus + Loki + Grafana).
2. Sent a host-side OTLP/HTTP log with a unique `spike_run_id` resource attribute, confirmed arrival in Loki. Sanity baseline.
3. Built a minimal Inspect task (`evals/spikes/d0_sandbox_otel/task.py`) whose solver:
   - Writes a stdlib-only Python emitter (`emit.py`) into the sandbox via `sandbox().write_file`.
   - Invokes `python3 /tmp/emit.py` with `OTEL_RESOURCE_ATTRIBUTES` and `OTEL_EXPORTER_OTLP_ENDPOINT` passed through `sandbox().exec(env=...)`.
4. `emit.py` parses `OTEL_RESOURCE_ATTRIBUTES` itself, builds an OTLP/HTTP `resourceLogs` payload, and POSTs to `http://host.docker.internal:4318/v1/logs`.
5. `assert_tags.py` polls Loki for `{service_name="d0-sandbox-spike"} | spike_run_id="<run-id>"` and exits 0 on match.

Scope narrowing: the spike does **not** run Claude Code inside the sandbox. The question is whether the sandbox→host OTEL plumbing works; a 70-line stdlib emitter isolates that from model-specific behaviour. Sub-issue D will exercise the same plumbing with Claude Code as the emitter.

## Findings

### Env propagation
- Inspect's `sandbox().exec(..., env={...})` injects environment variables into the sandbox process. The emitter read `OTEL_RESOURCE_ATTRIBUTES` exactly as passed.
- **Implication for D.** Baseline harness can set per-run tags (version, ruleset hash, task id, attempt number) via `sandbox().exec(env=...)` when launching Claude Code inside the sandbox, and they will be attached to every log the Claude Code process emits.

### Network path
- `http://host.docker.internal:4318` works on macOS with Docker Desktop. `compose.yaml` also declares `extra_hosts: ["host.docker.internal:host-gateway"]`, which makes the same endpoint resolvable on native Linux Docker (CI).
- OTLP/HTTP (`:4318`) tested and passes. OTLP/gRPC (`:4317`) not tested in this spike — flagged for D because the project's `.envrc` currently configures Claude Code for gRPC.

### Redaction interaction
- `telemetry/otel-collector-config.yaml` redacts only specific identity keys (`user.email`, `user.account_uuid`, `user.account_id`, `user.id`, `organization.id`). Custom resource attributes used by the baseline harness (e.g. `spike_run_id`, `service.name`, future `workflow_version`, `ruleset_hash`) pass through untouched.
- **Implication for D.** Choose attribute names that do not collide with the redaction list. `service.name` is the one to reserve, because Loki promotes it to a stream label.

### Loki label model
- Loki's OTLP ingestion promotes **only** `service.name` (and a small built-in set) to queryable stream labels. All other resource attributes land as structured metadata.
- Retrieval requires the pipe syntax: `{service_name="..."} | spike_run_id="..."`. `{spike_run_id="..."}` alone returns zero results.
- **Implication for D.** The `scripts/compare-versions.py` that #112 calls for must query using this pattern, or push tags intended for grouping into `service.name` (ugly) or configure Loki to promote additional labels (cleaner, configurable in `loki-config.yaml`).

## Decision / Recommendation

Proceed with Sub-issue D on the assumption that sandbox→host OTEL works via the approach demonstrated here. Specifically:
- Use Inspect Docker sandboxes with a compose file that declares `extra_hosts` for Linux portability.
- Launch Claude Code inside the sandbox with `sandbox().exec(env={...})` carrying the baseline-harness tags.
- Point Claude Code's `OTEL_EXPORTER_OTLP_ENDPOINT` at `http://host.docker.internal:4318` (HTTP/protobuf) inside the sandbox, overriding the host `.envrc` default which is gRPC.
- Before scaling to real tasks, add one D-level check that gRPC also works in-sandbox (or accept that the baseline harness stays on HTTP).
- In `compare-versions.py`, either use the `{service_name=...} | tag="..."` LogQL pattern, or extend `loki-config.yaml` to promote baseline-harness tags to stream labels.

No workarounds needed — the primary path works.

## Artifacts

- `evals/spikes/d0_sandbox_otel/` — reproducible demo.
- `evals/spikes/d0_sandbox_otel/run.sh` — one-shot entrypoint.
- `evals/spikes/d0_sandbox_otel/README.md` — usage.

## Follow-ups

- [#119](https://github.com/philippe-ths/ai-coding-workflow/issues/119) — Verify OTLP/gRPC from an Inspect Docker sandbox (this spike covered HTTP only).
- [#120](https://github.com/philippe-ths/ai-coding-workflow/issues/120) — Decide Loki label-promotion strategy for baseline-harness tags.
- First commit of runtime Python triggers the `project-context.md` update noted in #112's body — that update belongs to D proper, not D0.
