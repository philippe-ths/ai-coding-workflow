---
name: aiw-github
description: "Rules for every GitHub and git history action during a task: starting work on an issue, switching branches, rebasing, committing, pushing, opening a pull request, post-merge cleanup, and handling parent and sub-issue hierarchies. Use this skill whenever the agent is about to read a GitHub issue at task start, create or switch to a branch, run a rebase, create a commit, push to remote, open a pull request, or run post-merge cleanup, even if the user does not name the action explicitly. Also use when the agent encounters a parent issue with sub-issues, when a deterministic policy hook blocks a git action, or when the agent suspects new commits have landed on the target branch since the last rebase. The skill exists to keep GitHub actions traceable to an issue, taken at the right point in the task, safe against silent working-tree loss during branch operations, and short of the one action that stays the human's: the merge."
---

# GitHub Workflow

## Why this skill exists

GitHub actions touch shared state. Each one becomes visible to others the moment it lands. Branch operations can silently lose untracked files. Issues anchor scope; without one, work drifts and commits lose traceability. This skill keeps each action anchored to an issue, taken only after the done gate, and safe against working-tree surprises. The human's part is the merge, and the policy layer blocks the agent from it deterministically; nothing else in this skill waits for their word.

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
- Check whether `.archive/` holds anything. It is ignored, so it survives a checkout but not a `git clean -fdx`, and nothing in `git status` will mention it first.
- If either check reveals unexpected files or path overlap, stop and report before proceeding.
- If the human approves, back up the working tree (excluding `.git/`) before the operation.
- Delete the backup after confirming no files were lost.
- If a rebase produces modify/delete conflicts, stop and discuss with the human before resolving.

## Commits, pushes, and pull requests

Commit, push, and open the pull request yourself, without asking, once the done gate (aiw-verification, aiw-validation, aiw-housekeeping) has run for the work. (Why: an issue-scoped branch and its pull request reach nobody until merged, the merge is blocked to the agent by the policy layer, and the pull request is where the human's done decision starts rather than a step they authorise on the way to it.)

- Commit as the work reaches a coherent state; do not hold a task's changes for one commit at the end.
- Push and open the pull request when the pre-pull-request checks below pass. Do not push work the done gate has not covered.
- Post evidence that was deferred in the justification on the task's own pull request when it arrives. Commenting on any other pull request stays the human's.
- After opening the pull request, stop and report: the link, the justification's unverified surfaces, and what the human is now deciding.
- Never merge a pull request, and never work around the hook that blocks it.

## Pre-pull-request readiness

Before the first push, check:

- Confirm aiw-verification's justification step has been completed for the work in this PR, and that the pull request body carries it. Pass the body from a file rather than leaving it to an editor or to commit messages, because the policy layer reads it there and blocks a body it cannot read. (Why: a pull request without a completed verification justification is a pull request opened on unverified work. Completed means every surface part 3 names has a resolution, not that every check has already run. See aiw-verification for the justification step itself.)
- Confirm the body carries aiw-validation's line: the deliverable, and how it was met. Confirm it carries aiw-housekeeping's line too: what was removed or moved, or that nothing was. (Why: a check that leaves nothing behind cannot be told apart from a check that was skipped, and the human decides after the pull request is open, not before.)
- Scope what the body claims to the evidence that exists as you open it. Evidence you intend to gather is deferred in the justification, named with its method, never written up as though it has already run; post it on the pull request when it arrives, before the human's done decision. (Why: opening a pull request is not the done decision, so the pull request is part of the verification surface rather than the end of it.)
- Whether documentation or README files need updating based on the change.
- Whether the branch changed what `project-context.md` records, and if so refresh it with the aiw-project-context-management skill.
- Whether version numbers need updating.
- Whether a tagged release is needed.
- Parent and sub-issue closure status.

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
