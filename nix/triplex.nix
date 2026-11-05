# triplex.nix — Emigre Triplex as a TeX Live package ("triplex").
#
# $out is the top of a TEXMFDIST tree carrying the TeX-Live-package
# attributes (see mtp2.nix), so texlive.withPackages merges it like any tlpdb
# package and enables triplex.map in updmap.cfg.
#
# NFSS families (T1 + TS1, generated with otftotfm: kern, liga, lnum):
#   triplexsans   Triplex Sans  m/b/eb = Light/Bold/XBold
#   triplexserif  Triplex Serif m/b/eb = Light/Bold/XBold
# Both take their italic from the separate Triplex Italic design; sc and sl
# fall back to n and it. Triplex Sans is loaded at "s*[\triplexscale]"
# (default 1; minmath.sty [triplex] sets 1.08 to match Minion Pro capitals).
#
# The encoding vectors are fontools' Cork (T1) and textcomp (TS1) ones.
# pdfTeX cannot embed OpenType/CFF, so otftotfm also writes Type 1 PFBs
# (cfftot1); the OTFs are kept for XeTeX/LuaTeX. Triplex has no dotless j:
# the T1 slot is left empty, as otftotfm's substitute "<Font>LCDFJ" Type 1
# fonts are rejected by pdfTeX ("Subrs array: entry index out of range").
#
# LaTeX usage: \usepackage{triplex} (Triplex Sans as \sfdefault);
# options: serif (Triplex Serif as \rmdefault), nosans.
#
# NOTE: non-free (Emigre license) — do NOT redistribute.
{
  lib,
  stdenvNoCC,
  unzip,
  lcdf-typetools,
  texlivePackages,
  sources,
}: let
  fontware = texlivePackages.fontware; # pltotf/vptovf for otftotfm
  encDir = "${texlivePackages.fontools.tex}/fonts/enc/dvips/fontools";

  encs = [
    {enc = "t1"; encoding = "T1";}
    {enc = "ts1"; encoding = "TS1";}
  ];
  shapes = [
    {shape = "n"; face = wt: wt.up;}
    {shape = "it"; face = wt: wt.it;}
  ];
  italics = {
    m = "TriplexItalic-Light";
    b = "TriplexItalic-Bold";
    eb = "TriplexItalic-XBold";
  };
  families = [
    {
      family = "triplexsans";
      desc = "Triplex Sans";
      scale = "triplexscale";
      weights = [
        {series = "m"; up = "TriplexSans-Light"; it = italics.m;}
        {series = "b"; up = "TriplexSans-Bold"; it = italics.b;}
        {series = "eb"; up = "TriplexSans-XBold"; it = italics.eb;}
      ];
    }
    {
      family = "triplexserif";
      desc = "Triplex Serif";
      scale = null;
      weights = [
        {series = "m"; up = "TriplexSerif-Light"; it = italics.m;}
        {series = "b"; up = "TriplexSerif-Bold"; it = italics.b;}
        {series = "eb"; up = "TriplexSerif-XBold"; it = italics.eb;}
      ];
    }
  ];

  # One line per TFM: "<otf face> <tfm name> <enc>" (newline-terminated:
  # `while read` drops an unterminated last line). Duplicates (the shared
  # italics) are harmless: otftotfm just rewrites the same files.
  fontJobs = lib.concatMapStrings (fam:
    lib.concatMapStrings (e:
      lib.concatMapStrings (wt:
        lib.concatMapStrings (sh: "${sh.face wt} ${sh.face wt}-lf-${e.enc} ${e.enc}\n") shapes)
      fam.weights)
    encs)
  families;

  fd = fam: e: let
    sizeSpec =
      if fam.scale == null
      then "<->"
      else "<-> s*[\\${fam.scale}]";
    sub = series: shape: target: "\\DeclareFontShape{${e.encoding}}{${fam.family}}{${series}}{${shape}}{<->ssub * ${fam.family}/${target}}{}\n";
  in
    ''
      \ProvidesFile{${e.enc}${fam.family}.fd}[2026/11/06 ${fam.desc} (otftotfm, triplex)]
      \DeclareFontFamily{${e.encoding}}{${fam.family}}{}
    ''
    + lib.optionalString (fam.scale != null) "\\providecommand*{\\${fam.scale}}{1}\n"
    + lib.concatMapStrings (wt:
      lib.concatMapStrings (sh: "\\DeclareFontShape{${e.encoding}}{${fam.family}}{${wt.series}}{${sh.shape}}{${sizeSpec} ${sh.face wt}-lf-${e.enc}}{}\n") shapes)
    fam.weights
    + lib.concatStrings [
      (sub "m" "sc" "m/n")
      (sub "b" "sc" "b/n")
      (sub "m" "sl" "m/it")
      (sub "b" "sl" "b/it")
      (sub "bx" "n" "b/n")
      (sub "bx" "it" "b/it")
      (sub "bx" "sl" "b/it")
      (sub "bx" "sc" "b/n")
    ];
  # "@@@ <file>" header + contents for every fd file, split in installPhase.
  fdBundle = lib.concatMapStrings (fam: lib.concatMapStrings (e: "@@@ ${e.enc}${fam.family}.fd\n${fd fam e}") encs) families;
