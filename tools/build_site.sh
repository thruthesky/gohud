#!/usr/bin/env bash
# Assemble the GitHub Pages build — `www/` becomes the site root, and a copy of the images is also left at the old image addresses.
#
#   bash addons/gohud/tools/build_site.sh _site              # called by .github/workflows/pages.yml
#   bash addons/gohud/tools/build_site.sh /tmp/gohud-site && python3 -m http.server 8765 -d /tmp/gohud-site
#                                                             # preview exactly what goes up (old addresses included)
#
# 🔑 Why images are left at the old place
#   READMEs from before 2026-09-15 (including the released ZIPs 1.0.2 and 1.0.3) use
#   https://thruthesky.github.io/gohud/docs/www/img/… as an absolute address. The README of an already
#   installed addon cannot be fixed. 404.html forwards old page addresses to the new ones, but an <img>
#   request runs no script, so the images must be real files at that place. The repository keeps one copy
#   and only the build duplicates it — fixing an image changes both places at once.
# 🛑 Stop if the output folder exists and is not empty — so a mistyped path never overwrites another folder.
set -euo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?give an output folder}"
if [ -d "$OUT" ] && [ -n "$(ls -A "$OUT")" ]; then
  echo "🛑 the output folder is not empty: $OUT" >&2
  exit 1
fi
mkdir -p "$OUT/docs/www"
cp -R "$ADDON/www/." "$OUT/"
cp -R "$ADDON/www/img" "$OUT/docs/www/img"

# 🔑 At the old document addresses, leave **a real forwarding page**.
#   The script in 404.html does the same job, but that response carries status 404 — it forwards only when
#   a person opens it in a browser, and stays a "broken address" for search engines, link checkers and chat
#   previews. The files left here answer 200.
#   Both old structures are covered: `docs/www/…` (just before 2026-09-15) and the earlier `docs/…`.
for page in index.html theming.html widgets.html ko/index.html ko/theming.html ko/widgets.html; do
  for old in docs/www docs; do
    rel="$old/$page"
    up="$(dirname "$rel" | awk -F/ '{for (i = 1; i <= NF; i++) printf "../"}')"
    target="$up$page"
    mkdir -p "$OUT/$(dirname "$rel")"
    cat > "$OUT/$rel" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>gohud — this page moved</title>
<link rel="canonical" href="$target">
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=$target">
<script>location.replace("$target" + location.search + location.hash);</script>
</head>
<body>
<p>This page moved. <a href="$target">Open it at its new address →</a></p>
</body>
</html>
HTML
  done
done
echo "site assembled: $(find "$OUT" -type f | wc -l | tr -d ' ') files → $OUT"
