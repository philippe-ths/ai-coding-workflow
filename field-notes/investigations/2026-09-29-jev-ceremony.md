# Can Jev tell from an issue how much process the task warrants?

Investigation for issue #307, run 2026-09-29, with `scripts/jev/questions/ceremony.json` at question version `415ee66bb6a7` (the file before `act_above` was set) on `jev-1.13.0`. Case numbers are pull request numbers.

**Answer: not yet shown.** Jev applies the three definitions the way careful readers do, and above a confidence of 0.8 it never called a task lighter than it turned out to be. But 88 of 112 tasks in this repository are full, so answering "full" every time scores almost as well, and Jev's value lies in the few tasks it calls lighter: 4 at or above 0.8 here, all correct. That is too few to rely on. `act_above` is set to 0.8, chosen on this same data, and the light and standard tiers need a corpus with more of them before the workflow leans on Jev's answer.

## Method

- **Cases.** The 114 merged pull requests in this repository that close an issue, one case each, anchored on the first issue closed.
- **Jev sees foresight.** The issue title and body only, as state `{title, body}`, the way the agent would ask at task start.
- **Labellers see hindsight.** Three fresh sub-agents, each reading the cases in a different order, labelled every case light, standard or full from the issue plus the files the merged change touched with line counts. They used the same three definitions as the question's criteria and saw no Jev output.
- **Oracle.** The majority label. The three labellers agreed unanimously on 101 cases and had a majority on 112; the two without a majority are excluded.

The per-case record, including every Jev probability and all three labels, is in `2026-09-29-jev-ceremony-data.json`. `measure-jev-ceremony.py report 2026-09-29-jev-ceremony-data.json` reproduces the Results figures from it; the Cost figures come from the run log of the measurement, which is not kept.

## Results

On the 112 cases with a majority label: labels 10 light, 14 standard, 88 full; Jev 8 light, 13 standard, 91 full.

| majority label \ Jev | light | standard | full |
|---|---|---|---|
| light | 5 | 1 | 4 |
| standard | 0 | 6 | 8 |
| full | 3 | 6 | 79 |

Exact agreement 90 of 112. Jev called 9 tasks lighter than the label and 13 heavier.

The costly error is the lighter call, because a task started too light skips process it needed. Acting only on answers at or above a confidence threshold:

| threshold | cases covered | exact | called lighter | light calls correct |
|---|---|---|---|---|
| none | 112 | 90 | 9 | 5 of 8 |
| 0.6 | 81 | 71 | 2 | 3 of 3 |
| 0.7 | 74 | 67 | 1 | 3 of 3 |
| 0.8 | 70 | 64 | 0 | 3 of 3 |
| 0.9 | 60 | 55 | 0 | 3 of 3 |

At 0.8 the six disagreements are all Jev calling a task heavier than the label, which costs process rather than safety.

## Against answering "full" every time

The trivial answer is the right comparison, because it is what the workflow does today.

- **Overall.** Always-full is exact on 88 of 112 and never calls a task lighter. Jev is exact on 90.
- **At or above 0.8.** The 70 cases there are labelled 60 full, 6 standard, 4 light. Always-full is exact on 60; Jev on 64. Jev calls 66 of them full, and its 4 other calls (PRs #50, #56 and #247 light, #167 standard) all match the labels.
- **Below 0.8.** Of Jev's 21 non-full calls overall, 11 match the labels; the 17 below the threshold are where its errors sit.

So acting on Jev at 0.8 changes nothing for most tasks and lightens about one in eighteen, correctly on this data. Whether that rate holds, and how much it saves, depends on a corpus where light and standard tasks are common.

## The lighter calls, below threshold

All nine were labelled full by at least two labellers, and all nine had confidence under 0.8.

- **Foresight cannot see them.** PR #280 asked for a README list fix; the merged change added a skill and edited several others. No reading of the issue predicts that, which is why the tier sets where a task starts and a task moves up when the work proves bigger.
- **Hooks described as small bugs.** PRs #117, #199 and #236 read as one-line fixes to a guard; the labellers rated them full because every push or pull request passes through that guard. PR #221 (0.77) is the one lighter call close to the threshold.
- **Low confidence overall.** PR #153 came back light at confidence 0.00 with probabilities 0.49 light, 0.27 standard, 0.24 full. Jev's confidence measures how concentrated the whole distribution is, not the top level's probability, so a leading level with the rest spread across the scale reads as no confidence; PR #280 (0.81 light, confidence 0.57) is the same effect.

## Limits

- **Lopsided corpus.** 88 of 112 tasks here are full, because most work in this repository changes rules agents follow. There are 10 light and 14 standard tasks, and only 3 light calls and 1 standard call clear the threshold. The two tiers where the saving is are barely measured. A repository whose work is mostly product code would test it properly.
- **Threshold chosen in-sample.** 0.8 is the lowest listed threshold with no lighter calls on this data, and the next lower one fails on a single case (PR #221 at 0.77). It is a starting point to revisit from the run log, not a measured property.
- **Shared wording.** Labellers and Jev judged against the same three definitions, so agreement shows Jev applies the definitions as a careful reader does, not that the definitions are the right ones.
- **Model labellers.** The labels come from Claude sub-agents, not the human; they may share the bias toward more process that #269 describes.

## Cost

114 calls: 108,746 input tokens in total, about half a US cent at the published $0.042 per million. Median latency 293 ms, slowest 3.6 s.
