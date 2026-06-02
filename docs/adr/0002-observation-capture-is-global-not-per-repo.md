# Session observation is installed per-developer (global), not copied per-repo

**Status:** accepted

This repo's governing model is that workflow files are copied into each target repo, because guardrails are a per-repo concern. Session observation is the opposite: it's about one developer's activity *across all* their repos, so copying the capture mechanism into each repo guarantees coverage gaps the first time a repo is forgotten. We therefore install the two capture pieces — the SessionStart Manifest hook and the `/rate` skill — globally in `~/.claude/` (settings + skills), writing to a single global Session Store under `~/.claude/aiw-observation/`. This repo holds only the collection script, the dashboard generator, and the docs. The per-repo copy-in model still governs the workflow rules; it explicitly does not govern observation.

## Consequences

- "Installing observation" is a one-time global setup, separate from copying workflow files into a repo.
- The Session Store may contain repo names/paths from many private codebases, but no prompt or code content (metrics only), so pooling them locally needs no redaction.
- The collection script and dashboard are the only observation code in this repo; everything that produces data lives in global Claude config.
