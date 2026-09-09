---
name: aiw-housekeeping
description: "Makes keeping the project clean and well organised a step in the workflow rather than something that happens when someone notices. Use this skill at the done gate, third after aiw-verification and aiw-validation, before presenting any work for the human's done decision, and on every task including one that set out to remove or move nothing. It asks whether anything the task caused should now be removed or moved: a code path the change orphaned, a file the work left behind, a thing sitting in the wrong place. It owns the footprint that bounds what may be acted on, the tiering that sets what evidence a removal needs from how far the thing reaches rather than how large it is, the archive that makes removal recoverable, and the disposition of mess found outside the boundary. It does not define the searches themselves; aiw-ground-truth owns the oracle for a delete and aiw-verification owns the dependency search that establishes it."
---

# Housekeeping

Read this file at the done gate, after aiw-verification and aiw-validation, before presenting work for the human's done decision.

## Why This Skill Exists

The workflow already knows how to remove things safely. aiw-ground-truth gives a delete its oracle, the absence of remaining dependencies. aiw-verification's Delete modality gives that oracle its search. ai-workflow.md says what to do with a finding outside the task.

Every one of those fires only once the agent has already decided to remove something. Nothing asks. So a task ends with the paths it killed still standing, because removing them was never anyone's job at the moment they died.

That moment is the cheap one, and it is the only point where someone still holds the reason the thing became dead. A session later a dead path and a deliberate extension point are indistinguishable, and telling them apart costs more than the mess does. What is not removed then is removed in a sitting, or never.

This skill is the asking. It adds no rules about how to remove; it delegates that.

## The Footprint

Act on what this task caused, and nothing else. That is:

- the files this branch changed, committed or not: `git diff --name-only "$(git merge-base HEAD <target-branch>)"`
- the untracked files present: `git status --porcelain -uall`
- whatever those changes left with no remaining reference, reached from the diff rather than by browsing

Use that first command rather than the three-dot `main...HEAD` form. At the done gate the work is usually still uncommitted, because commit is the next step and not this one, and the three-dot form compares commits: it reports the committed part of the branch and silently omits everything staged or unstaged, which on this step is most of it.

Untracked files that predate the branch are outside, and so are ignored files. Build output and caches are held by whatever produces them.

The third bullet is where most of the work is, and a boundary drawn on the first two alone would miss the case this skill exists for. Orphaning happens in a file the change never opened: the caller goes here, the callee dies there.

It reads rather than runs, but it is still a procedure rather than an instinct: take the names the diff stopped calling, importing, reading, or passing, and search for each one. What comes back with only its own definition is the candidate. Skipping this bullet is skipping the skill, whatever the first two returned.

Everything else is outside this step. It is not untouchable, and the standing rule in ai-workflow.md still governs what becomes of it; what it is not is housekeeping you do now under this skill. (Why: a done-gate step permitted to act anywhere puts unrelated change in every pull request, and the human reviewing one cannot then tell the task from the tidying.)

The boundary is on what you act on, not on what you notice. What you noticed while doing the work still counts, and this is not a licence to go browsing the repository for more.

## What to Look For

Three questions, asked of the footprint:

1. **Does anything here now have no reason to exist?** A function whose last caller this change removed. A branch it made unreachable. An import, a fixture, a flag, a config key that nothing reads any more. Orphaning is a side effect of a change that meant to do something else, which is why nobody notices it.
2. **Did this task leave anything behind?** A scratch script, intermediate output, a draft superseded by the thing that replaced it, a file that was only ever going to be temporary.
3. **Is anything here in the wrong place?** A file under a directory that does not own it, a rule in a document that does not own it, a helper far from its only caller.

A task that answers no to all three is finished. Say nothing about it in chat; the line in the pull request body is still written, because that is the record that it ran.

## Removing and Moving

What a removal costs is set by how far the thing reaches, not by how large it is. Size is a judgement you can talk yourself past at the end of a long task; reach is a property of the thing.

- **Nothing outside the working tree can refer to it.** An untracked file this task produced, or one only this branch added. Evidence: that provenance, and no reference to it. Archive it if untracked, delete it if tracked.
- **References are inside the repository and can be found by searching.** A private function, a branch made unreachable, an import, a fixture, a local constant. Evidence: aiw-verification's dependency search across the repository, including dynamic references, and the repository's own checks green both before and after. Both, because a search over names cannot see a behavioural reference: a test that asserts what a helper does through its caller names the helper nowhere, and the search comes back clean on code the suite is holding up. An orphan whose behaviour something still asserts is not an orphan, it is a regression with its evidence still standing.
- **Something outside the repository could refer to it.** An exported symbol, a published interface, a config key, a command-line flag, a documented path, state the code installed elsewhere. This is a delete in aiw-ground-truth's sense, and the task has acquired that modality: aiw-verification's Delete requirements apply in full, including the sweep for state outside the repository. It is also an Ask First under ai-workflow.md, because removing it changes a contract even when the path is unreachable. Narrowing a signature is the common case.

