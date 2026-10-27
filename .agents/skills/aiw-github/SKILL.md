---
name: aiw-github
description: "Rules for git and GitHub actions during a task: reading the issue at task start, creating or switching branches, rebasing, committing, pushing, opening a pull request, closing an issue, post-merge cleanup, and parent and sub-issue hierarchies. Use whenever about to take any of these actions, even if the user does not name it, and when a policy hook blocks a git action or new commits may have landed on the target branch."
---

# GitHub Workflow

## Why this skill exists

GitHub actions touch shared state. Each one becomes visible to others the moment it lands. Branch operations can silently lose untracked files. Issues anchor scope; without one, work drifts and commits lose traceability. This skill keeps each action anchored to an issue, every one that reaches the remote taken only after the done gate, and safe against working-tree surprises. The merge is the human's, and the policy layer blocks the agent from it deterministically.

## Starting work on an issue

- Confirm the GitHub issue number before any other action.
- Read the issue body and the issue comments. Comments often carry scope changes, clarifications, and constraints not in the original body.
- Gather the request: the human's own words for this task, verbatim. They are the issue's `## Request` quote, the issue body where a person rather than an agent wrote it, and what they said in the conversation. Where the issue records a `## Shape`, in its body or a comment, the latest one adds their quoted pick, reason and OK, and beside the OK the done line it approved, unquoted and labelled as agent-written. Where any of it exists only in the conversation, add it to the issue as a comment, and do the same with each correction they give during the work, each reply beside what it answered, so the words outlive the session and still read alone; leave out anything they would not want in the tracker, and mark where you did. Anything an agent wrote about them, the rest of an agent-drafted issue and your plan included, is a reading of the request, not the request.
- If the issue has sub-issues, treat the parent as broader context. Stop and ask the human which sub-issue to work on. Do not implement the full parent scope.
- If the issue is a sub-issue, read the direct parent issue and its comments for context. Do not read further up the hierarchy.
- When completing a sub-issue, check whether it is the last open sub-issue under the parent. If it is, flag this to the human.

## Branch protection and naming

- Never work directly on `main` or `master`.
- Create or switch to an issue-scoped branch before planning, editing files, or making commits.
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

Commit at the end of each implementation loop, as Task Flow step 4 in `ai-workflow.md` sets out, without asking. Stage the files the loop changed by name rather than everything in the tree, so build output and stray files do not ride into a checkpoint. Where the repository's commit gate needs a full validation run, a commit costs that run, so commit at the loops worth returning to. Push and open the pull request yourself, without asking, once the done gate (aiw-verification, aiw-validation, aiw-housekeeping) has run for the work. (Why: an issue-scoped branch and its pull request reach nobody until merged, the merge is blocked to the agent by the policy layer, and the pull request is where the human's done decision starts rather than a step they authorise on the way to it.)

- Push and open the pull request when the pre-pull-request checks below pass.
- Post evidence that was deferred in the justification on the task's own pull request when it arrives. Commenting on any other pull request stays the human's.
- After opening the pull request, stop and report: the link, the justification's unverified surfaces, and what the human is now deciding.
- Never merge a pull request, and never work around the hook that blocks it.

## Pre-pull-request readiness

Before the first push, check:

