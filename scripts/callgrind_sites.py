import re, sys
from collections import defaultdict
path = sys.argv[1]
want = sys.argv[2] if len(sys.argv) > 2 else "memset"
fn_re  = re.compile(r"^(c?fn)=\((\d+)\)(?:\s+(.*))?$")
fl_re  = re.compile(r"^(fl|fi|fe|cfi|cfl)=\((\d+)\)(?:\s+(.*))?$")
calls_re = re.compile(r"^calls=(\d+)\s+(\d+)")
names, files = {}, {}
cur_fn = None; cur_file = None; pending_fn = None
sites = defaultdict(lambda: defaultdict(int))
with open(path, errors="replace") as h:
    for line in h:
        line = line.rstrip("\n")
        m = fn_re.match(line)
        if m:
            i, nm = m.group(2), m.group(3)
            if nm: names[i] = nm
            if line.startswith("cfn="): pending_fn = i
            else: cur_fn = i
            continue
        m = fl_re.match(line)
        if m:
            kind, i, nm = m.group(1), m.group(2), m.group(3)
            if nm: files[i] = nm
            if kind == "fi": cur_file = i
            elif kind == "fl": cur_file = i
            continue
        if pending_fn is not None:
            c = calls_re.match(line)
            if c:
                callee = names.get(pending_fn, pending_fn)
                if want in callee:
                    key = (files.get(cur_file, "?"), c.group(2), names.get(cur_fn, "?"))
                    sites[callee.split(" [")[0]][key] += int(c.group(1))
                pending_fn = None
                continue
tot = 0
for callee, d in sites.items():
    print(f"== {callee} call sites ==")
    s = sum(d.values())
    tot += s
    for (f, ln, caller), n in sorted(d.items(), key=lambda x: -x[1])[:12]:
        cf = f.split('/')[-1]
        cn = caller.split(' [')[0].replace('engine.Worker(io.linux_loop.Loop).','W.').replace('stack.tcp.Tcp(engine.Worker(io.linux_loop.Loop)).','tcp.')
        print(f"  {n:>9,}  {cf}:{ln}  <- {cn}")
    print(f"  {s:>9,}  TOTAL\n")
print(f"grand total {want} calls attributed: {tot:,}")
