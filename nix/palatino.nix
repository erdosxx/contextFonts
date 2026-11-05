# palatino.nix — Palatino LT Std (Adobe Font Folio 11) as a TeX Live package
# ("palatino"): NFSS family "palatino", \usepackage{palatinolt} makes it the
# main text font (\rmdefault). Small caps only exist in the Roman (m/sc).
# NOTE: non-free (Adobe/Linotype license) — do NOT redistribute.
{
  callPackage,
  adobeFontFolio,
}:
callPackage ./otf-text-package.nix {} {
  pname = "palatino";
  styName = "palatinolt"; # palatino.sty would clash with psnfss' (obsolete) palatino.sty
  version = "2.0"; # Palatino LT Std (Font Folio 11)
  description = "Palatino LT Std (Adobe Font Folio) for pdfLaTeX (palatinolt.sty, family palatino)";
  family = "palatino";
  desc = "Palatino LT Std";
  fontDir = "${adobeFontFolio}/share/fonts/opentype";
  vendor = "adobe";
  defaultRole = "rm";
  weights = [
    {series = "l"; up = "PalatinoLTStd-Light"; it = "PalatinoLTStd-LightItalic";}
    {series = "m"; up = "PalatinoLTStd-Roman"; it = "PalatinoLTStd-Italic";}
    {series = "mb"; up = "PalatinoLTStd-Medium"; it = "PalatinoLTStd-MediumItalic";}
    {series = "b"; up = "PalatinoLTStd-Bold"; it = "PalatinoLTStd-BoldItalic";}
    {series = "k"; up = "PalatinoLTStd-Black"; it = "PalatinoLTStd-BlackItalic";}
  ];
  smallCaps = [{series = "m"; face = "PalatinoLTStd-Roman";}];
}
