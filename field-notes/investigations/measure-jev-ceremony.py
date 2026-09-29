#!/usr/bin/env python3
"""Rebuild the corpus and figures for the 2026-09-29 Jev ceremony measurement (#307).

  measure-jev-ceremony.py fetch  WORKDIR   merged PRs that close an issue -> WORKDIR/cases.json
  measure-jev-ceremony.py blind  WORKDIR   hindsight view for labellers  -> WORKDIR/blind.md
  measure-jev-ceremony.py jev    WORKDIR   Jev's tier from the issue alone -> WORKDIR/jev.json
  measure-jev-ceremony.py report WORKDIR   compare with WORKDIR/labels_*.json
  measure-jev-ceremony.py report 2026-09-29-jev-ceremony-data.json   same figures from the saved record

READ ONLY against GitHub. Jev sees only the issue title and body (what is known at task
start); labellers see the issue plus what the merged change touched (hindsight).
Archival: pinned to this investigation and not covered by validation.
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "scripts", "jev"))
TIERS = ["light", "standard", "full"]


def gh(*args):
    return json.loads(subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout)


def fetch(work):
    prs = gh("pr", "list", "--state", "merged", "--limit", "500",
             "--json", "number,title,closingIssuesReferences,files,additions,deletions")
    cases = []
    for pr in prs:
        refs = pr["closingIssuesReferences"]
        if not refs:
            continue
        # One case per PR, anchored on the first issue it closes.
        issue = gh("issue", "view", str(refs[0]["number"]), "--json", "number,title,body")
        cases.append({
            "pr": pr["number"], "pr_title": pr["title"],
            "issue": issue["number"], "issue_title": issue["title"], "issue_body": issue["body"],
            "files": [(f["path"], f["additions"], f["deletions"]) for f in pr["files"]],
            "additions": pr["additions"], "deletions": pr["deletions"],
        })
    cases.sort(key=lambda c: c["pr"])
    json.dump(cases, open(os.path.join(work, "cases.json"), "w"), indent=1)
    print(f"{len(cases)} cases")


def blind(work):
    cases = json.load(open(os.path.join(work, "cases.json")))
    out = []
    for c in cases:
        files = "\n".join(f"  {p} (+{a} -{d})" for p, a, d in c["files"])
        out.append(f"## Case {c['pr']}\n\n### Issue: {c['issue_title']}\n\n{c['issue_body'].strip()}\n\n"
                   f"### What the merged change touched (+{c['additions']} -{c['deletions']})\n\n{files}\n")
    open(os.path.join(work, "blind.md"), "w").write("\n".join(out))
    print(f"{len(cases)} cases written")


def jev(work):
    import ask
    cases = json.load(open(os.path.join(work, "cases.json")))
    results = {}
    for c in cases:
        state = json.dumps({"title": c["issue_title"], "body": c["issue_body"]})
        code, r = ask.ask("ceremony", state)
        results[str(c["pr"])] = r if code == 0 else {"unavailable": r}
    json.dump(results, open(os.path.join(work, "jev.json"), "w"), indent=1)
    print(f"{sum(1 for r in results.values() if 'answer' in r)} of {len(results)} answered")


def report(work):
    if work.endswith(".json"):
        # The saved per-case record (2026-09-29-jev-ceremony-data.json) carries everything the report needs.
        saved = json.load(open(work))
        jev_r = {str(c["pr"]): c["jev"] for c in saved}
        labels = [{str(c["pr"]): c["labels"][i] for c in saved} for i in range(len(saved[0]["labels"]))]
        label_files = labels
    else:
        jev_r = json.load(open(os.path.join(work, "jev.json")))
        label_files = sorted(f for f in os.listdir(work) if f.startswith("labels_") and f.endswith(".json"))
        labels = [json.load(open(os.path.join(work, f))) for f in label_files]
    rows = []
    for pr, r in jev_r.items():
        votes = [l.get(pr) for l in labels]
        if "answer" not in r or None in votes:
            continue
        top = max(TIERS, key=votes.count)
        majority = top if votes.count(top) >= 2 else None
        rows.append({"pr": pr, "jev": r["answer"], "conf": r["confidence"], "votes": votes, "majority": majority})

    agreed = [r for r in rows if r["majority"]]
    unanimous = [r for r in rows if len(set(r["votes"])) == 1]
    print(f"labellers: {len(label_files)}; cases compared: {len(rows)}; "
          f"majority exists: {len(agreed)}; unanimous: {len(unanimous)}")
    print("\nlabel distribution (majority):", {t: sum(r["majority"] == t for r in agreed) for t in TIERS})
    print("jev distribution (same cases):", {t: sum(r["jev"] == t for r in agreed) for t in TIERS})

    print("\nconfusion (rows = majority label, cols = jev):")
    print("          " + "".join(f"{t:>10}" for t in TIERS))
    for lt in TIERS:
        print(f"{lt:>10}" + "".join(f"{sum(r['majority'] == lt and r['jev'] == jt for r in agreed):>10}" for jt in TIERS))

    hits = sum(r["jev"] == r["majority"] for r in agreed)
    print(f"\nexact agreement with majority: {hits}/{len(agreed)}")
    # The error that costs: Jev says lighter than the work turned out to be.
    under = [r for r in agreed if TIERS.index(r["jev"]) < TIERS.index(r["majority"])]
    over = [r for r in agreed if TIERS.index(r["jev"]) > TIERS.index(r["majority"])]
    print(f"jev lighter than label: {len(under)}; heavier: {len(over)}")

    print("\nby confidence threshold (acting only at or above it):")
    for t in (0.0, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95):
        band = [r for r in agreed if r["conf"] >= t]
        if not band:
            continue
        ok = sum(r["jev"] == r["majority"] for r in band)
        u = sum(TIERS.index(r["jev"]) < TIERS.index(r["majority"]) for r in band)
        light_calls = [r for r in band if r["jev"] == "light"]
        light_ok = sum(r["majority"] == "light" for r in light_calls)
        print(f"  >= {t:.2f}: covers {len(band)}/{len(agreed)}, exact {ok}/{len(band)}, under-called {u}, "
              f"light calls correct {light_ok}/{len(light_calls)}")

    print("\nunder-calls (jev lighter than majority):")
    for r in under:
        print(f"  PR {r['pr']}: jev {r['jev']} ({r['conf']:.2f}), labels {r['votes']}")


if __name__ == "__main__":
    cmd, work = sys.argv[1], sys.argv[2]
    if not work.endswith(".json"):
        os.makedirs(work, exist_ok=True)
    {"fetch": fetch, "blind": blind, "jev": jev, "report": report}[cmd](work)
