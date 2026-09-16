#!/usr/bin/env bash
# GitHub Pages 배포본 조립 — `www/` 를 사이트 최상위로 두고, 옛 그림 주소에도 그림을 한 벌 둔다.
#
#   bash addons/gohud/tools/build_site.sh _site              # .github/workflows/pages.yml 이 부른다
#   bash addons/gohud/tools/build_site.sh /tmp/gohud-site && python3 -m http.server 8765 -d /tmp/gohud-site
#                                                             # 올라갈 모습 그대로 미리보기(옛 주소 포함)
#
# 🔑 왜 옛 자리에 그림을 두나
#   2026-09-15 전의 README(배포된 ZIP 1.0.2·1.0.3 포함)가 https://thruthesky.github.io/gohud/docs/www/img/… 를
#   절대 주소로 쓴다. 이미 설치된 애드온의 README 는 고칠 수 없다. 옛 페이지 주소는 404.html 이 새 주소로
#   넘기지만 <img> 요청은 스크립트를 실행하지 않으므로, 그림은 그 자리에 실제 파일로 있어야 한다.
#   저장소에는 한 벌만 두고 배포본에서만 복사한다 — 그림을 고치면 두 자리가 함께 바뀐다.
# 🛑 출력 폴더가 이미 있고 비어 있지 않으면 멈춘다 — 경로를 잘못 줘서 다른 폴더를 덮어쓰지 않게.
set -euo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?출력 폴더를 준다}"
if [ -d "$OUT" ] && [ -n "$(ls -A "$OUT")" ]; then
  echo "🛑 출력 폴더가 비어 있지 않다: $OUT" >&2
  exit 1
fi
mkdir -p "$OUT/docs/www"
cp -R "$ADDON/www/." "$OUT/"
cp -R "$ADDON/www/img" "$OUT/docs/www/img"

# 🔑 옛 문서 주소에는 **넘겨 주는 페이지를 실물로** 둔다.
#   404.html 의 스크립트도 같은 일을 하지만 그 응답의 상태 코드는 404 다 — 사람이 브라우저로 열 때만
#   넘어가고, 검색엔진·링크 검사기·채팅 미리보기에는 끝까지 "깨진 주소" 로 남는다. 여기 둔 파일은 200 이다.
#   옛 구조 두 벌을 모두 덮는다: `docs/www/…`(2026-09-15 직전)와 그 전의 `docs/…`.
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
echo "사이트 조립 $(find "$OUT" -type f | wc -l | tr -d ' ') 파일 → $OUT"
