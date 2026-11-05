#!/usr/bin/env python3
"""Write a bare CFF of a Minion Math OTF with the vendor glyph names added.

Minion Math 1.026 names most glyphs ``glyphNNN``; the typoma TeX encodings
(minionmath-*.enc) address them as ``parenleft.vsize3``, ``uni2308`` etc.
For every ``name -> code point`` line of glyphmap.tsv (made by
resolve_glyphs.py) whose code point the font maps, the glyph's charstring is
duplicated under ``name``.  The original glyphs stay untouched, so names that
already exist and glyphs used under several names both keep working.

The output is a bare CFF font (what cfftot1 needs to make the PFB).
Usage: add_glyph_names.py glyphmap.tsv in.otf out.cff
"""

import sys

from fontTools.cffLib import CharStrings
from fontTools.misc.psCharStrings import T2CharString
from fontTools.ttLib import TTFont


def main(mapfile, src, dst):
    mapping = []
    for line in open(mapfile):
        if line.strip() and not line.startswith("#"):
            name, code = line.split("\t")[:2]
            mapping.append((name, int(code, 16)))

    font = TTFont(src)
    cff = font["CFF "].cff
    cff.desubroutinize()  # charstrings become self-contained programs
    top = cff.topDictIndex[0]
    old = top.CharStrings
    cmap = font.getBestCmap()
    order = list(font.getGlyphOrder())

    # Rebuild CharStrings as a plain dict-backed table we can extend.
    new = CharStrings(None, None, old.globalSubrs, top.Private, None, None)
    for gname in order:
        new[gname] = old[gname]
    added = 0
    for name, code in mapping:
        if name in new.charStrings or code not in cmap:
            continue
        srcs = old[cmap[code]]
        srcs.decompile()
        new[name] = T2CharString(program=list(srcs.program), private=srcs.private, globalSubrs=srcs.globalSubrs)
        order.append(name)
        added += 1
    top.CharStrings = new
    top.charset = order
    font.setGlyphOrder(order)

    with open(dst, "wb") as out:
        cff.compile(out, font)
    print(f"{src}: added {added} glyph names", file=sys.stderr)


if __name__ == "__main__":
    main(*sys.argv[1:4])
