"""Estimated session cost from token counts.

Claude Code transcripts store no cost figure (cost is null on disk), so cost here
is ESTIMATED: token counts times the public list price for the model tier. It is a
convenience signal, not an authoritative bill. Token counts themselves are exact.

Maintenance: update RATES when prices change or a new model tier ships. An unknown
model yields a null estimate rather than a wrong one.
"""

# USD per 1,000,000 tokens, by model tier. cache_write is the 5-minute ephemeral rate.
RATES = {
    "opus":   {"input": 15.0, "output": 75.0, "cache_read": 1.50, "cache_write": 18.75},
    "sonnet": {"input": 3.0,  "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "haiku":  {"input": 0.80, "output": 4.0,  "cache_read": 0.08, "cache_write": 1.0},
}


def _tier(model):
    if not isinstance(model, str):
        return None
    m = model.lower()
    if "opus" in m:
        return "opus"
    if "sonnet" in m:
        return "sonnet"
    if "haiku" in m:
        return "haiku"
    return None


def estimate_cost(model, tokens):
    """Return estimated USD (float, rounded) for a token dict, or None if the model is unknown."""
    tier = _tier(model)
    if tier is None:
        return None
    rate = RATES[tier]
    cost = (
        (tokens.get("input", 0) or 0) * rate["input"]
        + (tokens.get("output", 0) or 0) * rate["output"]
        + (tokens.get("cache_read", 0) or 0) * rate["cache_read"]
        + (tokens.get("cache_creation", 0) or 0) * rate["cache_write"]
    ) / 1_000_000.0
    return round(cost, 4)