in
  stdenvNoCC.mkDerivation {
    pname = "triplex";
    version = "2007"; # Emigre font release

    src = sources.triplex;
    inherit fontJobs fdBundle encDir;
    passAsFile = ["fontJobs" "fdBundle"];
    sty = ../triplex/triplex.sty;
    nativeBuildInputs = [unzip lcdf-typetools fontware];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      unzip -q "$src" -d "$TMPDIR/otf"
      otfdst="$out/fonts/opentype/emigre/triplex"
      t1dst="$out/fonts/type1/emigre/triplex"
      mkdir -p "$otfdst" "$t1dst"
      cp "$TMPDIR"/otf/*.otf "$otfdst/"

      textdir="$TMPDIR/text"
      mkdir -p "$textdir" "$TMPDIR/enc"
      for e in t1 ts1; do
        sed 's|/dotlessj\b|/.notdef|' "$encDir/fontools_$e.enc" > "$TMPDIR/enc/$e.enc"
      done
      while read -r face tfm enc; do
        f="$TMPDIR/otf/$face.otf"
        [ -f "$f" ] || { echo "missing $face.otf" >&2; exit 1; }
        ( cd "$textdir" && otftotfm --directory=. --no-updmap \
            --map-file=triplex.map -e "$TMPDIR/enc/$enc.enc" \
            -f kern -f liga -f lnum "$f" "$tfm" 2>/dev/null )
      done < "$fontJobsPath"

      mkdir -p "$out/fonts/tfm/emigre/triplex" "$out/fonts/enc/dvips/triplex" \
        "$out/fonts/map/dvips/triplex"
      cp "$textdir"/*.tfm "$out/fonts/tfm/emigre/triplex/"
      if ls "$textdir"/*.vf >/dev/null 2>&1; then
        mkdir -p "$out/fonts/vf/emigre/triplex"
        cp "$textdir"/*.vf "$out/fonts/vf/emigre/triplex/"
      fi
      cp "$textdir"/*.enc "$out/fonts/enc/dvips/triplex/"
      cp "$textdir"/*.pfb "$t1dst/"
      grep -v -e '^%' -e '^$' "$textdir/triplex.map" > "$out/fonts/map/dvips/triplex/triplex.map"

      mkdir -p "$out/tex/latex/triplex"
      awk -v dir="$out/tex/latex/triplex" \
        '/^@@@ / { f = dir "/" $2; next } { print > f }' "$fdBundlePath"
      install -m644 "$sty" "$out/tex/latex/triplex/triplex.sty"
      runHook postInstall
    '';

    meta = {
      homepage = "https://www.emigre.com/Fonts/Triplex";
      description = "Emigre Triplex Sans/Serif/Italic for pdfLaTeX (triplex.sty, families triplexsans/triplexserif)";
      license = lib.licenses.unfree;
      platforms = lib.platforms.all;
    };
  }
  // {
    outputSpecified = true;
    tlOutputName = "tex";
    fontMaps = ["Map triplex.map"];
  }
