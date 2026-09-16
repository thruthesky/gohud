#!/usr/bin/env bash
# 사이트(`www/`) 촬영 — 페이지마다 데스크톱·폰 폭으로 한 장씩 찍는다.
#
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots            # 6 페이지 × 2 폭 = 12 장
#   bash addons/gohud/tools/site_shots.sh /tmp/site_shots theming    # 이름에 theming 이 든 페이지만
#   SITE_DARK=1 bash addons/gohud/tools/site_shots.sh /tmp/site_shots  # 다크 팔레트로(이름에 _dark)
#   SITE_SEARCH=sheet bash addons/gohud/tools/site_shots.sh /tmp/site_shots index  # 그 말로 검색창을 연 채(_search)
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
# 🔍 검색 팔레트를 연 채로 찍는다 — 색인은 `<script>` 로 늦게 받으므로 크롬에 가상 시간을 준다.
#    이렇게 하지 않으면 검색 기능은 **아무도 보지 않은 채** 배포된다(스크린샷에 나오지 않으니까).
SEARCH="${SITE_SEARCH:-}"
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
# 🛑 검색 팔레트는 창 높이의 10% 아래에 뜬다 — 페이지 전체를 담으려고 높이 9000 으로 찍으면 팔레트가
#    900px 아래에 있어 "안 보인다" 는 그림이 나온다(2026-09-16 실측). 검색은 **실제 창 크기**로 찍는다.
[ -n "$SEARCH" ] && SIZES="desktop:1100x900:1 phone:400x860:2"

shots=0; failed=0
# 🛑 아랍어를 목록에 둔다 — 오른쪽에서 왼쪽으로 흐르는 판은 눈으로 보지 않으면 어긋난 것을 못 잡는다
#    (목차·검색창·코드 칸이 모두 방향을 뒤집는다).
# 🔑 쪽이 다섯이 된 뒤로는 새 쪽(install·ai)도 찍는다 — 안 찍으면 그 두 장은 눈으로 한 번도
#    확인되지 않는다. 한국어는 전부, 아랍어는 오른쪽에서 왼쪽으로 흐르는 판만 표본으로.
for page in index install ai theming widgets \
           ko/index ko/install ko/ai ko/theming ko/widgets \
           ar/index ar/ai ar/theming; do
  [ -n "$ONLY" ] && [[ "$page" != *"$ONLY"* ]] && continue
  file="$ADDON/www/$page.html"
  [ -f "$file" ] || { echo "🛑 없음: $file"; failed=$((failed+1)); continue; }
  for spec in $SIZES; do
    tag="${spec%%:*}"; rest="${spec#*:}"; size="${rest%%:*}"; scale="${rest#*:}"
    name="$(echo "$page" | tr '/' '_')_$tag${DARK:+_dark}${SEARCH:+_search}"
    png="$OUT/$name.png"
    rm -f "$png"
    url="file://$file"; window="$size"; extra=""
    if [ -n "$DARK" ] || [ -n "$SEARCH" ]; then
      copy="$PROFILES/$name.src.html"
      python3 - "$file" "$copy" "$ADDON/www/site/style.css" "$DARK" "$SEARCH" <<'PY' || { echo "🛑 사본 실패: $name"; failed=$((failed+1)); continue; }
import re, sys
src, dst, css, dark, search = sys.argv[1:6]
text = open(src, encoding="utf-8").read()
# 🛑 <base> 는 <link> 보다 **앞**이어야 스타일시트·스크립트가 원본 자리에서 풀린다.
inject = '<base href="file://%s">' % src
if dark:
    sheet = open(css, encoding="utf-8").read()
    # 🛑 주석을 먼저 지운다 — style.css 의 머리말이 이 블록의 **모양을 예시로 적어** 두었더니
    #    정규식이 그 주석을 먼저 물어 `:root { … }` 라는 빈 껍데기를 뽑았다(2026-09-16).
    sheet = re.sub(r"/\*.*?\*/", "", sheet, flags=re.S)
    block = re.search(r"@media \(prefers-color-scheme: dark\) \{\s*(:root \{.*?\})", sheet, re.S)
    if not block:
        sys.exit("style.css 에 다크 :root 블록이 없다")
    inject += '<style>%s</style>' % block.group(1).replace(':root', ':root:root')
out, n = re.subn(r"(<head[^>]*>)", r"\1" + inject.replace("\\", "\\\\"), text, count=1)
if n != 1:
    sys.exit("<head> 가 없다")
if search:
    # 페이지가 다 뜬 뒤 그 말로 검색 팔레트를 연다 — `site/search.js` 가 전역에 열쇠를 둔다.
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
      echo "🛑 못 찍음: $name"; failed=$((failed+1))
    fi
  done
done
echo "사이트 촬영 $shots 장 · 실패 $failed → $OUT"
[ "$failed" -eq 0 ]
