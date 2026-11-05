#!/usr/bin/env python3
"""Recover the vendor glyph names that the Minion Math TeX bundle expects.

The typoma TeX support files (MinionMath-TeXLocal-current.zip, minionmath.sty
v1.024) re-encode the fonts through dvips .enc files that address glyphs by
PostScript name (``parenleft.vsize3``, ``uni2308``, ``zero.taboldstyle`` ...).
The Minion Math OTFs we have (version 1.026) carry generic CFF glyph names
(``glyph501``) and put every variant glyph on a Private Use Area code point
instead.  pdfTeX then finds none of the encoded names and prints .notdef.

This tool maps every glyph name used by the vendor encodings (for the map
entries whose font file is a MinionMath font) to a Unicode / PUA code point of
the 1.026 fonts.  ``minmath/rename_glyphs.py`` then adds glyphs under those
names when building the Type 1 fonts (see ../minmath.nix).

Resolution order, per name:

1. direct   - ``uniXXXX`` / ``uXXXXX`` / AGL name / ligature alias -> cmap.
2. gsub     - suffix with an OpenType feature: .taboldstyle (onum),
              .small (ss01), .dtls (dtls), zero.slash (zero), .alt & co.
              (salt / aalt alternates), filtered by advance widths.
3. shape    - size variants and extensible pieces: candidates are the code
              points whose advance widths equal the vendor TFM widths in all
              20 fonts; they are scored by raster similarity (IoU of
              bbox-normalised bitmaps) against the base glyph (or the matching
              part of it for .top/.bot/.mid/.ext/.left/.right pieces), and
              assigned greedily without reusing a code point.

Output: TSV ``name<TAB>codepoint-hex<TAB>method<TAB>score`` on stdout.
Usage: resolve_glyphs.py <unzipped TeXLocal dir> <dir with MinionMath-*.otf>
"""

import glob
import os
import re
import sys

from fontTools import agl
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.pointInsidePen import PointInsidePen
from fontTools.ttLib import TTFont

GRID = 24
LIGATURES = {"f_f": 0xFB00, "f_i": 0xFB01, "f_l": 0xFB02, "f_f_i": 0xFB03, "f_f_l": 0xFB04}
SIZE_RE = re.compile(r"^(?P<base>.+)\.(?P<kind>[vh])size(?P<n>\d+)$")
PIECE_RE = re.compile(r"^(?P<base>.+)\.(?P<part>top|bot|mid|ext|left|right)$")
ALT_SUFFIXES = ("alt", "mathit", "slashed", "barred", "vs1", "slash")
# Vertical extensible delimiters laid out as top/mid/ext/bot at fixed offsets.
PIECE_LAYOUT_BASES = {"parenleft", "parenright", "braceleft", "braceright", "bracketleft", "bracketright",
                      "uni27E6", "uni27E7", "uni2983", "uni2984", "uni3014", "uni3015"}
PIECE_OFFSETS = {"top": 0x00, "mid": 0x08, "ext": 0x10, "bot": 0x18}
# Glyphs whose family does not follow a regular layout; checked visually
# against a xelatex glyph chart of MinionMath-Regular.otf.
OVERRIDES = {
    "radical.alt": 0xF8022,
    "radical.vsize1": 0xF5004, "radical.vsize3": 0xF5006, "radical.vsize5": 0xF500A,
    "radical.vsize7": 0xF500C, "radical.vsize9": 0xF500E, "radical.vsize11": 0xF5012,
    "radical.vsize13": 0xF5014,
    "radical.top": 0xF5000, "radical.ext": 0xF5008, "radical.bot": 0xF5010,
    "arrowup.top": 0xF5100, "arrowup.ext": 0xF5108, "arrowdown.bot": 0xF5110,
    "arrowdblup.top": 0xF5101, "arrowdblup.ext": 0xF5109, "arrowdbldown.bot": 0xF5111,
    # Square-bracket pieces exist twice (F6004.. and the ceiling/floor set
    # F60A2..); the paren/brace/bracket/white-bracket pieces share F600x.
    "bracketleft.top": 0xF6004, "bracketleft.ext": 0xF6014, "bracketleft.bot": 0xF601C,
    "bracketright.top": 0xF6005, "bracketright.ext": 0xF6015, "bracketright.bot": 0xF601D,
}
MIRROR_PAIRS = [
    ("parenleft", "parenright"),
    ("braceleft", "braceright"),
    ("bracketleft", "bracketright"),
    ("uni2308", "uni2309"),
    ("uni230A", "uni230B"),
    ("uni27E6", "uni27E7"),
    ("uni27E8", "uni27E9"),
    ("uni2983", "uni2984"),
    ("uni2989", "uni298A"),
    ("uni3014", "uni3015"),
]
# Base glyphs named differently from the vendor's piece prefix.
PIECE_BASES = {"arrowup": 0x2191, "arrowdown": 0x2193, "arrowdblup": 0x21D1, "arrowdbldown": 0x21D3}


