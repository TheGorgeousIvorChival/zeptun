#!/usr/bin/env python3
import json
import statistics
import sys


def load(paths):
    out = {}
    for p in paths:
        try:
            with open(p) as h:
                d = json.load(h)
        except Exception:
            continue
        for r in d.get("results", []):
            out.setdefault(r["name"], []).append(r["ns_per_op"])
    return out


def main():
    base = load(sys.argv[1].split(","))
    cand = load(sys.argv[2].split(","))
    rows = []
    for name in base:
        if name not in cand:
            continue
        b = min(base[name])
        c = min(cand[name])
        rows.append((name, b, c, (c - b) / b * 100.0))
    rows.sort(key=lambda r: r[3])
    out = ["| benchmark | base ns | candidate ns | delta |", "|---|---:|---:|---:|"]
    for name, b, c, d in rows:
        out.append(f"| {name} | {b:.2f} | {c:.2f} | {d:+.1f}% |")
    worse = [r for r in rows if r[3] > 5.0]
    better = [r for r in rows if r[3] < -5.0]
    out.append("")
    out.append(f"better by more than 5%: {len(better)}   worse by more than 5%: {len(worse)}")
    if worse:
        out.append("")
        out.append("regressions:")
        for name, b, c, d in worse:
            out.append(f"- {name}: {b:.2f} -> {c:.2f} ns ({d:+.1f}%)")
    text = "\n".join(out) + "\n"
    open(sys.argv[3], "w").write(text)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
