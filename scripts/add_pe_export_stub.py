#!/usr/bin/env python3
"""Add stub exports to a 32-bit PE DLL (used on Wine's i386 ntdll.dll / user32.dll).

usage: add_pe_export_stub.py <in.dll> <out.dll> Name:ARGBYTES[:RETVAL] [Name:ARGBYTES[:RETVAL] ...]

Each stub is `mov eax, RETVAL; ret ARGBYTES` (stdcall; RETVAL defaults to 0, accepts 0x..).
A new section holds the stubs and a rebuilt export directory (old exports + new names,
name table kept sorted). Forwarded exports are kept by copying their target strings into
the new export directory. Always start from the original runner DLL, not an already
patched one. Source-level equivalents live in patches/.
"""
import struct
import sys


def align(v, a):
    return (v + a - 1) // a * a


def parse_spec(spec):
    parts = spec.split(":")
    name = parts[0].encode()
    argbytes = int(parts[1], 0)
    ret = int(parts[2], 0) if len(parts) > 2 else 0
    if argbytes % 4 or not 0 <= argbytes < 0x10000:
        sys.exit(f"bad arg byte count in {spec}")
    return name, argbytes, ret & 0xFFFFFFFF


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    specs = [parse_spec(s) for s in sys.argv[3:]]
    d = bytearray(open(src, "rb").read())
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    optsz = struct.unpack_from("<H", d, pe + 20)[0]
    opt = pe + 24
    if struct.unpack_from("<H", d, opt)[0] != 0x10B:
        sys.exit("only PE32 supported")
    sect_align, file_align = struct.unpack_from("<II", d, opt + 32)
    size_of_headers = struct.unpack_from("<I", d, opt + 60)[0]
    dd = opt + 96
    sh = opt + optsz
    secs = [struct.unpack_from("<8sIIIIIIHHI", d, sh + i * 40) for i in range(nsec)]
    if any(s[0].rstrip(b"\0") == b".sbstub" for s in secs):
        sys.exit("input already patched; use the original DLL")

    def off(rva):
        for s in secs:
            va, vs, ra, rs = s[2], s[1], s[4], s[3]
            if va <= rva < va + max(vs, rs):
                return rva - va + ra
        raise ValueError(hex(rva))

    def cstr(o):
        return bytes(d[o:d.index(b"\0", o)])

    if sh + (nsec + 1) * 40 > size_of_headers:
        sys.exit("no room for another section header")

    erva, esz = struct.unpack_from("<II", d, dd)
    e = off(erva)
    (chars, ts, major, minor, name_rva, base, nfun, nnames, af, an, ao) = struct.unpack_from("<IIHHIIIIIII", d, e)
    funcs = [struct.unpack_from("<I", d, off(af) + 4 * i)[0] for i in range(nfun)]
    # forwarded exports point at strings inside the export directory: copy them into the new one
    forwards = {i: cstr(off(f)) for i, f in enumerate(funcs) if erva <= f < erva + esz}
    names = []
    for i in range(nnames):
        nrva = struct.unpack_from("<I", d, off(an) + 4 * i)[0]
        ordi = struct.unpack_from("<H", d, off(ao) + 2 * i)[0]
        names.append((cstr(off(nrva)), nrva, ordi))
    existing = {n for n, _, _ in names}
    for name, _, _ in specs:
        if name in existing:
            sys.exit(f"{name.decode()} already exported")

    # layout of the new section: [stubs][export dir][funcs][names][ordinals][strings][forwarders]
    new_va = align(max(s[2] + max(s[1], s[3]) for s in secs), sect_align)
    code = bytearray()
    stub_rvas = []
    for name, argbytes, ret in specs:
        stub_rvas.append(new_va + len(code))
        code += b"\xB8" + struct.pack("<I", ret) + b"\xC2" + struct.pack("<H", argbytes)  # mov eax,ret; ret n
        code += b"\xCC" * (-len(code) % 16)
    n_new = len(specs)
    dir_rva = new_va + align(len(code), 16)
    funcs_rva = dir_rva + 40
    names_rva = funcs_rva + 4 * (nfun + n_new)
    ords_rva = names_rva + 4 * (nnames + n_new)
    str_rva = ords_rva + 2 * (nnames + n_new)
    strings = bytearray()
    for k, (name, _, _) in enumerate(specs):
        names.append((name, str_rva + len(strings), nfun + k))
        strings += name + b"\0"
        funcs.append(stub_rvas[k])
    fwd_rva = str_rva + len(strings)
    fwd_blob = bytearray()
    for i, target in forwards.items():
        funcs[i] = fwd_rva + len(fwd_blob)
        fwd_blob += target + b"\0"
    end_rva = fwd_rva + len(fwd_blob)
    names.sort(key=lambda t: t[0])

    body = bytearray(end_rva - new_va)
    body[0:len(code)] = code
    struct.pack_into("<IIHHIIIIIII", body, dir_rva - new_va, chars, ts, major, minor, name_rva, base,
                     nfun + n_new, nnames + n_new, funcs_rva, names_rva, ords_rva)
    for i, f in enumerate(funcs):
        struct.pack_into("<I", body, funcs_rva - new_va + 4 * i, f)
    for i, (_, nrva, ordi) in enumerate(names):
        struct.pack_into("<I", body, names_rva - new_va + 4 * i, nrva)
        struct.pack_into("<H", body, ords_rva - new_va + 2 * i, ordi)
    body[str_rva - new_va:fwd_rva - new_va] = strings
    body[fwd_rva - new_va:end_rva - new_va] = fwd_blob

    raw_ptr = align(len(d), file_align)
    raw_size = align(len(body), file_align)
    d += b"\0" * (raw_ptr - len(d))
    d += body + b"\0" * (raw_size - len(body))

    struct.pack_into("<8sIIIIIIHHI", d, sh + nsec * 40, b".sbstub", len(body), new_va, raw_size, raw_ptr,
                     0, 0, 0, 0, 0x60000020)  # code | execute | read
    struct.pack_into("<H", d, pe + 6, nsec + 1)
    struct.pack_into("<I", d, opt + 56, align(new_va + len(body), sect_align))  # SizeOfImage
    struct.pack_into("<II", d, dd, dir_rva, end_rva - dir_rva)  # export directory
    struct.pack_into("<I", d, opt + 64, 0)  # CheckSum (not verified by Wine)
    open(dst, "wb").write(d)
    for (name, argbytes, ret), rva in zip(specs, stub_rvas):
        print(f"added {name.decode()} (ret {ret:#x}, pops {argbytes}) at RVA {rva:#x}")
    print(f"exports {nfun} -> {nfun + n_new}")


if __name__ == "__main__":
    main()
