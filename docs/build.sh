#!/usr/bin/env bash
set -eo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../common.sh"

MODE=single
ROOT="$PWD"
OUT=""
ENFORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)     MODE=all ;;
    --root)    ROOT="$(cd "$2" && pwd)"; shift ;;
    --out)     OUT="$2"; shift ;;
    --enforce) ENFORCE=1 ;;
    *) fail "Unknown argument: $1" ;;
  esac
  shift
done
OUT="${OUT:-$ROOT/build/docs}"
command -v doxygen >/dev/null || fail "doxygen not installed (brew install doxygen / apt install doxygen)"

CONFS=()
if [ "$MODE" = all ]; then
  while IFS= read -r line; do CONFS+=("$line"); done < <(find "$ROOT" -path '*/docs/docs.conf' -not -path '*/build/*' | sort)
else
  CONFS=("$ROOT/docs/docs.conf")
fi
[ -f "${CONFS[0]}" ] || fail "No docs/docs.conf found under $ROOT"

INPUT=""
for c in "${CONFS[@]}"; do
  repo="$(cd "$(dirname "$c")/.." && pwd)"
  unset DOCS_NAME DOCS_INPUT DOCS_VERSION
  source "$c"
  for p in $DOCS_INPUT; do INPUT="$INPUT \"$repo/$p\""; done
done
unset DOCS_NAME DOCS_VERSION
source "$ROOT/docs/docs.conf"

mkdir -p "$OUT"
doxygen -w html "$OUT/header.html" "$OUT/.footer.html" "$OUT/.style.css" >/dev/null
awk -v snip="$HERE/theme/head-snippet.html" '/<\/head>/ { while ((getline l < snip) > 0) print l } { print }' "$OUT/header.html" > "$OUT/header.tmp"
mv "$OUT/header.tmp" "$OUT/header.html"

{
  echo "@INCLUDE = $HERE/Doxyfile.base"
  echo "PROJECT_NAME = \"$DOCS_NAME\""
  echo "PROJECT_NUMBER = \"${DOCS_VERSION:-}\""
  echo "OUTPUT_DIRECTORY = $OUT"
  echo "INPUT = $INPUT"
  echo "STRIP_FROM_PATH = $ROOT"
  echo "HTML_HEADER = $OUT/header.html"
  echo "HTML_EXTRA_STYLESHEET = $HERE/theme/doxygen-awesome.css"
  echo "HTML_EXTRA_FILES = $HERE/theme/doxygen-awesome-darkmode-toggle.js $HERE/theme/doxygen-awesome-paragraph-link.js $HERE/theme/doxygen-awesome-interactive-toc.js"
  if [ -f "$ROOT/README.md" ]; then echo "USE_MDFILE_AS_MAINPAGE = $ROOT/README.md"; fi
  if [ "$ENFORCE" = 1 ]; then echo "WARNINGS = YES"; echo "WARN_AS_ERROR = YES"; fi
} > "$OUT/Doxyfile"

doxygen "$OUT/Doxyfile"
success "Docs built: $OUT/html/index.html"
