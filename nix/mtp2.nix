# mtp2.nix — MathTime Pro II (complete) as a TeX Live package ("mtp2").
#
# $out is the top of a TEXMFDIST tree and carries the TeX-Live-package
# attributes (outputSpecified/tlOutputName/fontMaps, the shape nixpkgs'
# texlivePackages.<name> have), so texlive.withPackages merges it like any
# tlpdb package and enables mtpro2.map in updmap.cfg.
#
# The full set is a superset of CTAN's mtp2lite (same mtpro2.sty/mtpro2.map
# names): use either mtp2 or mtp2lite in a TeX Live env, not both.
#
# NOTE: non-free, licensed per user (EULA-MTPro2.txt) — do NOT redistribute.
{
  lib,
  stdenvNoCC,
  unzip,
  sources,
}:
stdenvNoCC.mkDerivation {
  pname = "mtp2";
  version = "2.1a"; # mtpro2.sty v2.3, 2009/4/27

  src = sources.mtp2;
  nativeBuildInputs = [unzip];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    unzip -q "$src" -d "$TMPDIR/mtp2"
    # Archive root holds texmf/ (+ templates/, EULA). Merge texmf/ subtrees;
    # doc/ is skipped (PDF manuals only).
    for d in tex fonts dvips source tpm; do
      cp -r "$TMPDIR/mtp2/texmf/$d" "$out/"
    done
    runHook postInstall
  '';

  meta = {
    description = "MathTime Pro II (complete) math fonts: mtpro2.sty, TFM/Type1 fonts and dvips map";
    license = lib.licenses.unfree; # EULA-MTPro2.txt, per-user license
    platforms = lib.platforms.all;
  };
}
// {
  outputSpecified = true;
  tlOutputName = "tex";
  fontMaps = ["Map mtpro2.map"];
}
