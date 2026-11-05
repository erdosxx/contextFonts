# packages.nix — all packages of this repository for one nixpkgs instance.
#
# The TeX packages (mtp2) are TeX-Live-shaped derivations
# (outputSpecified/tlOutputName/fontMaps) meant to be passed to
# texlive.withPackages next to texlivePackages, e.g.
#   pkgs.texliveSmall.withPackages (ps: [ps.latexmk mtp2])
#
# NOTE: all fonts are non-free; `pkgs` must allow unfree packages.
pkgs: let
  inherit (pkgs) callPackage;
  sources = callPackage ./sources.nix {};
  adobeFontFolio = callPackage ./adobe-font-folio.nix {inherit sources;};
  triplexOtf = callPackage ./triplex-otf.nix {inherit sources;};
in {
  inherit adobeFontFolio triplexOtf;
  # System fonts (NixOS fonts.packages): Adobe Font Folio 11 + Emigre Triplex.
  contextFonts = callPackage ./context-fonts.nix {inherit sources adobeFontFolio triplexOtf;};
  # TeX Live packages.
  mtp2 = callPackage ./mtp2.nix {inherit sources;};
}
