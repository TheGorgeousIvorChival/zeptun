#!/usr/bin/env python3
import re
import sys
from collections import defaultdict


def parse(path):
    self_ir = defaultdict(int)
    calls = defaultdict(int)
    cur_fn = None
    pending_cfn = None
    names = {}
    fn_re = re.compile(r"^(?:c?fn)=\((\d+)\)(?:\s+(.*))?$")
    calls_re = re.compile(r"^calls=(\d+)")
    with open(path, "r", errors="replace") as h:
        for line in h:
            line = line.rstrip("\n")
            m = fn_re.match(line)
            if m:
                ident, nm = m.group(1), m.group(2)
                if nm:
                    names[ident] = nm
                if line.startswith("cfn="):
                    pending_cfn = ident
                else:
                    cur_fn = ident
                    pending_cfn = None
                continue
            if pending_cfn is not None:
                c = calls_re.match(line)
                if c:
                    calls[pending_cfn] += int(c.group(1))
                    pending_cfn = None
                    continue
            if line and (line[0].isdigit() or line[0] in "+-*") and cur_fn is not None:
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        self_ir[cur_fn] += int(parts[1])
                    except ValueError:
                        pass
    return names, self_ir, calls


def main():
    path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    names, self_ir, calls = parse(path)
    total = sum(self_ir.values()) or 1
    rows = []
    for ident, ir in self_ir.items():
        nm = names.get(ident, ident)
        nm = nm.split(" [")[0]
        c = calls.get(ident, 0)
        rows.append((ir, c, ir / c if c else 0.0, nm))
    rows.sort(reverse=True)

    out = []
    out.append(f"total self Ir: {total:,}")
    out.append("")
    out.append("== by total self cost ==")
    out.append(f"{'self Ir':>14}{'share':>8}{'calls':>14}{'Ir/call':>10}  function")
    out.append("-" * 104)
    for ir, c, per, nm in rows[:limit]:
        out.append(f"{ir:>14,}{100*ir/total:>7.2f}%{c:>14,}{per:>10.1f}  {nm[:66]}")

    out.append("")
    out.append("== by cost per call, among functions called at least 1000 times ==")
    out.append(f"{'self Ir':>14}{'calls':>14}{'Ir/call':>10}  function")
    out.append("-" * 104)
    hot = [r for r in rows if r[1] >= 1000]
    hot.sort(key=lambda r: -r[2])
    for ir, c, per, nm in hot[:limit]:
        out.append(f"{ir:>14,}{c:>14,}{per:>10.1f}  {nm[:66]}")

    text = "\n".join(out) + "\n"
    if len(sys.argv) > 3:
        open(sys.argv[3], "w").write(text)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
