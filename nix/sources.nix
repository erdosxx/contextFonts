# sources.nix — release assets of github:erdosxx/contextFonts (tag 0.2).
#
# All font archives are fetched from the GitHub release instead of being kept
# in a consumer project. NOTE: the fonts are non-free (Adobe, typoma, Emigre,
# PCTeX licenses) — do NOT redistribute the build outputs.
{fetchurl}: let
  version = "0.2";
  asset = name: hash:
    fetchurl {
      url = "https://github.com/erdosxx/contextFonts/releases/download/${version}/${name}";
      inherit hash;
    };
in {
  inherit version;
  # Adobe Font Folio 11 OTFs (Minion Pro, Myriad Pro, ...).
  adobeFontFolio = asset "Adobe_Font_Folio_11.zip" "sha256-xw5LN6cAvleQ0YwSupHVyH4kUi8Zo7QWJtEntbTE9hM=";
  # typoma LaTeX support bundle for Minion Math (sty, fd, TFM/VF, enc, maps).
  minionMathTeX = asset "MinionMath-TeXLocal-current.zip" "sha256-ExQSFmw0SooHFIZSdsJTkC2ViCxEG3xOTx7nK+JGuAI=";
  # typoma Minion Math OTFs (MinionMath/MinionMath/MinionMath-*.otf).
  minionMathOtf = asset "MinionMath_1_021.zip" "sha256-cUSRHlLr3wtTK/v8gNh3FPJ9MgQt3BM9ocKXhyOgDbs=";
  # MathTime Pro II (complete), texmf/ tree.
  mtp2 = asset "mtp2fonts.zip" "sha256-Q9m5jyAVch+5NFSfBKtiPeVvJvhI0r2vgaCIcb0iAeY=";
  # Emigre Triplex Sans / Serif / Italic OTFs (flat archive).
  triplex = asset "Triplex.zip" "sha256-HL/l9io+rxhvv1RUL2siRH5Osbt0pEJX1d1uhvejkBs=";
}
