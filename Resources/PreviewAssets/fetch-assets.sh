#!/usr/bin/env bash
# Fetch the vendored preview JS/CSS engines that are not committed (see VERSIONS.md).
# Run once on a machine with network access. Safe to re-run (overwrites).
set -euo pipefail
cd "$(dirname "$0")"

HLJS=11.9.0
KATEX=0.16.9
MERMAID=10.9.0

echo "Fetching highlight.js ${HLJS}…"
curl -fsSL "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/${HLJS}/highlight.min.js" \
  -o highlight/highlight.min.js

echo "Fetching KaTeX ${KATEX}…"
curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${KATEX}/dist/katex.min.js" -o katex/katex.min.js
curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${KATEX}/dist/katex.min.css" -o katex/katex.min.css

echo "Fetching KaTeX fonts…"
FONTS=$(curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${KATEX}/dist/katex.min.css" \
  | grep -oE 'fonts/[A-Za-z0-9_.-]+\.(woff2|woff|ttf)' | sort -u)
for f in $FONTS; do
  curl -fsSL "https://cdn.jsdelivr.net/npm/katex@${KATEX}/dist/${f}" -o "katex/${f}"
done

echo "Fetching Mermaid ${MERMAID}…"
curl -fsSL "https://cdn.jsdelivr.net/npm/mermaid@${MERMAID}/dist/mermaid.min.js" \
  -o mermaid/mermaid.min.js

echo "Done. Assets written under $(pwd)."
