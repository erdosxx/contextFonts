# myriad.nix — Myriad Pro (Adobe Font Folio 11) as a TeX Live package
# ("myriad"): NFSS family "myriad", \usepackage{myriad} makes it the
# sans-serif font (\sfdefault; [rm] for the main text font).
#
# Weights l Light, m Regular, sb Semibold, b Bold, k Black; widths normal,
# c Condensed, sc SemiCondensed, sx SemiExtended (series = weight + width,
# e.g. bc, lsx; the regular weight drops the "m": c, sc, sx). Shapes n, it;
# Myriad Pro has no small caps (sc -> n).
#
# Independent of minmath (which generates its own "myriadpro" family): a
# different family name and TFM tag, so both can be installed together.
# NOTE: non-free (Adobe license) — do NOT redistribute.
{
  lib,
  callPackage,
  adobeFontFolio,
}: let
  weights = [
    {w = "Light"; s = "l";}
    {w = ""; s = "m";}
    {w = "Semibold"; s = "sb";}
    {w = "Bold"; s = "b";}
    {w = "Black"; s = "k";}
  ];
  widths = [
    {x = ""; s = "";}
    {x = "Cond"; s = "c";}
    {x = "SemiCn"; s = "sc";}
    {x = "SemiExt"; s = "sx";}
  ];
  series = wt: wd:
    if wd.s == ""
    then wt.s
    else if wt.s == "m"
    then wd.s
    else wt.s + wd.s;
  upright = wt: wd:
    if wt.w == "" && wd.x == ""
    then "MyriadPro-Regular"
    else "MyriadPro-${wt.w}${wd.x}";
  italic = wt: wd: "MyriadPro-${wt.w}${wd.x}It";
in
  callPackage ./otf-text-package.nix {} {
    pname = "myriad";
    version = "2.0"; # Myriad Pro (Font Folio 11)
    description = "Myriad Pro (Adobe Font Folio) for pdfLaTeX (myriad.sty, family myriad)";
    family = "myriad";
    desc = "Myriad Pro";
    fontDir = "${adobeFontFolio}/share/fonts/opentype";
    vendor = "adobe";
    defaultRole = "sf";
    tfmTag = "cf"; # minmath already has MyriadPro-*-lf-* TFMs
    weights = lib.concatMap (wd:
      map (wt: {
        series = series wt wd;
        up = upright wt wd;
        it = italic wt wd;
      })
      weights)
    widths;
  }
