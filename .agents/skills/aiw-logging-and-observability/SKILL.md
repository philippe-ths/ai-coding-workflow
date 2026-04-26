---
name: aiw-logging-and-observability
description: "Ensures the agent has enough runtime observability to validate its changes. Use this skill when automated tests alone cannot prove the change works correctly. It covers which changes need observability, how to add logging, and how to write diagnostics for runtime investigation."
---

# Logging and Observability

Read this file when the change requires runtime observability to validate correctness.
This skill ensures you have enough runtime visibility to prove your changes work.

## Changes That Typically Need Observability

- Data writes or sync operations.
- State transitions.
- User-facing flows.
- Silently failing error handling paths.
- Integration points between layers.

## When Adding Logging

- Use the project's existing logging approach.
- If no logging approach exists, flag this in the plan.
- Log the action, relevant identifiers, and outcome.
- Include enough context to trace a problem without a debugger.
- Do not add logging for trivial operations.
- Do not add logging that would expose sensitive user data.
- Do not log full data payloads unless explicitly needed.
- If a change affects writes, sync behaviour, state transitions, or reactive screens, decide whether temporary diagnostic logging is needed to verify the runtime path.
- Prefer logs or probes that confirm which code path executed.
- Prefer logs or probes that confirm which identifiers were used.
- Prefer logs or probes that confirm which state transition occurred.
- If observability is too weak to distinguish between competing hypotheses, flag this before continuing.
- Remove temporary diagnostics before completion unless the human approves keeping them.
- If a higher-risk change fails manual verification before the runtime path is proven, decide whether temporary diagnostics or another direct observation method is needed before asking the human to retry.

## When Investigating Root Causes or Verifying Runtime Behaviour

- Prefer automated diagnostics over asking the human to observe and report.
- Write diagnostics that capture structured, non-sensitive output.
- Capture event types, state changes, control flow decisions, and timestamps when relevant.
- Run the diagnostic.
- Read the results.
- Use the results to drive the next step.
- If a diagnostic cannot avoid capturing sensitive data, do not write it.
- Describe what to look for.
- Let the human observe it directly.
- Only ask the human to provide logs or reproduce behaviour when automated observation is not possible.
- If only the human can trigger the condition, ask the human to trigger it and provide the raw output.
- Do not ask the human to interpret the results.
- Do not write diagnostics that output sensitive data, including tokens, credentials, PII, full payloads, or anything that could identify a real user.
