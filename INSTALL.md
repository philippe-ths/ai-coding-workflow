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
2. Ask the human which agent tool to install for (`claude`, `codex`, or
   `copilot`).
3. Run the installer from the source:

   ```bash
   <source>/scripts/install.sh --target <target> --tool <tool>
   ```

4. Author the target's `project-context.md` using the
   `aiw-project-context-management` skill. It must describe the **target** repo;
   the installer does not create it.
5. Report what was installed. Mention that invoking the `aiw-init` skill in the
   target scaffolds its `project-checks.md`; the installer does not create that
   one either. Say whether the Jev judge is live (see Notes).

## Update (already installed)

1. Confirm the target has an installed copy (`ai-workflow.md` at its root).
2. Run the updater from the source:

   ```bash
   <source>/scripts/update.sh --target <target>
   ```

   It detects every installed tool from the target and
   updates all of them, judged by the installer's `.gitignore` block. Pass
   `--tool` to add a tool that is not yet installed, or to choose one when
   the target predates that block and several entry points exist.
3. Report the version change, any files that were removed, and each `added new setting` or `did not add setting` line the update printed, since those concern the human's policy file.

## Notes

- **Vendored, not committed.** The installer records the installed files in the
  target's `.gitignore` so they do not enter the target's history. Do not commit
  them unless the human asks.
- **Removals on update** come only from this repo's `CHANGELOG.md` `### Removed`
  entries. A file is deleted from the target only if it was dropped from the
  product between the installed and current versions; local additions are kept.
- The installer copies only product files; factory files are never installed.
- **Jev judge.** `aiw-planning` asks TypeSafe's Jev for each task's ceremony
  tier through `.ai-policy/jev/ask.py`. It is live when a key is in
  `TYPESAFE_API_KEY` or `~/.typesafe_key`; the key is per machine, so one covers
  every repository. Without a key, or without `python3`, the agent sets the
  tier itself and nothing blocks. In a Codex target the shipped
  `workspace-write` sandbox has no network access, so the judge stays offline
  there; report it that way. A call costs a fraction of a cent. To switch
  it on, the human puts the key there themselves: never ask for it in chat or
  write it into the target, since either leaves the key in a transcript or a
  file.
