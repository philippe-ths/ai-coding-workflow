---
name: aiw-north-star
description: "Structured process for authoring and updating `north-star.md`, a repository's record of what it would refuse, which the workflow consults as the oracle for questions of desirability that correctness cannot settle. Use this skill before any edit to that file, when the human asks to create, scaffold, revise, or test the north-star, and when the agent notices it has been overruled twice on the same kind of choice, which is the raw material an entry is made from. Phrasings include 'what is our north-star', 'the north-star does not cover this', 'you keep getting this wrong', and 'record that preference'. The skill exists to stop the artifact drifting into a mission statement: a north-star built from intentions rather than refusals decides nothing, and one fitted to the cases used to write it cannot be tested."
---

# North Star

Read this file before creating or editing `north-star.md`.

## Why This Skill Exists

The workflow can tell whether a change is correct. It cannot tell whether a change is wanted.

aiw-ground-truth gives correctness a trust hierarchy, a sourcing protocol, provenance rules, and modality-specific rules. Intent has none of them, so every question with two acceptable answers is resolved by interrupting the human. That is why the human's attention is spent at implementation altitude instead of on direction.

`north-star.md` is the intent oracle. Its job is to answer "which of these two acceptable options" without asking.

## A Refusal Decides; An Intention Does Not

This is the whole craft. Most interruptions are a choice between two options that are both fine, and only a refusal collapses that choice.

"Fast and simple" is an intention. Both options are usually fast and simple enough, so nothing is decided and the human is interrupted anyway.

"Better to do nothing than the wrong thing" is a refusal. It settles whether to degrade or fail loudly, whether to auto-apply or ask first, and whether to guess a malformed input's format or reject it. One line, three decisions, no interruption.

Write every entry so that it rules something out. An entry that rules nothing out is decoration, and decoration in an oracle is worse than an empty file, because the agent will consult it and proceed on nothing.

## Trust Hierarchy for Intent

Rank every candidate entry by where it came from. Highest first:

1. A refusal the human actually made, in a situation on the record.
2. A refusal the human stated in the abstract.
3. A preference the human stated.
4. An intention or an aspiration.
5. Anything the agent inferred from the code.

Rank 1 is the only rung with real authority. Ranks 4 and 5 are how a north-star becomes a mission statement, and rank 5 is circular: the codebase is what the north-star is supposed to judge.

Record each entry's rank and the decisions it came from. Provenance is not bookkeeping here. It is what tells a later reader whether the entry earned its place, and it is what the predictive test is run against.

## The Altitude Test

An entry should speak about the project's character and still settle code-level questions.

Too low and it is a coding convention. "Never add a dependency to save fifty lines" belongs in project context or a lint rule; it names code, applies to one situation, and teaches nothing about the next.

Too high and it settles nothing. "Build quality software" is not wrong, it is inert.

The test: does this entry decide a question you did not have in mind when you wrote it? If it only decides the case it came from, climb.

## Authoring: Build It From Corrections

An aspirational north-star is worse than none, because the agent follows it and produces something that does not fit the human. Corrections are evidence; imagination is not.

- Gather the record of the human overruling the agent: logged failure entries, review threads, and the corrections the human has stated directly.
- Look for the same refusal appearing in different clothes. A refusal that shows up in three unrelated situations was never about those situations, and that is an entry.
- Write it as the refusal, not as the situations it came from.
- Keep the set small enough to hold in mind. A north-star with thirty entries is a style guide, and nothing consults a style guide at decision time.

## The Predictive Test

A north-star that cannot predict past calls will not predict future ones. This test is what stops it becoming a mission statement, and it only works if it is set up before the drafting starts.

**Split the corrections before authoring anything.** One part is the material entries are written from. The other is held back, unread, and is the test. A draft fitted to the cases used to write it will predict those cases, and the resulting figure is not evidence of anything.

Then: take the held-out decisions, ask what the draft north-star would have decided, and compare against what was actually decided.

Report hits and misses separately, and name each miss. Misses are the useful half. A north-star that decides confidently and wrongly is worse than no north-star, because under any reduced-interruption workflow it decides unattended.

Where the test was run inside a repository whose product is its own process, say so with the result. What passes there validates something narrower than a north-star for a repository that ships a product to users.

## Updating

Every time the human overrules the agent, that is a rank 1 correction and the raw material for an entry. Two overrules on the same kind of choice is the signal to open this skill; one is an instance.

When a plan's stated intent carries the same refusal for the third time, it was never specific to those pieces of work. Promote it.

An entry can also stop being true, because taste changes. Retire it rather than editing it into something vaguer, and keep the provenance of what replaced it. A vague entry is an entry that has stopped deciding.

## Anti-Patterns

- **The mission statement.** Every entry is rank 4, nothing is ruled out, and the agent consults it and asks the human anyway.
- **The style guide.** Thirty entries at coding-convention altitude. The set is too large to consult and too low to generalise.
- **Fitted to its own test.** Authored from the same cases it is scored against, then reported as a hit rate.
- **Inferred from the codebase.** Rank 5 dressed as rank 1. The north-star exists to judge the codebase, so it cannot be read out of it.
- **Silence treated as permission.** Where the north-star has no entry, the question is still open and still goes to the human. An oracle that answers everything is not an oracle.
