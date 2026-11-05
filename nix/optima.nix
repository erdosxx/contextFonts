# optima.nix — Optima LT Std (Adobe Font Folio 11) as a TeX Live package
# ("optima"): NFSS family "optima", \usepackage{optimalt} makes it \sfdefault
# ([rm] makes it the main text font). No small caps / old-style figures in
# these fonts. NOTE: non-free (Adobe/Linotype license) — do NOT redistribute.
{
  callPackage,
  adobeFontFolio,
}:
callPackage ./otf-text-package.nix {} {
  pname = "optima";
  styName = "optimalt"; # same naming as palatinolt (psnfss owns palatino.sty)
  version = "2.0"; # Optima LT Std (Font Folio 11)
  description = "Optima LT Std (Adobe Font Folio) for pdfLaTeX (optimalt.sty, family optima)";
  family = "optima";
  desc = "Optima LT Std";
  fontDir = "${adobeFontFolio}/share/fonts/opentype";
  vendor = "adobe";
  defaultRole = "sf";
  weights = [
    {series = "m"; up = "OptimaLTStd"; it = "OptimaLTStd-Italic";}
    {series = "mb"; up = "OptimaLTStd-Medium"; it = "OptimaLTStd-MediumItalic";}
    {series = "db"; up = "OptimaLTStd-DemiBold"; it = "OptimaLTStd-DemiBoldItalic";}
    {series = "b"; up = "OptimaLTStd-Bold"; it = "OptimaLTStd-BoldItalic";}
    {series = "k"; up = "OptimaLTStd-Black"; it = "OptimaLTStd-BlackItalic";}
    {series = "ub"; up = "OptimaLTStd-ExtraBlack"; it = "OptimaLTStd-XBlackItalic";}
  ];
}
