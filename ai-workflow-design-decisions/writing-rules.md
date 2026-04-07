# Writing Rules — AI Workflow Design Decisions

Covers how to write lines in `ai-workflow.md`: sentence structure, style, tone, and formatting.

## Writing Rules

**One sentence per line.**
Every line should contain exactly one sentence.

**No em-dashes.**

**Writing style.**
Every line should be a direct instruction or a direct statement of fact.
Use imperative mood: "Do X", "Do not do X", "Flag this to the human."
Do not use passive voice: "The plan should be reviewed" is weaker than "Wait for the human to review the plan."
When there is a conditional, put the condition first: "If X, do Y."
Do not hedge: avoid "consider", "you might want to", "it is generally a good idea to."
The file instructs. It does not teach, persuade, or justify.
Do not include rationale for bright-line mechanical rules where the instruction is unambiguous on its own.
Include inline rationale for a rule only when all three criteria are met: the rule requires a judgment call, an agent could comply with the literal wording while violating the intent, and understanding the why would materially change how the agent applies the rule in ambiguous cases.
Use the format: rule sentence on its own line, then "(Why: rationale.)" on the next line or in a parenthetical on the same line.
Every rationale line consumes tokens that compete with the actual task, so each one must earn its place.


**Negative rules need a positive alternative.**
A rule that only says "Do not do X" leaves the agent guessing what to do instead.
Where possible, pair it with the correct action: "Do not add logging for trivial operations" is fine because the alternative is obvious (do nothing). "Do not use console.log" is incomplete without "Use the project logger instead."

**Concrete over abstract.**
Prefer concrete actions over abstract goals.
"Run the full test suite" over "Ensure adequate test coverage."
"Flag the mismatch to the human" over "Communicate discrepancies appropriately."
Abstract instructions give the agent room to interpret, which means room to get it wrong.

**Keep lines short.**
If a line needs a subordinate clause to make sense, it is probably two rules and should be split.
Long lines are harder for the model to attend to and easier to partially skip.

**Emphasis formatting.**
Do not use bold, caps, or exclamation marks as a general priority signal across the file.
Position in the file and placement in First Principles remain the primary priority signals.
Exception: apply CAPS to the opening action verb in boundary rule bullets only (ALWAYS, ASK, NEVER).
This targets generation-time salience for unconditional rules, not abstract priority.
Do not extend caps emphasis to reference section rules or workflow steps.
If emphasis is used broadly, it loses its salience effect and adds noise tokens.
