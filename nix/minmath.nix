# minmath.nix — typoma Minion Math fonts as a TeX Live package ("minmath").
#
# $out is the top of a TEXMFDIST tree carrying the TeX-Live-package
# attributes (see mtp2.nix), so texlive.withPackages merges it like any tlpdb
# package and enables the font maps in updmap.cfg.
#
# Inputs (release assets, see sources.nix)
#   sources.minionMathTeX  MinionMath-TeXLocal-current.zip — the vendor LaTeX
#             support bundle (minionmath.sty, *.fd, TFM/VF, enc, dvips maps).
#             Its fonts/opentype and fonts/type1 dirs are empty: the fonts
#             themselves are supplied separately.
#   sources.minionMathOtf  MinionMath_1_021.zip — the 20 MinionMath-*.otf.
#   adobeFontFolio  Adobe MinionPro-*.otf / MyriadPro-*.otf. Required: the
#             vendor VFs for \mathrm, digits and operator names take their
#             glyphs from MinionPro-{Regular,Medium,Semibold,Bold}{,Capt,Subh,
#             Disp}, and t1minionmath.fd refers to italic MinionPro-*It*-lf-l1-t1
#             TFMs the bundle does not ship. The bundle has no text fonts of its
#             own either (its T1 "minionmath" VFs are math-only: slanted, zero
#             interword space), so the Minion Pro text family "minionpro" (and
#             the Myriad Pro sans family "myriadpro") is generated here with
#             otftotfm.
#
# pdfTeX cannot embed OpenType/CFF fonts, so every OTF used is converted to a
# Type 1 PFB with cfftot1, and the PFB-based vendor map (minionmath-ps.map) is
# the one registered (the OTF-based minionmath.map is installed for reference,
# not enabled). The bundle was made for Minion Math 1.024 with named glyphs;
# the OTFs here carry generic glyph names with the variants on PUA code
# points, so ../minmath/add_glyph_names.py first re-adds the names the vendor
# encodings use (mapping: ../minmath/glyphmap.tsv, made by resolve_glyphs.py).
#
# LaTeX usage: \usepackage{minmath} (../minmath/minmath.sty: Minion Pro text +
# minionmath + amsmath + minionamsmath in the required order);
# \usepackage[myriad]{minmath} makes Myriad Pro the sans-serif font,
# \usepackage[triplex]{minmath} Emigre Triplex Sans — the latter needs the
# separate "triplex" TeX package (./triplex.nix) in the same TeX Live env.
#
# NOTE: non-free (typoma / Adobe licenses) — do NOT redistribute.
{
  lib,
  stdenvNoCC,
  unzip,
  lcdf-typetools,
  texlivePackages,
  python3,
  sources,
  adobeFontFolio,
}: let
  fontware = texlivePackages.fontware; # pltotf/vptovf for otftotfm
  python = python3.withPackages (ps: [ps.fonttools]);
  minionPro = "${adobeFontFolio}/share/fonts/opentype";
  myriadPro = minionPro;

  # NFSS series -> Minion Pro weight prefix (series names as in the vendor fd).
  weights = [
    {series = "m"; w = "";}
    {series = "d"; w = "Medium";}
    {series = "sb"; w = "Semibold";}
    {series = "b"; w = "Bold";}
  ];
  # Optical sizes with the same size ranges as the vendor fd files.
  opticals = [
    {range = "<-8.5>"; o = "Capt";}
    {range = "<8.5-13.5>"; o = "";}
    {range = "<13.5-24.5>"; o = "Subh";}
    {range = "<24.5->"; o = "Disp";}
  ];
  # Minion Pro face names: upright regular is "Regular", its optical sizes
  # have no weight prefix ("Capt"); italics are "<w>It<o>".
  upright = w: o:
    if w == "" && o == ""
    then "Regular"
    else "${w}${o}";
  italic = w: o: "${w}It${o}";
  # Generated TFM names. "-lf-l1-t1" is what t1minionmath.fd expects. The
  # encoding vectors are the vendor's minionmath-<enc>.enc (T1 = Cork text,
  # TS1 = textcomp symbols such as \textbullet).
  t1Shapes = [
    {shape = "n"; face = upright; suffix = "lf-l1-t1"; enc = "t1"; feats = "";}
    {shape = "it"; face = italic; suffix = "lf-l1-t1"; enc = "t1"; feats = "";}
    {shape = "sc"; face = upright; suffix = "lf-sc-t1"; enc = "t1"; feats = "-f smcp";}
  ];
  ts1Shapes = [
    {shape = "n"; face = upright; suffix = "lf-ts1"; enc = "ts1"; feats = "";}
    {shape = "it"; face = italic; suffix = "lf-ts1"; enc = "ts1"; feats = "";}
  ];
  cross = lib.concatMap (wt: lib.concatMap (sh: map (op: {inherit wt sh op;}) opticals) (t1Shapes ++ ts1Shapes)) weights;
  # One line per generated font: "<otf face> <tfm name> <enc> <extra features>".
  fontJobs = lib.concatMapStrings (x: let
    face = x.sh.face x.wt.w x.op.o;
  in "MinionPro-${face} MinionPro-${face}-${x.sh.suffix} ${x.sh.enc} ${x.sh.feats}\n")
  cross; # (each line newline-terminated: `while read` drops an unterminated last line)

  # Sans-serif families without optical sizes or small caps (sc -> upright):
  # one OTF per series and shape. TFMs are "<otf>-lf-<enc>" for T1 and TS1.
  sansEncs = [
    {enc = "t1"; encoding = "T1";}
    {enc = "ts1"; encoding = "TS1";}
  ];
  sansShapes = [
    {shape = "n"; face = wt: wt.up;}
    {shape = "it"; face = wt: wt.it;}
  ];
  sansJobs = weights:
    lib.concatMapStrings (e:
      lib.concatMapStrings (wt:
        lib.concatMapStrings (sh: "${sh.face wt} ${sh.face wt}-lf-${e.enc} ${e.enc}\n") sansShapes)
      weights)
    sansEncs;
  # fd file for one encoding; `bold' is the series that b/bx fall back to.
  # A family with `scale' gets its fonts loaded at "s*[\<scale.macro>]",
  # where the macro (default scale.default) may be redefined in the preamble.
  sansFd = {family, desc, weights, scale ? null}: e: let
    sizeSpec =
      if scale == null
      then "<->"
      else "<-> s*[\\${scale.macro}]";
  in ''
    \ProvidesFile{${e.enc}${family}.fd}[2026/10/17 ${desc} (otftotfm, minmath)]
    \DeclareFontFamily{${e.encoding}}{${family}}{}
    ${lib.optionalString (scale != null) "\\providecommand*{\\${scale.macro}}{${scale.default}}\n"}
    ${lib.concatMapStrings (wt:
      lib.concatMapStrings (sh: "\\DeclareFontShape{${e.encoding}}{${family}}{${wt.series}}{${sh.shape}}{${sizeSpec} ${sh.face wt}-lf-${e.enc}}{}\n")
      sansShapes)
    weights}
    \DeclareFontShape{${e.encoding}}{${family}}{m}{sc}{<->ssub * ${family}/m/n}{}
    \DeclareFontShape{${e.encoding}}{${family}}{b}{sc}{<->ssub * ${family}/b/n}{}
    \DeclareFontShape{${e.encoding}}{${family}}{m}{sl}{<->ssub * ${family}/m/it}{}
    \DeclareFontShape{${e.encoding}}{${family}}{b}{sl}{<->ssub * ${family}/b/it}{}
    \DeclareFontShape{${e.encoding}}{${family}}{bx}{n}{<->ssub * ${family}/b/n}{}
    \DeclareFontShape{${e.encoding}}{${family}}{bx}{it}{<->ssub * ${family}/b/it}{}
    \DeclareFontShape{${e.encoding}}{${family}}{bx}{sl}{<->ssub * ${family}/b/it}{}
    \DeclareFontShape{${e.encoding}}{${family}}{bx}{sc}{<->ssub * ${family}/b/n}{}
  '';
  # Myriad Pro (NFSS family "myriadpro"), weights Light/Regular/Semibold/Bold.
  myriad = {
    family = "myriadpro";
    desc = "Myriad Pro";
    weights = [
      {series = "l"; up = "MyriadPro-Light"; it = "MyriadPro-LightIt";}
      {series = "m"; up = "MyriadPro-Regular"; it = "MyriadPro-It";}
      {series = "sb"; up = "MyriadPro-Semibold"; it = "MyriadPro-SemiboldIt";}
      {series = "b"; up = "MyriadPro-Bold"; it = "MyriadPro-BoldIt";}
    ];
  };
  sansFamilies = [myriad];
  # "<enc><family>.fd" file name -> contents, for every sans family.
  sansFdFiles = lib.listToAttrs (lib.concatMap (fam:
    map (e: lib.nameValuePair "${e.enc}${fam.family}.fd" (sansFd fam e)) sansEncs)
  sansFamilies);

  shapeDecl = encoding: wt: sh: ''
    \DeclareFontShape{${encoding}}{minionpro}{${wt.series}}{${sh.shape}}{
    ${lib.concatMapStringsSep "\n" (op: "   ${op.range} MinionPro-${sh.face wt.w op.o}-${sh.suffix}") opticals}}{}
  '';
  ts1FdFile = ''
    \ProvidesFile{ts1minionpro.fd}[2026/10/17 Minion Pro textcomp symbols (otftotfm, minmath)]
    \DeclareFontFamily{TS1}{minionpro}{}
    ${lib.concatMapStrings (wt: lib.concatMapStrings (shapeDecl "TS1" wt) ts1Shapes) weights}
    \DeclareFontShape{TS1}{minionpro}{bx}{n}{<->ssub * minionpro/b/n}{}
    \DeclareFontShape{TS1}{minionpro}{bx}{it}{<->ssub * minionpro/b/it}{}
    \DeclareFontShape{TS1}{minionpro}{m}{sc}{<->ssub * minionpro/m/n}{}
    \DeclareFontShape{TS1}{minionpro}{m}{sl}{<->ssub * minionpro/m/it}{}
    \DeclareFontShape{TS1}{minionpro}{b}{sl}{<->ssub * minionpro/b/it}{}
  '';
  fdFile = ''
    \ProvidesFile{t1minionpro.fd}[2026/10/17 Minion Pro (otftotfm, minmath)]
    \DeclareFontFamily{T1}{minionpro}{}
    ${lib.concatMapStrings (wt: lib.concatMapStrings (shapeDecl "T1" wt) t1Shapes) weights}
    \DeclareFontShape{T1}{minionpro}{bx}{n}{<->ssub * minionpro/b/n}{}
    \DeclareFontShape{T1}{minionpro}{bx}{it}{<->ssub * minionpro/b/it}{}
    \DeclareFontShape{T1}{minionpro}{bx}{sc}{<->ssub * minionpro/b/sc}{}
    \DeclareFontShape{T1}{minionpro}{m}{sl}{<->ssub * minionpro/m/it}{}
    \DeclareFontShape{T1}{minionpro}{b}{sl}{<->ssub * minionpro/b/it}{}
    \DeclareFontShape{T1}{minionpro}{bx}{sl}{<->ssub * minionpro/b/it}{}
  '';
