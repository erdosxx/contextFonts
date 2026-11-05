# triplex-otf.nix — Emigre Triplex OTFs in $out/share/fonts/opentype.
{
  lib,
  stdenvNoCC,
  unzip,
  sources,
}:
stdenvNoCC.mkDerivation {
  pname = "triplex-otf";
  version = "2007";

  src = sources.triplex;
  nativeBuildInputs = [unzip];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    unzip -q "$src" -d "$TMPDIR/triplex"
    mkdir -p "$out/share/fonts/opentype"
    find "$TMPDIR/triplex" -name '*.otf' -exec install -m644 -t "$out/share/fonts/opentype" {} +
    runHook postInstall
  '';

  meta = {
    homepage = "https://www.emigre.com/Fonts/Triplex";
    description = "Emigre Triplex Sans, Serif and Italic OpenType fonts";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
