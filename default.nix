{ lib, stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation rec {
  pname = "contextFonts";
  version = "0.1";

  src = fetchzip {
    url = "https://github.com/erdosxx/${pname}/releases/download/${version}/Adobe_Font_Folio_11.zip";
    sha256 = "sha256-vUfzTXZ9+GtxvotRe3l4LzVH72vUmEKrss1kdKtKRys=";
    stripRoot = true;
  };

  installPhase = ''
    runHook preInstall

    find . -name "*.otf" -exec cp {} . \;
    install -Dm644 *.otf -t $out/share/fonts/opentype

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://helpx.adobe.com/fonts/kb/font-folio-end-of-sale.html";
    description = "Fonts for ConTeXt including Adobe Font Folio";
    license = licenses.ofl;
    platforms = platforms.all;
    maintainers = [ maintainers.rycee ];
  };
}
