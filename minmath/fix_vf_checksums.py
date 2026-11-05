#!/usr/bin/env python3
"""Make the checksums recorded in virtual fonts agree with their base TFMs.

In the typoma MinionMath TeX bundle, many VFs (e.g. MinionMath-Regular-MXP.vf)
record, in the fnt_def of their local font (MinionMath-Regular-MXP--base),
a checksum that differs from the one in the shipped --base.tfm. TeX then
reports

    checksum mismatch in local font X--base in virtual font X.vf ignored.

and goes on with the shipped TFM. Neither side is uniformly "right": the
bundle's fonts/pl sources match the VFs for some fonts but not for others
(e.g. every *-MXP--base). This script therefore keeps what TeX already uses,
the shipped TFM, and rewrites each mismatching fnt_def checksum to the TFM's
checksum. Only the 4 checksum bytes change, so typesetting is unaffected and
the warning disappears.

Usage: fix_vf_checksums.py VFDIR TFMDIR [TFMDIR ...]
Exits non-zero if a mismatch remains after patching.
"""

import glob
import os
import struct
import sys

PRE, FNT_DEF1, FNT_DEF4 = 247, 243, 246


def tfm_checksum(path):
    with open(path, "rb") as f:
        data = f.read(28)
    return struct.unpack(">I", data[24:28])[0]  # header word 0


def fnt_defs(data):
    """Yield (offset of the checksum, checksum, font name) for each fnt_def."""
    if data[0] != PRE:
        raise ValueError("not a VF file")
    i = 3 + data[2] + 8  # pre i k comment[k] cs[4] ds[4]
    while FNT_DEF1 <= data[i] <= FNT_DEF4:
        i += 1 + (data[i] - FNT_DEF1 + 1)  # opcode + k[1..4]
        pos = i
        checksum = struct.unpack(">I", data[i : i + 4])[0]
        i += 12  # c[4] s[4] d[4]
        a, l = data[i], data[i + 1]
        i += 2
        name = data[i : i + a + l].decode("ascii")
        i += a + l
        yield pos, checksum, name


def find_tfm(name, tfmdirs):
    for d in tfmdirs:
        p = os.path.join(d, name + ".tfm")
        if os.path.exists(p):
            return p
    return None


def mismatches(data, tfmdirs):
    for pos, checksum, name in fnt_defs(data):
        tfm = find_tfm(name, tfmdirs)
        if tfm is None:
            continue
        actual = tfm_checksum(tfm)
        # TeX compares only when both checksums are non-zero.
        if checksum and actual and checksum != actual:
            yield pos, name, actual


def main(vfdir, *tfmdirs):
    patched = remaining = 0
    for vf in sorted(glob.glob(os.path.join(vfdir, "*.vf"))):
        with open(vf, "rb") as f:
            data = bytearray(f.read())
        fixes = list(mismatches(data, tfmdirs))
        if not fixes:
            continue
        for pos, _name, actual in fixes:
            data[pos : pos + 4] = struct.pack(">I", actual)
        with open(vf, "wb") as f:
            f.write(data)
        patched += len(fixes)
        remaining += sum(1 for _ in mismatches(data, tfmdirs))
    print(f"fix_vf_checksums: patched {patched} fnt_def checksums, {remaining} remaining")
    return 1 if remaining else 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], *sys.argv[2:]))
