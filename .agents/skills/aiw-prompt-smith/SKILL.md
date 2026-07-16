---
name: aiw-prompt-smith
description: Author or repair prompting artifacts, including system prompts, CLAUDE.md, AGENTS.md/AGENT.md files, and other skills. Use when writing any of these from scratch, and especially when one has produced a noticed failure and needs fixing at the cause rather than a narrow patch. Trigger whenever the user is drafting, reviewing, tightening, or debugging a system prompt, a project-instructions file, an agent-instructions file, or a skill, even if they don't say the word "prompt", e.g. "my CLAUDE.md keeps making it do X", "this skill over-triggers", "help me write instructions for the agent", "why does my agent ignore this rule". Prefer this skill over ad-hoc editing whenever the likely fix would otherwise be to just append another rule.
---

# Prompt Smith

Two jobs, one spine. Use this when **writing** a prompting artifact (system prompt, CLAUDE.md, AGENTS.md/AGENT.md, or another skill) or **repairing** one after it produced a failure you noticed.

The governing idea is **altitude**. Every instruction sits at some level of generality, and most prompt problems are altitude errors. Too low and you write a brittle rule for the one case in front of you, and this is what breeds bloat. Too high and you write something so vague it steers nothing. Aim for the altitude where a competent role or a named concept does the work.

This skill is deliberately small. If your edit makes an artifact longer without making it clearer, you are probably patching the instance, not fixing the class.

## Start here (both modes)

Before writing or editing anything, get three answers. If you are repairing, get a fourth.

1. **Behaviour**: what should the artifact make the model do?
2. **Failure it prevents**: what goes wrong without this? If nothing, you do not need the instruction.
3. **One example**: a concrete good-vs-bad pair, ideally an awkward case rather than an easy one.
4. **(Repair only) Instance or class**: is this a one-off, or a pattern the artifact should handle as a category?

If you cannot answer these, you are not ready to write. Ask, do not guess. A confident wrong instruction costs more than a question.

## Repair mode (a noticed failure)

The default reflex is to append a narrow rule aimed at the exact failure. Resist it. That reflex is what produces prompt bloat, one reasonable-looking line at a time.

- **Diagnose before you edit.** State the underlying cause and classify instance vs class *first*, in words, before touching the text. Reasoning first defeats the reflex patch.
- **Find the altitude of the fix.** Repair the class the instance belongs to, not the instance. Test any candidate line: *would this still tell the model what to do in a situation you did not foresee?* If not, it is too low, so climb.
- **Subtraction first.** Before adding anything, look for an existing instruction that is *causing* the failure. Often the fix is removing or rewriting a line, not adding one.
- **Net-zero, as a forcing question.** Ask "what can come out to make room for this?" You may genuinely need to add, but make addition earn its place instead of being the default.

*Worked repair.* A CLAUDE.md says "always run the tests," and the agent starts running the full suite after every trivial edit. The reflex is to append "but not after comment-only changes", a second rule racing the first. Diagnose instead: the failure is not a missing exception, it is that "always" is the wrong altitude. The instance is "skip tests for comment-only edits"; the class is "the rule over-commands." So the fix is subtraction, not addition: soften the existing line to "run the tests before handing work back." The artifact gets shorter and the behaviour gets righter.

Then apply the shared principles below to whatever you write.

## Write mode (a new artifact)

- **Pull, not push.** A skill is for behaviour that should not live in the always-on system prompt. Keep the always-on footprint tiny and let the skill be pulled in when its description matches. If it belongs in the base prompt, it is not a skill.
- **One job.** Keep each artifact to a single job and compose several, rather than growing one into a monolith. For a skill, the description header is what triggers it, so write that with the most care.
- **Trust the model for judgment, constrain it for interfaces.** For anything the model already knows well (a good running coach, clean code, clear writing), name the role or the standard and let its latent knowledge fill in. Do not enumerate every rule the role would follow, because you cannot finish the list, and trying breeds bloat. Specify explicitly only where the model *cannot* know: private facts, exact formats and APIs, current information, safety-critical limits. Delegate the disposition, pin down the interface. This is not licence to under-specify: a vague prompt just inherits the model's bland average.

Then apply the shared principles below.

## Shared principles (both modes)

- **Leading words.** Ground a behaviour in a named concept and reuse that exact phrase at the key steps. A good leading word ("vertical slice", "reason free constrain late", "a good running coach") compresses a paragraph into a term the model already carries, and it surfaces in the model's own reasoning. Check it landed: run the artifact and look for the phrase in the trace. If it is absent, pick a stronger phrase or demonstrate it. Use a leading word a couple of times, not on every line; overused, it is noise again.
- **Demonstrate, do not just describe.** An adjective leaves room the model fills with its average; an example pins down the hundred small choices the adjective cannot. Show the *hard* case (how the artifact behaves on a refusal, a messy input, being wrong), not the easy one. One good example retires several brittle rules.
- **Positive framing.** Say what to do, not only what to avoid. "Prefer X" steers better than a pile of "don't"s.
- **Write for the fresh reader, not the edit.** The artifact is read cold, with no memory of how it got here. Cut meta-commentary that only makes sense as a diff from a previous version — "this replaces the old X", "the gates are unchanged", "what changed is…", asides about your editing process. Test: *would this line still make sense to a reader who never saw the prior version?* If it only lands as a before-and-after, it is talking to you, not the model. State the current instruction as if it always said this.
- **Reason free, constrain late.** If the artifact forces an output format, let the model think in open text first and apply the strict shape at the end. Constraining from the first token starves the reasoning step; even a brief reason alongside the answer recovers most of the loss.

## Before you finish: the elegance check

Read your output once more with fresh eyes:

- Could this be shorter without losing meaning?
- Is anything a rule that would work better as one example?
- Did you add without cutting? If so, is the addition really earning its place?

A skill about avoiding bloat that is itself bloated has failed. Hold this one to its own standard.
