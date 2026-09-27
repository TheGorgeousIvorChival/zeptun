#!/usr/bin/env python3
import json
import os
import statistics
import sys


def num(value):
    try:
        return float(str(value).split()[0])
    except ValueError:
        return 0.0


def load(path):
    rows = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def capability(rows):
    engines = {}
    for r in rows:
        e = r["engine"]
        info = engines.setdefault(
            e,
            {
                "multiqueue": bool(r.get("multiqueue", False)),
                "requested": r.get("queues_requested"),
                "actual": r.get("queues_actual"),
                "procs": r.get("procs", 1),
            },
        )
        if r.get("queues_actual") is not None:
            info["actual"] = r["queues_actual"]
    lines = [
        "| engine | multiqueue | queues requested | queues actual | processes |",
        "|---|---|---:|---:|---:|",
    ]
    for e, i in sorted(engines.items()):
        lines.append(f"| {e} | {'yes' if i['multiqueue'] else 'no'} | {i['requested']} | {i['actual']} | {i['procs']} |")
    return "\n".join(lines) + "\n", engines


def main():
    results_path = sys.argv[1]
    summary_path = sys.argv[2]
    capability_path = sys.argv[3]
    rows = load(results_path)
    if not rows:
        open(summary_path, "w").write("no results\n")
        open(capability_path, "w").write("no results\n")
        return 0

    cap, engines = capability(rows)
    open(capability_path, "w").write(cap)

    groups = {}
    for r in rows:
        key = (r.get("queues_actual", 1), r["engine"], r["scenario"])
        groups.setdefault(key, []).append(r)

    tiers = sorted({k[0] for k in groups})
    out = []
    out.append("# Benchmark results\n")
    out.append("Engines are grouped by the number of TUN queues they actually received, so a")
    out.append("single-queue engine is never compared against a multi-queue engine inside one table.\n")
    for e, i in sorted(engines.items()):
        if i["requested"] is not None and i["actual"] is not None and i["actual"] != i["requested"]:
            out.append(f"> {e} was asked for {i['requested']} queues but got {i['actual']}.\n")
    reps = {len(v) for v in groups.values()}
    if reps and max(reps) < 3:
        out.append(f"> Only {max(reps)} round(s) per cell; treat differences under ~10% as noise.\n")

    for tier in tiers:
        out.append(f"\n## TUN queues: {tier}\n")
        out.append("| engine | scenario | median | rounds | spread | cpu % | max rss MB | rss after idle MB |")
        out.append("|---|---|---:|---:|---:|---:|---:|---:|")
        cells = {k: v for k, v in groups.items() if k[0] == tier}
        for (_, engine, scenario), rs in sorted(cells.items()):
            vals = sorted(num(r["value"]) for r in rs)
            mid = statistics.median(vals)
            spread = (vals[-1] - vals[0]) / mid * 100.0 if mid else 0.0
            shown = sorted(rs, key=lambda r: num(r["value"]))[len(rs) // 2]
            cpu = statistics.median(r["cpu_pct"] for r in rs)
            rss = max(r["rss_kb"] for r in rs) / 1024
            after = max(r.get("rss_after_kb", 0) for r in rs) / 1024
            out.append(
                f"| {engine} | {scenario} | {shown['value']} | {len(rs)} | {spread:.1f}% | {cpu:.0f} | {rss:.1f} | {after:.1f} |"
            )

    out.append("\n## Throughput by engine (best tier each engine reached)\n")
    out.append("| engine | queues | scenario | median |")
    out.append("|---|---:|---|---:|")
    best = {}
    for (tier, engine, scenario), rs in groups.items():
        shown = sorted(rs, key=lambda r: num(r["value"]))[len(rs) // 2]
        key = (engine, scenario)
        if key not in best or tier > best[key][0]:
            best[key] = (tier, shown)
    for (engine, scenario), (tier, shown) in sorted(best.items()):
        out.append(f"| {engine} | {tier} | {scenario} | {shown['value']} |")

    open(summary_path, "w").write("\n".join(out) + "\n")
    print("\n".join(out))
    print(cap)
    return 0


if __name__ == "__main__":
    sys.exit(main())
