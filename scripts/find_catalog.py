#!/usr/bin/env python3
"""Compute PE Authenticode SHA1/SHA256 of DLLs and find .cat files containing them.
usage: find_catalog.py <cat_dir> <dll>..."""
import hashlib, struct, sys, pathlib

def authenticode(path, algo):
    d = pathlib.Path(path).read_bytes()
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", d, opt)[0]
    cksum = opt + 64
    dd = opt + (96 if magic == 0x10B else 112)
    sec = dd + 4 * 8
    cert_off, cert_len = struct.unpack_from("<II", d, sec)
    end = cert_off if cert_off else len(d)
    h = hashlib.new(algo)
    h.update(d[:cksum]); h.update(d[cksum + 4:sec]); h.update(d[sec + 8:end])
    return h.digest(), cert_off != 0

cats = list(pathlib.Path(sys.argv[1]).glob("*.cat"))
blobs = {c: c.read_bytes() for c in cats}
for dll in sys.argv[2:]:
    for algo in ("sha1", "sha256"):
        dg, signed = authenticode(dll, algo)
        hits = [c.name for c, b in blobs.items() if dg in b]
        print(f"{pathlib.Path(dll).name}\t{algo}\t{dg.hex()}\tembedded_sig={signed}\t{hits}")
