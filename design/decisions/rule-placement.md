# Rule Placement — AI Workflow Design Decisions

Covers where rules belong within `ai-workflow.md`: canonical location, section boundaries, and structural discipline.

## Rule Placement

**One canonical location per rule.**
Every rule should exist in exactly one place.
If the same rule appears in two sections, decide which section owns it and remove the other.
Duplication causes drift over time and wastes context tokens: every added line dilutes compliance across all other rules.
(See `design/research/token-efficiency-in-agentic-workflows.md#ifscale-instruction-compliance-decay` for the measured compliance decay as instruction count grows, and `#chroma-context-rot` for retrieval and adherence degradation under long context.)
When a rule has both an advisory form and an enforcement form, keep the advisory form once in `ai-workflow.md` and keep the enforcement form in repo-local deterministic policy.

**Deterministic policy placement.**
Bright-line machine-checkable boundaries should move into deterministic repo-local policy when practical.
Keep the rule once in `ai-workflow.md` in its shortest actionable form if the agent needs it to avoid the blocked path before enforcement.
The workflow should prevent avoidable collisions with the trust layer.
The trust layer should catch misses, not replace the agent's ability to plan correctly.
Remove repeated wording, rationale, and mirrored positive or negative forms.
State activation checks and recovery steps once in the owning section.
Do not restate the same mechanically enforced boundary across multiple workflow sections.

**Workflow steps should be lean.**
A workflow step should contain sequenced actions and pointers to reference sections.
It should not contain detailed rules, principles, or human responsibility statements.
If a line in a workflow step reads like a rule rather than a sequenced action, it probably belongs in a reference section or boundary section.
(See `design/research/token-efficiency-in-agentic-workflows.md#chroma-context-rot` for why long always-loaded content degrades compliance even when the content is present, and `design/decisions/context-economics.md` for the progressive-disclosure economic argument.)

**Human responsibilities do not belong in workflow steps.**
Lines describing what the human does (e.g. "Human reviews the results") should not appear inline in workflow steps.
Human checkpoints are expressed as explicit numbered steps (e.g. "Checkpoint 4: human reviews the plan.").
Detailed human responsibilities live in the "The Human is Responsible For" section.

**Boundary rules are context-free. Reference section rules are context-dependent.**
A rule belongs in the boundary section if it applies regardless of which step or topic is active.
A rule belongs in a reference section if it only makes sense within that section's topic.
If a rule appears in both places, ask: does this rule need the surrounding context to be actionable?
If it does, the reference section is the canonical location.
If it does not, the boundary section is the canonical location.
Do not keep it in both.

**Boundary rule clustering.**
Over time, boundary rules tend to accumulate.
When 4-5 or more boundary rules cluster around the same topic, that is a signal the topic deserves its own reference section.
Extract the cluster into a new reference section and remove the individual rules from the boundary section.
The real test is whether the rules share a context: if you would naturally read them together and they reference the same concepts, they are a cluster.
This keeps the boundary sections lean and genuinely global.

**Keep First Principles minimal.**
Only add a line to First Principles if it is genuinely foundational and not adequately expressed by the workflow structure or any reference/boundary section.
If a principle can live in a reference section instead, put it there.
(See `design/research/prompt-engineering.md#lost-in-the-middle` for U-shaped positional attention, and `#mosaic-primacy-recency` for the caveat that primacy and recency effects are model-specific. The First Principles section is a high-salience location, but the effect depends on the model, so treat the section as a place for genuinely foundational rules rather than for any rule marked important.)

## Coupling Between Skills

**Naming a neighbour is intended; restating it is not.**
A skill names the skill that owns adjacent territory, so an agent reading one knows where the next rule lives: aiw-planning names aiw-verification for evidence, aiw-verification names aiw-ground-truth for the oracle. Listing which skills make up a step, such as the three at the done gate, is naming too.
That reference is the design working, and a change to one skill's territory is expected to touch the names that route to it.
A skill that restates what another file says, its rules or its sequence, is unintended coupling: the copy drifts, and a change to the owner then needs a matching edit that nothing prompts.
Restated content is removed when found, keeping the rule in the skill that owns it and a name everywhere else.

**Co-change across the core is not on its own evidence of a defect.**
In this repository most tasks change the rules themselves, and a rule about when the human is asked, or what the done gate checks, legitimately touches every skill that routes to it.
A co-change graph built from that history measures what the work was about as much as how the files are built.
The propagation-cost figure behind the question moved with its thresholds, so only a before-and-after at fixed settings would mean anything, and the scripts that produced it were not kept; rewriting them to measure a number whose absolute value means nothing is not worth doing when the distinction above can be applied directly.
So the decision rests on the distinction rather than on the graph.
Applied to the core, it found one instance of the unintended kind: `aiw-planning` restated the Task Flow from `ai-workflow.md` and the copy had drifted a step behind; #262 replaces the copy with a pointer.
Restatement in general is found by reading; #262 adds checks to `scripts/check-prose-integrity.sh` for the narrow cases where a list or a claim can be compared mechanically (done-gate lists, Task Flow step claims), and its output says it cannot judge the rest.
