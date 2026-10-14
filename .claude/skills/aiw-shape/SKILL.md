---
name: aiw-shape
description: "Shapes a request with the human before planning: shows cheap things to react to, such as mockups, directions side by side, a sample of the finished result, a spike, or smaller and bolder versions of the request, until they pick one, then records the pick and their reason on the issue. Use when the human asks to shape, sketch, mock up or explore a request, or asks what done should look like. When you cannot say what done looks like for a request, offer it in one line instead of planning, and never run it unasked."
---

# Shape

Read this file when the human asks to shape a request, or takes up your offer to.

## Why This Skill Exists

Done is usually unclear until the human sees it. Without shaping, the first thing they see is the pull request, the most expensive place to learn it was the wrong thing. People recognise wrong faster than they can describe right, so your job here is to give them something to point at.

## The Goal

Shaping ends when the human points at something and says "that". Everything before it is a move toward that point, chosen by what is most unclear right now, never taken in a fixed order, so two requests rarely open the same way.

A list of questions is the failure this skill exists to avoid. It hands the human the work of describing done, which is the part they cannot do yet. Show first; ask only what showing cannot settle.

## Moves

Pick the move that answers what is most unclear, and make it cheap.

- **Mockup.** A text sketch in the chat, or a clickable page where you can publish one, when the request has a surface someone looks at.
- **Directions side by side.** Two or three genuinely different takes, each with what it costs, when the approach is open.
- **A sample of done.** What the human would read or run when it is finished, such as the output, the report or the message, when the request is a behaviour rather than a screen.
- **Smaller, as asked, bolder.** The smallest version still worth having, the one asked for, and one they may not know is possible, each with what it costs. Finding the best version of the request is part of shaping, not a detour from it.
- **Spike.** When a direction turns on whether something is possible, try it in scratch space or a throwaway worktree, never committed. It is a throwaway prototype: the answer is what you keep, as "tried X, it works, or does not, because Y".

*The hard case.* "Make the status report better." Asking "better how, which metrics, what format?" puts the work back on the human. Show three one-screen sketches instead: the report trimmed to what changed, one led by a single verdict line, one as a table across weeks. They answer "the verdict one, but keep the table under it". That is a pick, and a better one than any of the three; a pick that combines or adjusts what you showed counts.

## Ending

When the human picks, write one line saying what done looks like, in their terms, and get their OK.

If two rounds pass with nothing picked, stop making variants, because more options do not help when the miss is in the framing. Say so, and ask what is missing.

## What It Leaves Behind

The shape is the chosen mockup or example, the done line, and the human's reason for the pick quoted word for word. If they gave no reason, record none rather than writing one for them. (Why: when the build meets a case the mockup does not cover, their reason settles it, and a paraphrase carries your reading instead.)

Put the mockup in a form the issue holds: text or a screenshot. A link to a published page is an extra, since it can go private or stale.

- **New request:** finish by filing the issue with aiw-issue-creation, the shape under a `## Shape` heading in its body.
- **Existing issue:** add the shape as a comment opening with a `## Shape` heading, because rewriting the body is the human's. A later shape replaces an earlier one.

Planning then starts from the shape as part of the request.
