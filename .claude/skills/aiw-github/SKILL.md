---
name: aiw-github
description: "Rules for every GitHub and git history action during a task: starting work on an issue, switching branches, rebasing, committing, pushing, opening a pull request, post-merge cleanup, and handling parent and sub-issue hierarchies. Use this skill whenever the agent is about to read a GitHub issue at task start, create or switch to a branch, run a rebase, create a commit, push to remote, open a pull request, or run post-merge cleanup, even if the user does not name the action explicitly. Also use when the agent encounters a parent issue with sub-issues, when a deterministic policy hook blocks a git action, or when the agent suspects new commits have landed on the target branch since the last rebase. The skill exists to keep GitHub actions explicitly approved, traceable to an issue, and safe against silent working-tree loss during branch operations."
---

# GitHub Workflow

Read this file before every GitHub or git history action: starting work on an issue, switching branches, rebasing, committing, pushing, opening a pull request, post-merge cleanup, or responding to a parent or sub-issue hierarchy.

## Why this skill exists

GitHub actions touch shared state. Each one becomes visible to others the moment it lands, and approval for one is not approval for another. Branch operations can silently lose untracked files. Issues anchor scope; without one, work drifts and commits lose traceability. This skill keeps each action gated by explicit human approval, anchored to an issue, and safe against working-tree surprises.

## Starting work on an issue

- Confirm the GitHub issue number before any other action.
- Read the issue body and the issue comments. Comments often carry scope changes, clarifications, and constraints not in the original body.
- If the issue has sub-issues, treat the parent as broader context. Stop and ask the human which sub-issue to work on. Do not implement the full parent scope.
- If the issue is a sub-issue, read the direct parent issue and its comments for context. Do not read further up the hierarchy.
- When completing a sub-issue, check whether it is the last open sub-issue under the parent. If it is, flag this to the human.

## Branch protection and naming

- Never work directly on `main` or `master`.
- Create or switch to an issue-scoped branch before editing files or making commits.
- Use the format `type/short-description` for branch names.

## Rebasing onto the target branch

- Rebase the issue branch onto the target branch before starting implementation.
- Rebase again before any remote GitHub action if new commits have landed on the target branch since the last rebase.

## Safe branch transitions

Before any operation that moves the working tree to a different branch state (rebase, checkout, switch):

- Compare tracked files between the current branch and the target.
- Check whether gitignored or untracked local files exist at paths the target state tracks.
- If either check reveals unexpected files or path overlap, stop and report before proceeding.
- If the human approves, back up the working tree (excluding `.git/`) before the operation.
- Delete the backup after confirming no files were lost.
- If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving.

## Commits, pushes, and pull requests are separate actions

Treat commit creation, push to remote, and pull request creation as separate GitHub actions.

- Do not infer approval for one GitHub action from approval for another.
- Do not push to remote or open a pull request without explicit human confirmation in the current session.
- If new commits are added after approval, stop and ask again before the next remote GitHub action.
- After running an approved GitHub action, stop and report the result.

## Pre-pull-request readiness

Before proposing the first remote GitHub action, check:

- Confirm aiw-verification's justification step has been completed for the work in this PR. (Why: a pull request without a completed verification justification is a pull request opened on unverified work. The implementation pass is not done until verification has run; the PR comes after. See aiw-verification for the justification step itself.)
- Whether documentation or README files need updating based on the change.
- Whether version numbers need updating.
- Whether a tagged release is needed.
- Parent and sub-issue closure status.
- State which GitHub action would be next if the human wants to publish the work.

## Deterministic policy hooks

- If Git `core.hooksPath` is not `.githooks`, run `./.ai-policy/scripts/install-hooks.sh`.
- If deterministic policy blocks an action, fix the blocked condition before retrying. Do not bypass the check or treat it as optional.
- If repo-local policy requires a passed validation state before commit or push, satisfy that requirement through the repository's validation flow.

## Post-merge cleanup

After the human merges the pull request:

- Check whether the local issue branch has unmerged commits before deleting it.
- Switch to the main branch.
- Pull latest changes from remote.
- Close the GitHub issue.
- If the issue uses checkboxes, check off completed items.
- Comment on the issue with key findings or direction changes.
