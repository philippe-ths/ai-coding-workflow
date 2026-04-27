---
name: aiw-security-testing
description: "Automated security testing rules for changes that touch authentication, authorisation, untrusted input, file-path or shell-command construction, secret handling, external API consumers, or data-access boundaries. Use this skill whenever the change crosses a trust boundary or processes input that could be hostile, even if the surface looks routine. The skill exists to prevent the pattern where happy-path tests pass while negative paths, boundaries, and threat-model assumptions go unchecked."
---

# Security Testing

Read this file when the change touches a trust boundary or handles input the system cannot trust.
This file contains rules for writing automated security tests before deferring to manual review or assuming framework guarantees.

## Related Workflow Sections

This skill works alongside these workflow sections. Consult them when writing security tests:

- **Non-Functional Test Coverage**: defines when automated coverage must be attempted before manual verification.
- **aiw-testing**: general test construction rules. This skill covers the security-specific subset.
- **aiw-failure-analysis**: covers what to do when a reported behaviour contradicts what a security test claims.

## When This Skill Applies

Load this skill when the change does any of the following:

- Adds, modifies, or removes an authentication or session check.
- Adds, modifies, or removes an authorisation rule (role check, ownership check, scope check).
- Reads, validates, parses, or transforms input from a user, the network, or an untrusted file.
- Constructs a file path, shell command, SQL query, HTML fragment, or any other string that will later be interpreted by a parser or shell.
- Reads, writes, transmits, or logs a secret: password, API key, token, signing key, or personally identifying data.
- Calls an external API, including hidden retries, callbacks, and webhooks.
- Crosses a data-access boundary between tenants, users, organisations, or environments.
- Adds or modifies CORS, CSP, cookie flags, redirect handling, or any other browser-trust mechanism.

If any of these apply and no automated security coverage exists for the affected behaviour, add coverage as part of the change.

## Rules

1. Test the negative path before claiming coverage.
   For every authorisation rule, write a test that supplies the wrong principal and asserts on the deny outcome: status code, raised exception, empty result set.
   For every input validator, write a test that supplies invalid input and asserts on the rejection.
   A passing happy-path test is not sufficient security coverage; the bug almost always lives in the path the happy test never walks.

2. Test boundaries, not just typical values.
   Empty input, oversized input, off-by-one input, unicode and control characters, null bytes, and the edges of any numeric range each get a test when the validator's behaviour at that boundary matters.
   Validators tend to be correct in the middle of the range and wrong at the edges, so testing only typical values gives a false sense of coverage.

3. Anchor security assertions to the threat model, not to the implementation.
   State what the attacker is trying to achieve and assert that they cannot achieve it.
   "Asserts that user A cannot read user B's records" survives a query refactor; "asserts the SQL contains a WHERE user_id clause" breaks the moment the query changes even if the rule still holds.

4. For path or command construction, test against a corpus of attack strings rather than a hand-rolled regex spot check.
   `..`, absolute paths, symlinks, percent-encoded slashes, null bytes, and shell metacharacters each belong in the corpus.
   The whole point of a corpus is that the next variant nobody anticipated is already in there; hand-rolled checks miss exactly that variant.

5. For parser, escaper, and serialiser code, test the round-trip.
   Encode then decode, or escape then unescape, and assert that the input is preserved exactly.
   A one-way assertion such as "the output contains no `<script>`" misses double-encoded payloads that decode back to the dangerous form downstream.

6. Do not put real secrets in test fixtures.
   Use clearly marked test values like `test-token-do-not-use-in-prod` so a leaked fixture is recognisable as a test artifact rather than a live credential.
   Real secrets in tests end up in version control history, CI logs, and grep results, and the leak is permanent.

7. Do not assert on log absence by string-equality of the payload.
   Assert that the secret-bearing field was redacted at the boundary that owns redaction, and that the redaction function returns the expected sentinel.
   String-matching the log buffer for the secret is fragile: framework changes, log format changes, and async timing all break the assertion without the redaction itself changing.

8. When an authentication or authorisation check is bypassed for a trusted caller (internal service, admin tool, test harness), write a test that proves the bypass cannot be reached from an untrusted caller.
   The bypass is the riskiest line in the change; the test exists to keep it from drifting into a general escape hatch on a future refactor.

9. If automated security coverage is not feasible (for example the path requires a live external service, a real signing certificate, or a production-only data store), state the reason in writing in the plan or summary and propose a manual check with explicit success and failure signals.
   Do not silently fall back to manual verification.

10. Do not weaken, skip, or delete a failing security test before investigating the cause.
    A failing security assertion is, by default, a security regression until proven otherwise.
    Loosening the assertion to make CI green hides exactly the class of bug the test was written to catch.

## What Not to Do

- Do not claim security coverage from a happy-path test that happens to use authenticated credentials. Authenticated traffic exercises the success path, not the boundary.
- Do not test framework-provided protections by reimplementing the attack against the framework. Test the project's own use of the framework: wrong CSRF scope, missing cookie flag, misconfigured CORS, unsigned webhook accepted. Do not test the framework's CSRF middleware itself.
- Do not paste real production tokens, keys, or personal data into test files, even temporarily during local development.
- Do not write security tests that depend on test execution order or on shared mutable state. A test that only passes when run after a specific seed leaves the actual security boundary unverified, because nothing pinned the boundary in place.
