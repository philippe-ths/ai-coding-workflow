# Lite Monolithic AI Workflow

A single-file version of the [AI Coding Workflow](https://github.com/philippe-ths/ai-coding-workflow) project.

## What This Is

One self-contained file (`ai-workflow.md`) that gives any AI coding agent a structured workflow with human checkpoints, planning discipline, validation rules, scope control, and failure analysis — without requiring additional infrastructure.

## Who It's For

Developers who want lightweight AI coding guardrails they can drop into any repository without setting up the full workflow infrastructure.

## How to Use It

1. Copy `ai-workflow.md` into your repository.
2. Point your AI coding agent at the file (e.g. via agent instructions or conversation context).
3. Run tasks through the workflow. The agent follows the steps; you review at checkpoints.

Or let the installer do it: from the full project, run `scripts/install.sh --target <repo> --tool <tool> --profile lite`, or point an agent at the full repository and say "install the AI workflow", choosing the `lite` profile. The installer drops `ai-workflow.md` in and generates a minimal entry file for your tool. See the full project's [`INSTALL.md`](../INSTALL.md).

## Relationship to the Full Project

`ai-workflow.md` here is a self-contained condensation of the [full AI Coding Workflow](https://github.com/philippe-ths/ai-coding-workflow): the same workflow steps, planning discipline, validation gates, scope control, and failure analysis, inlined into one file with no external dependencies. It is a *derived* artifact — re-condensed from the full workflow and its skills — and its `Version:` header is kept equal to the full project's canonical version, so you can tell which release it was distilled from. A lite version that lags the canonical version means it has not yet been re-synced.

Step up to the full version when you want what a single file cannot carry:

- A policy enforcement layer (`.ai-policy/` scripts and git hooks) that blocks commits and pushes when rules are violated.
- Skills loaded on demand (planning, ground truth, testing, verification, failure analysis, GitHub handoff, issue creation, project-context management, and more).
- Multi-agent entry points for VS Code Copilot, Claude Code, Codex, and Gemini CLI.
- A maintained `project-context.md` documenting your repository's implementation truth, authored with the `aiw-project-context-management` skill.
