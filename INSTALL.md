# Installing and Updating the AI Coding Workflow

This file tells an AI coding agent how to install this workflow into a target
repository, or update an already-installed copy. Point an agent at this
repository (a local path or its URL) and say "install the AI workflow" or
"upgrade the AI workflow"; the agent follows the steps below.

## What you are working with

- This repository is the **source** (the workflow plus its installer).
- The **target** is the repository the workflow is being installed into, usually
  the repo the agent is currently working in.
- `install-manifest.json` is the source of truth for which files are **product**
  (installed into the target) and which are **factory** (this repo's own
  machinery, never installed). The installer reads it. Do not copy files by hand.
  Run `make classify` here to see the boundary.

## If you only have the URL

Clone the repository to a local path first, then use that path as `<source>`:

```bash
git clone https://github.com/philippe-ths/ai-coding-workflow /tmp/ai-coding-workflow
```

If the agent's environment cannot clone, ask the human to provide the repository
as a local path instead.

## Install (fresh)

1. Confirm the target path and that it is a git repository. If not, run
   `git init` there first (the installer requires it for hooks and vendoring).
2. Ask the human which agent tool to install for (`claude`, `codex`, `gemini`, or
   `copilot`) and which profile: `full` (policy layer, skills, entry point) or
   `lite` (one self-contained file).
3. Run the installer from the source:

   ```bash
   <source>/scripts/install.sh --target <target> --tool <tool> --profile <profile>
   ```

4. Author the target's `project-context.md` using the
   `aiw-project-context-management` skill. It must describe the **target** repo;
   the installer does not create it.
5. Report what was installed.

## Update (already installed)

1. Confirm the target has an installed copy (`ai-workflow.md` at its root).
2. Run the updater from the source:

   ```bash
   <source>/scripts/update.sh --target <target>
   ```

   It auto-detects the installed tool and profile from the target. Pass
   `--tool` / `--profile` to override or to disambiguate if several tools are
   installed.
3. Report the version change and any files that were removed.

## Notes

- **Vendored, not committed.** The installer records the installed files in the
  target's `.gitignore` so they do not enter the target's history. Do not commit
  them unless the human asks.
- **Removals on update** come only from this repo's `CHANGELOG.md` `### Removed`
  entries. A file is deleted from the target only if it was dropped from the
  product between the installed and current versions; local additions are kept.
- The installer copies only product files; factory files are never installed.
