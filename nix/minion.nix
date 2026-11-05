# minion.nix — Minion Pro (Adobe Font Folio 11) as a TeX Live package
# ("minion"): NFSS family "minion", \usepackage{minion} makes it the main
# text font (\rmdefault).
#
# Series: m Regular, mb Medium, sb Semibold, b Bold, and their condensed
# widths c, mbc, sbc, bc; shapes n, it, sc (smcp, every weight). Each face is
# built in the four Minion Pro optical sizes, selected by point size:
# Capt (< 8.5pt), text (8.5–13.5pt), Subh (13.5–24.5pt), Disp (>= 24.5pt).
#
# Independent of minmath (which generates its own "minionpro" family for its
# math setup): different family name and TFM tag, so both can be installed
# in one TeX Live env.
# NOTE: non-free (Adobe license) — do NOT redistribute.
{
  lib,
  callPackage,
  adobeFontFolio,
}: let
  # Weight prefix in the face names x width; NFSS series code.
  weights = [
    {w = ""; s = "m";}
    {w = "Medium"; s = "mb";}
    {w = "Semibold"; s = "sb";}
    {w = "Bold"; s = "b";}
  ];
  widths = [
    {x = ""; s = "";}
    {x = "Cn"; s = "c";}
  ];
  series = wt: wd:
    if wd.s == ""
    then wt.s
    else if wt.s == "m"
    then wd.s
    else wt.s + wd.s;
  upright = wt: wd:
    if wt.w == "" && wd.x == ""
    then "MinionPro-Regular"
    else "MinionPro-${wt.w}${wd.x}";
  italic = wt: wd: "MinionPro-${wt.w}${wd.x}It";
  cross = lib.concatMap (wd: map (wt: {inherit wt wd;}) weights) widths;
in
  callPackage ./otf-text-package.nix {} {
    pname = "minion";
    version = "2.0"; # Minion Pro (Font Folio 11)
    description = "Minion Pro (Adobe Font Folio) for pdfLaTeX (minion.sty, family minion, optical sizes)";
    family = "minion";
    desc = "Minion Pro";
    fontDir = "${adobeFontFolio}/share/fonts/opentype";
    vendor = "adobe";
    defaultRole = "rm";
    tfmTag = "cf"; # minmath already has MinionPro-*-lf-* TFMs
    weights =
      map (c: {
        series = series c.wt c.wd;
        up = upright c.wt c.wd;
        it = italic c.wt c.wd;
      })
      cross;
    smallCaps =
      map (c: {
        series = series c.wt c.wd;
        face = upright c.wt c.wd;
      })
      cross;
    opticals = [
      {range = "<-8.5>"; suffix = "Capt";}
      {range = "<8.5-13.5>"; suffix = "";}
      {range = "<13.5-24.5>"; suffix = "Subh";}
      {range = "<24.5->"; suffix = "Disp";}
    ];
    # MinionPro-Regular + Capt -> MinionPro-Capt; others append the suffix.
    opticalFace = face: suffix:
      if suffix != "" && lib.hasSuffix "-Regular" face
      then lib.removeSuffix "Regular" face + suffix
      else face + suffix;
  }
