# Session Observation

A local, single-developer tool that reads Claude Code session transcripts and presents
descriptive per-session metrics. It does not compute a verdict: it shows how metrics move
across workflow versions and over time, and you are the judge.

See `docs/adr/0001` (descriptive observation over statistical comparison), `docs/adr/0002`
(global, per-developer capture), and `CONTEXT.md` (glossary) for the rationale and language.

## What it collects

One row per session, metrics only (never prompt or code content):

- repo, workflow version (from the Manifest), start time, duration
- model, token usage (input / output / cache read / cache creation)
- estimated cost (tokens times a model price table; the transcript stores no cost)
- tool calls (total and per tool), skill activations (which skills), user turns
- your 1-4 rating, if you gave one

## Install (once, global)

Capture is per-developer and cross-repo, so it installs into your global `~/.claude/`,
not into each repo. Requires `python3`.

```bash
./observation/install-observation.sh
```

This places a defensive SessionStart hook (writes the Manifest), the `/rate` skill, and
helper scripts under `~/.claude/aiw-observation/`, and wires the hook into
`~/.claude/settings.json`. Re-running is safe.

## Daily use

- Work normally. The hook records each session automatically in every repo.
- Optionally rate a session live: `/rate 3` (1 bad, 2 fine, 3 good, 4 excellent).
- When you want to look: `make observe` (from this repo) rebuilds the store and opens the dashboard.

## Where data lives

All under `~/.claude/aiw-observation/` (global, gitignored by being outside any repo):

- `manifest.jsonl` — session_id to workflow_version, written by the hook
- `ratings.jsonl` — your `/rate` entries
- `sessions.jsonl` — the Session Store, rebuilt fully on every `make observe`
- `dashboard.html` — the generated dashboard

## Files

- `collect.py` — orchestrator: transcripts + Manifest + Ratings -> Session Store + dashboard
- `parse.py` — the only module that knows the transcript format
- `pricing.py` — model price table and estimated-cost calculation
- `dashboard.py` — Session Store -> self-contained static HTML
- `test_parse.py` — parser regression test (`make observe-test`)
- `fixtures/sample-transcript.jsonl` — real-shaped fixture for the test
- `capture/` — the global hook, `/rate` skill, and rating recorder
- `install-observation.sh` — global installer (honors `CLAUDE_HOME` for testing)

## Maintenance

- `pricing.py` holds list prices; update it when prices change or a new model ships.
  Unknown models yield a null cost estimate rather than a wrong one.
- If Claude Code changes its transcript format, `parse.py` is the single place to repair,
  guarded by `test_parse.py`.
