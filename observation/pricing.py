"""Estimated session cost from token counts.

Claude Code transcripts store no cost figure (cost is null on disk), so cost here
is ESTIMATED: token counts times the public list price for the model. It is a
convenience signal, not an authoritative bill. Token counts themselves are exact.

Source: https://platform.claude.com/docs/en/about-claude/pricing, read 2026-10-05.

Maintenance: add a model to RATES when it ships, by its model ID, and re-read the
source when prices change. An unknown model yields a null estimate rather than a
wrong one, so a new model is never priced as its predecessor.
"""

import re

# USD per 1,000,000 tokens: (base input, output, cache-read multiplier of base input).
# Cache writes are 1.25x base input for the 5-minute cache and 2x for the 1-hour cache.
# A ":fast" key is fast mode, whose premium base rates the caching multipliers stack on.
RATES = {
    "claude-fable-5-1": (10.0, 50.0, 0.025),
    "claude-fable-5": (10.0, 50.0, 0.1),
    "claude-opus-5-5": (4.0, 20.0, 0.05),
    "claude-opus-5-5:fast": (8.0, 40.0, 0.05),
    "claude-opus-5": (5.0, 25.0, 0.1),
    "claude-opus-5:fast": (10.0, 50.0, 0.1),
    "claude-opus-4-8": (5.0, 25.0, 0.1),
    "claude-opus-4-8:fast": (10.0, 50.0, 0.1),
    "claude-opus-4-7": (5.0, 25.0, 0.1),
    "claude-opus-4-6": (5.0, 25.0, 0.1),
    "claude-opus-4-5": (5.0, 25.0, 0.1),
    "claude-sonnet-5-5": (2.0, 10.0, 0.1),
    "claude-sonnet-5": (2.0, 10.0, 0.1),
    "claude-sonnet-4-6": (3.0, 15.0, 0.1),
    "claude-sonnet-4-5": (3.0, 15.0, 0.1),
    "claude-haiku-4-5": (1.0, 5.0, 0.1),
}

WRITE_5M = 1.25
WRITE_1H = 2.0

# A dated snapshot ("-20251001") or a context-window suffix ("[1m]") prices as its model.
_SUFFIX = re.compile(r"(-\d{8})?(\[[^\]]*\])?(?=(:fast)?$)")


def _rate(model):
    if not isinstance(model, str):
        return None
    return RATES.get(_SUFFIX.sub("", model.lower(), count=1))


def estimate_cost(model, tokens):
    """Return estimated USD (float, rounded) for a token dict, or None if the model is unknown.

    `cache_creation` is all cache writes; `cache_creation_1h`, where present, is the
    part written to the 1-hour cache, and the rest is priced at the 5-minute rate.
    """
    rate = _rate(model)
    if rate is None:
        return None
    base_in, out, read_mult = rate
    writes = tokens.get("cache_creation", 0) or 0
    writes_1h = min(tokens.get("cache_creation_1h", 0) or 0, writes)
    cost = (
        (tokens.get("input", 0) or 0) * base_in
        + (tokens.get("output", 0) or 0) * out
        + (tokens.get("cache_read", 0) or 0) * base_in * read_mult
        + (writes - writes_1h) * base_in * WRITE_5M
        + writes_1h * base_in * WRITE_1H
    ) / 1_000_000.0
    return round(cost, 4)


def estimate_cost_by_model(tokens_by_model):
    """Sum estimate_cost over a {model: tokens} map, so each model is priced at its own rate.

    Returns None if any model with non-zero tokens is unknown: a partial sum would
    read as the whole cost.
    """
    total = 0.0
    for model, tokens in tokens_by_model.items():
        if not any(tokens.get(k) for k in ("input", "output", "cache_read", "cache_creation")):
            continue
        cost = estimate_cost(model, tokens)
        if cost is None:
            return None
        total += cost
    return round(total, 4)
