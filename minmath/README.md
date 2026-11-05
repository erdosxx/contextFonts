# minmath — Minion Math for pdfLaTeX (support files for ../nix/minmath.nix)

| File | Role |
| --- | --- |
| `minmath.sty` | `\usepackage{minmath}`: T1 + Minion Pro text (`minionpro`) + `minionmath[withamsmath,amssymb]` + `amsmath` + `minionamsmath`, with a fix for the math accents under LaTeX ≥ 2020. Options `myriad` / `triplex` pick Myriad Pro / Emigre Triplex Sans as sans-serif (Triplex Sans from the separate `triplex` package, scaled by `\triplexscale`, default 1.08 = cap-height ratio Minion Pro : Triplex Sans); other options are passed to `minionmath.sty`. |
| `glyphmap.tsv` | Vendor glyph name → code point in the Minion Math 1.026 OTFs, plus how each was found (`direct`, `gsub`, `block`, `layout`, `shape`, `override`). |
| `add_glyph_names.py` | Build step: copies each mapped glyph under its vendor name, then writes a bare CFF for `cfftot1`. |
| `resolve_glyphs.py` | Dev tool that generated `glyphmap.tsv`. |
| `fix_vf_checksums.py` | Build step: sets the local-font checksums in the vendor VFs to those of the shipped `*--base.tfm` (silences "checksum mismatch in local font ... ignored"). |

Why the mapping exists: the typoma TeX bundle (`MinionMath-TeXLocal-current.zip`,
v1.024) addresses glyphs by PostScript name in its `.enc` files. The OTFs in
`MinionMath_1_021.zip` (release asset) have generic `glyphNNN` names and put the size variants
and extensible pieces on Private Use Area code points. Without the mapping,
pdfTeX prints `.notdef` boxes for most math.

To regenerate the mapping (takes about 1 min, needs fontTools):

    unzip -q MinionMath-TeXLocal-current.zip -d /tmp/mm
    unzip -q MinionMath_1_021.zip -d /tmp/mmotf
    python3 resolve_glyphs.py /tmp/mm /tmp/mmotf/MinionMath/MinionMath > glyphmap.tsv

Check entries that are not `direct` in a glyph chart, or by compiling a test document.
