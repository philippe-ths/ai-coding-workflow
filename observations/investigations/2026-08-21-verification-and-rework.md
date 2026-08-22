# Does independent verification reduce rework, and on which surfaces?

Investigation for issue #215, run 2026-08-21.

**Answer: not with the instruments available. Two of them were tried and both fail, for different and independent reasons.** No change to the workflow's routing guidance is proposed on this evidence.

## What the question needed

Three variables: a treatment (did an independent verification pass run), an outcome (did rework follow), and a stratifier (which surface). The issue named `observation/` as the natural instrument.

## Instrument 1: the session-observation tool. Structurally cannot answer it.

The Session Store records `session_id`, `repo`, `cwd`, `started_at`, `ended_at`, `duration_seconds`, `model`, `tokens.*`, `tool_calls.total` and `by_tool`, `skills.total` and `by_skill`, `user_turns`, `estimated_cost_usd`, `workflow_version`, and `rating`.

- **Treatment: not identifiable.** `tool_calls.by_tool` carries an `Agent` count, but nothing records what a sub-agent was for. An independent verification pass and a reconnaissance search are the same integer.
- **Outcome: absent.** Rework is a relation between two units of work. Rows carry no cross-session reference, no parent session, no issue or task id. Nothing relates two sessions.
- **Stratifier: absent by design.** No field records a per-file path or extension. The session's `cwd` and the `repo` basename derived from it are recorded, so the repository is known and the surface within it is not. `parse.py` extracts metrics only, never prompt or code content, and that is what lets sessions from many repositories pool locally with no redaction.
- **No link to git or GitHub.** Nothing in `parse.py`, `collect.py`, `dashboard.py` or `pricing.py` reads a commit, branch, or pull request.

The store holds 189 rows spanning 2026-07-17 to 2026-08-21. The dataset that raised the question covers February to August, so the tool does not cover the period either.

Closing these gaps means recording file paths per session, which is the one thing the store's design deliberately excludes.

## Instrument 2: the pull request corpus. Measurable, and the measurement is uninformative.

489 merged pull requests from `philippe-ths/ai-running-coach`, 2026-02-07 to 2026-08-20, classified by surface from the real tree, by treatment from body and comment text, and by whether a later pull request touched the same files within 72 hours.

### Power: three of four surfaces have no comparison to make

| surface | treated | untreated | total |
|---|---:|---:|---:|
| backend-dominant | 32 | 296 | 328 |
| frontend-dominant | **1** | 72 | 73 |
| mixed | 1 | 22 | 23 |
| neither | 0 | 65 | 65 |

Frontend receives an independent verification pass **once in 73 pull requests**. No difference computed on one observation means anything, so the surface the question is most interested in is the surface with no data.

### The outcome measure is a proxy for size, not for defects

Rework rate rises monotonically with how many files a pull request touched, and with a median of about 19 pull requests merging in any 72-hour window, "a later pull request touched one of my files within three days" largely measures file count. Both figures below are backend-dominant pull requests only; the corpus-wide 72-hour median is 20.

| files changed | n | rework rate |
|---|---:|---:|
| 1 | 7 | 14.3% |
| 2-3 | 99 | 48.5% |
| 4-6 | 80 | 72.5% |
| 7-11 | 62 | 80.6% |
| 12-20 | 54 | 85.2% |
| 21+ | 26 | 88.5% |

Treated backend pull requests are 2.3 times the untreated median in files and 3.1 times in lines. Independent verification is applied to the big, risky changes, which is a reasonable thing to do and fatal to this comparison.

The raw backend difference is +20.6 points **against** the treatment (87.5% treated, 66.9% untreated). That is what the size gap predicts, not a finding about verification. Stratifying by size shrinks the gap without reversing it overall, though the smallest stratum (1 to 3 files) does reverse sign at -13.3 points on a treated n of 3. Every stratum cell is small (treated n of 3, 4, 15, 10) against an untreated baseline of 47 to 87 percent, so no stratum has the headroom to detect a reduction even if one exists, and the reversal in the smallest is not evidence of one.

## How treatment was classified, and how to re-audit it

Treatment is read from pull request body, comment and review text. The keyword set and its raw per-keyword hit counts:

| pattern | pull requests hit |
|---|---:|
| `adversarial` | 30 |
| `clean[\s-]context` | 21 |
| `independent\s+(reviewer\|review\|check\|pass\|agent)` | 4 |
| `independent(ly)?\s+verif` | 3 |
| `fresh\s+(sub-?agent\|agent\|eyes\|context)` | 3 |
| `second opinion`, `sub-?agent\s+(verif\|review...)`, `(separate\|another\|second)\s+agent` | 0 |

50 raw matches, 41 after two automatic filters, 34 final after reading every survivor.

The filters matter more than the keywords. A negation filter drops a match preceded within 90 characters by `no|not|never|without|didn't|cannot|absent|skipped|disabled`, because bodies here also record the *absence* of a pass: "no clean-context sub-agent drove the end-to-end run", "clean-context verification did not run". A naive count reads both as treated. A second filter drops `adversarial` followed by `injection|input|prompt|payload|suite|test|case|corpus|fixture`, which is adversarial-input security testing rather than adversarial review.

The seven excluded by reading, with the reason, so the judgement can be re-audited rather than taken on trust:

| pull request | why excluded |
|---|---|
| #191 | fixes findings from a review of #170, not a review of itself |
| #195 | the adversarial review was quota-blocked and never ran |
| #201 | the adversarial-review workflow was explicitly skipped |
| #202 | "adversarial pin" is a test name |
| #259 | "adversarial free-text" is a test input |
| #741 | "adversarial note" is a test fixture |
| #832 | "clean-context author" describes who wrote the tests, not a verifier |
| #863 | the adversarial review verified #847, not itself |

This is the part of the method that cannot be reproduced mechanically. Anyone re-running it should expect to re-make these calls, not to inherit them.

## Re-running this

`fetch-pr-corpus.py` rebuilds the corpus and `analyse-verification-rework.py` recomputes every figure above. Both live beside this file. The corpus itself is not committed: it is three megabytes of another repository's pull request data, and the fetch reproduces it. The fetch is read-only against that repository and pages by merged-date window, because the single bulk query returns HTTP 502.

These two scripts are archival. They are pinned to this investigation and to the shape the data had on 2026-08-21, and no validation covers them.

## What was established

- **The routing fact in the issue holds.** Independent verification is essentially not applied to frontend work in this corpus: 1 of 73.
- **Whether that is a problem is unresolved**, and this corpus cannot resolve it.
- **The original frontend-versus-backend comparison is confounded twice over**, by surface as the issue already noted and by change size, which it did not.

## What a future answer needs

1. **An outcome that names causation.** A later pull request that cites the earlier one as broken, or reverts it. Same-file-within-72-hours is a size proxy in any repository with this merge rate.
2. **A frontend arm that receives the treatment.** At 1 in 73 there is nothing to compare, whatever the outcome measure.
3. **Treatment recorded rather than inferred.** Treatment here is read from what a pull request body claims. A pass that ran without being written up counts as untreated.

## Why no rule change is proposed

The workflow's Resource Discipline section routes work by shape. Changing it on the strength of a comparison this confounded would be worse than leaving it, because the result runs against the treatment and the reason is measurement error rather than evidence. An uninformative measurement is a reason to leave guidance alone, not a reason to invert it.
