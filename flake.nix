{
  description = "Install required fonts for ConTeXt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          contextFonts = pkgs.stdenv.mkDerivation rec {
            pname = "contextFonts";
            version = "0.1";

            src = pkgs.fetchzip {
              url = "https://github.com/erdosxx/${pname}/releases/download/${version}/Adobe_Font_Folio_11.zip";
              sha256 = "sha256-vUfzTXZ9+GtxvotRe3l4LzVH72vUmEKrss1kdKtKRys=";
              # headers = [ "Authorization: token ${builtins.getEnv "GITHUB_TOKEN"}" ];
            };

            installPhase = ''
              runHook preInstall

              find . -name "*.otf" -exec cp {} . \;
              install -Dm644 *.otf -t $out/share/fonts/opentype

              runHook postInstall
            '';
          };
        });
    };
}
