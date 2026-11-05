# adobe-font-folio.nix — Adobe Font Folio 11 OTFs in $out/share/fonts/opentype
# (flat directory: minmath.nix looks fonts up as <dir>/<PostScript name>.otf).
{
  lib,
  stdenvNoCC,
  unzip,
  sources,
}:
stdenvNoCC.mkDerivation {
  pname = "adobe-font-folio";
  version = "11";

  src = sources.adobeFontFolio;
  nativeBuildInputs = [unzip];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    unzip -q "$src" -d "$TMPDIR/aff"
    mkdir -p "$out/share/fonts/opentype"
    find "$TMPDIR/aff" -name '*.otf' -exec install -m644 -t "$out/share/fonts/opentype" {} +
    runHook postInstall
  '';

  meta = {
    homepage = "https://helpx.adobe.com/fonts/kb/font-folio-end-of-sale.html";
    description = "Adobe Font Folio 11 OpenType fonts";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
