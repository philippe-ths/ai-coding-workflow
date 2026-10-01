---
name: aiw-upkeep
description: "Works one upkeep issue the human did not choose: picks the oldest open `aiw:upkeep` issue, checks it is still upkeep within the limits, runs it through the Task Flow and hands back a pull request. Use when the human or a scheduled run asks for upkeep, such as 'do upkeep' or 'work an upkeep issue'. Not for an issue the human assigned, which follows the ordinary Task Flow."
---

# Upkeep

Read this file when asked to do upkeep. You are working an issue nobody chose, often with nobody there to ask, so the job is to stay inside what upkeep is and hand the result back where the human will see it.

## Pick

- Work nothing when the project already has an open pull request labelled `aiw:upkeep`, or the working tree has uncommitted changes; say which. (Why: two upkeep branches in one repository conflict, and a dirty tree is someone's work in progress.)
- Take the oldest open issue labelled `aiw:upkeep` that carries neither `aiw:direction` nor `aiw:close-proposed`, has no open pull request, and has no upkeep pull request closed without merging. If none qualifies, say so and stop.

## Check Before Writing

Predict what the fix will touch. If it reaches anything on aiw-planning's Full list, an Ask First item in `ai-workflow.md`, or CI, it is not upkeep you may work: add `aiw:direction`, comment what it reaches, and pick again.

## Work It

Branch from the default branch as it is on the remote, run the Task Flow from task start, and when you finish put the checkout back on the branch it was on. Two things differ:

- The plan is agreed at the pull request, not before or during the work: write it at the top of the body, where the human judges plan and work together at merge. (Why: upkeep needs no taste or direction, so review at merge protects everything agreement beforehand would.)
- Remove only tracked files, each as a tombstone: the pull request lists its path with `git checkout <sha> -- <path>`, the SHA being the commit your branch started from.

Label a finished pull request `aiw:upkeep`.

## When the Work Needs the Human

Wherever the workflow would stop for the human, stop there instead of deciding for them: the tier rising to Full, an Ask First item or a choice a skill reserves for them, a conflict you cannot resolve without one. Keep the work, and leave the checkout clean and back where it was:

- If validation passes on what you have, commit, push, and open a draft pull request labelled `aiw:direction`, whose body says what stopped you, that the rest is unverified, and that no aiw-prompt-smith pass ran.
- If it does not, stash it with everything untracked under a message naming the issue (`git stash push -u -m "aiw-upkeep #<n>: <reason>"`), and push the branch only if it already holds commits.

Then add `aiw:direction` to the issue and comment what stopped you and where the work is: the draft, the stash, or the branch. (Why: a stopped run that leaves changes in the tree blocks every later run, since upkeep never starts on a dirty tree.)

## Hand Over

Report the pull request, or why nothing was worked, and name every issue you touched.
