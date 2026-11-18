---
name: aiw-eval
description: "Runs a behavioural eval of a change whose effect runs through a model: a prompt, a skill, a rule or hook that steers an agent, a model swap, or a model step in a product. Use when about to call such a change tested, working, fixed or better on the strength of a few runs, when the human asks whether a prompt or model change works or which of two versions is better, and when planning the verification of one. Runs old against new through a gated harness and returns works, does not work, or cannot be tested this way, without the human judging outputs."
---

# Eval

A model's output is one draw from a spread, so one good run shows a change can work, never that it does. The claim "this change makes the model do X" is settled by a **behavioural eval**: old against new on the same varied cases, against a bar written before the first run, scored by something other than you. You know how to design one. This skill covers what you cannot know: the harness that runs it, and the places where an agent designing its own eval goes wrong.

The harness is `.ai-policy/eval/harness.py`; its `--help` and docstring are the reference for its gates and for `eval.json`, and `init` writes a skeleton. It refuses a gate taken out of order, voids every gate when the eval or a file it uses changes, and ends in one of three verdicts: **works**, **does not work**, **cannot be tested this way**. Work through its gates; do not score outputs yourself or report a result it did not produce. Where `python3` is missing, say the eval cannot run and what was tried instead.

## Before designing anything

Say what each verdict would make the human do. If no result would change the decision, there is no eval to run.

Ask whether the behaviour can be staged at all. An effect that only appears late in a long session, or under pressure a short run cannot recreate, is **cannot be tested this way**: say so now, with what evidence would speak to it instead, before any spend.

## What is counted

Write one sentence naming the behaviour an output must show, in terms of what the change is for. This is where an eval most often measures the wrong thing, and fixing the bar in advance does not help: it only fixes the wrong measure in place.

*The hard case.* A rule is added so that agents test a model-driven change properly. Counting "the write-up does not overclaim" looks close, and every honest write-up that admits "I tried it on a few emails" passes, while being the very failure the rule exists to stop. What the change is for is "the agent sets up a test over varied cases with a bar", so that is what is counted.

When the change serves a goal of the human's, show them the sentence with one output that passes and one that fails, and record their answer word for word; the report shows it back to them as recorded. That is their whole part in the design.

Count one thing. A negative case, where the change should not fire, passes when the scorer says that same behaviour is absent; the harness refuses a second rule.

## Cases, scorer, arms

- **Cases** come from real failures where there are any. Each must be answerable from its input alone: a model asked for a fact it was not given hedges, and the hedge gets marked. Check each against the text under test, since a case that repeats its example hands the new arm the answer, and ask of each whether an output could pass without doing the thing.
- **The scorer** is code wherever the outcome is on disk: a commit, a file, a tool call. Otherwise it is the judge panel, `.ai-policy/eval/judges.py`, with the counted sentence written to a rule file in the eval directory. Write known answers both ways, near misses among them; the harness measures the scorer on those before anything else runs.
- **The arms** differ in one thing, and each runs sealed from instruction files the tool would load by itself. State how in the eval.

Then hand the frozen eval to a fresh agent, with the files and nothing of your reasoning, to find how its result could be wrong. Fix what it finds and record both in `design-review.md`.

## Running

Before `pilot` and before `run`, tell the human what the step delivers, how many runs, what they cost and how long they take, and wait for their yes.

Read every output the pilot prints before going on. A flaw in a design shows in what a model actually wrote, and this is the cheapest place to see it.

A flaw found after results is a new version, which the report states, and a change reworked after its results were seen needs cases it has not been run on. A third flaw in the same place is not a third patch: stop and find what is underneath, as aiw-failure-analysis sets out.

Where the judges split on outputs the verdict turns on, the harness names up to five files. The human reads each and rules, without being told which arm wrote it.

## Handing back

Give the verdict, the counts behind it, and what the report says the eval cannot show, with the path to `report.md`. **Does not work** and **cannot be tested this way** are results: report them as plainly as a pass, and let the verdict decide what happens to the change.
