# AI Workflow Observability

The language for how this repo collects and presents data about Claude Code sessions running under the AI workflow. This context covers the redesign that replaces statistical version-comparison ("is A better than B") with descriptive observation a single developer reads and judges.

## Language

**Session**:
One Claude Code run under the AI workflow, in any repo where the workflow is installed. The unit that data is collected about.
_Avoid_: run (reserved for baseline-harness repeats), conversation.

**Descriptive Trend**:
The display of how a collected metric moves across workflow versions or over time, with no significance test, threshold, or pass/fail verdict attached. The tool surfaces the movement; the human decides whether it matters.
_Avoid_: A/B result, evaluation, score.

**Comparison**:
Reading a Descriptive Trend to notice change. Redefined from its old meaning (a statistical A/B verdict produced by `compare-versions.py`). Comparison is now an act the human performs against the dashboard, not a number the tool computes.
_Avoid_: verdict, winner, significance.

**Raw Aggregate**:
A summed or averaged native metric across sessions (cost, tokens, duration, tool-call count). Because Sessions span repos of wildly different difficulty, a Raw Aggregate describes *what happened*, not *whether the workflow is better*. It is descriptive only and carries no quality authority.
_Avoid_: quality metric, score.

**Judged Signal**:
A per-session assessment that is somewhat normalized against task difficulty and therefore carries a quality story where Raw Aggregates do not. Currently this means the human's 1-4 session **Rating** only. An LLM-judge signal (success, thinking-approach) is deferred, not cut: when added it must respect the closed-loop constraint (the judge reads only the Transcript, which is Claude's own account, so it cannot hold authority over "did it succeed").
_Avoid_: metric (when quality is meant).

**Rating**:
The human's 1-4 verdict on a Session (1 bad, 2 fine, 3 good, 4 excellent). The only success signal in the current design, and the only one sourced from outside the Transcript, so it is the ground-truth break in the closed loop. Captured live via a `/rate` skill the human invokes during or at the end of a Session; recorded as `{repo, timestamp, 1-4}` and matched to its Session by repo + time at collection. Optional and sparse: a Session may have no Rating.
_Avoid_: score, grade.

**Repo Tag** (`workflow_repo`):
The label identifying which repository a Session ran in. Every Session everywhere the workflow is installed pools into one local store; the Repo Tag lets the dashboard group or narrow to a single repo for a fairer Comparison.
_Avoid_: project, workspace.

**Transcript**:
The JSONL file Claude Code writes to disk for every Session (under `~/.claude/projects/<encoded-path>/`). It is the source of all collected data: native metrics are parsed from it and the LLM judge reads it. Replaces the OTLP stream as the single data source.
_Avoid_: log, OTLP stream.

**Session Store**:
The one **global**, per-developer JSONL file (one row per Session) that the collection script writes after parsing each Transcript, joining the Manifest, and joining the human Rating. Lives in global Claude config (e.g. `~/.claude/aiw-observation/`), not in any repo, because it pools Sessions from all repos. The dashboard reads only this. Holds metrics only, never prompt or code content. Replaces Prometheus + Loki.
_Avoid_: database, telemetry store, warehouse.

**Manifest**:
A global sidecar file appended to at Session start by a small SessionStart hook installed in global `~/.claude/settings.json`, recording `{session_id, repo, workflow_version, started_at}`. It is the only reliable source of the **Workflow Version** active during a Session, because the Transcript does not record it and the repo's workflow files may change after the Session ends.
_Avoid_: log, metadata file.

**Capture vs Tooling** (locality boundary):
**Capture** (the Manifest hook and the `/rate` skill) is a per-developer, cross-repo concern, so it is installed **globally** in `~/.claude/` and fires in every repo. The **Tooling** (collection script, dashboard generator, docs) is the only observation code that lives in *this* repo. This deliberately departs from the repo's "copy governance files into each target repo" model, which still applies to the Workflow rules but not to observation.
_Avoid_: install (unqualified — say global Capture install vs per-repo Workflow install).

**Workflow Version**:
The version of `ai-workflow.md` active during a Session, captured into the Manifest at start. Clean and current only in this repo (where the workflow is actively edited); in other repos it is whatever stale snapshot was last copied in, so version-axis Comparison is trustworthy only for this-repo Sessions.
_Avoid_: ruleset version, release.

## Flagged ambiguities

- **"Evaluation"** is retired. It previously named the whole statistical apparatus (pass^k, McNemar, the n=20 gate in `design/decisions/evaluation.md`, the `aiw-evaluation` skill), all of which are being deleted. The replacement is **Observation** (descriptive, human-judged). Do not reuse "evaluation" for the new system; it implies a verdict the new system deliberately does not produce.