def read_enc(path):
    text = re.sub(r"%[^\n]*", "", open(path).read())
    return re.findall(r"/([^\s/\[\]{}]+)", text[text.index("[") + 1 : text.rindex("]")])


def read_pl_metrics(path):
    """slot -> (width, height, depth) in 1/1000 em from a vendor .pl file."""
    text = open(path).read()
    metrics = {}
    for m in re.finditer(r"\(CHARACTER (O|C) (\S+)\n(.*?)\n   \)", text, re.S):
        slot = int(m.group(2), 8) if m.group(1) == "O" else ord(m.group(2))
        dims = dict(re.findall(r"\(CHAR(WD|HT|DP) R (-?[\d.]+)\)", m.group(3)))
        metrics[slot] = tuple(round(float(dims.get(k, 0)) * 1000) for k in ("WD", "HT", "DP"))
    return metrics


def code_of_name(name):
    """Unicode value implied by a glyph name, or None."""
    if name in LIGATURES:
        return LIGATURES[name]
    m = re.fullmatch(r"uni([0-9A-F]{4})", name) or re.fullmatch(r"u([0-9A-F]{4,6})", name)
    if m:
        return int(m.group(1), 16)
    if name in agl.AGL2UV:
        return agl.AGL2UV[name]
    return None


class Font:
    def __init__(self, path):
        self.tt = TTFont(path)
        self.gs = self.tt.getGlyphSet()
        self.cmap = self.tt.getBestCmap()
        self.names = set(self.tt.getGlyphOrder())
        self._raster = {}
        self._extent = {}

    def width(self, code):
        return self.gs[self.cmap[code]].width if code in self.cmap else None

    def extent(self, code):
        """(height, depth) of the glyph's bounding box, both >= 0."""
        if code not in self._extent:
            bp = BoundsPen(self.gs)
            self.gs[self.cmap[code]].draw(bp)
            _, y0, _, y1 = bp.bounds or (0, 0, 0, 0)
            self._extent[code] = (max(0, round(y1)), max(0, round(-y0)))
        return self._extent[code]

    def raster(self, code):
        """GRID x GRID occupancy bitmap of the glyph, normalised to its bbox."""
        if code in self._raster:
            return self._raster[code]
        g = self.cmap[code]
        bp = BoundsPen(self.gs)
        self.gs[g].draw(bp)
        bits = None
        if bp.bounds:
            x0, y0, x1, y1 = bp.bounds
            bits = []
            for j in range(GRID):
                row = []
                for i in range(GRID):
                    pen = PointInsidePen(self.gs, (x0 + (i + 0.5) * (x1 - x0) / GRID, y0 + (j + 0.5) * (y1 - y0) / GRID))
                    self.gs[g].draw(pen)
                    row.append(pen.getResult())
                bits.append(row)
        self._raster[code] = bits
        return bits


def crop(bits, part):
    """Sub-bitmap of a base glyph matching an extensible piece, re-gridded."""
    if bits is None:
        return None
    # Bitmap row 0 is the bottom of the glyph (y grows upwards).
    rows = {"top": (2 / 3, 1), "bot": (0, 1 / 3), "mid": (1 / 3, 2 / 3), "ext": (0.45, 0.55)}
    cols = {"left": (0, 1 / 3), "right": (2 / 3, 1)}
    r0, r1 = rows.get(part, (0, 1))
    c0, c1 = cols.get(part, (0, 1))
    out = []
    for j in range(GRID):
        y = r0 + (j + 0.5) / GRID * (r1 - r0)
        row = []
        for i in range(GRID):
            x = c0 + (i + 0.5) / GRID * (c1 - c0)
            row.append(bits[min(GRID - 1, int(y * GRID))][min(GRID - 1, int(x * GRID))])
        out.append(row)
    return out


def iou(a, b):
    if a is None or b is None:
        return 0.0
    inter = union = 0
    for ra, rb in zip(a, b):
        for x, y in zip(ra, rb):
            inter += x and y
            union += x or y
    return inter / union if union else 0.0


def gsub_alternates(tt):
    """feature tag -> {base code: [alternate codes]} for single/alternate subst."""
    rev = {g: u for u, g in tt.getBestCmap().items()}
    out = {}
    gsub = tt["GSUB"].table
    for fr in gsub.FeatureList.FeatureRecord:
        table = out.setdefault(fr.FeatureTag, {})
        for li in fr.Feature.LookupListIndex:
            lookup = gsub.LookupList.Lookup[li]
            for st in lookup.SubTable:
                st = getattr(st, "ExtSubTable", st)
                pairs = []
                if hasattr(st, "mapping"):
                    pairs = [(a, [b]) for a, b in st.mapping.items()]
                elif hasattr(st, "alternates"):
                    pairs = list(st.alternates.items())
                for a, bs in pairs:
                    if a in rev:
                        table.setdefault(rev[a], []).extend(rev[b] for b in bs if b in rev)
    return out


