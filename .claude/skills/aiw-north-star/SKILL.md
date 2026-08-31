---
name: aiw-north-star
description: "Structured process for authoring and updating `north-star.md`, a repository's high-altitude statement of the goal it is trying to achieve and the restrictions it must stay inside. Use this skill when the human asks to create, scaffold, revise, or check the north-star, with phrasings like 'what is this project for', 'set up a north-star', or 'is that still our goal'. Use it also, and without being asked, when a request that has just arrived would break the stated goal or a restriction, before any planning happens: that conflict means either the request is wrong or the goal has moved, and neither is the agent's call. The skill exists because a project's direction is the one thing no oracle can derive: the codebase shows what is, the spec shows what is asked, and neither says what the project is for or what it must never become."
---

# North Star

Read this file before creating or editing `north-star.md`, and when a request conflicts with what it says.

## Why This Skill Exists

The workflow knows what the system does, because the codebase says so. It knows what the system should do, because the spec says so. It knows what the system currently is, because `project-context.md` says so.

Nothing says what the project is *for*, or what it must never become. So every judgement that turns on the project's direction is resolved by interrupting the human, and the human ends up spending their attention on implementation instead of on direction.

`north-star.md` holds exactly two things: the goal, and the restrictions.

## What Goes In

**The goal.** What the project is trying to achieve, in one statement. It names the outcome, never the mechanism. A reader who knows nothing about the implementation should be able to tell from it whether a proposed piece of work belongs here.

**The restrictions.** What the project must never become, must never require, or must never give up. These are what make the goal decisive, because a goal on its own can usually be honoured in two opposite ways and settles nothing between them.

Both are the human's. The agent writes the file and the human is its source of truth, the same division `project-context.md` already uses with the codebase.

## Altitude

`project-context.md` has an Important Constraints section. Everything in it is a *consequence* of a restriction, and the difference between the two files is exactly that gap.

"`project-context.md` must stay under 300 lines" is a constraint. The restriction that produced it is that an agent has to carry the whole governance layer in context alongside the work it is doing. The constraint names a number; the restriction explains why a number exists and would still guide you if the number changed.

The test, in both directions:

- If a restriction names a file, a number, a command, or a tool, it has fallen to constraint altitude. Climb until it explains the constraint instead of repeating it.
- If a restriction rules out nothing a reasonable person would otherwise have proposed, it is decoration. Descend until it excludes something real.

Keep the set small. Restrictions that never bind are noise, and a long list is a sign they have drifted down to constraint altitude.

## Authoring: Interview, Confirm, Write

Never write this file from inference alone. The codebase cannot tell you the goal, because the goal is why the codebase looks the way it does, and reading intent out of an artifact is circular.

1. **Prepare.** Read `project-context.md` and enough of the repository to form a candidate goal and candidate restrictions. Bring these to the interview. Starting the human from a blank page wastes the one thing the agent can genuinely do here.
2. **Interview.** Put questions to the human one at a time, most consequential first. Ask what the project is for, what it must never become, and what they would turn down even when it would work.
3. **Confirm.** State the goal and each restriction back in plain terms and get explicit agreement on each. A restriction the human has not affirmed is the agent's guess wearing the human's authority.
4. **Write.** Record each restriction with what it rules out, so a later reader can tell whether it still binds.

Questions that work ask for a boundary: what would you turn down, what would make you abandon this, what would you refuse even if it were free. Questions that fail ask for a summary, because a summary of a project is its description and this file is not a description.

## When a Request Conflicts

A request that would break the goal or a restriction is a signal, not an obstacle. It means one of two things is wrong, and the agent can determine neither.

Act on it when the request arrives, before planning. Planning around a conflict resolves it silently in favour of the request, and by the time a plan exists the conflict has already been designed away.

- **Stop.** Name the goal or restriction, and say specifically how the request meets it.
- **Ask.** Put it to the human: the request may be wrong, or the north-star may have moved.
- **Update, or proceed.** If the north-star moved, interview and confirm the change and rewrite the file before the work starts. If the request was wrong, the human says so and the file stands.

Do not soften a restriction to fit a request. A restriction quietly rewritten to permit the thing in front of you has stopped being a restriction, and nothing will ever conflict with it again.

## Updating

The goal changes rarely. When it does, it is because the project became something else, and that is worth recording rather than smoothing over.

Restrictions change more often, and each change is the human's to make and to confirm. Retire one outright rather than editing it into something vaguer, because a vague restriction binds nothing and still looks like governance.

## Anti-Patterns

- **The description.** The goal restates what the project currently does. It was read out of the codebase, so it can never judge the codebase.
- **The mission statement.** A goal nobody could disagree with, and no restrictions. It excludes nothing.
- **The second constraints section.** Restrictions at the altitude of `project-context.md`'s constraints, duplicating them and drifting from them separately.
- **The silent resolution.** A conflicting request gets planned, and the conflict surfaces at review, or never.
- **Inferred and unconfirmed.** The agent wrote a plausible goal, the human never affirmed it, and it now decides things on their behalf.
