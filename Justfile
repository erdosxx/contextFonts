# Test documents for the TeX packages of this flake. Run inside `nix develop`
# (devShells.default provides pdflatex/latexmk with minmath, triplex, mtp2,
# optima, palatino, trajan, minion and myriad, plus pdffonts). PDFs go to
# tests/out/.

set shell := ["bash", "-euo", "pipefail", "-c"]

outdir := "tests/out"

default:
    @just --list

# Build all test PDFs: tests/out/<name>.pdf for every recipe below
testdocs: minmath triplex mtp2 optima palatino trajan minion myriad

# Build tests/<name>.tex; fail unless every font pattern is embedded, no
# bitmap (Type 3) font was used and no glyph was reported missing.
_doc name +fonts:
    latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir={{outdir}} tests/{{name}}.tex
    pdffonts {{outdir}}/{{name}}.pdf
    for f in {{fonts}}; do pdffonts {{outdir}}/{{name}}.pdf | grep -q -- "$f" || { echo "font $f not embedded" >&2; exit 1; }; done
    ! pdffonts {{outdir}}/{{name}}.pdf | grep 'Type 3'
    ! grep -a -H 'Missing character' {{outdir}}/{{name}}.log

# Minion Pro text + Minion Math (minmath)
minmath: (_doc "minmath" "MinionMath-" "MinionPro-")

# Triplex Sans/Serif (triplex) with minmath
triplex: (_doc "triplex" "Triplex-" "TriplexItalic-" "TriplexSerif-" "MinionMath-")

# MathTime Pro II complete (mtp2)
mtp2: (_doc "mtp2" "MT2")

# Optima LT Std (optima, \usepackage{optimalt})
optima: (_doc "optima" "OptimaLTStd-Black" "OptimaLTStd-ExtraBlack" "OptimaLTStd-XBlackItalic" "OptimaLTStd-Italic")

# Palatino LT Std (palatino, \usepackage{palatinolt})
palatino: (_doc "palatino" "PalatinoLTStd-Light" "PalatinoLTStd-Roman" "PalatinoLTStd-BlackItalic")

# Trajan Pro (trajan, \usepackage{trajan})
trajan: (_doc "trajan" "TrajanPro-Regular" "TrajanPro-Bold")

# Minion Pro (minion, \usepackage{minion}): weights, condensed, optical sizes
minion: (_doc "minion" "MinionPro-Capt" "MinionPro-Regular" "MinionPro-Disp" "MinionPro-BoldCnIt" "MyriadPro-Regular")

# Myriad Pro (myriad, \usepackage{myriad}): weights x widths
myriad: (_doc "myriad" "MyriadPro-Light" "MyriadPro-BlackSemiExtIt" "MyriadPro-BoldCond" "MyriadPro-SemiCn")

clean:
    rm -rf {{outdir}}
