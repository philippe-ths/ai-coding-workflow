# Replace statistical version-comparison with transcript-based descriptive observation

**Status:** accepted

As a single developer running the AI workflow across many repos, the statistical A/B apparatus (baseline harness, frozen tasks, pass^k, McNemar, the n=20 readiness gate) never produced trustworthy verdicts: data was too sparse, cross-repo task difficulty made aggregates noisy, and the OTLP/Prometheus pipeline was silently dropping ~80% of sessions. We are deleting the entire baseline harness, the OTLP/Docker/Grafana telemetry stack, and the evaluation governance, and replacing them with a single script that reads Claude Code session Transcripts already on disk, extracts native per-session metrics into a JSONL Session Store, and regenerates a self-contained static HTML dashboard. The tool now only *describes* — it surfaces how metrics move across workflow versions (this repo) and over time (all repos); the human is the judge. We accept the loss of automated success grading and statistical authority in exchange for radical simplicity, zero running infrastructure, and 100% session coverage.

## Considered options

- **Keep OTLP live-streaming** (Collector + Loki, drop only Prometheus) — rejected: it is the heavy, partly-broken part, still requires Docker and a babysitting skill, and the live property has no value for a single dev doing periodic review.
- **Keep the baseline harness dormant** rather than deleting it — rejected: it exists only to produce the A/B verdict we're abandoning, and half-dead code traps the next reader.

## Consequences

- Success is known only for Sessions the human Rates 1-4; unrated Sessions carry descriptive metrics only.
- An LLM judge is deferred, not cut. When added it must respect the closed-loop constraint: it reads only the Transcript (Claude's own account), so it cannot hold authority over "did it succeed."
- Workflow-version Comparison is trustworthy only for this repo, where the version is real and current. Cross-repo Sessions are ambient time-based observation, never the basis for a version verdict.
