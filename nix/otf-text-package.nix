# otf-text-package.nix — build a TeX Live package for one OpenType text
# family with otftotfm (pdfLaTeX: TFM/VF + Type 1 PFB + dvips map + fd + sty).
#
# Used by optima.nix and palatino.nix (Adobe Font Folio families). $out is
# the top of a TEXMFDIST tree carrying the TeX-Live-package attributes (see
# mtp2.nix), so texlive.withPackages merges it like any tlpdb package and
# enables "<pname>.map" in updmap.cfg.
#
# NFSS family `family' in T1 and TS1 (fontools' Cork / textcomp encodings;
# features kern, liga, lnum), shape n for every weight, it for weights with
# an italic face (`it' may be null), plus sc for the weights listed in
# `smallCaps' (smcp feature). Missing shapes fall back: sc -> n, sl -> it
# (or n without italic), it -> n (without italic), bx -> b.
#
# With `opticals' every face is built in several optical sizes, chosen by
# point size in the fd ranges: face name = opticalFace <face> <suffix>.
# TFMs are named <face>-<tfmTag>[-sc]-<enc>; pick a tfmTag that differs from
# other packages generating TFMs for the same OTFs (minmath uses "lf"). Fonts are loaded at "s*[\<family>scale]"
# (default 1). The dotless j is left empty in T1: these fonts lack it, and
# otftotfm's substitute "<Font>LCDFJ" Type 1 fonts make pdfTeX fail.
#
# The generated <styName>.sty defines \<family>family and selects the family
# as `defaultRole' (rm, sf, or none = only \<family>family); options rm / sf
# / none choose explicitly. styName must not clash with TeX Live
# (e.g. psnfss already has an obsolete palatino.sty).
{
  lib,
  stdenvNoCC,
  lcdf-typetools,
  texlivePackages,
}: {
  pname,
  styName ? pname, # LaTeX package name (<styName>.sty)
  version,
  description,
  family, # NFSS family name
  desc, # human readable family name
  fontDir, # directory with the OTFs
  vendor, # TDS supplier directory, e.g. "adobe"
  weights, # [{series; up; it;}] OTF base names (without .otf); it may be null
  smallCaps ? [], # [{series; face;}] faces with an smcp feature
  scFeatures ? "-f smcp", # otftotfm features for the sc shape
  tfmTag ? "lf", # TFM name tag, see above
  # [{range; suffix;}] optical sizes, e.g. {range = "<-8.5>"; suffix = "Capt";};
  # null = one face for all sizes.
  opticals ? null,
  opticalFace ? face: suffix: face + suffix,
  defaultRole ? "rm", # "rm", "sf" or "none"
  license ? lib.licenses.unfree,
  homepage ? null,
}: let
  fontware = texlivePackages.fontware; # pltotf/vptovf for otftotfm
  encDir = "${texlivePackages.fontools.tex}/fonts/enc/dvips/fontools";
  scale = "${family}scale";

  encs = [
    {enc = "t1"; encoding = "T1";}
    {enc = "ts1"; encoding = "TS1";}
  ];
  sizes =
    if opticals == null
    then [{range = "<->"; suffix = null;}]
    else opticals;
  # One job per optical size of a base face.
  mkJobs = e: {face, series, shape, sc ? false}:
    map (o: let
      f =
        if o.suffix == null
        then face
        else opticalFace face o.suffix;
    in {
      face = f;
      tfm = "${f}-${tfmTag}${lib.optionalString sc "-sc"}-${e.enc}";
      inherit series shape;
      inherit (o) range;
      feats = lib.optionalString sc scFeatures;
    })
    sizes;
  # [{face; tfm; shape; series; range; feats;}] per encoding. Small caps are
  # T1 only.
  jobsFor = e:
    lib.concatMap (wt:
      mkJobs e {face = wt.up; inherit (wt) series; shape = "n";}
      ++ lib.optionals (wt.it or null != null)
      (mkJobs e {face = wt.it; inherit (wt) series; shape = "it";}))
    weights
    ++ lib.optionals (e.enc == "t1") (lib.concatMap (sc:
      mkJobs e {inherit (sc) face series; shape = "sc"; sc = true;})
    smallCaps);
  # "<otf face> <tfm name> <enc> <extra features>", newline-terminated.
  fontJobs = lib.concatMapStrings (e:
    lib.concatMapStrings (j: "${j.face} ${j.tfm} ${e.enc} ${j.feats}\n") (jobsFor e))
  encs;

  hasSeries = s: lib.any (wt: wt.series == s) weights;
  boldSeries =
    if hasSeries "b"
    then "b"
    else (lib.last weights).series;
  fd = e: let
    decl = series: shape: spec: "\\DeclareFontShape{${e.encoding}}{${family}}{${series}}{${shape}}{${spec}}{}\n";
    sub = series: shape: target: decl series shape "<->ssub * ${family}/${target}";
    jobs = jobsFor e;
    hasShape = series: shape: lib.any (j: j.series == series && j.shape == shape) jobs;
  in
    ''
      \ProvidesFile{${e.enc}${family}.fd}[2026/11/06 ${desc} (otftotfm, ${pname})]
      \DeclareFontFamily{${e.encoding}}{${family}}{}
      \providecommand*{\${scale}}{1}
    ''
    # One declaration per (series, shape), listing all its size ranges.
    + lib.concatMapStrings (g:
      decl g.series g.shape (lib.concatMapStringsSep " " (j: "${j.range} s*[\\${scale}] ${j.tfm}") g.jobs))
    (lib.mapAttrsToList (_: js: {
      inherit (lib.head js) series shape;
      jobs = js;
    }) (lib.groupBy (j: "${j.series}/${j.shape}") jobs))
    + lib.concatMapStrings (wt:
      lib.optionalString (!hasShape wt.series "sc") (sub wt.series "sc" "${wt.series}/n")
      + lib.optionalString (!hasShape wt.series "it") (sub wt.series "it" "${wt.series}/n")
      + sub wt.series "sl" "${wt.series}/it")
    weights
    + lib.optionalString (!hasSeries "bx") (lib.concatStrings [
      (sub "bx" "n" "${boldSeries}/n")
      (sub "bx" "it" "${boldSeries}/it")
      (sub "bx" "sl" "${boldSeries}/it")
      (sub "bx" "sc" "${boldSeries}/sc")
    ]);
  fdBundle = lib.concatMapStrings (e: "@@@ ${e.enc}${family}.fd\n${fd e}") encs;

  sty = ''
    %% ${styName}.sty -- ${desc} for pdfLaTeX (NFSS family "${family}").
    %% Generated by nix/otf-text-package.nix (contextFonts). Series:
    %% ${lib.concatMapStringsSep ", " (wt: "${wt.series} = ${wt.up}") weights}.
    %% \${family}family selects it locally. Options: rm (${desc} as
    %% \rmdefault + \familydefault), sf (as \sfdefault), none (neither);
    %% default: ${defaultRole}. Fonts are scaled by \${scale} (default 1).
    %% NOTE: non-free fonts.
    \NeedsTeXFormat{LaTeX2e}
    \ProvidesPackage{${styName}}[2026/11/06 v1.0 ${desc}]
    \def\${styName}@role{${defaultRole}}
    \DeclareOption{rm}{\def\${styName}@role{rm}}
    \DeclareOption{sf}{\def\${styName}@role{sf}}
    \DeclareOption{none}{\def\${styName}@role{none}}
    \ProcessOptions\relax
    \RequirePackage[T1]{fontenc}
    \providecommand*{\${scale}}{1}
    \DeclareRobustCommand{\${family}family}{\fontfamily{${family}}\selectfont}
    \def\${styName}@rm{rm}
    \def\${styName}@sf{sf}
    \ifx\${styName}@role\${styName}@rm
      \renewcommand{\rmdefault}{${family}}
      \renewcommand{\familydefault}{\rmdefault}
    \fi
    \ifx\${styName}@role\${styName}@sf
      \renewcommand{\sfdefault}{${family}}
    \fi
    \endinput
  '';
