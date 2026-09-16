#!/usr/bin/env bash
# Site (`www/`) screenshots — one shot per page at desktop and phone width.
#
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots            # 6 pages x 2 widths = 12 shots
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots theming    # only pages with theming in the name
#   SITE_DARK=1 bash addons/gohud/tools/site_shots.sh /tmp/site_shots  # in the dark palette (_dark in the name)
#   SITE_SEARCH=sheet bash addons/gohud/tools/site_shots.sh /tmp/site_shots index  # with the search palette open on that word (_search)
#
# Why it exists: the gallery and demo have screenshot tools, while the site needed headless Chrome raised and reaped by hand (I-75).
#   Table widths, tooltip underlines and horizontal scrolling at phone width cannot be seen by reading HTML.
#
# 🛑 Chrome's `--headless=new` **does not exit** even after saving the screenshot. So it is started with
#    `&` and killed once the file appears. macOS has no `timeout`. The profile folder is created fresh per
#    shot (two processes sharing one folder die with "already running").
set -u
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?give an output folder}"
ONLY="${2:-}"
# 🌙 Dark — there is no way to give headless Chrome a `prefers-color-scheme`, so the dark `:root` block of
#    style.css is injected verbatim at the top of a copy's <head> (style.css stays the single source). A
#    `<base>` pins relative paths to the original location — 🛑 <base> must come **before** <link> or it does not apply to the stylesheet.
DARK="${SITE_DARK:-}"
# 🔍 Shoot with the search palette open — the index arrives late via `<script>`, so Chrome is given virtual time.
#    Without this the search feature ships **with nobody having looked at it** (it appears in no screenshot).
SEARCH="${SITE_SEARCH:-}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  echo "🛑 no Chrome at: $CHROME (pass CHROME=path)"; exit 1
fi
mkdir -p "$OUT"
PROFILES="$(mktemp -d)"
trap 'rm -rf "$PROFILES"' EXIT

# Page width and height — the height is generous so a long page fits. Phone is 400dp (the same as gohud's phone-portrait baseline).
# 🛑 Chrome **will not go below 500 CSS px** of window width — even with `--window-size=400` the layout is
#    laid out at 500 and only the image is cropped to 400, giving a picture with body text cut off on the
#    right (measured 2026-09-13: innerWidth 500, the same at scale 2). So the phone shot photographs a
#    **wrapper holding the page in a 400-wide iframe** — the layout width inside an iframe is unrelated
#    to the window minimum (measured 400). At scale 2 the image is 800px wide and the right margin is gray.
SIZES="desktop:1100x9000:1 phone:400x14000:2"
# 🛑 The search palette sits 10% down the window height — shooting at height 9000 to fit the whole page puts
#    it 900px down and yields a picture where it "is not there" (measured 2026-09-16). Search is shot at the **real window size**.
[ -n "$SEARCH" ] && SIZES="desktop:1100x900:1 phone:400x860:2"

