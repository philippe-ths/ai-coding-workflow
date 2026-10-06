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

Tokens and cost include the subagents a session launched. Each reply is counted once, from
the last of the entries Claude Code splits it into: each entry repeats the reply's usage, and
in subagent transcripts the output count grows until the last one.

One row per task as well, where a task is the issue number in a branch name
(`feat/344-mode-flip` is `#344`; `fix/424-421-...` is `#424`), or the branch name when it carries
no number. Each task also keeps its tokens and cost per day, so a date filter shows the part of a
task that falls in range. Every reply
counts against the branch it ran on and every subagent against the branch it was launched
from, so a session that worked on several issues splits across them and a task worked over
several sessions adds up. Each task shows its branches, sessions, subagents and
`aiw-failure-analysis` runs alongside its tokens and cost. Work on `main`, on a detached
HEAD, in a worktree no reply launched, or with no branch recorded is unattributed and shown as a share rather than guessed.

## Install (once, global)

Capture is per-developer and cross-repo, so it installs into your global `~/.claude/`,
not into each repo. Requires `python3`.

```bash
./observation/install-observation.sh
```

This places a defensive SessionStart hook (writes the Manifest), the `/rate` skill, and
helper scripts under `~/.claude/aiw-observation/`, and wires the hook into
`~/.claude/settings.json`. Re-running is safe.

## Uninstall

```bash
./observation/uninstall-observation.sh
```

Removes the hook, the `/rate` skill, and the helper scripts, and unwires the hook from
`~/.claude/settings.json`, leaving every other setting and hook in place. Re-running is safe.

Your recorded data is kept. Add `--purge-data` to remove `manifest.jsonl`, `ratings.jsonl`,
`history.jsonl`, `sessions.jsonl`, `tasks.jsonl`, and `dashboard.html` as well. The Session Store
and dashboard can be rebuilt from transcripts and history; the Manifest, Ratings and history cannot.

Run this **before** deleting this repository. Capture installs itself outside the repo, so
deleting the repo alone leaves the SessionStart hook wired into your global config.

## Daily use

- Work normally. The hook records each session automatically in every repo.
- Optionally rate a session live: `/rate 3` (1 bad, 2 fine, 3 good, 4 excellent).
- When you want to look: `make observe` (from this repo) rebuilds the store and opens the dashboard.

## Where data lives

All under `~/.claude/aiw-observation/` (global, gitignored by being outside any repo):

- `manifest.jsonl` — session_id to workflow_version, written by the hook
- `ratings.jsonl` — your `/rate` entries
- `history.jsonl` — each session's metrics as last read, so a session survives Claude Code
  deleting its transcript (after `cleanupPeriodDays`, 30 by default); metrics only, no content
- `sessions.jsonl` — the Session Store, rebuilt fully on every `make observe` from transcripts
  still on disk and, for the rest, from history
- `tasks.jsonl` — one row per task, rebuilt alongside the Session Store
- `dashboard.html` — the generated dashboard

## Files

- `collect.py` — orchestrator: transcripts + Manifest + Ratings -> Session Store, tasks + dashboard
- `parse.py` — the only module that knows the transcript format
- `pricing.py` — model price table and estimated-cost calculation
- `dashboard.py` — Session Store -> self-contained static HTML
- `test_parse.py` — parser regression test (`make observe-test`)
- `fixtures/sample-transcript.jsonl` — real-shaped fixture for the test
- `capture/` — the global hook, `/rate` skill, and rating recorder
- `install-observation.sh` — global installer (honors `CLAUDE_HOME` for testing)
- `uninstall-observation.sh` — the inverse; keeps recorded data unless `--purge-data`

## Maintenance

- `pricing.py` holds list prices; update it when prices change or a new model ships.
  Unknown models yield a null cost estimate rather than a wrong one.
- If Claude Code changes its transcript format, `parse.py` is the single place to repair,
  guarded by `test_parse.py`.