- Confirm the body carries a `## Request` section quoting the request gathered at the start, corrections included, verbatim as `>` lines, and only words about this task, marking with "[…]" where you cut a message. It must read alone beside "What changes for the user": before each quote that replies to something you put, write what it answered on a plain line, not bold and not a heading, so it reads as yours and the hook keeps reading the section: the question or proposal and its options as you put them at the time, naming the one you recommended ("Asked where the horizon lives, recommending a line in `north-star.md`:" then "> ok north-star.md line"). After a quote that points elsewhere, such as "let's do #371", quote the human's words that issue holds; where an agent drafted it with no `## Request`, give its goal on a plain line instead. Where no human asked, as in an upkeep run, say so there and quote the issue. The pull request hook blocks a body without the section. (Why: the human's words are read once at the start and every later step checks the nearest translation of them; quoted in the body beside the result, a gap between the two is in front of you and the human at once. A bare "yes" or "a) (Recommended)" shows no gap, because nobody can tell what it agreed to.)
- Confirm the body's account of the change is a section headed "What changes for the user", listing what the user aiw-validation's end impact names can now do, see, or rely on, in that user's terms rather than the files' ("audits stop flagging an empty worktrees directory", not "`project-checks.md`: an empty worktrees directory is normal"). There is no separate list of files; name a file inside a bullet only where it helps the review. (Why: the human reads the body to decide, and a summary of files makes them work out the effect before they can judge it.)
- Confirm aiw-verification's justification step has been completed for the work in this PR, and that the pull request body carries it. Pass the body from a file rather than leaving it to an editor or to commit messages, because the policy layer reads it there and blocks a body it cannot read. (Why: a pull request without a completed verification justification is a pull request opened on unverified work. Completed means every surface part 3 names has a resolution, not that every check has already run. See aiw-verification for the justification step itself.)
- Confirm the body states the ceremony tier and its source from aiw-planning, any move up a tier during the work, and the plan's approach with each direction decision in it and who settled it: `north-star.md` or the human. (Why: the human judges the plan with the work at the pull request, and the tier is the account of how much process the task was given; neither is readable afterwards unless written down.)
- Confirm the body carries aiw-validation's line: the deliverable, how it was met against the `## Request` section, and the end impact as delivered and for which user. Confirm it carries aiw-housekeeping's line too: what was removed or moved, or that nothing was. (Why: a check that leaves nothing behind cannot be told apart from a check that was skipped, and the human decides after the pull request is open, not before.)
- Scope what the body claims to the evidence that exists as you open it. Evidence you intend to gather is deferred in the justification, named with its method, never written up as though it has already run; post it on the pull request when it arrives, before the human's done decision. (Why: opening a pull request is not the done decision, so the pull request is part of the verification surface rather than the end of it.)
- Whether the branch changed agent-facing prose: a skill, an agent prompt file, `ai-workflow.md`, an entry point (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`), or a file one of those pulls in with an `@` line. If so, aiw-prompt-smith has run over those files and the body records what it found, even when that was nothing to change; the pull request hook blocks a body without that record wherever it can read the branch. (Why: a probe or a reviewer answers the questions it is asked, while prompt-smith reads the artifact against itself.)
- Whether documentation or README files need updating based on the change.
- Whether the branch changed what `project-context.md` records, and if so update it with the aiw-project-context-management skill.
- Whether version numbers need updating.
- Whether a tagged release is needed.
- Parent and sub-issue closure status.

## Deterministic policy hooks

- If Git `core.hooksPath` is not `.githooks`, run `./.ai-policy/scripts/install-hooks.sh`.
- If deterministic policy blocks an action, fix the blocked condition before retrying. Do not bypass the check or treat it as optional.
- If repo-local policy requires a passed validation state before commit or push, satisfy that requirement through the repository's validation flow.

## Closing an issue

An issue that should close for any reason but completion stays open: add a comment saying why and what it points to (the duplicate, what superseded it, or the commit that already fixed it) and the `aiw:close-proposed` label, creating the label if the repository lacks it. The human closes it or removes the label. (Why: a closed issue stops being seen, so a wrong close is lost where a wrong proposal is one line in a list the human reviews in one pass.)

## Post-merge cleanup

After the human merges the pull request:

- Check whether the local issue branch has unmerged commits before deleting it.
- Switch to the main branch.
- Pull latest changes from remote.
- Close the GitHub issue if the pull request completed it, judged from its body and the issue's comments; leave open an issue whose pull request or latest comment names a remainder, and reopen it if the merge closed it.
- If the issue uses checkboxes, check off completed items.
- Comment on the issue with key findings or direction changes.
