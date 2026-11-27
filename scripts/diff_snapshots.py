#!/usr/bin/env python3
"""Compare two bottle snapshots made by this project (files.sha256 + user.reg/system.reg).
usage: diff_snapshots.py <before_dir> <after_dir>"""
import re, sys, collections

def files(p):
    out = {}
    for line in open(f"{p}/files.sha256", encoding="utf-8", errors="replace"):
        h, name = line.rstrip("\n").split("  ", 1)
        out[name] = h
    return out

def reg(p, name):
    keys, cur = {}, None
    for line in open(f"{p}/{name}", encoding="utf-8", errors="replace"):
        if line.startswith("["):
            cur = re.sub(r"\] \d+$", "]", line.strip()); keys[cur] = []
        elif cur and line.strip() and not line.startswith("#"):
            keys[cur].append(line.rstrip("\n"))
    return keys

a, b = sys.argv[1], sys.argv[2]
fa, fb = files(a), files(b)
groups = collections.Counter()
print("## Files outside drive_c/windows")
for n in sorted(set(fa) | set(fb)):
    st = "ADDED" if n not in fa else "REMOVED" if n not in fb else "CHANGED" if fa[n] != fb[n] else None
    if not st or n.endswith(".reg") and n.count("/") == 1: continue
    if "/drive_c/windows/" in n:
        groups[(st, "/".join(n.split("/")[:5]))] += 1; continue
    print(f"{st:8} {n}")
print("\n## drive_c/windows changes (counts)")
for (st, g), c in sorted(groups.items()): print(f"{st:8} {c:5}  {g}")
NOISE = re.compile(r"DeviceClasses|\\\\Enum\\\\|Control\\\\Class|Control\\\\Video|Wine\\\\Fonts|Perflib|DeviceMap|Hardware", re.I)
for name in ("user.reg", "system.reg"):
    ra, rb = reg(a, name), reg(b, name)
    print(f"\n## {name}: keys added")
    for k in sorted(set(rb) - set(ra)):
        if not NOISE.search(k): print(k); [print("    " + v) for v in rb[k][:8]]
    print(f"\n## {name}: keys with changed values")
    for k in sorted(set(ra) & set(rb)):
        if ra[k] != rb[k] and not NOISE.search(k):
            print(k); [print("  - " + v) for v in ra[k] if v not in rb[k]][:6]; [print("  + " + v) for v in rb[k] if v not in ra[k]][:6]
