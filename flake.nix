{
  description = "Non-free fonts for ConTeXt/NixOS and TeX Live packages built from them";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    # The fonts are unfree; allow them for the packages built by this flake.
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    # packages.<system>:
    #   contextFonts    Adobe Font Folio 11 + Emigre Triplex OTFs in
    #                   share/fonts/opentype (NixOS: fonts.packages)
    #   minmath         TeX package: typoma Minion Math + Minion Pro text
    #   triplex         TeX package: Emigre Triplex Sans/Serif
    #   mtp2            TeX package: MathTime Pro II (complete)
    #   adobeFontFolio, triplexOtf  the two halves of contextFonts
    # Use the TeX packages like texlivePackages:
    #   pkgs.texliveSmall.withPackages (ps: [ps.latexmk minmath triplex mtp2])
    packages = forAllSystems (system: let
      pkgs = import ./nix/packages.nix (pkgsFor system);
    in
      pkgs // {default = pkgs.contextFonts;});

    # devShells.<system>.default: TeX Live with minmath, triplex and mtp2 for
    # the test documents in tests/ (`just testdocs`).
    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
      cf = self.packages.${system};
      texlive = pkgs.texliveSmall.withPackages (ps: [
        ps.latexmk
        ps.geometry
        cf.minmath
        cf.triplex
        cf.mtp2
      ]);
    in {
      default = pkgs.mkShell {
        packages = [texlive pkgs.just pkgs.poppler-utils];
      };
    });

    # Overlay adding the packages to a consumer's nixpkgs (needs allowUnfree).
    overlays.default = final: prev: import ./nix/packages.nix final;
  };
}