def main(texdir, otfdir):
    fonts = {os.path.basename(p)[:-4]: Font(p) for p in sorted(glob.glob(os.path.join(otfdir, "MinionMath-*.otf")))}
    ref = fonts["MinionMath-Regular"]
    feats = gsub_alternates(ref.tt)

    # name -> {font: (wd, ht, dp)} for every map entry whose font is MinionMath.
    need = {}
    mapfile = os.path.join(texdir, "fonts/map/dvips/minionmath/minionmath-ps.map")
    for line in open(mapfile):
        m = re.match(r"(\S+) \S+ .*<\[(\S+\.enc) <(MinionMath-\S+)\.pfb", line)
        if not m:
            continue
        tfm, enc, font = m.groups()
        names = read_enc(os.path.join(texdir, "fonts/enc/dvips/minionmath", enc))
        metrics = read_pl_metrics(os.path.join(texdir, "fonts/pl/typoma/minionmath", tfm + ".pl"))
        for slot, name in enumerate(names):
            if name != ".notdef" and slot in metrics:
                need.setdefault(name, {})[font] = metrics[slot]

    def fits(code, fp):
        """Advance width equals the TFM width (+-1) in every font."""
        return all(fonts[f].width(code) is not None and abs(fonts[f].width(code) - m[0]) <= 1 for f, m in fp.items())

    def plausible(code, name, fp):
        """Vertical sanity check against the (quantised) TFM height/depth.

        Size variants: total extent within 20 %.  Pieces: same sign pattern
        (above / below the baseline) and extent within a factor 3 (some
        piece heights are deliberately set to the axis in the TFMs)."""
        fname = sample_font(fp)
        _, ht, dp = fp[fname]
        h, d = fonts[fname].extent(code)
        if SIZE_RE.match(name):
            return 0.8 <= (h + d) / max(1, ht + dp) <= 1.25
        if PIECE_RE.match(name):
            return (ht > 0) == (h > 0) and (dp > 0) == (d > 0) and 1 / 3 <= (h + d) / max(1, ht + dp) <= 3
        return True

    def sample_font(fp):
        """Font used for shape tests: Regular, or a Tiny one for Tiny-only names."""
        return "MinionMath-Regular" if "MinionMath-Regular" in fp else sorted(fp)[0]

    def is_pua(code):
        return 0xE000 <= code <= 0xF8FF or code >= 0xF0000

    def base_of(name):
        m = SIZE_RE.match(name) or PIECE_RE.match(name)
        base = m.group("base") if m else name.partition(".")[0]
        return PIECE_BASES.get(base, code_of_name(base))

    def ok(font, code, name):
        fp = need[name]
        return code in font.cmap and fits(code, fp) and plausible(code, name, fp)

    def name_options(name, fp):
        """Per-name candidates scored by IoU against the base glyph."""
        font = fonts[sample_font(fp)]
        base_code = base_of(name)
        if base_code is None or base_code not in font.cmap:
            print(f"# unresolved (no base): {name}", file=sys.stderr)
            return []
        m = PIECE_RE.match(name)
        target = font.raster(base_code)
        if m:
            target = crop(target, m.group("part"))
        cands = [c for c in sorted(font.cmap) if c != base_code and ok(font, c, name)]
        # Variants live in the Private Use Area; fall back to encoded
        # characters only when no PUA glyph fits (e.g. zero.inferior).
        cands = [c for c in cands if is_pua(c)] or cands
        # Big-operator bases on PUA code points have their display size 8
        # code points further on (uF5830 -> F5838, uF5816 -> F581E, ...).
        if is_pua(base_code) and base_code + 8 in cands:
            return [(2.0, "layout", {name: base_code + 8})]
        return [(iou(target, font.raster(c)), "shape", {name: c}) for c in cands]

    def size_options(base, kind, names):
        """A size family occupies one 16-code block: offset = size number,
        or (vsize with sizes > 15) the k-th glyph of the block."""
        names = sorted(names, key=lambda n: int(SIZE_RE.match(n).group("n")))
        sizes = [int(SIZE_RE.match(n).group("n")) for n in names]
        font = fonts[sample_font(need[names[0]])]
        base_code = base_of(names[0])
        if base_code is None or base_code not in font.cmap:
            return []
        target = font.raster(base_code)
        out = []
        for block in sorted({c >> 4 for c in font.cmap if is_pua(c)}):
            entries = sorted(c for c in font.cmap if c >> 4 == block and c & 0xF)
            if max(sizes) <= 15:
                codes = [(block << 4) + n for n in sizes]
            elif len(entries) >= len(sizes):
                codes = entries[: len(sizes)]
            else:
                continue
            if not all(ok(font, c, n) for c, n in zip(codes, names)):
                continue
            score = sum(iou(target, font.raster(c)) for c in codes) / len(codes)
            if block == base_code >> 4:
                score += 1.0  # e.g. uF5C70 -> F5C71..F5C7B
            out.append((score, "block", dict(zip(names, codes))))
        return out

    def piece_options(base, names):
        """Extensible pieces: top = P, mid = P+8, ext = P+0x10, bot = P+0x18."""
        font = fonts[sample_font(need[names[0]])]
        base_code = base_of(names[0])
        if base_code is None or base_code not in font.cmap:
            return []
        out = []
        for top in sorted(c for c in font.cmap if is_pua(c)):
            assign = {n: top + PIECE_OFFSETS[PIECE_RE.match(n).group("part")] for n in names}
            if not all(ok(font, c, n) for n, c in assign.items()):
                continue
            score = sum(iou(crop(font.raster(base_code), PIECE_RE.match(n).group("part")), font.raster(c))
                        for n, c in assign.items()) / len(assign)
            out.append((score, "layout", assign))
        return out

    result = {}
    pending = []
    for name, fp in sorted(need.items()):
        if all(name in fonts[f].names for f in fp):
            continue  # real glyph name already present
        code = code_of_name(name)
        if code is not None and all(code in fonts[f].cmap for f in fp):
            result[name] = (code, "direct", 1.0)
            continue
        base, _, suffix = name.partition(".")
        base_code = code_of_name(base)
        feat_cands = []
        if base_code is not None:
            if suffix == "taboldstyle":
                feat_cands = feats.get("onum", {}).get(base_code, [])
            elif suffix == "small":
                feat_cands = feats.get("ss01", {}).get(base_code, [])
            elif suffix == "dtls":
                feat_cands = feats.get("dtls", {}).get(base_code, [])
            elif name == "zero.slash":
                feat_cands = feats.get("zero", {}).get(base_code, [])
            elif suffix in ALT_SUFFIXES:
                feat_cands = feats.get("salt", {}).get(base_code, []) + feats.get("aalt", {}).get(base_code, [])
        feat_cands = [c for c in dict.fromkeys(feat_cands) if fits(c, fp)]
        if len(feat_cands) == 1:
            result[name] = (feat_cands[0], "gsub", 1.0)
            continue
        pending.append((name, fp))

    # Shape matching for the rest: build options (a name->code assignment
    # for one name or a whole family, with a score), then accept them
    # greedily by score without reusing a code point.
    options = []  # (score, method, {name: code})
    families = {}
    for name, fp in pending:
        if name in OVERRIDES:
            result[name] = (OVERRIDES[name], "override", 1.0)
            continue
        m = SIZE_RE.match(name)
        if m:
            families.setdefault(("size", m.group("base"), m.group("kind")), []).append(name)
            continue
        m = PIECE_RE.match(name)
        if m and m.group("base") in PIECE_LAYOUT_BASES:
            families.setdefault(("piece", m.group("base"), None), []).append(name)
            continue
        options += name_options(name, need[name])
    for (what, base, kind), names in families.items():
        if what == "size" and len(names) == 1:
            options += name_options(names[0], need[names[0]])
        elif what == "size":
            options += size_options(base, kind, names)
        else:
            options += piece_options(base, names)

    options.sort(key=lambda o: -o[0])
    used = {c for c, _, _ in result.values()}
    for score, how, assign in options:
        if any(n in result for n in assign) or any(c in used for c in assign.values()):
            continue
        for n, c in assign.items():
            result[n] = (c, how, score)
            used.add(c)
    for name, _ in pending:
        if name not in result:
            print(f"# unresolved: {name}", file=sys.stderr)

    # Mirror pairs have identical metrics and near-identical normalised
    # rasters; the font always puts the left/opening member first.
    for left, right in MIRROR_PAIRS:
        for name_l in [n for n in result if n.startswith(left + ".")]:
            name_r = right + name_l[len(left):]
            if name_r in result and result[name_l][0] > result[name_r][0]:
                result[name_l], result[name_r] = result[name_r], result[name_l]
    for name_l in [n for n in result if n.endswith(".left")]:
        name_r = name_l[: -len("left")] + "right"
        if name_r in result and result[name_l][0] > result[name_r][0]:
            result[name_l], result[name_r] = result[name_r], result[name_l]

    for name in sorted(result):
        code, how, score = result[name]
        print(f"{name}\t{code:04X}\t{how}\t{score:.3f}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
