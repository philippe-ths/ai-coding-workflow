# Can Jev tell from an issue how much process the task warrants?

Investigation for issue #307, run 2026-09-29, with `scripts/jev/questions/ceremony.json` at question version `415ee66bb6a7` (the file before `act_above` was set) on `jev-1.13.0`. Case numbers are pull request numbers.

**Answer: yes, conservatively, and only where lighter tasks exist.** Jev rarely calls a task lighter than it turns out to be: at confidence 0.8 or above, once in the 68 cases of the second corpus, which the threshold was not chosen on, and by one step. It errs heavy: it calls about half of standard tasks full. On `ai-running-coach`, a product codebase, it beats answering "full" every time by a wide margin (81 against 49 of 120 exact) and at confidence 0.8 or above lightens 12 of 120 tasks, 11 of them correctly. On this repository, where 88 of 112 tasks are genuinely full, it adds little over always-full. Its confident light calls are few, 4 across both corpora, so most Light tiers will be the agent's own call. `act_above` stays 0.8.

The first corpus below is this repository; the second, added the same day, is `ai-running-coach`.

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

So acting on Jev at 0.8 changes nothing for most tasks and lightens about one in eighteen, correctly on this data. The second corpus below is where light and standard tasks are common enough to measure that rate.

## The lighter calls, below threshold

All nine were labelled full by at least two labellers, and all nine had confidence under 0.8.

- **Foresight cannot see them.** PR #280 asked for a README list fix; the merged change added a skill and edited several others. No reading of the issue predicts that, which is why the tier sets where a task starts and a task moves up when the work proves bigger.
- **Hooks described as small bugs.** PRs #117, #199 and #236 read as one-line fixes to a guard; the labellers rated them full because every push or pull request passes through that guard. PR #221 (0.77) is the one lighter call close to the threshold.
- **Low confidence overall.** PR #153 came back light at confidence 0.00 with probabilities 0.49 light, 0.27 standard, 0.24 full. Jev's confidence measures how concentrated the whole distribution is, not the top level's probability, so a leading level with the rest spread across the scale reads as no confidence; PR #280 (0.81 light, confidence 0.57) is the same effect.

## Limits

- **Lopsided corpus.** 88 of 112 tasks here are full, because most work in this repository changes rules agents follow. There are 10 light and 14 standard tasks, and only 3 light calls and 1 standard call clear the threshold. The two tiers where the saving is are barely measured. The second corpus below is the product-code repository that tests them.
- **Threshold chosen in-sample.** 0.8 is the lowest listed threshold with no lighter calls on this data, and the next lower one fails on a single case (PR #221 at 0.77). The second corpus is the out-of-sample check on it; beyond that it is a starting point to revisit from the run log.
- **Shared wording.** In the first corpus, labellers and Jev judged against the same three definitions, so agreement shows Jev applies the definitions as a careful reader does, not that the definitions are the right ones.
- **Model labellers.** The labels come from Claude sub-agents, not the human; they may share the bias toward more process that #269 describes.

## Cost

114 calls: 108,746 input tokens in total, about half a US cent at the published $0.042 per million. Median latency 293 ms, slowest 3.6 s.

## Second corpus: ai-running-coach

The first corpus could not measure the light and standard tiers, so the same method was run on `philippe-ths/ai-running-coach`, a FastAPI and Next.js running coach with an LLM coach. Of its 515 merged pull requests, 327 close an issue; 120 were sampled with a fixed seed (`measure-jev-ceremony.py fetch WORKDIR philippe-ths/ai-running-coach 120`). Jev ran at question version `4e54c16bad99`, the file with `act_above` set. The labellers used the first corpus's light and standard definitions, and a full definition with this codebase's own examples of reach: full "changes shared contracts or interfaces (e.g. an API both backend and frontend use), schema or stored data, prompts or instructions the LLM coach follows, several areas at once, or the cause of the problem was not known at the start". Jev's criteria were unchanged. The per-case record is `2026-09-29-jev-ceremony-running-coach-data.json`.

All 120 cases had a majority label; 101 were unanimous. Labels 10 light, 61 standard, 49 full. Jev 3 light, 37 standard, 80 full.

| majority label \ Jev | light | standard | full |
|---|---|---|---|
| light | 3 | 4 | 3 |
| standard | 0 | 31 | 30 |
| full | 0 | 2 | 47 |

Exact agreement 81 of 120, against 49 for always-full. Jev called 2 tasks lighter than the label and 37 heavier.

| threshold | cases covered | exact | called lighter | Jev's non-full calls matching the label |
|---|---|---|---|---|
| none | 120 | 81 | 2 | 34 of 40 |
| 0.6 | 92 | 64 | 1 | 22 of 25 |
| 0.8 | 68 | 50 | 1 | 11 of 12 |
| 0.9 | 50 | 35 | 1 | 3 of 4 |

- **Where the saving is.** Jev's standard and light calls are nearly always right: of the six that miss, four are light tasks called standard, the safe side, and two are the lighter calls below. At 0.8 it lightens 12 tasks; lowering the threshold to 0.6 would lighten 25 with the same single lighter call here, but on the first corpus 0.6 admits two lighter calls. The run log is what should move the threshold, not this sample.
- **The two lighter calls** are both changes to what the LLM coach is told: PR #192 (standard at 0.91) reworks how the coach treats low-confidence interval data, and PR #671 (standard at 0.56) gates prompt sections on a prompt ID. The labellers' definitions named "the prompts the coach follows" as full; Jev's criteria say "rules or instructions that agents follow", which a product's LLM prompt does not obviously match. A product whose model prompts are a contract would name them in its question's criteria.
- **The heavy lean** is the cost: 30 of 61 standard tasks called full. That loses savings, not safety.

120 calls: 113,773 input tokens, median latency 290 ms, from the run log of this measurement, which is not kept.