in
  stdenvNoCC.mkDerivation {
    pname = "minmath";
    version = "1.024"; # minionmath.sty v1.024, 2012/06/25 (fonts: release 1.026)

    src = sources.minionMathTeX;
    otfZip = sources.minionMathOtf;
    inherit minionPro myriadPro fdFile ts1FdFile;
    fontJobs = fontJobs + lib.concatMapStrings (fam: sansJobs fam.weights) sansFamilies;
    # Written by a loop in installPhase: one "<name>\n<contents>" record per file.
    sansFds = lib.concatStrings (lib.mapAttrsToList (n: c: "@@@ ${n}\n${c}") sansFdFiles);
    passAsFile = ["fontJobs" "fdFile" "ts1FdFile" "sansFds"];
    # glyphmap.tsv + add_glyph_names.py (see resolve_glyphs.py) and minmath.sty.
    tools = ../minmath;
    nativeBuildInputs = [unzip lcdf-typetools fontware python];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      unzip -q "$src" -d "$TMPDIR/mm"
      # Vendor tree: tex/latex/minionmath, fonts/{enc,map,tfm,vf}/...
      # (doc/ is empty; pl/ is only the TFM source, skip it).
      cp -r "$TMPDIR/mm/tex" "$out/"
      mkdir -p "$out/fonts"
      for d in enc map tfm vf; do
        cp -r "$TMPDIR/mm/fonts/$d" "$out/fonts/"
      done
      chmod -R u+w "$out/fonts/vf"
      # The vendor VFs record, for 148 local *--base fonts, checksums that
      # differ from the shipped --base TFMs ("checksum mismatch in local font
      # ... ignored" on every run). Set them to the TFM checksums, i.e. what
      # TeX already falls back to; metrics are unchanged.
      python3 "$tools/fix_vf_checksums.py" \
        "$out/fonts/vf/typoma/minionmath" "$out/fonts/tfm/typoma/minionmath"

      otfdst="$out/fonts/opentype/typoma/minionmath"
      t1dst="$out/fonts/type1/typoma/minionmath"
      mkdir -p "$otfdst" "$t1dst"

      # MinionMath: keep the OTFs (for XeTeX/LuaTeX) + PFB for pdfTeX. The
      # 1.026 OTFs name their glyphs glyphNNN, while the vendor .enc files
      # use PostScript names (parenleft.vsize3, uni2308, ...): add those
      # names (glyphmap.tsv) before converting to Type 1.
      unzip -q "$otfZip" -d "$TMPDIR/mmotf"
      for f in "$TMPDIR"/mmotf/MinionMath/MinionMath/MinionMath-*.otf; do
        b=$(basename "$f" .otf)
        cp "$f" "$otfdst/"
        python3 "$tools/add_glyph_names.py" "$tools/glyphmap.tsv" "$f" "$TMPDIR/$b.cff"
        cfftot1 "$TMPDIR/$b.cff" "$t1dst/$b.pfb" 2>/dev/null # flex-hint warnings only
      done

      # Minion Pro text family "minionpro": TFM per weight x optical size x
      # shape -- T1 (n, it, sc; vendor minionmath-t1.enc Cork layout, kerning
      # + ligatures + lining figures) and TS1 (n, it; minionmath-ts1.enc). The upright
      # and italic PFBs also serve the vendor OT1/T1 math VFs. The same loop
      # makes the sans-serif family "myriadpro" (T1 + TS1).
      textdir="$TMPDIR/text"
      mkdir -p "$textdir"
      while read -r face tfm enc feats; do
        f="$minionPro/$face.otf"
        [ -f "$f" ] || f="$myriadPro/$face.otf"
        [ -f "$f" ] || { echo "missing $face.otf" >&2; exit 1; }
        ( cd "$textdir" && otftotfm --directory=. --no-updmap --no-type1 \
            --map-file=minmath-text.map \
            -e "$TMPDIR/mm/fonts/enc/dvips/minionmath/minionmath-$enc.enc" \
            -f kern -f liga -f lnum $feats "$f" "$tfm" 2>/dev/null )
        [ -f "$t1dst/$face.pfb" ] || cfftot1 "$f" "$t1dst/$face.pfb" 2>/dev/null
      done < "$fontJobsPath"
      mkdir -p "$out/fonts/tfm/typoma/minionpro" "$out/fonts/vf/typoma/minionpro" \
        "$out/fonts/enc/dvips/minionpro"
      cp "$textdir"/*.tfm "$out/fonts/tfm/typoma/minionpro/"
      cp "$textdir"/*.vf "$out/fonts/vf/typoma/minionpro/" 2>/dev/null || true
      cp "$textdir"/*.enc "$out/fonts/enc/dvips/minionpro/"
      # otftotfm writes "<MinionPro-X.otf"; pdfTeX needs the PFB instead.
      grep -v -e '^%' -e '^$' "$textdir/minmath-text.map" | sed -E 's/<([^ ]+)\.otf$/<\1.pfb/' \
        > "$out/fonts/map/dvips/minionmath/minmath-text.map"

      install -Dm644 "$fdFilePath" "$out/tex/latex/minmath/t1minionpro.fd"
      install -Dm644 "$ts1FdFilePath" "$out/tex/latex/minmath/ts1minionpro.fd"
      # Split the sans-family fd bundle ("@@@ <file>" headers) into files.
      awk -v dir="$out/tex/latex/minmath" \
        '/^@@@ / { f = dir "/" $2; next } { print > f }' "$sansFdsPath"
      install -Dm644 "$tools/minmath.sty" "$out/tex/latex/minmath/minmath.sty"

      runHook postInstall
    '';

    meta = {
      description = "typoma Minion Math + Minion Pro text for pdfLaTeX (minmath.sty, minionmath.sty)";
      license = lib.licenses.unfree;
      platforms = lib.platforms.all;
    };
  }
  // {
    # TeX-Live-package-shaped attributes (see mtp2.nix).
    outputSpecified = true;
    tlOutputName = "tex";
    fontMaps = ["Map minionmath-ps.map" "Map minmath-text.map"];
    # fontmath.minion loads rsfs (\mathscr); resolved in the consumer's TL set.
    tlDeps = ps: [ps.rsfs];
  }
