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

Predict what the fix will touch. If it reaches anything on aiw-planning's Full list, a direction decision, a new dependency, or CI, it is not upkeep you may work: swap `aiw:upkeep` for `aiw:direction`, comment what it reaches, and pick again. Splitting a file without changing behaviour reaches only that file and this repository's imports of it, however many areas those sit in, unless the file is itself on the Full list or code outside the repository imports it.

## Work It

Branch from the default branch as it is on the remote, run the Task Flow from task start, and when you finish put the checkout back on the branch it was on. One thing differs:

- Remove only tracked files, each as a tombstone: the pull request lists its path with `git checkout <sha> -- <path>`, the SHA being the commit your branch started from.

Label a finished pull request `aiw:upkeep`; one that does not complete its issue also follows the last paragraph of When the Work Needs the Human.

## When the Work Needs the Human

Wherever the workflow would stop for the human, stop there instead of deciding for them: the work reaching anything on aiw-planning's Full list, a direction decision, an item under The Human is Responsible For or a choice a skill reserves for them, a conflict you cannot resolve without one. Keep the work, and leave the checkout clean and back where it was:

- If validation passes on what you have, commit, push, and open a draft pull request labelled `aiw:direction`, whose body quotes the issue under `## Request` and says what stopped you, that the rest is unverified, and that no aiw-prompt-smith pass ran.
- If it does not, stash it with everything untracked under a message naming the issue (`git stash push -u -m "aiw-upkeep #<n>: <reason>"`), and push the branch only if it already holds commits and validation passes on them.

Whenever a run ends with its issue not complete, whether it stopped or shipped a pull request that does part of the issue, and whatever the reason for leaving the rest, swap the issue's `aiw:upkeep` for `aiw:direction` and comment what remains and where the work is: the pull request, the draft, the stash, or the branch. A pull request that does not complete its issue says so in its body, names the remainder, and refers to the issue without a closing keyword such as `Closes #<n>`, in its body or any commit message. (Why: a later run takes any issue still labelled `aiw:upkeep`, so it would pick up exactly what was handed to the human, and a closing keyword would close the issue on merge with the remainder in it. A stopped run that leaves changes in the tree blocks every later run, since upkeep never starts on a dirty tree.)

## Hand Over

Report the pull request, or why nothing was worked, and name every issue you touched.
