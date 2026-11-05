# trajan.nix — Trajan Pro (Adobe Font Folio 11) as a TeX Live package
# ("trajan"): NFSS family "trajan", \usepackage{trajan} defines
# \trajanfamily (options rm / sf make it \rmdefault / \sfdefault).
# Trajan is a capitals-only display face: its lowercase letters are small
# capitals by design; shape sc (\textsc) uses smcp + c2sc, so capitals
# become small capitals too (all small caps). Regular (m) and Bold (b), no italic (it -> n).
# NOTE: non-free (Adobe license) — do NOT redistribute.
{
  callPackage,
  adobeFontFolio,
}:
callPackage ./otf-text-package.nix {} {
  pname = "trajan";
  version = "1.0"; # Trajan Pro (Font Folio 11)
  description = "Trajan Pro (Adobe Font Folio) for pdfLaTeX (trajan.sty, family trajan)";
  family = "trajan";
  desc = "Trajan Pro";
  fontDir = "${adobeFontFolio}/share/fonts/opentype";
  vendor = "adobe";
  defaultRole = "none";
  weights = [
    {series = "m"; up = "TrajanPro-Regular"; it = null;}
    {series = "b"; up = "TrajanPro-Bold"; it = null;}
  ];
  scFeatures = "-f smcp -f c2sc";
  smallCaps = [
    {series = "m"; face = "TrajanPro-Regular";}
    {series = "b"; face = "TrajanPro-Bold";}
  ];
}
