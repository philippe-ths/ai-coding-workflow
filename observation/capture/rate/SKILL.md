---
name: rate
description: "Record a 1-4 quality rating for the current Claude Code session (1 bad, 2 fine, 3 good, 4 excellent). Use this skill when the user invokes /rate, says 'rate this session', or otherwise wants to log how the session went. The rating is the only human quality signal in AI Workflow session observation; it is matched to the session by repo and time at collection. Installed globally so it works in every repo."
---

# Rate this session

The user is recording a 1-4 quality rating for the current session:
1 = bad, 2 = fine, 3 = good, 4 = excellent.

## What to do

1. Determine the rating number from the user's message (e.g. `/rate 3` -> `3`). It must be 1, 2, 3, or 4.
2. If no clear number was given, ask the user for one (1-4) and stop. Do not guess.
3. Record it by running exactly:

   ```
   bash ~/.claude/aiw-observation/record-rating.sh <N>
   ```

   where `<N>` is the number. Run it from the session's working directory (the default), so the rating is tagged with the correct repo.
4. Report the one-line confirmation the script prints. Do not add commentary or interpretation.

## Notes

- This records only the rating, repo name, and timestamp. No prompt or code content.
- Ratings are sparse and optional; one rating per session is enough. If the user rates twice, the later rating wins at collection time.
- To see ratings on the dashboard, run `make observe` in the ai-coding-workflow repo.
