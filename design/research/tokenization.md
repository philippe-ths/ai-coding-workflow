# Tokenization and Token-Level Effects

Primary-source notes on how tokenization shapes model behavior and affects instruction files.
See `design/research/README.md` for the citation convention.

---

## Sennrich et al. — BPE as the unit of model consumption {#sennrich-bpe-subword-units}

Source: https://arxiv.org/abs/1508.07909
Extracted: 2026-04-23
Finding: Sennrich, Haddow, and Birch introduced byte pair encoding (BPE) as a subword segmentation strategy for neural sequence models, adapting a compression algorithm to represent an open vocabulary through a fixed-size vocabulary of variable-length character sequences. The model never sees characters or whole words; it sees a sequence of subword token IDs determined by greedy merges learned from a training corpus. This establishes the load-bearing fact that every instruction file is consumed as a BPE token stream, not as text. Any claim about "lines" or "words" in an instruction file is, at the model's input layer, a claim about how that string happens to segment under a specific tokenizer's merge table. The paper does not discuss instruction-file design, but it defines the unit of consumption that all downstream claims rest on.

---

## Karpathy — tokenization causes rare-word, casing, and whitespace pathologies {#karpathy-tokenization-pathologies}

Source: https://github.com/karpathy/minbpe
Extracted: 2026-04-23
Finding: Karpathy's minbpe repository and accompanying "Let's build the GPT Tokenizer" lecture state that "a lot of weird behaviors and problems of LLMs actually trace back to tokenization," and enumerate specific failure modes: poor handling of rare or non-English words, trouble with arithmetic because numbers split into arbitrary multi-digit chunks, case sensitivity (the same word with different capitalisation becomes different token IDs and different learned representations), and sensitivity to leading or trailing whitespace (e.g. "hello" vs " hello" are distinct tokens). The lecture supports the claim that rare words, casing, and whitespace affect how the model parses instructions — BPE boundaries are load-bearing for fidelity. It does not quantify a threshold at which this matters for instruction files specifically.

---

## Sclar et al. — prompt format perturbations swing accuracy by up to 76 points {#sclar-prompt-format-sensitivity}

Source: https://arxiv.org/abs/2310.11324
Extracted: 2026-04-23
Finding: Sclar, Choi, Tsvetkov, and Suhr (ICLR 2024) measure LLM sensitivity to meaning-preserving prompt-formatting changes: different separators, whitespace, casing of field names, choice of bullet character, and similar surface features. On LLaMA-2-13B, performance spreads up to 76 accuracy points across plausible formats of the same task. Sensitivity persists when increasing model size, adding few-shot examples, or applying instruction tuning. Format performance correlates only weakly between models, so a format that helps one model may hurt another. The paper quantifies the load-bearing role of formatting characters — bold, headers, bullets, separators — in determining what the model does. It supports the claim that formatting choices have real downstream effects; it does not claim that formatting is "noise" to be minimised, only that it is not meaning-preserving at the model's level.

---

## Singh and Strouse — digit tokenization changes arithmetic accuracy by ~20% {#singh-strouse-digit-tokenization}

Source: https://arxiv.org/abs/2402.14903
Extracted: 2026-04-23
Finding: Singh and Strouse show that how GPT-3.5 and GPT-4 tokenize multi-digit numbers (the default GPT tokenizer has separate tokens for 1-, 2-, and 3-digit groups and applies them left-to-right) directly affects arithmetic accuracy. Forcing right-to-left tokenization by comma-separating the input numbers improves accuracy by up to 20 percentage points on the same problems. Error patterns under left-to-right tokenization are stereotyped rather than random, suggesting the model's computation is tokenization-aligned. This is a concrete quantitative example of BPE boundaries changing model behaviour on the same underlying content. It generalises beyond arithmetic: the same input string, segmented differently, produces measurably different outputs.

---

## Land and Bartolo — under-trained glitch tokens from tokenizer/training mismatch {#land-bartolo-glitch-tokens}

Source: https://arxiv.org/abs/2405.05417
Extracted: 2026-04-23
Finding: Land and Bartolo (EMNLP 2024) formalise and automate detection of "glitch tokens," tokens present in the tokenizer vocabulary but nearly or entirely absent from training data. The original observation was SolidGoldMagikarp: a single BPE token scraped from a Reddit username list, never encountered in training, that caused GPT-3 to refuse to repeat it, hallucinate, or produce garbled output. The paper develops tokenizer analysis, model-weight indicators, and prompting methods that identify such tokens across current open models, showing the phenomenon is widespread, not a GPT-3 curiosity. The mechanism is a disconnect between the corpus used to train the tokenizer and the corpus used to train the model. This supports the general claim that the identity of a BPE token — not just the string it encodes — can determine instruction fidelity, and that rare or unusual vocabulary items in an instruction file carry additional risk.

---

## No primary-source evidence found for the "long lines are harder to attend to" claim {#no-evidence-line-length-attention}

Source: (negative finding)
Extracted: 2026-04-23
Finding: We could not locate a primary source — arXiv paper, model-maker documentation, or named practitioner writing — that directly tests the claim that long lines inside an instruction file are harder for the model to attend to than short lines of equivalent total token count. Adjacent findings exist: Chroma's context-rot work shows degradation as total context grows (already covered in `token-efficiency-in-agentic-workflows.md`); Sclar et al. (above) show formatting perturbations including separator and newline changes affect output; prompt-sensitivity work (arXiv:2310.11324, arXiv:2508.11383) shows punctuation and whitespace matter. None of these isolate line length from total token count, total rule count, or formatting choice. The claim that short imperative sentences are more token-efficient than verbose prose is trivially true on token count but has no isolated empirical study of attention-per-line that we could locate. Treat the line-length rule in `authoring.md` as a stylistic and diffability choice rather than one with direct empirical backing.
