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

## What's Different from the Full Version

The full version includes:

- A policy enforcement layer (`.ai-policy/` scripts and git hooks) that blocks commits and pushes when rules are violated.
- Separate skill files loaded on demand for planning, failure analysis, and logging/observability.
- Multi-agent entry points for VS Code Copilot, Claude Code, Codex, and Gemini CLI.
- A project-spec template for documenting implementation truth in target repositories.
- Parent and sub-issue handling for decomposed GitHub work.

This lite version strips all of that down to a single file with the essential rules inlined. If you need deterministic enforcement or multi-agent configuration, use the [full version](https://github.com/philippe-ths/ai-coding-workflow).