The tier names the evidence. Produce it and remove the thing; fail to produce it and leave the thing, naming what the search returned rather than asserting you were unsure. There is no third move where the evidence is weighed against how much the mess is worth, because that trade always resolves the same way on a small mess at the end of a long task.

A move updates the references rather than expecting them to be absent, and carries one hazard a delete does not. Where a reference resolves by convention rather than by path, moving the file changes what an unchanged reference points at, and nothing in the diff shows it: an import found on a search path, a fixture located by directory, a template or asset found by name. Exercise those after the move rather than reading them.

Then put what you removed or moved back through aiw-verification's justification step, and where it touched the deliverable or anything the deliverable depends on, back through aiw-validation's first two questions: that it still exists, and that it still does what was asked. Question one alone passes a move that broke a convention-resolved reference, because the file is there, at the new path. (Why: this step runs after both of them, so its own changes are the one part of the tree nothing has checked, and a move can relocate the very artifact validation just confirmed.)

## Outside the Footprint

Mess outside the footprint is a finding, not housekeeping. Give it the disposition ai-workflow.md's resolve-or-track rule calls for, and read that rule there rather than here.

Where there is no tracker to file to, saying so is the disposition. What is not a disposition is the bare list with nothing decided, because that is work moved to the human rather than a finding reported to them.

## The Archive

Removal feels permanent, and an agent that believes that behaves timidly. For a file that is in a commit the belief is simply false, and the answer is the fact rather than a mechanism: git holds that version, and `git checkout <commit> -- <path>` brings it back. Say so, and delete the file. A second copy on disk is worse than history, because it is invisible in review and a later search cannot tell it from live code.

The axis is whether it is in a commit, not whether it is tracked. At this step the task's work is usually not committed yet, so a file this task added and staged is held by nothing at all, exactly like an untracked one, and `git checkout` recovers nothing for it. Treat it as the case below.

Files no commit holds are the real case. Nothing holds them, so deleting one is irreversible.

Move those to `.archive/<issue>/<original path>` rather than deleting them. Where the task has no issue, use the branch name with any `/` replaced, so a name like `feat/thing` does not become two directories. Create `.archive/` on first use with a `.gitignore` inside it containing a single `*`. The pattern matches that file too, so the directory is invisible to git and needs no entry anywhere else.

Keep the original path. An archive that does not record where a thing came from is a junk drawer, which is the mess in a new location.

The archive buys a session, not permanence. It is untracked and ignored, so `git clean -fdx` removes it without warning and nothing in `git status` will mention it first. It converts a delete that is irreversible now into one that is recoverable while the work is still in front of you, and it is not the place to leave anything you would mind losing.

That is also why it does not accumulate quietly. aiw-init reports what is sitting in it at session start; deciding what happens to each thing is the human's, and the report is what puts it in front of them.

## What It Leaves Behind

One line in the pull request body, beside the verification justification and validation's line: what was removed or moved and under which tier, or, where nothing was, the names the diff stopped referring to and what the search returned for each. (Why: this is the one of the three whose ordinary outcome is that nothing happened, which makes it the one where running it and skipping it look identical. A line that only asserts you looked is one a skipping agent writes just as easily and just as fast; a line naming what the search returned is one only a real pass can produce.)

Name anything archived on that line as well. Archived files are invisible to git before and after, so nothing else records them.

Where the task's work is already committed, put these changes in a commit of their own, so the removal reads on its own. Where it is not, which is the common case at this step because commit is the next one, they land inside the task's commit and the line above is the only thing telling a reviewer the task from the tidying.

## What It Costs

Opening the footprint is two git commands. They list files on any task that changed one, so a non-empty result is the normal case and carries no signal. The third bullet is the part that takes reading rather than running, and what it returns is not predictable from the size of the diff: a one-line change that deletes the last call site orphans as much as a large one.

The floor is one pass of the three questions over the footprint, on every task. Resource Discipline sets how hard you look past that, never whether you look. Above the floor the cost is the tier's evidence, and the tiers are arranged so the common case, a file this task made, costs almost nothing.
