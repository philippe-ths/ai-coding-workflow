#!/usr/bin/env python3
"""Compare two workflow versions' baseline results.

Usage:
    compare-versions.py <version_a> <version_b>

Reports:
- Per-task pass^k per version (k = number of runs for that task+version).
- Aggregate pass^k per version.
- McNemar p-value on paired pass/fail outcomes across matched (task, repeat_index) pairs.
- Continuous-metric deltas (duration, cost, tokens, fix_cycles): mean and median.

Runs are paired within each task by sorted started_at order — the i-th run of
version A pairs with the i-th run of version B. Tasks with unequal run counts
fall back to the shorter count; tasks missing from one version are reported
but excluded from McNemar.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean, median

REPO_ROOT = Path(__file__).resolve().parent.parent
BASELINE_ROOT = REPO_ROOT / "telemetry" / "data" / "baseline"


def load_runs(version: str) -> dict[str, list[dict]]:
    """Return {task_id: [record, ...]} sorted by started_at."""
    version_root = BASELINE_ROOT / version
    if not version_root.exists():
        return {}
    by_task: dict[str, list[dict]] = defaultdict(list)
    for json_file in version_root.rglob("*.json"):
        try:
            rec = json.loads(json_file.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        by_task[rec["task_id"]].append(rec)
    for runs in by_task.values():
        runs.sort(key=lambda r: r.get("started_at", ""))
    return dict(by_task)


def pass_k(runs: list[dict]) -> tuple[int, int, float]:
    """Return (passes, k, passes/k raised to k). Empty returns (0, 0, 0.0)."""
    k = len(runs)
    passes = sum(1 for r in runs if r.get("tests", {}).get("post_change_passed"))
    if k == 0:
        return 0, 0, 0.0
    return passes, k, (passes / k) ** k


def mcnemar(a: list[bool], b: list[bool]) -> tuple[int, int, float]:
    """Return (b01, b10, two-sided p-value) using scipy if available,
    otherwise an exact binomial fallback.
    """
    assert len(a) == len(b)
    b01 = sum(1 for x, y in zip(a, b) if not x and y)
    b10 = sum(1 for x, y in zip(a, b) if x and not y)
    n = b01 + b10
    if n == 0:
        return b01, b10, 1.0
    try:
        from scipy.stats import binomtest

        p = binomtest(min(b01, b10), n=n, p=0.5, alternative="two-sided").pvalue
    except Exception:
        # Exact binomial two-sided, symmetric around n/2.
        from math import comb

        k = min(b01, b10)
        tail = sum(comb(n, i) for i in range(0, k + 1)) / (2 ** n)
        p = min(1.0, 2 * tail)
    return b01, b10, p


def continuous_delta(runs_a: list[dict], runs_b: list[dict], path: tuple[str, ...]) -> dict:
    def extract(recs):
        out = []
        for r in recs:
            v = r
            for k in path:
                if not isinstance(v, dict):
                    v = None
                    break
                v = v.get(k)
            if isinstance(v, (int, float)):
                out.append(v)
        return out

    va, vb = extract(runs_a), extract(runs_b)
    if not va or not vb:
        return {"path": ".".join(path), "a": None, "b": None, "delta_mean": None, "delta_median": None}
    ma, mb = mean(va), mean(vb)
    meda, medb = median(va), median(vb)
    return {
        "path": ".".join(path),
        "a_mean": ma,
        "b_mean": mb,
        "delta_mean": mb - ma,
        "a_median": meda,
        "b_median": medb,
        "delta_median": medb - meda,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("version_a")
    ap.add_argument("version_b")
    args = ap.parse_args()

    a_by_task = load_runs(args.version_a)
    b_by_task = load_runs(args.version_b)

    if not a_by_task and not b_by_task:
        print(f"no results under {BASELINE_ROOT}", file=sys.stderr)
        return 2

    all_tasks = sorted(set(a_by_task) | set(b_by_task))

    print(f"Comparing {args.version_a}  ->  {args.version_b}")
    print("=" * 64)

    print("\nPer-task pass^k")
    print("-" * 64)
    print(f"{'task':<32} {'A (p/k pass^k)':<18} {'B (p/k pass^k)':<18}")
    for t in all_tasks:
        pa, ka, rka = pass_k(a_by_task.get(t, []))
        pb, kb, rkb = pass_k(b_by_task.get(t, []))
        print(f"{t:<32} {pa}/{ka} {rka:.3f}       {pb}/{kb} {rkb:.3f}")

    # Aggregate pass^k.
    all_a = [r for runs in a_by_task.values() for r in runs]
    all_b = [r for runs in b_by_task.values() for r in runs]
    pa, ka, rka = pass_k(all_a)
    pb, kb, rkb = pass_k(all_b)
    print(f"\nAggregate: A={pa}/{ka} pass^k={rka:.3f}   B={pb}/{kb} pass^k={rkb:.3f}")

    # McNemar on paired outcomes.
    paired_a, paired_b = [], []
    for t in all_tasks:
        ra, rb = a_by_task.get(t, []), b_by_task.get(t, [])
        n = min(len(ra), len(rb))
        for i in range(n):
            paired_a.append(bool(ra[i].get("tests", {}).get("post_change_passed")))
            paired_b.append(bool(rb[i].get("tests", {}).get("post_change_passed")))
    if paired_a:
        b01, b10, p = mcnemar(paired_a, paired_b)
        print(
            f"\nMcNemar on {len(paired_a)} paired runs: "
            f"A-only-pass={b10}, B-only-pass={b01}, two-sided p={p:.4f}"
        )
    else:
        print("\nMcNemar: no paired runs.")

    # Continuous deltas.
    print("\nContinuous metric deltas (B - A)")
    print("-" * 64)
    for path in [
        ("duration_seconds",),
        ("cost_usd",),
        ("tokens", "input"),
        ("tokens", "output"),
        ("fix_cycles",),
    ]:
        d = continuous_delta(all_a, all_b, path)
        if d.get("delta_mean") is None:
            print(f"{d['path']:<24} (insufficient data)")
        else:
            print(
                f"{d['path']:<24} mean {d['a_mean']:.3f} -> {d['b_mean']:.3f} "
                f"(Δ {d['delta_mean']:+.3f})   median {d['a_median']:.3f} -> "
                f"{d['b_median']:.3f} (Δ {d['delta_median']:+.3f})"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
