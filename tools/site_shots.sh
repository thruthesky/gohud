#!/usr/bin/env bash
# 사이트(`www/`) 촬영 — 페이지마다 데스크톱·폰 폭으로 한 장씩 찍는다.
#
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots            # 6 페이지 × 2 폭 = 12 장
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots theming    # 이름에 theming 이 든 페이지만
#   SITE_DARK=1 bash addons/gohud/tools/site_shots.sh /tmp/site_shots  # 다크 팔레트로(이름에 _dark)
#
# 왜 있나: 갤러리·데모는 촬영 도구가 있는데 사이트는 헤드리스 크롬을 손으로 띄우고 거둬야 했다(I-75).
#   표 폭·풍선 밑줄·폰 폭에서의 가로 스크롤은 HTML 을 읽어서는 안 보인다.
#
# 🛑 크롬의 `--headless=new` 는 스크린샷을 저장한 뒤에도 **끝나지 않는다.** 그래서 `&` 로 띄우고 파일이
#    생기면 죽인다. macOS 에는 `timeout` 이 없다. 프로필 폴더는 촬영마다 새로 만든다(같은 폴더를 두 프로세스가
#    쓰면 "already running" 으로 죽는다).
set -u
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?출력 폴더를 준다}"
ONLY="${2:-}"
# 🌙 다크 — 헤드리스 크롬에 `prefers-color-scheme` 을 줄 수단이 없으니, 페이지 사본의 <head> 첫머리에
#    style.css 의 다크 `:root` 블록을 그대로 넣어 찍는다(원천은 style.css 하나). `<base>` 로 상대 경로를 원본
#    자리에 묶는다 — 🛑 <base> 는 <link> 보다 **앞**에 있어야 스타일시트에 적용된다.
DARK="${SITE_DARK:-}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  echo "🛑 크롬이 없다: $CHROME (CHROME=경로 로 준다)"; exit 1
fi
mkdir -p "$OUT"
PROFILES="$(mktemp -d)"
trap 'rm -rf "$PROFILES"' EXIT

# 페이지 폭·높이 — 높이는 긴 페이지가 다 들어가도록 넉넉히. 폰은 400dp(gohud 의 폰 세로 기준과 같다).
# 🛑 크롬은 창 폭을 **500 CSS px 아래로 안 줄인다** — `--window-size=400` 을 줘도 레이아웃은 500 으로 되고
#    그림만 400 으로 잘려, 본문 글자가 오른쪽에서 끊긴 그림이 나온다(2026-09-13 실측: innerWidth 500,
#    배율 2 를 줘도 같다). 그래서 폰은 페이지를 **폭 400 의 iframe 에 넣은 래퍼**를 찍는다 — iframe 안의
#    레이아웃 폭은 창 최소 폭과 무관하다(실측 400). 그림은 배율 2 라 800px 폭이고 오른쪽 여백은 회색이다.
SIZES="desktop:1100x9000:1 phone:400x14000:2"

shots=0; failed=0
for page in index theming widgets ko/index ko/theming ko/widgets; do
  [ -n "$ONLY" ] && [[ "$page" != *"$ONLY"* ]] && continue
  file="$ADDON/www/$page.html"
  [ -f "$file" ] || { echo "🛑 없음: $file"; failed=$((failed+1)); continue; }
  for spec in $SIZES; do
    tag="${spec%%:*}"; rest="${spec#*:}"; size="${rest%%:*}"; scale="${rest#*:}"
    name="$(echo "$page" | tr '/' '_')_$tag${DARK:+_dark}"
    png="$OUT/$name.png"
    rm -f "$png"
    url="file://$file"; window="$size"
    if [ -n "$DARK" ]; then
      copy="$PROFILES/$name.src.html"
      python3 - "$file" "$copy" "$ADDON/www/site/style.css" <<'PY' || { echo "🛑 다크 사본 실패: $name"; failed=$((failed+1)); continue; }
import re, sys
src, dst, css = sys.argv[1:4]
text = open(src, encoding="utf-8").read()
sheet = open(css, encoding="utf-8").read()
block = re.search(r"@media \(prefers-color-scheme: dark\) \{\s*(:root \{.*?\})", sheet, re.S)
if not block:
    sys.exit("style.css 에 다크 :root 블록이 없다")
inject = '<base href="file://%s"><style>%s</style>' % (src, block.group(1).replace(':root', ':root:root'))
out, n = re.subn(r"(<head[^>]*>)", r"\1" + inject.replace("\\", "\\\\"), text, count=1)
if n != 1:
    sys.exit("<head> 가 없다")
open(dst, "w", encoding="utf-8").write(out)
PY
      url="file://$copy"
    fi
    if [ "${size%%x*}" -lt 500 ]; then
      wrapper="$PROFILES/$name.html"
      printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#888}iframe{border:0;display:block}</style></head><body><iframe src="%s" width="%s" height="%s"></iframe></body></html>' \
        "$url" "${size%%x*}" "${size#*x}" > "$wrapper"
      url="file://$wrapper"; window="500x${size#*x}"
    fi
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
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
      echo "🛑 못 찍음: $name"; failed=$((failed+1))
    fi
  done
done
echo "사이트 촬영 $shots 장 · 실패 $failed → $OUT"
[ "$failed" -eq 0 ]
