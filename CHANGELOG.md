# Changelog

This changelog follows [Common Changelog](https://common-changelog.org/).

The canonical version is the `Version:` header in `ai-workflow.md`. Every bump of that header requires a matching entry here; the pre-push hook enforces this.

Every `### Removed` bullet must lead with the removed path as a backticked token (`` - `path/to/thing` — explanation``), one removed path per bullet. The update path reads these to know which installed files to delete from a target repo, so the format must stay machine-extractable. `scripts/check-changelog-removals.sh` enforces this (factory-only validation; it is not shipped to target repos).

## 3.26.0 - 2026-08-21

### Changed

- A named unverified surface can now end in a fourth state, **deferred**, and the workflow says where work is presented for the human's done decision. Across 489 merged pull requests in a repository running this workflow, 12 carry a comment reporting substantive verification posted after the pull request was opened, every one of them within two hours and half within fifteen minutes: a clean-context pass run once quota reset, a check performed inside the real production image rather than by inspection, manual items closed out. The rule required the justification before the work was presented for the done decision, practice treated opening the pull request as that presentation, and the two disagreed. Neither was wrong. Opening a pull request is not the moment the human decides, since they decide afterwards, so the pull request is part of the verification surface rather than the end of it. `aiw-verification` gains `deferred` beside checked, tracked and waived: the artifact is the method named, why it has not run, and that it runs before the human decides, and posting the result where the work is presented is what moves the item to checked in front of the person deciding. It is the existing Wait option kept visible rather than finished work held back, and it is explicitly not available for a method that cannot run at all, which stays the human's decision under "When the Committed Method Cannot Run". `aiw-github` gains the matching floor at the moment the pull request opens: scope what the body claims to the evidence that exists then, and never write up evidence you intend to gather as though it has already run. The alternative was to tighten the gate so all evidence had to exist before opening, which would have made the honest act of posting further evidence into a violation, and a rule that penalises disclosure produces less of it ([#210]).
## 3.25.1 - 2026-08-21

### Fixed

- Installing a second agent tool into the same target no longer strips the first tool's vendored paths from the target's `.gitignore`. The installer-managed block was rebuilt from only the current run's paths, so the documented multi-tool procedure — one installer run per tool, which `scripts/update.sh` requires by refusing to auto-detect an ambiguous target — left each run undoing the one before it. In a repository running this workflow with four tools installed, the result was `.claude/`, `.codex/`, `.gemini/`, `CLAUDE.md` and `AGENTS.md` all untracked, one `git add -A` away from being committed into a history that is supposed to vendor them. The block is now a union: entries already in it are kept in order and the current run's paths appended if absent. This is the opposite symptom of [#166], and [#166]'s fix is its cause — to stop duplicate entries the installer began deleting matching lines from anywhere in the file, and combined with each run knowing only one tool's paths, removal outran replacement. That file-wide deletion is now confined to the first install, the only run with no managed block to date the file against; once a block exists, a matching line outside it is hand-maintained and is left alone, so a section a human labelled as needing to survive updates does. `scripts/update.sh` prunes paths named in `### Removed` changelog bullets from the block, since a union would otherwise keep a path that had left the product forever, and never prunes one the current product still ships. The gap that let this run for two months was that both sandbox tests only ever installed a single tool; they now install three in sequence and assert on `git status --porcelain`, which is the hazard the issue actually describes rather than a proxy for it ([#216]).

## 3.25.0 - 2026-08-21

### Added

- Added `.ai-policy/hooks/check-pr-verification.sh`, a PreToolUse guard that blocks opening or editing a pull request whose body carries no verification justification, or whose unverified-surface section is a bare assertion. `aiw-github` already required the justification before the first remote action and `aiw-verification` already required an empty part 3 to be an argument rather than an assertion, but both were asked of the agent at the moment it is least able to hear them, and nothing checked whether either happened. Wired into all four agent entry points on both the shell and MCP routes, and covered by `.ai-policy/scripts/test-pr-verification-hook.sh`, which also asserts the wiring, since behaviour tests pass just as happily when nothing invokes the hook. A body the hook cannot read — an editor session, `--fill` from commit messages, a `--body-file` naming a path that does not exist — is blocked rather than passed over, because reporting green on an unread input is the shape of failure `check-validation.sh` was fixed for in 3.17.0; `aiw-github` now says to pass the body from a file ([#224]).

### Changed

- The guard deliberately does not require each named gap to carry an issue number, though that was the rule it was created to enforce. The twenty pull requests merged into this repository were run against a draft that did: every one of the six that built these rules declared an unverified surface, and none of those declarations carried an issue, because they were limitations of the evidence — "two runs per arm is indicative, not conclusive", "no automated test covers skill prose" — rather than gaps anyone should own. Only the author can tell those apart, so the rule would have fired on the normal path, and this repository has already recorded what happens then: a gate that fires on the normal path gets routed around. What survives are the two checks a script can make without that judgement. Three false-positive classes were found by running the guard against this repository's own workflow rather than by imagining what might go wrong, and each is now a test: a body file whose path is built from a shell variable, which a hook cannot expand; a body file the same command is about to write, which does not exist yet when a PreToolUse hook runs; and a command that merely quotes the pull-request-creating form, which is blocked because this matches the command string rather than parsing the shell, the same trade `block-pr-merge.sh` already makes. The first two are named separately in the block message, because "could not read the file" is a useless thing to tell someone whose command was about to work. Quoted spans are blanked before the bare-assertion check, because a body that quotes the bare form while discussing it is not declaring it, and the pull request for [#208] reads exactly that way; blanking can also swallow a real declaration when apostrophes pair across it, which is the direction to err in, since a missed box-tick costs a caveat and a false block costs the guard its credibility ([#224]).

## 3.24.0 - 2026-08-21

### Changed

- A verification gap that keeps recurring is now caught by `aiw-init`'s session preflight rather than at the done claim, and `aiw-verification` keeps only the rule that makes the repeat recognisable. Prompted by 463 closed pull requests in a repository running this workflow, where the same structural limitation was re-declared for six months — a suite standing in an in-memory database for the real one was declared in ten of them, across February to August — because the workflow had no notion of a gap it had seen before. Splitting the rule by the moment it applies puts each half where it costs least. Naming a gap by its cause rather than by the task ("no real external-model call, the API key is unfunded" rather than "could not fully test the coach for #712") is a writing rule, so it stays beside the writing, needs no tool call, and is what makes a later search possible at all. Finding the repeat is a reading rule about the repository rather than about the change under test, so it belongs to preflight, where it runs once, blocks nothing, and reaches the human before a task is chosen instead of arriving at the moment the agent already carries the most obligations. `aiw-init` gains it as a declared surface with a normal it can evaluate, alongside the drift checks it already owns. Escalation stays the human's: the preflight reports the recurrence and `aiw-issue-creation` describes the shape of the resulting issue, one that removes the limitation rather than tracking another instance of it, which keeps the agent on the correct side of the approval gate that [#208] restored. No new file or state is introduced, since the merged pull requests and issues are already the durable record ([#209]).

## 3.23.0 - 2026-08-21

### Changed

- `aiw-verification`'s scoping step now drives every named unverified surface to one of three resolutions the human can see — checked, tracked as its own issue, or waived by the human — instead of leaving it as prose. Prompted by 463 closed pull requests in a repository running this workflow: 105 of 461 merged pull requests explicitly declared an unverified surface, and for 81 of them (77%) that declaration is the last trace of the item anywhere, with no later comment, issue, or reference. The declaration rate is rising rather than falling — 0% in February, 21% in June, 55% of August's 62 merged pull requests — so honesty was increasing the volume of untracked risk rather than reducing it. No new machinery is introduced, because the receiving mechanism already exists and works: where a gap was filed as an issue instead (31 cases), 26 are closed and the median time to close was the same day. It was simply never connected to the step that produces the gaps, so `aiw-issue-creation` now names the scoping step as a normal source and `ai-workflow.md` gains an Always Do entry. A state is reached when its artifact exists rather than when its word is written — what you ran, the issue number, or the human's words — because a label is not checkable and a column of correct-looking labels would hide an undisclosed gap better than plain prose did. Tracking is explicitly not licence to file: proposing the issue is the agent's and creating it is the human's, which is what `ai-workflow.md`'s "surface follow-up work without acting on it" and `aiw-issue-creation`'s duplicate-confirmation gate already required. A waiver must carry what the human was told, since an agent that may waive on their behalf has three states on paper and one in practice. The box-ticking case — one pull request in the dataset reads "Not verified: nothing" — is handled by rewriting the existing line that caused the defensive answer rather than by adding a section to argue with it: an empty part 3 is now an argument in terms of what the change is, never a bare assertion. The Always Do entry folds into the existing justification bullet, which fires at the same moment, and the scoping step's preamble arguing for naming is dropped, since the new subsection requires more than naming. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#208]).

## 3.22.0 - 2026-08-20

### Changed

- `aiw-verification` gains a "When the Committed Method Cannot Run" section, so a verification method becoming unavailable is raised as a decision instead of resolved by substitution. Prompted by a pull request in a repository running this workflow that records clean-context verification not running because sub-agents were unavailable in that session: the end-to-end evidence became self-verified and the work shipped. The substitution was disclosed and it was still made by the agent. The same shape appears elsewhere in that dataset as verification deferred for quota or an unfunded API key, with a deterministic proxy standing in for the real path. The section names why honest disclosure is the trap rather than the remedy — the sentence is true, the decision is still the agent's, and what a done claim is worth is the human's call — and gives the three options the human actually has: accept the weaker evidence with its reduced worth stated, wait for the committed method, or narrow the claim to what the available evidence supports. `aiw-ground-truth` already forbade silently substituting a lower trust level for an input; the rule was missing for evidence, which is the symmetry this restores. `aiw-planning` now says the verification approach the plan names is a commitment rather than an aspiration, and `ai-workflow.md` gains an Ask First entry. The mandatory-end-to-end rule is reworded to separate a check that is disproportionate to the change, which is named as a risk and carried, from one that cannot run at all, which is not the agent's to resolve — the two sat in consecutive paragraphs giving opposite instructions for what an agent would read as the same situation. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#214]).

## 3.21.0 - 2026-08-20

### Changed

- `aiw-failure-analysis` gains a "What Counts as a Contradiction" section, so the stop-and-audit fires when the agent contradicts its own recent claim and not only when the human does. Every source the trigger named was external — the user, runtime behaviour, manual verification — and the agent's own second attempt at the same defect is the louder signal, because it is an explicit admission that the first attempt failed. Prompted by evidence from 463 closed pull requests in a repository running this workflow: one bug needed three fixes in a single day, two of those pull-request titles saying "supersedes" and naming the ones they replace; one issue has two merged pull requests with word-for-word identical titles; one is titled "unbreaks Re-run in prod"; and 23 fix pull requests repair code another fix pull request was the last to touch. The convergence check ran in none of them. The section names the mechanism as well as the signals, because the framing is what does the damage: a new issue, a new branch, and a new plan make attempt two look like task one, and nothing in the new task's context remembers that something already failed there. It also says catching it yourself is the cheaper moment rather than a confession, since an agent that reads the trigger as an admission of fault will find reasons not to be the one who reports it. The skill's `description` carries the same signals so the skill is selected on them, and the Reactive Rules in `ai-workflow.md` say the contradiction need not come from the human. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#213]).

## 3.20.0 - 2026-08-20

### Changed

- `aiw-verification` rewrites part 1 of the justification rather than adding a section to correct it. Part 1 already asked for "the surfaces downstream of those", and the failure it is meant to catch happened anyway, because "downstream" reads as "the other code that calls this" and the surface that broke was on the same screen, computed by a charting library that nothing in the codebase calls. Prompted by a pull request in a repository running this workflow that posted a thorough browser verification against a real 400-activity database, with measured values, and passed; within the hour the owner caught three defects in the same view, the second of them a regression created by the fix for the first, where regrouping the data changed how the library computed the vertical scale and pushed the highest values outside the plot area. Supporting the pattern rather than the incident: across 463 closed pull requests in that repository, 23 fix pull requests repair code another fix pull request was the last to touch, and 43% of fixes land within a day of the code's previous change. Part 1 now asks two questions in place of one — what reads the value, shape, ordering, grouping, or type that moved, and what is derived from it that nobody wrote down — and bounds the answer explicitly, because a check that reads as licence to re-verify everything gets skipped for cost. Repairing the line that failed rather than appending a second rule to race it keeps the net change to two lines. The Fix modality requirement gains the derived surfaces alongside its existing adjacent-inputs clause. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#211]).

## 3.19.0 - 2026-08-20

### Changed

- `aiw-ground-truth`'s trust hierarchy now separates how real an input is from whether it describes the thing being changed, and requires evidence drawn from a running system to name where it was read and confirm the code under test runs in that same place. The hierarchy ranked authenticity only, and its top rung read as unconditional: an agent that scored its evidence level 1 had no further question to ask. Prompted by a seven-day cross-user data leak in a repository running this workflow, where an audit downgraded the defect to config fragility on the evidence that the recipient setting was "set in prod today". That reading was true, and taken from the web process, while the worker that sends had no such setting; the leak then outlived two hardening changes that inherited the same framing, one reinforcing the copy of the logic that already worked and one guarding the process that does not send. The rule is pitched at the locus of evidence rather than at processes, because the same blind spot produced three other instance families in the same repository: ten separate changes verified against an in-memory database standing in for the real one, a local seeded copy standing in for production rows, and a desktop automation window standing in for mobile layout. A rule naming processes would have caught one of the four. Level 1's wording lost "in real environments", the phrase that invited the error by letting authenticity read as sufficiency, and the Origin field of artifact provenance gains the process or environment a capture came from. `aiw-verification`'s runtime-output inspection gains the matching bullet and points back here, because the reading that caused this was taken while auditing a live system rather than while building a fixture, and that is not a moment `aiw-ground-truth` is loaded — a rule the agent never reads is not a rule. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#212]).

## 3.18.0 - 2026-08-07

### Changed

- `aiw-verification`'s Delete requirement extends the dependency sweep beyond the repository, to state the removed code installed elsewhere: scheduled jobs, global or user-level config, registered hooks, files under `$HOME`, installed services. Deleting code does not unregister what it registered, and nothing in the repository can report the leftover, so it keeps firing against a path that no longer exists. The justification must now say either how that state was accounted for or that the subsystem installed none. Prompted by two launchd agents from the eval and telemetry stack removed in 3.3.0 ([#143], [#145]), still loaded and exiting 78 on every fire more than two months later, against scripts deleted with that stack. The sweep at the time was correct about the codebase and never looked outside it, which is why this belongs to verification rather than to the delete oracle: what "correct" means for a delete did not change, only where the evidence has to come from. Mirrored into `.claude/skills/` and `.agents/skills/`, and re-condensed into `lite-monolithic/ai-workflow.md` ([#204]).
- The `telemetry/` residue is deleted from the working tree: four zero-byte `.log` files and five empty directories, three of them named `*.yaml` as docker bind-mount artifacts created when the host file was absent. None of it was tracked, which is why `git status` read clean and the residue survived unnoticed — git does not track empty directories and `*.log` covered the rest. Deliberately not recorded under `### Removed`: that section arms the updater to delete the named path from every target repo, and `telemetry/` was never a product file, so listing it would delete an unrelated directory of the same name from someone else's project ([#204]).

### Added

- Added `observation/uninstall-observation.sh`, the inverse of the installer that observation capture never had. Capture installs itself into the developer's global `~/.claude/` by design ([`docs/adr/0002`](docs/adr/0002-observation-capture-is-global-not-per-repo.md)), so deleting this repository alone would leave a SessionStart hook wired into global config, pointing at a path that no longer exists — the same shape as the launchd agents above, in the one subsystem here that is still live. It removes the helper scripts, the `/rate` skill, and the hook, unwiring only its own command from `settings.json` and leaving every other setting, hook event, and co-located hook in place. Recorded data is kept unless `--purge-data` is passed: `manifest.jsonl` and `ratings.jsonl` are append-only captures that cannot be rebuilt from transcripts, and the store directory is removed only once it is empty. An unparseable `settings.json` is left untouched rather than rewritten, since replacing a file that could not be read would destroy configuration that cannot be seen ([#204]).
- Added `scripts/test-observation-install.sh`, sandbox coverage for the install and uninstall pair against a throwaway `CLAUDE_HOME`. The installer had no test at all, so nothing would have caught an uninstall that corrupted the developer's global settings or deleted months of recorded sessions. The cases that matter are the destructive ones: an unrelated skill, an unrelated SessionStart hook, an unrelated hook event, and an unrelated top-level setting all survive; a hook hand-merged into the same entry as ours survives while ours is removed; and the data files survive by default. Wired into `scripts/repo-validation.sh` ([#204]).

## 3.17.0 - 2026-08-06

### Fixed

- `.ai-policy/scripts/check-validation.sh` rejects a passing validation result that was computed against a different working tree, closing a gate that failed open. The state file recorded a bare `passed` with nothing tying it to the content that produced it, so an hour-old result satisfied the commit and push gates for a tree that had moved on since; the defect was observed with ten files edited after the recorded pass. The gate exists so that what is being committed has been validated, and a stale pass satisfied the mechanism while defeating its purpose. It also failed in the dangerous direction, reporting green, and the only workaround put the guarantee back on remembering to re-run validation immediately before every commit, which is what the gate was meant to remove. A new `.ai-policy/scripts/tree-fingerprint.sh` hashes the tracked and untracked-not-ignored content with git's own object hashing, so no external checksum tool is needed, and `run-validation.sh` records it alongside the result. Ignored files are excluded because validation does not read them; the state file is excluded explicitly rather than by ignore rules, since a target that has not ignored it would otherwise have each recorded result invalidate itself on the next read. `mark-validation-pass.sh` stamps the same fingerprint, so the manual override remains an escape hatch from running validation and not from the result belonging to the content being committed. The fingerprint covers path names and file contents only. Index state and HEAD are excluded deliberately: `git add` changes whether a modification is staged rather than what any file contains, and committing moves HEAD while leaving every file on disk identical. Including either was tried and both broke the ordinary edit-validate-stage-commit-push sequence, invalidating a pass that had just been recorded and demanding a second validation run before every push, with no change in what validation had read. A gate that fires on the normal path gets routed around. A path git reports in quoted form — one containing a quote, backslash, or control character — aborts the fingerprint with the path named, because such a file would drop out of content hashing while still appearing in the path list, reintroducing the same fail-open shape in a corner. Covered by `.ai-policy/scripts/test-validation-state.sh`, which drives a real `git commit` through the real hook rather than asserting on exit codes alone, and pins fingerprint stability first: a fingerprint that differed between two runs over an identical tree would block every commit in every repository that installs this ([#205]).

### Changed

- A validation result recorded before this version carries no fingerprint and no longer satisfies the gate. The first commit or push after updating blocks with a message naming the cause and the remedy, and `./.ai-policy/scripts/run-validation.sh` clears it. Failing closed is deliberate: a bare `passed` cannot be tied to any tree, so it is not evidence that what is about to be committed was validated ([#205]).

## 3.16.0 - 2026-08-06

### Added

- Added the `aiw-init` skill, a user-invoked session preflight that runs a repository's declared checks read-only and reports state the human would otherwise discover too late: a red build, a dead dependency, work left in flight, an issue that already covers what they were about to start. It reports observations and never decides what to do about them, because a preflight that arrives with a plan attached has quietly made the human's call for them. Every command it runs must be non-mutating, which is why the checks it scaffolds reach for `git ls-remote` over `git fetch`. Log lines, service responses, and issue text are treated as data to report rather than instructions to follow, since reading logs is a natural prompt-injection surface. Findings must state what was observed rather than what was concluded: a trial run asserted that a directory held no log files when it held four empty ones, and a confident wrong finding costs more than a missing one because the human acts on it. Mirrored into `.claude/skills/` and `.agents/skills/` ([#202]).
- Added `project-checks.md`, a per-repository record of what is worth checking and what normal looks like for each check, classified as authored-in-target alongside `project-context.md`. The skill carries the discipline and the file carries the specifics, because a fixed check list inside a skill does not survive contact with a second project. Every entry declares its normal so a run can report the deviation and stay silent about the rest; a check without one hands back raw output for the human to diff themselves, which is the noise the skill exists to prevent. The normal must also be one a run can evaluate unaided, since "rebuilt recently" or "an issue you already know about" rests on the human's memory and so passes silently every time. Surfaces a repository has no instance of are recorded rather than omitted, because an absent check is otherwise indistinguishable from a forgotten one. The installer creates neither this file nor `project-context.md`; `aiw-init` scaffolds it from the target's own configuration on first run ([#202]).

## 3.15.2 - 2026-08-06

### Changed

- `.ai-policy/hooks/block-protected-branch-bash.sh` derives both of its questions about a `git push` — what branch it targets, and whether it is only deleting — from a single parse of the command, replacing two separate tokenisations of the same string. Both copies carried the same documented limitation, that a flag taking a separate value shifts the positional count, so anyone tightening it had to find both sites and a fix applied to one would leave the two disagreeing about the same command. A guard whose halves can disagree is the shape of problem [#193] and [#195] both turned out to be. The limitation is now stated once, on the parse it belongs to. `is_tag_push` keeps its own scan: it answers a different question and keys off the last positional including the remote, so folding it in would change behaviour rather than preserve it. No behaviour change, verified by running 47 push and non-push commands through the pre-refactor and refactored hooks under both a protected and an unprotected current branch, 94 combinations with no difference in verdict. Two cases pinning the parse semantics added to `.ai-policy/scripts/test-claude-code-enforcement.sh`: a refspec list mixing a deletion with an ordinary push is not delete-only, and `--delete` reads the same trailing as leading ([#200]).

## 3.15.1 - 2026-08-06

### Fixed

- `.githooks/pre-push` no longer runs the current-branch check on a delete-only push, so deleting a merged feature branch from `main` is allowed. Post-merge cleanup runs from the protected branch by nature: you switch back to it, then delete the branch you just merged. Asking "where am I standing?" rejects that, which made CLI branch cleanup structurally impossible; it went unnoticed only because GitHub's auto-delete-on-merge had been removing branches server-side. A deletion writes to no branch, and `check-push-refs.sh` runs first and unconditionally, so a delete naming a protected branch is already rejected before the exemption is reached. Delete-only is read from git's own pre-push input, where a deleted ref carries an all-zero local sha; a deletion combined with any branch update is not delete-only and still gets the check ([#177]).
- `.ai-policy/hooks/block-protected-branch-bash.sh` allows `git push --delete`, `-d`, and `:<ref>` deletions of non-protected branches from a protected branch, matching the pre-push hook. Fixing only the git hook would have left the symptom in place on the route that produced it, since post-merge cleanup is run by the agent and this hook blocks the command before git sees it. The exemption is applied after the refspec check, so `git push origin --delete main` still blocks, and it covers deletions only: `git push origin feature/x` from `main` is still rejected ([#177]).

## 3.15.0 - 2026-08-05

### Added

- Added `.ai-policy/hooks/block-pr-approve.sh`, which blocks the agent from approving a pull request on the shell route (`gh pr review --approve`, bare `gh pr review`, and `gh api` POSTs to a `/pulls/N/reviews` endpoint) and the MCP route (review-creation and review-submission tools under any server prefix). [#194] narrowed the allow-list so approval prompted rather than running unattended, but a prompt is the wrong gate: approving review is a human judgement in the same category as merging. The failure this prevents is self-approval, where an agent opens a pull request and approves it, satisfying a human-shaped review requirement using only its own judgement; [#194] stops that loop completing at the merge step, but the approval is still a false signal recorded against a human process. Bare `gh pr review` is blocked because it is interactive and offers approval as an option. The MCP branch fails closed: an absent or unrecognised `event` is treated as an approval, since guessing the other way is precisely how `merge_pull_request` passed the branch guards before [#193]. Wired into all four agent entry points, and `Bash(gh pr review:*)` added to the Claude Code `deny` list. Covered by `.ai-policy/scripts/test-pr-approve-hook.sh` ([#197]).

### Changed

- Review comments and change requests are explicitly not blocked. `gh pr review --comment` and `--request-changes` pass this hook, as do the MCP equivalents with `event` set to `COMMENT` or `REQUEST_CHANGES`. Neither is auto-approved in the permission defaults, so both still prompt ([#197]).

## 3.14.0 - 2026-08-05

### Added

- Added `.ai-policy/scripts/check-push-refs.sh`, invoked by `.githooks/pre-push`, which blocks a push when any ref being pushed targets a protected branch. Every existing guard asked "where am I standing?" rather than "what am I writing to", so from a feature branch `git push origin HEAD:main` was allowed by all of them: the agent hook checked the current branch, and the pre-push hook read the refs only to decide whether the push was tag-only before delegating to a current-branch check. This is the same design flaw as [#193] on a route [#194] did not close, and unlike a pull request merge the target is named explicitly in the command, so nothing but the absence of a refspec check let it through. The pre-push hook is the only layer that receives git's resolved refs, so it is the only place the real target can be checked rather than guessed; the new script runs there, first and unconditionally, since tag refs pass it by construction. Blocks `HEAD:main`, `feature:main`, `+HEAD:main`, `HEAD:refs/heads/main`, and `:main` (deleting the remote protected branch). Covered by `.ai-policy/scripts/test-push-refs.sh`, auto-discovered by `project-validation.sh` and run in every repo since neither layer is tool-specific ([#195]).

### Changed

- `.ai-policy/hooks/block-protected-branch-bash.sh` now parses a `git push` refspec and blocks when its target names a protected branch, independent of the current branch. This fires before the command runs, so the agent gets a better error than a rejected push, but it works from a command string and can be defeated by shell constructs it cannot parse (a flag taking a separate value shifts the positional count); `check-push-refs.sh` is the backstop. Tag pushes, plain `git push`, and pushes to non-protected branches are unaffected ([#195]).
- Corrected the comment at `.ai-policy/hooks/block-protected-branch-bash.sh:22-24`, which stated that "the authoritative safety net is the pre-push git hook, which inspects the actual refs being pushed". The pre-push hook read the refs only to classify the push as tag-only, then delegated to a check that ignored them, so the layer described as authoritative did not perform the check attributed to it and a reader would reasonably conclude the route was already protected. The comment now names `check-push-refs.sh`, which does perform it, and states which layer wins when the two disagree ([#195]).

### Fixed

- Fixed a fail-open in `check-push-refs.sh` where a final input line with no trailing newline was silently skipped, allowing the very ref under inspection. Git's pre-push always terminates its lines, so this was not reachable through the hook, but a guard should not depend on its caller's formatting. Caught by a test written before the behaviour was checked ([#195]).

## 3.13.0 - 2026-08-04

### Added

- Added `.ai-policy/hooks/block-pr-merge.sh`, a hook that blocks the agent from merging a pull request on both the shell route (`gh pr merge`, and `gh api` against a `/pulls/N/merge` endpoint) and the MCP route (`merge_pull_request` under any server prefix). `ai-workflow.md` already listed merging and deploy authorisation under "The Human is Responsible For", but nothing enforced it: `.claude/settings.json` allowed `Bash(gh pr:*)` with an empty `deny`, so `gh pr merge` inherited the approval granted to `gh pr view`, and `block-protected-branch-bash.sh` filters to `git commit*|git push*` before evaluating any policy. The existing guards ask "which branch does this write to?", a question a pull request merge cannot answer — it is server-side, touches no local ref, and names no branch — so a merge passed every check while reaching the same end state as a push to a protected branch. This hook asks "is this a merge?" instead, and blocks unconditionally rather than consulting `PROTECTED_BRANCHES`; it deliberately does not look up the PR's base branch, since a network call inside a `PreToolUse` hook fails open on timeout. Wired into all four agent entry points (`.claude/settings.json`, `.codex/hooks.json`, `.gemini/settings.json`, `.github/hooks/block-protected-branch.json`) with no command filter, so it is reached regardless of how each tool gates hook invocation. Covered by `.ai-policy/scripts/test-pr-merge-hook.sh`, auto-discovered by `project-validation.sh` and run in every repo since the hook is not tool-specific ([#193]).

### Changed

- Narrowed the auto-approved `gh pr` permission from a whole-family wildcard to named subcommands (`view`, `list`, `diff`, `status`, `checks`, `checkout`, `create`) in `.claude/settings.json` and `.vscode/settings.json`, and added `Bash(gh pr merge:*)` to the previously empty Claude Code `deny` list. Grouping a consequential command with trivial ones let the most destructive member of the family inherit the approval granted to the most harmless; `gh pr merge`, `gh pr close`, `gh pr edit`, `gh pr ready` and `gh pr review` now prompt. The `deny` entry is secondary to the hook, which is the load-bearing guard ([#193]).
- Inverted the three enforcement-test assertions that certified this gap. `test-claude-code-enforcement.sh`, `test-vscode-copilot-enforcement.sh` and `test-gemini-enforcement.sh` each asserted `assert_allowed "merge_pull_request (no branch — known limitation)"`, so the green validation bar stated that an agent may merge a pull request and any fix closing the hole would have failed validation. Each now keeps the branch-hook assertion, relabelled to record *why* that hook alone was never sufficient, and adds assertions that `block-pr-merge.sh` blocks the merge on both routes. Updated the corresponding fail-open comment in `block-protected-branch-mcp.sh` to point at the new hook instead of describing the gap as a limitation ([#193]).
- `lite-monolithic/ai-workflow.md` has no policy layer, so its version is bumped to stay in canonical parity with no content change ([#193]).

## 3.12.0 - 2026-07-17

### Added

- Added a `SessionStart` drift-reminder hook (`.ai-policy/hooks/check-context-drift.sh`) that injects a reminder when `project-context.md` has not been touched in `CONTEXT_DRIFT_THRESHOLD` or more commits (default 10, configurable in `.ai-policy/policy.env`). The workflow already instructs the agent to read `project-context.md` at task start and flag staleness, but that soft instruction is easily skipped, so context drifts unnoticed in frequently-used repos. The hook adds a deterministic commit-count signal in the repo's existing policy-check pattern; it cannot judge drift (that stays with `aiw-project-context-management`) and is advisory only, always exiting 0 and staying silent when it cannot measure drift (no git repo, or the context file is absent or never committed). Wired into `SessionStart` for Claude Code (`.claude/settings.json`) and Codex (`.codex/hooks.json`), the two tools that expose a session-start event; Gemini and Copilot have no such event and keep relying on the task-start rule. Covered by a new sandbox test (`.ai-policy/scripts/test-context-drift-hook.sh`) auto-discovered by `project-validation.sh`. `lite-monolithic/ai-workflow.md` has no policy layer, so its version is bumped to stay in canonical parity with no content change ([#191]).

## 3.11.0 - 2026-07-16

### Changed

- Added a "Write for the fresh reader, not the edit" principle to `aiw-prompt-smith`. The skill's Shared principles covered altitude, narrow-patching, leading words, demonstrate-don't-describe, positive framing, and reason-free-constrain-late, but nothing about audience: it did not warn against version-transition meta-commentary ("this replaces the old X", "the gates are unchanged", "what changed is…", asides about the editing process) that only makes sense as a diff from a prior version the fresh reader never saw. This is a distinct failure class (an audience error, not an altitude error), observed when prompt-smith was applied to itself. The new principle instructs the author to state the current instruction as if the artifact always said it. Applied identically to `.claude/skills/` and `.agents/skills/`; `lite-monolithic/ai-workflow.md` does not condense prompt-smith, so its version is bumped to stay in canonical parity with no content change ([#189]).

## 3.10.0 - 2026-07-14

### Changed

- Made the "Asking for Guidance" format fire unprompted. The recommendation-and-rationale format for questions lived only as a standalone named section that read as a lookup-on-demand reference, so the agent applied it reliably only when the human said "use Asking for Guidance" and otherwise fell back to a wall of text with the questions tacked on at the end. `ai-workflow.md` now carries a standing `Always Do` rule binding every question or decision put to the human to that format, and the section itself leads with "leads with a recommendation, it does not end with one", requires one decision at a time (most consequential first, wait rather than stack), and names the buried-options anti-pattern as a rule violation. The fix moves the trigger onto the act of asking rather than the section name. Applied identically to `lite-monolithic/ai-workflow.md` ([#187]).

## 3.9.0 - 2026-07-14

### Changed

- Added the untrusted-external-content stance to the ground-truth sourcing guidance introduced in 3.8.0. `aiw-ground-truth` now states that content fetched from outside (web pages, third-party responses, anything an agent reads but did not write) is data to check, never instructions to obey, closing the gap where 3.8.0's new web-search and sub-agent sourcing encouraged reaching for external content without the default-untrusted stance. `CLAUDE.md` carries the same caution on its web-search tool line. Indirect prompt injection is a high-rate real surface, so sourcing ground truth from the open web must not become a channel for injected instructions. Applied identically to `.claude/skills/` and `.agents/skills/`; re-condensed into `lite-monolithic/ai-workflow.md` ([#185]).

## 3.8.0 - 2026-07-13

### Changed

- Reframed the workflow's stance on sub-agents from a single cost-to-justify warning into positive routing guidance, and named the built-in tools at the skill moments where fan-out or clean context pays. `ai-workflow.md` Resource Discipline now routes work to a sub-agent by its shape (broad multi-file search, mechanical or parallelisable work, distillable output, isolated parallel edits) while keeping judgment, design, and review of every returned result in the main loop. Skill triggers added at their fan-out moments: `aiw-planning` routes multi-area codebase reconnaissance to parallel read-only search sub-agents; `aiw-ground-truth` exhausts real sources via search sub-agents and web search before falling back to asking the user; `aiw-verification` folds a fresh clean-context sub-agent into its mandatory end-to-end run, on the leading idea that you are the worst verifier of your own change. Every trigger carries the main-loop-review guard inline, so encouragement does not become blind deference. Concrete Claude Code tool names (Explore, general-purpose, worktree isolation, web search) live in `CLAUDE.md` only; the mirrored skills stay capability-framed and identical across `.claude/skills/` and `.agents/skills/`. Design input drawn from the maintainer's knowledge base; the KB itself does not ship. Re-condensed into `lite-monolithic/ai-workflow.md` ([#183]).

## 3.7.3 - 2026-07-13

### Changed

- Trimmed skill-body openings that restated the frontmatter `description` the loader already matches on, so the body starts at what it uniquely adds. `aiw-github` lost its intro line outright (pure restatement of the description's action enumeration, already the section headings below). `aiw-ground-truth`, `aiw-performance-profiling`, and `aiw-security-testing` kept only the part beyond the description (the re-entry trigger, the added scope of sync/async conversion and stated latency requirement plus platform examples, and the "broader than they look" amplification), dropping the trigger-recap framing. `aiw-planning` collapsed its two adjacent orientation sections ("Where This Skill Sits" and "The Full Skill Sequence") into one, keeping the numbered sequence and the defers-to-other-skills principle. No trigger or rule intent was lost. Surfaced by running the `aiw-prompt-smith` skill across the skill set. Applied identically to `.claude/skills/` and `.agents/skills/`; the lite condensation carries no skill intros, so only its `Version:` header is synced ([#180]).

## 3.7.2 - 2026-07-11

### Changed

- Removed the redundant negative-restatement tail sections ("Anti-Patterns", "What Not to Do", "What Not to Include") from seven skills, where each mostly re-stated in "don't" form a rule the body already gives positively. `aiw-planning`, `aiw-failure-analysis`, and `aiw-verification` lost the section outright (every bullet was a restatement). `aiw-testing`, `aiw-performance-profiling`, `aiw-security-testing`, and `aiw-project-context-management` kept their genuinely net-new items, promoted into the body as positive rules: the component under test must actually run (testing); host-independent assertions and non-production input (performance); testing the project's own use of a framework rather than the framework itself (security); and excluding issue/PR references and process documentation (project-context). No rule's intent was lost. Surfaced by running the `aiw-prompt-smith` skill across the skill set. Applied identically to `.claude/skills/` and `.agents/skills/` ([#178]).

## 3.7.1 - 2026-07-10

### Changed

- `aiw-issue-creation`: collapsed the four-item "What the Issue Must Not Contain" enumeration and its rationale note into a single class-level principle folded into the "may contain" path guidance. The prohibitions (reproducing file contents, code snippets, function/line references, prescribing an approach) were four instances of one class the skill's own note already named; they now read as one rule built on the leading word "peg", stated once, so the guidance also covers cases the list did not enumerate. Applied identically to `.claude/skills/` and `.agents/skills/`; the lite condensation already stated the class-level form, so only its `Version:` header is synced ([#175]).

## 3.7.0 - 2026-07-10

### Added

- `aiw-prompt-smith` skill added to `.claude/skills/` and `.agents/skills/`: a meta-authoring skill for writing and repairing prompting artifacts (system prompts, `CLAUDE.md`, `AGENTS.md`/`AGENT.md`, and other skills). It is organised around *altitude* — fixing the class an instance belongs to rather than appending a narrow rule per failure — and covers a write mode and a repair mode over a shared set of principles. It ships in the full profile to all four tools and is pulled by its description rather than wired into the numbered task flow, like `aiw-issue-creation`. The `lite-monolithic` condensation is unchanged in content because prompt-smith is orthogonal to the coding task flow it condenses; only its `Version:` header is synced to the canonical anchor ([#173]).

## 3.6.0 - 2026-06-18

### Added

- `ai-workflow.md`: new `Resource Discipline` section instructing the agent to protect its context window and the human's quota without doing less than the task requires. It establishes a single priority order (minimise total token cost, with correctness as an absolute floor), a general floor rule that efficiency governs how a required step is discharged and never whether, narrow reading qualified by need, and subagent use tied to the sanctioned parallelism/clean-context purposes rather than spawned as a reflex to empty the main context. The companion rationale and misuse analysis are recorded in `design/decisions/context-economics.md` ([#170]).

## 3.5.2 - 2026-06-12

### Fixed

- `lite-monolithic/ai-workflow.md`: closed the remaining content drift against the canonical workflow and skills. The lite condensation had silently fallen behind on a handful of agent-facing rules; the genuine gaps are now inlined: a new "Test Construction" section (write the failing test first for a Fix, propose a broader class-of-bug test and name the coverage gap, do not mock the boundary a Configure/Migrate must exercise, assert on observable behaviour, and the mutation-style spot check that a suite turns red under deliberate breakage); ground-truth provenance metadata; duplicate-issue search before creating a follow-up; the back-up-the-working-tree safeguard before a risky branch transition; adding observability when the runtime path has no output to read; and the post-merge issue comment and checkbox steps ([#114]).

### Added

- `scripts/repo-validation.sh` now fails when `lite-monolithic/ai-workflow.md`'s `Version:` header does not equal the canonical `ai-workflow.md` version. The lite parity rule was documentation-only and drifted unnoticed; this turns a lagging lite version into a loud validation failure so a canonical bump cannot silently leave the lite file unsynced ([#114]).

## 3.5.1 - 2026-06-12

### Fixed

- The update path now removes the superseded un-prefixed skill directories left behind when upgrading an install that predates the `aiw-` skill-name prefix. The prefix rename ([#100], [#105]) and the project-spec to project-context rename ([#99], [#107]) were recorded only under `### Changed`, never as removable paths, so the updater treated the old directories as local additions and kept them next to the current `aiw-*` skills. They are now recorded as `### Removed` paths below, so the existing directory-removal reconciliation in `scripts/update.sh` deletes them while still preserving genuine local additions (skill directories with no current-product counterpart) ([#165]).

### Removed

- `.claude/skills/planning/` — superseded by `aiw-planning` in the `aiw-` prefix rename; left behind on upgrades from pre-prefix installs.
- `.claude/skills/testing/` — superseded by `aiw-testing`.
- `.claude/skills/failure-analysis/` — superseded by `aiw-failure-analysis`.
- `.claude/skills/issue-creation/` — superseded by `aiw-issue-creation`.
- `.claude/skills/project-spec-management/` — superseded by `aiw-project-context-management` (renamed in the project-spec to project-context move).
- `.claude/skills/logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`; no standalone skill remains.
- `.agents/skills/planning/` — superseded by `aiw-planning`.
- `.agents/skills/testing/` — superseded by `aiw-testing`.
- `.agents/skills/failure-analysis/` — superseded by `aiw-failure-analysis`.
- `.agents/skills/issue-creation/` — superseded by `aiw-issue-creation`.
- `.agents/skills/project-spec-management/` — superseded by `aiw-project-context-management`.
- `.agents/skills/logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`.

## 3.5.0 - 2026-06-11

### Added

- `ai-workflow.md` and `lite-monolithic/ai-workflow.md`: new "Asking for Guidance" section. Whenever the agent asks the human a question or requests guidance on a decision, it must present it as a short framing paragraph, a list of options each with an explanation, a clear recommendation, and the rationale for that recommendation.

## 3.4.1 - 2026-06-09

### Fixed

- `.ai-policy/scripts/project-validation.sh` now warns loudly when no `./scripts/repo-validation.sh` is wired, instead of silently skipping it. A fresh install previously reported "Validation passed" while running only the policy-layer self-checks — none of the host project's tests, linters, or type checks — implying coverage that was not there. The validator now prints an unmistakable `WARNING` whenever repo-specific checks are absent (and announces them when present), so a fresh install can no longer present a silently-empty green gate. Behaviour is unchanged for repos that have wired their own checks ([#155]).

### Added

- `.ai-policy/scripts/test-project-validation.sh`: sandbox regression test asserting the validator warns and still passes when `./scripts/repo-validation.sh` is absent, and runs it without warning when present.

## 3.4.0 - 2026-06-07

### Changed

- `aiw-issue-creation` skill (both `.agents/skills/` and `.claude/skills/`): issues may now reference relevant files by path to locate a concern, while restating, pasting, or paraphrasing file contents is forbidden. This reconciles the former blanket "no file paths" rule into a single coherent boundary — a bare path locates the concern (allowed); file contents, an implementation approach, or a function/line reference bias the implementing agent (forbidden). Issues may also carry an optional, non-binding list of suggested workflow skills to orient whoever implements them ([#156]).

## 3.3.0 - 2026-06-02

### Removed

- `telemetry/` — the entire local OTEL Collector + Prometheus + Loki + Grafana stack, the five dashboards, the redaction pipeline, and both launchd autostart installers. The OTLP/Prometheus pipeline was silently dropping ~80% of sessions and required a babysitting skill to keep alive.
- `evals/` — the baseline evaluation harness. The statistical A/B apparatus (pass^k, McNemar, the n=20 readiness gate) could not produce trustworthy verdicts from a single developer's sparse, cross-repo data.
- `scripts/run-baseline.sh` — baseline harness runner.
- `scripts/compare-versions.py` — pass^k / McNemar comparison.
- `scripts/eval-preflight.sh` — between-review readiness gate.
- `.agents/skills/aiw-evaluation/` — review-readiness skill.
- `.claude/skills/aiw-evaluation/` — review-readiness skill.
- `.agents/skills/aiw-telemetry-setup/` — telemetry enablement skill.
- `.claude/skills/aiw-telemetry-setup/` — telemetry enablement skill.
- `design/decisions/evaluation.md` — evaluation gate rationale.
- `docs/telemetry-setup.md` — telemetry setup guide.
- `docs/telemetry-schema.md` — per-session JSON contract.
- `docs/spikes/d0-sandbox-otel.md` — sandbox OTEL spike.
- `.envrc.example` — telemetry env template.
- `.ai-policy/scripts/update-session-tags.sh` — session-tag writer.

### Added

- `observation/`: a local, single-developer session-observation tool that reads Claude Code transcripts already on disk into a JSONL Session Store and a self-contained static HTML dashboard. Descriptive only, no Docker, no server, nothing running in the background. Captures token usage, estimated cost, tool calls, skill activations, session length, and user turns per session across all repos.
- Global capture installed by `observation/install-observation.sh`: a defensive SessionStart Manifest hook (records `workflow_version` per session) and a `/rate` skill (records a 1-4 quality Rating). Capture is per-developer and global; only the reader and dashboard live in this repo.
- `docs/adr/0001` and `docs/adr/0002` recording the move from statistical comparison to descriptive observation and the global-not-per-repo capture decision; `CONTEXT.md` glossary for the observation domain.

### Changed

- `project-context.md` rewritten to describe the observation tool and corrected skill inventory; `Version:` header bumped to `1.12.0`.
- `scripts/repo-validation.sh` now validates `observation/` (shell syntax, `py_compile`, the parser regression test, JSONL fixture validity) instead of the removed telemetry and harness surface.
- `README.md` and `design/README.md` updated to drop the removed telemetry and evaluation surface.

## 3.2.1 - 2026-05-29

### Fixed

- Shortened the frontmatter `description` of five skills (`aiw-planning`, `aiw-ground-truth`, `aiw-testing`, `aiw-verification`, `aiw-failure-analysis`) in both `.agents/skills/` and `.claude/skills/` to under 1024 characters. OpenAI Codex enforces a 1024-character maximum on skill descriptions and was silently skipping these five at load time, leaving Codex users running the workflow without its core planning, ground-truth, testing, verification, and failure-analysis disciplines. Intent and triggering content are preserved; the repo's own authoring rule (`design/decisions/authoring.md`) already mandated the 1024-character limit ([#152]).

## 3.2.0 - 2026-05-28

### Added

- `scripts/eval-preflight.sh` Condition 5: `.envrc` `OTEL_RESOURCE_ATTRIBUTES` must match the values recomputed from current ruleset files. Catches the recurring tagging-staleness class where a workflow bump or rule edit was never propagated to `.envrc`, so the current session's data was being emitted under the wrong tag.
- `scripts/eval-preflight.sh` Condition 6: the baseline harness must be able to resolve `workflow_version` and `ruleset_hash` at import time. Catches code-side breakage in `evals/harness/context.py` before the next review walks into it.
- `design/decisions/evaluation.md` minimum-data gate updated to document Conditions 5 and 6.

### Fixed

- `evals/harness/context.py` was reading `ruleset_hash` from `.claude/settings.json`'s `env` block, which the telemetry policy (`aiw-telemetry-setup/SKILL.md`) explicitly forbids and `update-session-tags.sh` never writes there. The baseline harness raised `RuntimeError` on every invocation. Now reads from `.envrc`, which is the policy-mandated source.

## 3.1.0 - 2026-05-28

### Added

- `aiw-evaluation` skill in both `.agents/skills/` and `.claude/skills/`: enforces the between-review readiness gate before the periodic workflow review process can produce proposals. Reads `telemetry/eval-readiness.json` (produced by `scripts/eval-preflight.sh`), refuses to run the review past a red gate, and writes a thin-data report under `observations/workflow-reviews/<date>.md` instead. Hands off to `design/decisions/evaluation.md` only when the preflight returns exit 0 ([#145]).

### Changed

- `project-context.md` Project Structure section lists `aiw-evaluation`; `Version:` header bumped to `1.10.0` ([#145]).

## 3.0.0 - 2026-05-28

Major redesign of the workflow structure. The 14-step numbered workflow plus reference sections in `ai-workflow.md` is replaced by a leaner four-section structure (First Principles, Task Flow, Boundary Rules, The Human is Responsible For) that delegates enforcement to a refactored skill set. Three new core skills own concerns previously fused into a single workflow document.

### Added

- `aiw-verification` skill in both `.agents/skills/` and `.claude/skills/`: owns the required justification step before any "done" claim, the evidence hierarchy from static checks through end-to-end runs on real artifacts, the rules for when end-to-end execution is mandatory, modality-aware verification requirements, and the scoping step that names what was not checked.
- `aiw-ground-truth` skill in both directories: establishes where trusted inputs and expected outputs come from during coding tasks. Owns the canonical task modality decision procedure (New, Feature, Fix, Refactor, Improve, Investigate, Migrate, Configure, Delete) shared across `aiw-planning`, `aiw-testing`, and `aiw-verification`.
- `aiw-github` skill in both directories: rules for every GitHub and git history action during a task, including branch safety, rebase discipline, and the rule that commit, push, and PR creation are separate human-approved actions.
- `ai-workflow.md` Task Flow section: six high-level steps that delegate enforcement to the skill set at each step.
- `ai-workflow.md` Non-Functional Dimensions section: conditional loading triggers for `aiw-performance-profiling` and `aiw-security-testing`.
- `ai-workflow.md` Reactive Rules section: explicit override stating that `aiw-failure-analysis` runs when a "done" claim is contradicted, before any fix is proposed; this rule overrides the rest of the workflow when triggered.
- Entry-point files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md`) now require the agent to confirm reading both `ai-workflow.md` and `project-context.md` and being able to invoke the `aiw-*` project skills before responding to the first task message.
- `observations/workflow-reviews/2026-05-28.md`: second worked-example execution of the periodic review process; demonstrates the gate refusing on structural data thinness rather than just sample-size thinness.

### Changed

- `ai-workflow.md` restructured around four sections (First Principles, Task Flow, Boundary Rules, The Human is Responsible For) plus a Reactive Rules override and a Non-Functional Dimensions loader. Replaces the prior 14-step numbered workflow plus reference-section structure.
- `aiw-planning` skill rewritten to own the pre-planning codebase baseline checks (smoke tests, global suite, test readiness, bounded-change confirmation), the task modality classification step that hooks into `aiw-ground-truth`, oracle naming, assumption classification (issue-sourced vs codebase-confirmed), higher-risk flagging, and verification-approach expectations.
- `aiw-testing` skill rewritten to focus on test mechanics, test-level selection, modality-specific testing emphasis (cross-referenced into `aiw-ground-truth`), the anti-patterns that produce misleading green bars, and the hygiene rules that keep a test suite a reliable signal. Ground-truth concerns move to `aiw-ground-truth`; verification-sufficiency concerns move to `aiw-verification`.
- `aiw-failure-analysis` skill rewritten to own the structured pause after a contradicted "done" claim, the audit of the three core skills (`aiw-ground-truth`, `aiw-testing`, `aiw-verification`) to locate where the gap opened, the hypothesis-and-evidence loop that replaces speculative fixing, the convergence check for when repeated fixes are not working, and plan-level flaw detection.
- `aiw-performance-profiling` and `aiw-security-testing` skills retained with light edits to align with the new section structure.

### Removed

- `.agents/skills/aiw-logging-and-observability/` — content redistributed into `aiw-verification` (runtime-output reading as evidence) and `aiw-failure-analysis` (diagnostic logging during investigation). No standalone observability skill remains; the obligations are owned by the verification and failure-analysis skills that consume them.
- `.claude/skills/aiw-logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`.

## 2.16.0 - 2026-04-26

### Added

- `aiw-security-testing` skill in both `.agents/skills/` and `.claude/skills/`: automated security testing rules for changes that touch authentication, authorisation, untrusted input, file-path or shell-command construction, secret handling, external API consumers, or data-access boundaries. Names the trigger surface explicitly and prescribes negative-path coverage, boundary testing, threat-model-aligned assertions, attack-corpus testing for path and command construction, parser/escaper round-trip testing, fixture-secret hygiene, redaction-boundary assertions for log leak coverage, bypass-path testing for trusted-caller exemptions, a feasibility-fallback rule that forbids silent reversion to manual, and a rule against weakening failing security tests without investigation. Motivated by issue #129: security coverage was previously a single negative-path bullet inside `aiw-testing`, which is too narrow for projects with real security surface ([#129]).
- `Security Testing` loader section in `ai-workflow.md`: names the trigger conditions under which `aiw-security-testing` must be loaded, including the catch-all for novel trust boundaries introduced during implementation ([#129]).

### Changed

- `aiw-testing` skill in both skill directories now cross-references `aiw-security-testing` from its `Related Workflow Sections` block and from its `Non-Functional Coverage` security paragraph; the existing one-line negative-path summary remains in place as a minimum bar so `aiw-testing` is still useful when read on its own ([#129]).
- `design/decisions/ai-workflow-line-by-line.md` gains a `### Security Testing` block with rationale entries for each new line in the loader, mirroring the structure used for `Performance and UI-State Profiling` ([#129]).
- `project-context.md` Project Structure section lists `aiw-security-testing`; `Version:` header bumped to `1.8.0` ([#129]).

## 2.15.0 - 2026-04-22

### Changed

- `aiw-telemetry-setup` skill in both `.agents/skills/` and `.claude/skills/` rewritten so that invoking it is the only user-facing action required to turn on telemetry in a target repository. Phase 1 now catches poisoned identity (an `OTEL_RESOURCE_ATTRIBUTES` whose `workflow_repo` does not match the target directory basename, or `workflow_repo=ai-coding-workflow` outside the upstream repo), missing exporters (`OTEL_LOGS_EXPORTER` or `OTEL_METRICS_EXPORTER` absent while telemetry is enabled), protocol/endpoint mismatch, stale identity in tracked `.claude/settings.json`, and local-stack reachability for Prometheus and Loki. Phase 2 always writes both exporters and always bases `workflow_repo` on the target directory. Phase 3 writes to gitignored `.envrc` (direnv path) or `.claude/settings.local.json` (IDE path), never to tracked `.claude/settings.json`. Phase 4 gains a fourth probe layer that emits a synthetic OTLP counter and verifies round-trip via Prometheus, so a configuration that passes but emits no metrics can no longer be mistaken for success ([#136]).
- `.claude/settings.json` no longer carries `env.OTEL_RESOURCE_ATTRIBUTES`. Telemetry identity moves to gitignored `.envrc`, so copying this repository's files into a target repository cannot silently propagate `workflow_repo=ai-coding-workflow` into that target ([#136]).
- `.ai-policy/scripts/update-session-tags.sh` retargets to `.envrc` and inserts/updates a sentinel-delimited managed block idempotently. The `--check` drift mode is removed because there is no longer a tracked file to drift. The script self-scopes to the `ai-coding-workflow` repository by directory-basename check and exits 0 in any other repo ([#136]).
- `README.md` promotes `aiw-telemetry-setup` from an "Optional" extra to the standard telemetry install step for Claude Code. The "Session Telemetry" reference section is rewritten to reflect `.envrc`-hosted identity and the removal of the pre-commit drift check ([#136]).
- `docs/telemetry-setup.md` restructured so the target-repo path points at the skill and the `ai-coding-workflow` path points at `.envrc.example`; both list `OTEL_METRICS_EXPORTER=otlp` and `OTEL_LOGS_EXPORTER=otlp` as required-together ([#136]).
- `.envrc.example` now declares `OTEL_RESOURCE_ATTRIBUTES` alongside the exporter variables so enabling telemetry in this repo sets identity in one place ([#136]).
- `.envrc.example`, the `aiw-telemetry-setup` skill's required change set, README, and `docs/telemetry-setup.md` now require `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`. Claude Code defaults to delta temporality, but the shipped `prometheusremotewrite` exporter requires cumulative — without the override, real Claude Code sessions emit logs to Loki but metrics silently fail to reach Prometheus, leaving the Session Overview, Tool Usage, and Version Comparison dashboards empty. Discovered while post-implementation-verifying that real telemetry (not just the synthetic probe) was reaching both backends ([#136]).

### Removed

- `.ai-policy/hooks/check-session-tags.sh` — pre-commit hook (and its invocation from `.githooks/pre-commit`). The drift it caught was drift in a tracked file; now that identity is no longer tracked, the drift class does not exist ([#136]).
- `.ai-policy/scripts/test-session-tags-hook.sh` — covered the deleted hook ([#136]).
- `.ai-policy/scripts/project-validation.sh` — removed the session-tags test gating from it ([#136]).

## 2.14.0 - 2026-04-20

### Changed

- `ai-workflow.md` Step 9 header reframed from "fix and revalidate" to "check [Failure Analysis Mode] before proposing a fix" so the trigger check runs ahead of the fix; the bullet count drops from four to three ([#98]).
- `ai-workflow.md` Failure Analysis Mode section rewritten to name the dominant trigger inline (user says behaviour is still broken, a fix didn't help, or what they see contradicts what validation reported), retain the manual-verification and runtime-contradiction triggers, and add an explicit "if uncertain, enter" line; total length held to five short sentences ([#98]).
- `aiw-failure-analysis` skill in both `.agents/skills/` and `.claude/skills/` updated: the frontmatter description now names concrete user phrases ("still broken", "still doesn't work", "didn't help", "the bug remains", "not working", "doing the wrong thing") to raise Claude Code auto-surface salience, and the em-dash construction is removed. The skill body is unchanged; triggers live once, in the description, and the body describes the process after entry ([#98]).
- `lite-monolithic/ai-workflow.md` mirrors the Step 9 reframe and the leaner Failure Analysis Mode wording inline; `Version:` header bumped to `2.14.0` ([#98]).

## 2.13.0 - 2026-04-19

### Changed

- `.ai-policy/scripts/project-validation.sh` is now portable across repos. It validates only the policy layer itself (`bash -n` on `.ai-policy/scripts/`, `.ai-policy/hooks/`, and `.githooks/`) and then runs each `test-*.sh` under `.ai-policy/scripts/` whose matching agent entry point is installed: `test-claude-code-enforcement.sh` and `test-session-tags-hook.sh` require `./.claude/`, `test-codex-enforcement.sh` requires `./.codex/`, `test-gemini-enforcement.sh` requires `./.gemini/`, `test-vscode-copilot-enforcement.sh` requires `./.github/hooks/`; `test-changelog-hook.sh` and `test-pre-push-hook.sh` always run. If `./scripts/repo-validation.sh` exists and is executable, it runs at the end. Fresh target-repo installs following the README no longer fail validation on missing paths, and per-tool installs (Claude-Code-only, Codex-only, etc.) are now supported out of the box without editing any shipped file ([#131]).

### Added

- `scripts/repo-validation.sh` at the repo root carries this repo's repo-specific checks (telemetry YAML/JSON syntax, baseline-harness Python `py_compile`, `bash -n` on `telemetry/*.sh` and `scripts/run-baseline.sh`, `docker compose config -q`). The file is not part of the shipped policy layer; target repos supply their own `scripts/repo-validation.sh` to declare their tests, linters, or type checks. The shipped `project-validation.sh` invokes it automatically when present ([#131]).
- README `Post-install setup` now documents `scripts/repo-validation.sh` as the per-repo extension point and describes the agent-gated skipping behaviour of the enforcement tests ([#131]).

## 2.12.0 - 2026-04-19

### Added

- `aiw-performance-profiling` skill in both `.agents/skills/` and `.claude/skills/` — automated performance and UI-state-transition coverage rules. Lists the trigger conditions (UI state transitions, reactive rerenders, caching, memoisation, debouncing, manual state resets, heavy data loops, sync/async path swaps) and prescribes baseline capture, tolerance-anchored latency assertions, multi-run stable-statistic benchmarks, isolated timed sections, UI transition outcome plus latency assertions, caching-workaround regression tests, a feasibility-fallback rule that forbids silent reversion to manual, and a rule against weakening failing thresholds without investigation ([#127]).
- `Non-Functional Test Coverage` reference section in `ai-workflow.md` — requires the agent to attempt automated coverage for UI state transitions, execution latency, and security-relevant behaviour before suggesting manual verification, and to state in writing when automation is not feasible. Motivated by Entry 21 in `observed-ai-failings.md`, where the agent passed functional tests while shipping severe UI stuttering and latency regressions in FCP Auto-Editor ([#127]).
- `Performance and UI-State Profiling` loader section in `ai-workflow.md` — names the conditions under which `aiw-performance-profiling` must be loaded ([#127]).

### Changed

- `Manual Verification Requirements` in `ai-workflow.md` tightened — manual checks must cite the non-functional coverage section before being proposed, and the "automated tests can verify" exclusion is rephrased to target behaviour rather than checks ([#127]).
- Step 7 in `ai-workflow.md` now points at `Non-Functional Test Coverage` and restricts manual checks to what automation cannot cover ([#127]).
- `aiw-testing` skill in both skill directories gained a `Non-Functional Coverage` subsection covering the three categories, a pointer to `aiw-performance-profiling`, a security negative-path rule, and the feasibility-fallback rule ([#127]).
- `lite-monolithic/ai-workflow.md` mirrors the Non-Functional Test Coverage rules inline and carries `Version: 2.12.0`; the file had drifted from canonical since `2.8.0` and this change realigns it only for the non-functional coverage rule set, not for changes introduced between `2.9.0` and `2.11.0` ([#127]).
- `project-context.md` Project Structure section lists `aiw-performance-profiling`; `Version:` header bumped to `1.5.0` ([#127]).

## 2.11.0 - 2026-04-19

### Added

- `aiw-telemetry-setup` skill in both `.agents/skills/` and `.claude/skills/` — guided, mostly-automated process for enabling Claude Code session telemetry in any repository and verifying end-to-end that tagged data reaches the local telemetry store before reporting success. The skill automates pre-flight detection (collector reachability, direnv presence, launch context, existing configuration) and the round-trip probe (collector reachability, shell-env propagation, synthetic OTLP log carrying a fresh UUID matched back in Loki), presents a single consolidated change set for user approval, and never enables telemetry as a default side effect. Motivated by a silent non-emission failure observed during acceptance testing of #101 on 2026-04-19, where an IDE-launched Claude Code session in this repo emitted nothing because `.envrc` did not propagate through the VS Code launch path ([#124]).

### Changed

- `project-context.md` Project Structure section lists `aiw-telemetry-setup` in the enumerated skill set; `Version:` header bumped to `1.4.0` ([#124]).
- `.ai-policy/scripts/update-session-tags.sh` self-scopes to the `ai-coding-workflow` upstream repository. When the current `env.OTEL_RESOURCE_ATTRIBUTES` does not declare `workflow_repo=ai-coding-workflow`, both `--check` and write modes exit 0 without reading, writing, or drift-checking. Downstream repositories that copy `.ai-policy/` wholesale per the install instructions no longer have their skill-written repo-distinguishing tag strings overwritten or commits blocked by the session-tags hook. Covered by three new cases in `.ai-policy/scripts/test-session-tags-hook.sh` ([#124]).

## 2.10.0 - 2026-04-19

### Added

- `workflow-review.md` at repo root — calendar-driven periodic review process executed outside the per-task workflow. Defines a minimum-data gate (≥ 2 versions of baseline data, ≥ 20 real Claude Code sessions per version, paired task coverage, consistent ruleset hash within each version), the inputs read (baseline JSONs, Loki session logs, Prometheus aggregates, sampled transcripts, `observed-ai-failings.md`), the analyses run (`scripts/compare-versions.py` for pass^k / McNemar / metric deltas, event-cluster scans on `tool_decision` and `fix_cycles`, LLM-as-judge on transcripts with required snippet citations), the proposal output format with five classifications (`hook`, `skill`, `rule`, `step`, `multi`), the disqualifying conditions (single-session evidence, sub-gate quantitative data, no specific surface, uncited LLM-judge claims, vague proposed change, missing rollback plan), and the approval workflow that funnels accepted proposals into `aiw-issue-creation` ([#113]).
- `docs/workflow-review-example-2026-04-19.md` — first worked example produced under the periodic review process; demonstrates the gate refusing on quantitative thinness (only `2.9.0` mock-agent baseline data on disk, zero captured Claude Code sessions) and includes one illustrative qualitative-only proposal that would itself be rejected under the disqualifying conditions ([#113]).

### Changed

- `project-context.md` Scope and Project Structure sections updated to list the new periodic review process and worked example; `Version:` header bumped to `1.3.0` ([#113]).
- `README.md` Maintenance documents section updated with a one-line pointer to `workflow-review.md` and the first worked example ([#113]).

## 2.9.0 - 2026-04-19

### Added

- `evals/` directory — baseline task harness (Sub-issue D) that runs frozen coding tasks and writes per-session JSONs matching `docs/telemetry-schema.md` ([#112]).
- `evals/harness/` — runner, JSON writer, workflow-version / ruleset-hash reader, pytest-based grader, and two agents: a host-side `mock` (copies a reference `solution/` into the workspace to prove the pipeline end-to-end) and `claude-code` (launches `claude -p` headlessly and parses `stream-json` for tokens, cost, tool calls, and session id; parser verified against a real t-001 run producing `input=8 output=301 cache_read=53401 cache_creation=27029 cost=$0.20 tool_use=[Read, Edit]`) ([#112]).
- `evals/harness/Dockerfile` and `evals/harness/compose.yaml` — sandbox image with the Claude Code CLI and pytest; reuses the D0 `host.docker.internal:host-gateway` bridge so OTEL traffic from inside the sandbox reaches the host collector ([#112]).
- `evals/tasks/` — three initial tasks drawn from `observed-ai-failings.md` patterns: `t-001-add-sum-function`, `t-002-fix-off-by-one`, `t-003-rename-function`, each with `spec.md`, `starter/`, `solution/`, and a hidden pytest `grader/` ([#112]).
- `scripts/run-baseline.sh` — creates `evals/.venv`, installs requirements, and runs one or more tasks × repeats; writes results to `telemetry/data/baseline/<version>/<ruleset_hash>/<task>/<run>.json` ([#112]).
- `scripts/compare-versions.py` — loads two versions' results, reports per-task and aggregate pass^k, runs McNemar's test on paired pass/fail outcomes (via `scipy.stats.binomtest` with an exact-binomial fallback), and prints mean/median deltas on duration, cost, tokens, and fix cycles ([#112]).
- `project-validation.sh` now `bash -n`s `scripts/run-baseline.sh` and `py_compile`s everything under `evals/harness/`, `evals/tasks/`, `evals/spikes/`, and `scripts/` ([#112]).
- Root `.gitignore` blocks `evals/.venv/` and Python caches ([#112]).

### Changed

- `docs/telemetry-schema.md` promoted from draft v0.1 to v0.2; `fix_cycles`, `checkpoint_reached`, `plan_accepted_first_pass`, and `tests.pre_baseline_passed` are now explicitly optional (nullable) in the v0.2 harness; shape is otherwise unchanged ([#112]).
- `project-context.md` Architecture Summary and Project Structure updated: this repo now ships runtime Python code under `evals/` and `scripts/` alongside the documentation and telemetry layers ([#112]).

## 2.8.0 - 2026-04-19

### Added

- `telemetry/` directory with a local OpenTelemetry Collector + Prometheus + Loki + Grafana stack (`docker-compose.yml`, per-service configs, provisioning, and four dashboards: session overview, tool usage, fix cycles, version comparison) for visualising Claude Code session telemetry emitted under the tags added in 2.7.0 ([#110]).
- `telemetry/otel-collector-config.yaml` redaction pipeline: strips `user.email`/`user.account_uuid`/`user.account_id`, hashes `user.id`/`organization.id`, scrubs emails/home paths/API-key patterns from log bodies, and truncates log attributes to 4096 chars ([#110]).
- `telemetry/up.sh`, `telemetry/down.sh` convenience wrappers and `telemetry/.gitignore` blocking captured data from the repo ([#110]).
- `docs/telemetry-setup.md` maintainer-facing setup, redaction, and troubleshooting guide ([#110]).
- `docs/telemetry-schema.md` draft v0.1 of the baseline-harness per-session JSON contract consumed by Sub-issue D (#112) ([#110]).
- `project-validation.sh` now syntax-checks `telemetry/*.sh`, telemetry YAML configs (when `python3` + `pyyaml` are present), Grafana dashboard JSON, and runs `docker compose config -q` when Docker is installed ([#110]).

### Changed

- README Session Telemetry section now links to `docs/telemetry-setup.md` and documents `./telemetry/up.sh` / `./telemetry/down.sh` ([#110]).
- `project-context.md` Architecture Summary updated to reflect the optional telemetry runtime layer; Key Dependencies document `docker` + `python3` + `pyyaml` as optional ([#110]).

## 2.7.1 - 2026-04-19

### Fixed

- Pre-push hook and agent PreToolUse hooks no longer block tag pushes from protected branches; `git push <tag>`, `git push --tags`, and MCP `create_ref` for `refs/tags/*` now succeed from `main` while branch pushes remain blocked ([#104]).

### Added

- `.ai-policy/scripts/test-pre-push-hook.sh` covering tag-vs-branch discrimination in the git-level pre-push hook, wired into `project-validation.sh` ([#104]).

## 2.7.0 - 2026-04-19

### Added

- `.ai-policy/scripts/update-session-tags.sh` computing `workflow_version` and an 8-hex `ruleset_hash` across rule-defining files and writing them into `.claude/settings.json`'s `env.OTEL_RESOURCE_ATTRIBUTES` ([#109]).
- `.ai-policy/hooks/check-session-tags.sh` pre-commit check that blocks commits when the tag fragment drifts from the current ruleset ([#109]).
- `.ai-policy/scripts/test-session-tags-hook.sh` enforcement test, wired into `project-validation.sh` ([#109]).
- README section describing the three maintainer-side telemetry shell variables and the OTEL temporality gotcha ([#109]).

### Changed

- `.claude/settings.json` carries a committed `env.OTEL_RESOURCE_ATTRIBUTES` value so Claude Code sessions emit tagged telemetry when the maintainer enables it.

## 2.6.0 - 2026-04-19

### Added

- `CHANGELOG.md` at repo root with backfilled entries for 2.0.0 through 2.5.1.
- `.ai-policy/hooks/check-changelog.sh` pre-push hook rejecting version bumps without a matching changelog entry.
- `.ai-policy/scripts/test-changelog-hook.sh` enforcement test, wired into `project-validation.sh`.

### Changed

- `ai-workflow-design-decisions/context-budget-and-maintenance.md` names `ai-workflow.md`'s `Version:` header as the canonical version source and requires a changelog entry for every bump.
- `lite-monolithic/ai-workflow.md` version header aligned to the canonical version.

## 2.5.1 - 2026-04-19

### Changed

- Renamed `project-spec` to `project-context` across workflow, skills, and agent entry points ([#99], [#107]).

## 2.5.0 - 2026-04-18

### Changed

- Namespaced core workflow skills with the `aiw-` prefix to avoid collisions with project-specific or third-party skills ([#100], [#105]).

## 2.4.0 - 2026-04-18

### Added

- `project-spec-management` skill, replacing the static `project-spec-template.md` ([#103]).

## 2.3.0 - 2026-04-13

### Changed

- Condensed the Validation Requirements, GitHub Workflow, and Boundary Rules sections ([#87], [#88]).

## 2.2.0 - 2026-04-13

### Added

- Test readiness checks in Step 1, feedback loop rules, and the `testing` skill ([#85], [#86]).

## 2.1.0 - 2026-04-13

### Added

- Explicit pre-PR readiness check as Step 11 ([#81], [#83]).

## 2.0.1 - 2026-04-13

### Fixed

- Audit-driven quick fixes across workflow wording and consistency ([#78], [#82]).

## 2.0.0 - 2026-04-12

### Changed

- Rewrote `ai-workflow.md` for writing quality, rule placement, and structural cleanup ([#77]).

[#77]: https://github.com/philippe-ths/ai-coding-workflow/pull/77
[#78]: https://github.com/philippe-ths/ai-coding-workflow/issues/78
[#81]: https://github.com/philippe-ths/ai-coding-workflow/issues/81
[#82]: https://github.com/philippe-ths/ai-coding-workflow/pull/82
[#83]: https://github.com/philippe-ths/ai-coding-workflow/pull/83
[#85]: https://github.com/philippe-ths/ai-coding-workflow/issues/85
[#86]: https://github.com/philippe-ths/ai-coding-workflow/pull/86
[#87]: https://github.com/philippe-ths/ai-coding-workflow/issues/87
[#88]: https://github.com/philippe-ths/ai-coding-workflow/pull/88
[#99]: https://github.com/philippe-ths/ai-coding-workflow/issues/99
[#100]: https://github.com/philippe-ths/ai-coding-workflow/issues/100
[#103]: https://github.com/philippe-ths/ai-coding-workflow/pull/103
[#105]: https://github.com/philippe-ths/ai-coding-workflow/pull/105
[#107]: https://github.com/philippe-ths/ai-coding-workflow/pull/107
[#104]: https://github.com/philippe-ths/ai-coding-workflow/issues/104
[#109]: https://github.com/philippe-ths/ai-coding-workflow/issues/109
[#110]: https://github.com/philippe-ths/ai-coding-workflow/issues/110
[#156]: https://github.com/philippe-ths/ai-coding-workflow/issues/156
[#155]: https://github.com/philippe-ths/ai-coding-workflow/issues/155
[#99]: https://github.com/philippe-ths/ai-coding-workflow/issues/99
[#165]: https://github.com/philippe-ths/ai-coding-workflow/issues/165
[#166]: https://github.com/philippe-ths/ai-coding-workflow/issues/166
[#114]: https://github.com/philippe-ths/ai-coding-workflow/issues/114
[#170]: https://github.com/philippe-ths/ai-coding-workflow/issues/170
[#173]: https://github.com/philippe-ths/ai-coding-workflow/issues/173
[#175]: https://github.com/philippe-ths/ai-coding-workflow/issues/175
[#178]: https://github.com/philippe-ths/ai-coding-workflow/issues/178
[#180]: https://github.com/philippe-ths/ai-coding-workflow/issues/180
[#183]: https://github.com/philippe-ths/ai-coding-workflow/issues/183
[#185]: https://github.com/philippe-ths/ai-coding-workflow/issues/185
[#187]: https://github.com/philippe-ths/ai-coding-workflow/issues/187
[#189]: https://github.com/philippe-ths/ai-coding-workflow/issues/189
[#191]: https://github.com/philippe-ths/ai-coding-workflow/issues/191
[#193]: https://github.com/philippe-ths/ai-coding-workflow/issues/193
[#194]: https://github.com/philippe-ths/ai-coding-workflow/pull/194
[#195]: https://github.com/philippe-ths/ai-coding-workflow/issues/195
[#197]: https://github.com/philippe-ths/ai-coding-workflow/issues/197
[#177]: https://github.com/philippe-ths/ai-coding-workflow/issues/177
[#200]: https://github.com/philippe-ths/ai-coding-workflow/issues/200
[#202]: https://github.com/philippe-ths/ai-coding-workflow/issues/202
[#143]: https://github.com/philippe-ths/ai-coding-workflow/issues/143
[#145]: https://github.com/philippe-ths/ai-coding-workflow/issues/145
[#204]: https://github.com/philippe-ths/ai-coding-workflow/issues/204
[#205]: https://github.com/philippe-ths/ai-coding-workflow/issues/205
[#212]: https://github.com/philippe-ths/ai-coding-workflow/issues/212
[#211]: https://github.com/philippe-ths/ai-coding-workflow/issues/211
[#213]: https://github.com/philippe-ths/ai-coding-workflow/issues/213
[#214]: https://github.com/philippe-ths/ai-coding-workflow/issues/214
[#208]: https://github.com/philippe-ths/ai-coding-workflow/issues/208
[#209]: https://github.com/philippe-ths/ai-coding-workflow/issues/209
[#224]: https://github.com/philippe-ths/ai-coding-workflow/issues/224
[#210]: https://github.com/philippe-ths/ai-coding-workflow/issues/210
[#216]: https://github.com/philippe-ths/ai-coding-workflow/issues/216
