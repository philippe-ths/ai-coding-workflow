# Does independent verification reduce rework, and on which surfaces?

Investigation for issue #215, run 2026-08-21.

**Answer: not with the instruments available. Two of them were tried and both fail, for different and independent reasons.** No change to the workflow's routing guidance is proposed on this evidence.

## What the question needed

Three variables: a treatment (did an independent verification pass run), an outcome (did rework follow), and a stratifier (which surface). The issue named `observation/` as the natural instrument.

## Instrument 1: the session-observation tool. Structurally cannot answer it.

The Session Store records `session_id`, `repo`, `cwd`, `started_at`, `ended_at`, `duration_seconds`, `model`, `tokens.*`, `tool_calls.total` and `by_tool`, `skills.total` and `by_skill`, `user_turns`, `estimated_cost_usd`, `workflow_version`, and `rating`.

- **Treatment: not identifiable.** `tool_calls.by_tool` carries an `Agent` count, but nothing records what a sub-agent was for. An independent verification pass and a reconnaissance search are the same integer.
- **Outcome: absent.** Rework is a relation between two units of work. Rows carry no cross-session reference, no parent session, no issue or task id. Nothing relates two sessions.
- **Stratifier: absent by design.** No field records a file path, extension, or directory. `parse.py` extracts metrics only, never prompt or code content, and that is what lets sessions from many repositories pool locally with no redaction.
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

Rework rate rises monotonically with how many files a pull request touched, and with a median of about 19 pull requests merging in any 72-hour window, "a later pull request touched one of my files within three days" largely measures file count.

| files changed | n | rework rate |
|---|---:|---:|
| 1 | 7 | 14.3% |
| 2-3 | 99 | 48.5% |
| 4-6 | 80 | 72.5% |
| 7-11 | 62 | 80.6% |
| 12-20 | 54 | 85.2% |
| 21+ | 26 | 88.5% |

Treated backend pull requests are 2.3 times the untreated median in files and 3.1 times in lines. Independent verification is applied to the big, risky changes, which is a reasonable thing to do and fatal to this comparison.

The raw backend difference is +20.6 points **against** the treatment (87.5% treated, 66.9% untreated). That is what the size gap predicts, not a finding about verification. Stratifying by size shrinks it without reversing it, and every stratum cell is small (treated n of 3, 4, 15, 10) against an untreated baseline of 47 to 87 percent, so no stratum has the headroom to detect a reduction even if one exists.

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
