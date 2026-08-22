#!/usr/bin/env python3
"""Fetch merged PRs from philippe-ths/ai-running-coach into a local cache.

READ ONLY (gh pr list only). The single 1000-row bulk query returns HTTP 502
(response too large), so the corpus is paged in half-month merged-date windows,
each cached separately under cache/ so a re-run refetches nothing it has.
Windows are then merged and de-duplicated by PR number into rc_prs.json.
"""
import json, os, subprocess, sys, datetime

REPO = "philippe-ths/ai-running-coach"
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "rc_prs.json")
WDIR = os.path.join(HERE, "cache")
FIELDS = "number,title,mergedAt,body,files,comments,reviews,author,additions,deletions"

def windows(start="2026-01-01", end="2026-09-30"):
    s = datetime.date.fromisoformat(start); e = datetime.date.fromisoformat(end)
    out = []; cur = s
    while cur <= e:
        nxt = cur + datetime.timedelta(days=7)
        out.append((cur.isoformat(), min(nxt - datetime.timedelta(days=1), e).isoformat()))
        cur = nxt
    return out

def fetch_window(a, b):
    fn = os.path.join(WDIR, "%s_%s.json" % (a, b))
    if os.path.exists(fn):
        return json.load(open(fn))
    cmd = ["gh", "pr", "list", "--repo", REPO, "--state", "merged", "--limit", "500",
           "--search", "merged:%s..%s" % (a, b), "--json", FIELDS]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        print("  WINDOW FAIL %s..%s : %s" % (a, b, out.stderr.strip()[:300]), file=sys.stderr)
        return None
    d = json.loads(out.stdout)
    json.dump(d, open(fn, "w"))
    return d

def main():
    os.makedirs(WDIR, exist_ok=True)
    by_num = {}
    failures = []
    for a, b in windows():
        d = fetch_window(a, b)
        if d is None:
            failures.append((a, b)); continue
        print("  %s..%s -> %d" % (a, b, len(d)), file=sys.stderr)
        for p in d:
            by_num[p["number"]] = p
    data = sorted(by_num.values(), key=lambda p: p["number"])
    json.dump(data, open(CACHE, "w"), indent=1)
    print(json.dumps({
        "count": len(data),
        "failed_windows": failures,
        "with_files": sum(1 for p in data if p.get("files")),
        "with_comments": sum(1 for p in data if p.get("comments")),
        "min_merged": min(p["mergedAt"] for p in data if p.get("mergedAt")),
        "max_merged": max(p["mergedAt"] for p in data if p.get("mergedAt")),
    }, indent=1))

if __name__ == "__main__":
    main()
