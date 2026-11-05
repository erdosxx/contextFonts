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
    #   mtp2            TeX package: MathTime Pro II (complete)
    #   adobeFontFolio, triplexOtf  the two halves of contextFonts
    # Use the TeX packages like texlivePackages:
    #   pkgs.texliveSmall.withPackages (ps: [ps.latexmk mtp2])
    packages = forAllSystems (system: let
      pkgs = import ./nix/packages.nix (pkgsFor system);
    in
      pkgs // {default = pkgs.contextFonts;});

    # Overlay adding the packages to a consumer's nixpkgs (needs allowUnfree).
    overlays.default = final: prev: import ./nix/packages.nix final;
  };
}
