# How Uplift placed its judgement in the wrong context layers

Investigation for issue #298, run 2026-09-16. Subject: `philippe-ths/site-uplift`, 110 pull requests, 10 August to 15 September 2026.

**Answer: the pipeline was built to make honest pictures, and it does. The judgement that decides what to propose was never given a home, so it ended up as prose scattered across always-on files written for a human, and prose at that altitude produces cautious, schema-shaped work. Nothing in the workflow asked, at any of the four moves that built this architecture, which layer the instruction belonged in or who would be reading it. The failure was found only by interrogating the system about its own process.**

In the human's words, the system was optimised for nothing: wrong audience, leaky context, poor architecture, no observation, no awareness.

## What was seen

Three runs of the findings step, the same tooling each time, recorded in the project's `agents/runs.md`:

| date | site | context | run tokens | tool uses | first finding | verdict |
|---|---|---|---:|---:|---|---|
| 2026-09-14 | everestspice.co.uk | primed session (#279) | not recorded | not recorded | a restyled hero | what was wanted, per the human |
| 2026-09-14 | thescubaschool.co.uk | clean, `frontend-design` skill loaded, method as written | 155,924 | 53 | a copy line and a button | small |
| 2026-09-15 | thescubaschool.co.uk | clean, `frontend-design` loaded, method rewritten | 174,113 | 49 | course page restyle inside the site's own palette | timid |

The tooling handled all three. The difference was entirely what the findings step was told and where it was told it.

## How the architecture got there

Four moves, each sound on its own terms, none of which asked the placement question.

### Move 1. A method written for a human, handed to an agent unchanged

PR #6 (10 August) wrote the playbook for a person running a review. Every phrase later found steering the step small is in it: `01-walk.md` "Step 6 is the technique that earns the fee", `02-diagnose.md` a finding "names one thing on one screen", `README.md` "small design and UX improvements". The auditor role was the human's, written down before an agent was in the loop.

By 23 August (#36 to #113) the playbook was about 1,700 lines across four phases, all bookkeeping for a manual process.

The M1 to M5 rebuild (#142 to #165, 2 to 4 September) replaced the manual process with a deterministic pipeline. M5 (commit `60f1dce`) deleted the playbook and, in its own words, carried "the judgement that survives" into `README.md` as a one-page method, with the belief walk "carried over in full" because "it is the technique that earns the fee". The audience changed; the prose did not. A human reads "one thing on one screen" as a tip. A model reads it as a constraint. The PR body still said "a person writes `findings.json` and the patches, and that is the work": the agent was not yet expected to propose anything, so nobody wrote what it should be when it did.

### Move 2. Judgement placed by plumbing, not by layer

The first real report (#185, karenmcclure.co.uk, 6 September) read as "a list of faults" (#193). The human asked for "writing rules or even better a project skill". The skill was declined because `.claude/` was gitignored and installer-managed, so a skill there would be neither committed nor safe. The rules went instead into `sites/README.md` (#194, section "How to write the parts a client reads"), 112 lines next to the field tables of the file reference. Where an instruction lived was decided by what git could track.

### Move 3. A budget on one file, so prose flowed to the unmeasured ones

#224 (8 September) put a token ceiling on `project-context.md`. #226 met it partly by moving prose into other agent-facing files. #223, filed the same day from an adversarial review, named the leak: the budget "is a gradient rather than a limit", and `sites/README.md` at 51,000 bytes was one of the files nothing weighed. #223 is still open. The always-on layer had a ceiling in the one place it mattered least.

`sites/README.md`, born as a capture-tool reference at 184 lines (#142), reached 762 in three days (#165), 1,026 by 8 September, peaked at 1,152 (#268), was cut to 906 (#274) and stood at 937 when the runs above were made.

### Move 4. A mode defined as files, not roles

#228 (9 September) made the agent the operator. Work Mode is defined as which files load (`north-star.md`, `README.md`) and which skills are parked (all but `aiw-issue-creation`). `sites/README.md` is "read it when you need a field". The findings step is one line, "write findings.json from the pictures, the HTML and browser.json", with five of the ten minutes. No design skill loads at any step. Nobody wrote who the agent is when it writes findings, so the step took its role from the schema it was filling: severity, step, one device, one selector.

### The outcome was named on 9 September and sat open through fourteen PRs

#239, filed the day Work Mode landed, quotes the human: "I expected the design skill to be used a lot in this project, not just for mockups, but also for suggestions post walk, it's the system's job to be an expert on websites and design." Its body has the diagnosis: "the system renders proposals it had no part in making, and is meant to be the expert."

#243 to #281 (10 to 14 September) then shipped fourteen sound changes to the mechanism: device per finding, comparisons, removals, video boxes, live-page render, publishing. Each passed its own done gate. None touched what the findings step was told. #239 is still open.

## The pattern

Context was managed as files and bytes, never as layers and roles. Every decision asked "which file, how big" and none asked "what does the model at this step need to believe it is doing, and what else is in its head while it does it".

In the KB's terms:

- **Context layer placement** was never applied. The placement test asks how often a thing is needed, whether it is knowledge or enforcement, and whether it needs to be in this context. Moves 1, 2 and 4 each skipped all three questions.
- **Adherence is a floor, not a slope.** Past a modest instruction count, following rate collapses. Work Mode loaded a 196-line method plus a 937-line reference on demand and expected the one line about findings to bind.
- **Narrow-patching, instance over class.** #193's fix added rules for the titles that were wrong. #226 moved prose to meet a number. Fourteen mechanism PRs fixed the instance in front of them. The class, where does the judgement live, was filed (#239, #223) and not worked.
- **The constraint tax: reason free, constrain late.** The step was asked to think inside `findings.json` and a patch file. A patch names a step, a finding names a page, a title names the page. Site-wide changes were structurally unthinkable, not merely unencouraged. The schema did not invent the ceiling, it inherited "one thing on one screen" from Move 1 and made it structural.
- **Harness engineering, guides without sensors.** The pipeline had deterministic sensors for every picture and none for the step's judgement. `agents/runs.md` is the first number anyone recorded about the findings step, on 14 September.

## How it was found

Not by the workflow. The human made the system list its own process step by step, then asked questions about each, then asked about context control. The system then stated that it had not scoped or compartmentalised the designer and that its instructions were scattered across files. The KB's material on agents and context was checked against that account and agreed with it.

No step in the workflow asks an agent to describe what the agent that runs a step will have in its context, or whether that was chosen or accumulated. The done gate asks whether a change is correct and whether the deliverable is what was asked. Neither question reaches an architecture that is wrong for its reader.

## What the workflow was missing

1. **Context layer placement as a discipline.** The workflow has skills for planning, testing, verification, but nothing that asks which layer an instruction belongs in before it goes into a method file. `aiw-prompt-smith` covers the altitude of a line; nothing covers the altitude of the artifact. Tracked with gap 2 as #299.
2. **A step-owning agent as an execution shape.** `aiw-orchestration` knows solo, scouts, builders, relay. It does not know "one step of a pipeline is always run by one sealed agent with one prompt", which is the shape that makes a step testable and its context measurable. Tracked with gap 1 as #299.
3. **Evaluation by artefact.** Nothing runs the same agent on three inputs and puts the outputs side by side, which is the only way a prompt or skill change is judged by evidence rather than argument. Already tracked as #242.
4. **An open structural issue does not stop the next mechanism task.** #239 and #223 both named the class before the fourteen instance fixes. Tracking worked; nothing asked, at each task start, whether an open issue made this task the wrong task. Tracked as #300.

## What Uplift is changing

Issue #282 in `site-uplift`. One agent file under 200 lines, sealed from `CLAUDE.md`, one skill line, the site folder as its only interface in and out. A run log with prompt tokens, run tokens, tool uses and a one-word verdict, so context is tuned against numbers. The clean run on three sites is the standing test; a skill swap is one line changed and three runs.

In one line: where a task has a judgement-heavy step that recurs, that step wants its own sealed agent and its own evidence, and the always-on files should describe the pipeline, not perform it.

## What this record cannot claim

- Three runs on two sites are an observation, not a measurement. The verdicts in `agents/runs.md` are the human's one-word judgements.
- The five-name pattern is the human's reading and this trace's, checked against the KB's concepts. It is a coherent account of the history, not a controlled comparison against a project that made the placement decisions.
- Whether the sealed agent fixes it is not yet known. #282 names the oracle: the same clean run, rerun, passing if the first proposal changes how a page looks rather than what it says.
