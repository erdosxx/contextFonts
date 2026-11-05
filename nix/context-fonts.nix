# context-fonts.nix — system fonts for ConTeXt / NixOS `fonts.packages`:
# Adobe Font Folio 11 + Emigre Triplex, all in $out/share/fonts/opentype.
{
  lib,
  symlinkJoin,
  sources,
  adobeFontFolio,
  triplexOtf,
}:
symlinkJoin {
  pname = "contextFonts";
  inherit (sources) version;
  paths = [adobeFontFolio triplexOtf];

  meta = {
    homepage = "https://github.com/erdosxx/contextFonts";
    description = "Fonts for ConTeXt: Adobe Font Folio 11 and Emigre Triplex";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