shots=0; failed=0
# 🛑 Keep Arabic in the list — a right-to-left layout gone wrong cannot be caught without looking
#    (the contents, the search box and the code blocks all flip direction).
# 🔑 Since there are five pages, the new ones (install, ai) are shot too — otherwise those two are never
#    seen by eye. Korean gets all of them; Arabic is sampled only for the right-to-left layout.
# 🛑 Do not keep the list here by hand — the 2026-09-16 split took the pages from 5 to 19 while the
#    hand-kept list stayed put, leaving **fourteen newly split pages never once seen by eye**.
#    The single source is `PAGES` in `tools/site_langs.py`.
ALL_PAGES="$(python3 -c "
import sys; sys.path.insert(0, '$ADDON/tools')
import site_langs
print(' '.join(page[:-5] for page in site_langs.PAGES))
")"
for page in $ALL_PAGES \
           $(for p in $ALL_PAGES; do echo "ko/$p"; done) \
           ar/index ar/ai ar/widgets ar/widgets-forms ar/theming ar/theming-tokens; do
  [ -n "$ONLY" ] && [[ "$page" != *"$ONLY"* ]] && continue
  file="$ADDON/www/$page.html"
  [ -f "$file" ] || { echo "🛑 missing: $file"; failed=$((failed+1)); continue; }
  for spec in $SIZES; do
    tag="${spec%%:*}"; rest="${spec#*:}"; size="${rest%%:*}"; scale="${rest#*:}"
    name="$(echo "$page" | tr '/' '_')_$tag${DARK:+_dark}${SEARCH:+_search}"
    png="$OUT/$name.png"
    rm -f "$png"
    url="file://$file"; window="$size"; extra=""
    if [ -n "$DARK" ] || [ -n "$SEARCH" ]; then
      copy="$PROFILES/$name.src.html"
      python3 - "$file" "$copy" "$ADDON/www/site/style.css" "$DARK" "$SEARCH" <<'PY' || { echo "🛑 could not make the copy: $name"; failed=$((failed+1)); continue; }
import re, sys
src, dst, css, dark, search = sys.argv[1:6]
text = open(src, encoding="utf-8").read()
# 🛑 <base> must come **before** <link> so stylesheets and scripts resolve at the original location.
inject = '<base href="file://%s">' % src
if dark:
    sheet = open(css, encoding="utf-8").read()
    # 🛑 Strip comments first — the preamble of style.css **spells this block out as an example**, and the
    #    regex bit on that comment first and pulled out an empty `:root { … }` shell (2026-09-16).
    sheet = re.sub(r"/\*.*?\*/", "", sheet, flags=re.S)
    block = re.search(r"@media \(prefers-color-scheme: dark\) \{\s*(:root \{.*?\})", sheet, re.S)
    if not block:
        sys.exit("style.css has no dark :root block")
    inject += '<style>%s</style>' % block.group(1).replace(':root', ':root:root')
out, n = re.subn(r"(<head[^>]*>)", r"\1" + inject.replace("\\", "\\\\"), text, count=1)
if n != 1:
    sys.exit("there is no <head>")
if search:
    # Once the page has loaded, open the search palette on that word — `site/search.js` leaves the key on the global object.
    word = re.sub(r"[^\w \uAC00-\uD7A3\u3040-\u30FF\u4E00-\u9FFF-]", "", search)
    auto = ("<script>window.addEventListener('load',function(){setTimeout(function(){"
            "if(window.GOHUD_SEARCH_OPEN)window.GOHUD_SEARCH_OPEN('%s');},50);});</script>" % word)
    out = out.replace("</body>", auto + "</body>", 1)
open(dst, "w", encoding="utf-8").write(out)
PY
      url="file://$copy"
      [ -n "$SEARCH" ] && extra="--virtual-time-budget=9000"
    fi
    if [ "${size%%x*}" -lt 500 ]; then
      wrapper="$PROFILES/$name.html"
      printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#888}iframe{border:0;display:block}</style></head><body><iframe src="%s" width="%s" height="%s"></iframe></body></html>' \
        "$url" "${size%%x*}" "${size#*x}" > "$wrapper"
      url="file://$wrapper"; window="500x${size#*x}"
    fi
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars $extra \
      --user-data-dir="$PROFILES/$name" --window-size="${window/x/,}" --force-device-scale-factor="$scale" \
      --screenshot="$png" "$url" >/dev/null 2>&1 &
    pid=$!
    for _ in $(seq 1 80); do
      [ -s "$png" ] && break
      sleep 0.25
    done
    kill "$pid" >/dev/null 2>&1; wait "$pid" 2>/dev/null
    if [ -s "$png" ]; then
      echo "SHOT $png"; shots=$((shots+1))
    else
      echo "🛑 could not shoot: $name"; failed=$((failed+1))
    fi
  done
done
echo "site screenshots: $shots taken · $failed failed → $OUT"
[ "$failed" -eq 0 ]
