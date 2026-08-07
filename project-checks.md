# Project Checks

What is worth checking in this repository at the start of a session, and what normal looks like for each check.

Maintained by the `aiw-init` skill, which runs these read-only and reports only the deviations. Every check states its normal so a run can stay silent about what is healthy.

Surfaces this repository has no instance of are recorded under "Not Covered Here" rather than left out, so an absent check is never confused with a forgotten one.

## Work in Flight

### Open issues
- Check: `gh issue list --state open --search "updated:>=$(date -v-7d +%Y-%m-%d)"`
- Normal: empty, or only the issue for the branch you are on.
- Matters: an issue filed or updated since your last session may already cover what you were about to start. Scoped to the last week and to the current branch's issue so the normal is one a run can actually evaluate, rather than resting on what you happen to remember.

### Open pull requests
- Check: `gh pr list --state open`
- Normal: none waiting on you.
- Matters: a pull request left open blocks the branch it came from and the issue it closes.

### Uncommitted work
- Check: `git status --porcelain`
- Normal: empty.
- Matters: work left in the tree from a previous session is easy to overwrite on the next branch switch.

### Unpushed commits
- Check: `git log --branches --not --remotes --oneline`
- Normal: empty.
- Matters: commits that exist only locally are invisible to everything else and are lost with the working copy.

### Branches left after a merge
- Check: `git branch --merged origin/main --format='%(refname:short)' | grep -vx "$(git branch --show-current)" | grep -vx main`
- Normal: empty.
- Matters: post-merge cleanup was skipped, and the leftover branch will be mistaken for live work.

## Repository Integrity

### Local main matches remote
- Check: compare `git ls-remote origin main` against `git rev-parse main`
- Normal: identical shas.
- Matters: a branch cut from a stale `main` rebases onto surprises later. Uses `ls-remote` rather than `git fetch`, which writes remote-tracking refs.

### Validation state
- Check: `./.ai-policy/scripts/check-validation.sh; echo "exit $?"`
- Normal: `exit 0`.
- Matters: commits and pushes are blocked until validation passes, so a failed state left from last session stops the first commit of this one. The gate itself compares the recorded pass against a fingerprint of the current tree, so running it reports staleness exactly rather than inferring it from modification times; a non-zero exit names which of the two cases applies. Read-only: the check reads the state file and hashes the tree without writing either.

## Policy Layer

### Git hooks active
- Check: `git config core.hooksPath`
- Normal: `.githooks`.
- Matters: an empty result means protected-branch and validation enforcement is silently off. `./.ai-policy/scripts/install-hooks.sh` restores it.

## Background Jobs

### Scheduled jobs pointed at this repository
- Check: `launchctl list | grep -i aiw` and `ls ~/Library/LaunchAgents | grep -i aiw`
- Normal: no entries, unless the job is one you installed deliberately and its status column reads `0`.
- Matters: a launchd agent outlives the code it calls, so a removed subsystem leaves a job firing on a timer against a path that no longer exists. Nothing in the repository reports this, because the job lives in the user's global config, not here.

## Expiry and Limits

### GitHub authentication
- Check: `gh auth status`
- Normal: logged in with an active account.
- Matters: an expired token turns every issue and pull request check in this file into a false reading rather than an obvious failure.

## Drift

### Project context freshness
- Check: `git rev-list --count "$(git log -1 --format=%H -- project-context.md)"..HEAD`
- Normal: fewer than 10 commits, matching `CONTEXT_DRIFT_THRESHOLD` in `.ai-policy/policy.env`.
- Matters: `project-context.md` is read at task start, so once it drifts the agent plans against a repository that no longer exists.

### Observation dashboard freshness
- Check: `python3 -c "import os,time;p=os.path.expanduser('~/.claude/aiw-observation/dashboard.html');print(int((time.time()-os.path.getmtime(p))/86400))"`
- Normal: 30 or fewer days since the last `make observe`.
- Matters: the dashboard is the only view of how workflow changes are landing across sessions, and a stale one invites conclusions drawn from old data.

## Not Covered Here

- **Application logs and error tracking.** No runtime application exists to produce them. The four zero-byte `.log` files under `telemetry/launchd/` are residue from the removed eval stack, gitignored and never written to since; they are not a live surface.
- **Dependent services.** Nothing is called at runtime. `bash`, `git`, `jq`, and `python3` are developer tools, checked by their absence breaking validation rather than by a health probe.
- **Deployment and CI.** `.github/` holds no workflows, so there is no remote build whose status could be red. The nearest equivalent is the local validation state above.
- **Certificate and secret expiry.** No secrets are held; the only credential is the `gh` token, checked under Expiry and Limits.
- **Database schema and migrations.** No database.