in
  stdenvNoCC.mkDerivation {
    inherit pname version fontDir encDir vendor family fontJobs fdBundle sty;
    passAsFile = ["fontJobs" "fdBundle" "sty"];
    nativeBuildInputs = [lcdf-typetools fontware];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      otfdst="$out/fonts/opentype/$vendor/$family"
      t1dst="$out/fonts/type1/$vendor/$family"
      mkdir -p "$otfdst" "$t1dst" "$TMPDIR/enc"
      for e in t1 ts1; do
        sed 's|/dotlessj\b|/.notdef|' "$encDir/fontools_$e.enc" > "$TMPDIR/enc/$e.enc"
      done

      textdir="$TMPDIR/text"
      mkdir -p "$textdir"
      while read -r face tfm enc feats; do
        f="$fontDir/$face.otf"
        [ -f "$f" ] || { echo "missing $face.otf" >&2; exit 1; }
        [ -f "$otfdst/$face.otf" ] || cp "$f" "$otfdst/"
        ( cd "$textdir" && otftotfm --directory=. --no-updmap \
            --map-file=${pname}.map -e "$TMPDIR/enc/$enc.enc" \
            -f kern -f liga -f lnum $feats "$f" "$tfm" 2>/dev/null )
      done < "$fontJobsPath"

      mkdir -p "$out/fonts/tfm/$vendor/$family" "$out/fonts/enc/dvips/$family" \
        "$out/fonts/map/dvips/$family" "$out/tex/latex/$family"
      cp "$textdir"/*.tfm "$out/fonts/tfm/$vendor/$family/"
      if ls "$textdir"/*.vf >/dev/null 2>&1; then
        mkdir -p "$out/fonts/vf/$vendor/$family"
        cp "$textdir"/*.vf "$out/fonts/vf/$vendor/$family/"
      fi
      cp "$textdir"/*.enc "$out/fonts/enc/dvips/$family/"
      cp "$textdir"/*.pfb "$t1dst/"
      grep -v -e '^%' -e '^$' "$textdir/${pname}.map" > "$out/fonts/map/dvips/$family/${pname}.map"
      # Every PFB named in the map must exist (e.g. no LCDFJ substitutes).
      for p in $(grep -o '<[^[ ][^ ]*\.pfb' "$out/fonts/map/dvips/$family/${pname}.map" | tr -d '<'); do
        [ -f "$t1dst/$p" ] || { echo "map refers to missing $p" >&2; exit 1; }
      done

      awk -v dir="$out/tex/latex/$family" \
        '/^@@@ / { f = dir "/" $2; next } { print > f }' "$fdBundlePath"
      install -m644 "$styPath" "$out/tex/latex/$family/${styName}.sty"
      runHook postInstall
    '';

    meta =
      {
        inherit description license;
        platforms = lib.platforms.all;
      }
      // lib.optionalAttrs (homepage != null) {inherit homepage;};
  }
  // {
    outputSpecified = true;
    tlOutputName = "tex";
    fontMaps = ["Map ${pname}.map"];
  }
