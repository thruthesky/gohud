#!/bin/bash
# 🧪 gohud 의 **모든 검사**를 한 번에. 고친 뒤 이것 하나만 돌리면 된다.
#
#   bash addons/gohud/tools/check_all.sh
#   GOHUD_PROJECT=/path/to/project bash .../check_all.sh     # 검증용 프로젝트를 지정
#   GODOT_46=/path/to/Godot4.6 bash .../check_all.sh          # 두 엔진 모두에서 단위 검사
#
# 왜 묶는가
#   검사가 셋으로 나뉘어 있다 — 서로 **볼 수 있는 범위가 다르기 때문**이다.
#     ① 단위 검사(Godot)      위젯 동작 · 스킨이 실행 중에 만드는 색의 대비
#     ② 대비 검사(Python)     테마 .tres 의 색 짝과 버튼 상태별 판 위 글자
#     ③ 사이트 검사(Python)   www(루트 영문 · ko/ 한국어) 의 링크·그림·용어 사전
#   따로 기억해서 돌리면 반드시 하나를 빠뜨린다. 그래서 진입점을 하나로 둔다.
#
# 🛑 4.6 호환은 4.7 로 확인할 수 없다. `GODOT_46` 을 주면 **두 엔진 모두**에서 단위 검사를 돌린다.
set -uo pipefail

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

step() { printf "\n\033[1m── %s\033[0m\n" "$1"; }

step "① 단위 검사"
bash "$ADDON/tools/run_tests.sh" || FAILED=1

step "①-a 단위 검사 — 나중에 들인 위젯"
# 🔑 스낵바·스피너·배지·표처럼 뒤에 들인 것들은 파일을 나눠 두었다(`gohud_test.gd` 는 이미 2000줄이
#    넘는다). **진입점이 둘이면 하나를 잊는다** — 그래서 여기서 나란히 부른다.
GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_extra_test.gd" \
  bash "$ADDON/tools/run_tests.sh" || FAILED=1

step "①-t 단위 검사 — 스킬이 나눠 주는 템플릿 다섯"
# 🛑 `skills/gohud/assets/templates/` 는 사람이 **제 프로젝트로 복사해 그대로 쓰는 코드**인데,
#    2026-09-16 까지 그 다섯 장을 여는 검사가 하나도 없었다(문서에는 "headless-tested" 라고 적혀
#    있었다). 그 자리에 템플릿을 고치다 함수 이름을 겹쳐 놓았고, 이 검사가 그것을 바로 잡았다.
GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_templates_test.gd" \
  bash "$ADDON/tools/run_tests.sh" || FAILED=1

# 🛑 **화면 하나로만 돌리면 다른 화면에서만 도는 코드가 통째로 미검증이다.** 폼의 폭 제한이 그랬고
#    (폰에서는 상한이 "없음"), HUD 의 가로 자리 이동도 그랬다. 크기를 바꿔 같은 검사를 다시 돌린다.
for VIEWPORT in 844x390 768x1024 1280x800; do
  step "①-$VIEWPORT 단위 검사 — 다른 화면"
  GOHUD_VIEWPORT="$VIEWPORT" bash "$ADDON/tools/run_tests.sh" | tail -2 || FAILED=1
done

if [ -n "${GODOT_46:-}" ]; then
  if [ -x "$GODOT_46" ]; then
    step "①-b 단위 검사 — Godot 4.6"
    # 🛑 4.6 은 **자기 프로젝트 폴더**가 필요하다. `.godot` 캐시가 버전마다 다르기 때문이다.
    GODOT_BIN="$GODOT_46" GOHUD_PROJECT="${GOHUD_PROJECT_46:-${GOHUD_PROJECT:-}}" \
      bash "$ADDON/tools/run_tests.sh" || FAILED=1
  else
    echo "🛑 GODOT_46 이 실행 파일이 아니다 — $GODOT_46" >&2
    FAILED=1
  fi
fi

step "①-c 워크플로가 파싱되는가"
# 🛑 **CI 는 자기가 뜨지 못한 것을 알려 주지 못한다.** 워크플로 YAML 에 문법 오류가 있으면 잡이
#    아예 만들어지지 않아 `0s` 만에 failure 이고 로그도 남지 않는다 — 어느 검사가 실패했는지
#    알 길이 없어 사흘을 헤맸다(2026-09-16: `run:` 값을 따옴표로 시작한 한 줄 때문이었다).
#    그래서 **로컬에서** 먼저 파싱해 본다. PyYAML 이 없으면 조용히 건너뛴다(선택 의존).
if python3 -c "import yaml" 2>/dev/null; then
  for wf in "$ADDON"/.github/workflows/*.yml; do
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$wf" \
      || { echo "🛑 워크플로 YAML 오류: $wf" >&2; FAILED=1; }
  done
  echo "✅ 워크플로 $(ls "$ADDON"/.github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ')개 파싱"
else
  echo "⏭ PyYAML 이 없어 건너뛴다 (pip install pyyaml)"
fi

step "② 테마 대비"
python3 "$ADDON/tools/check_contrast.py" --quiet || FAILED=1

step "③ 홈페이지"
python3 "$ADDON/tools/check_site.py" || FAILED=1

step "③-a 문서가 가리키는 gohud API 가 실재하는가"
# 🛑 글은 검사가 없으면 아무도 안 본다 — 2026-09-16 에 새 위젯을 문서에 적으면서 **코드를 열지 않고
#    기억으로 쓴 호출이 아홉 군데 틀렸고**, 그중 둘은 베껴 쓰면 파싱 오류가 나는 코드였다.
python3 "$ADDON/tools/check_docs_api.py" || FAILED=1

step "④ 테마 생성물이 소스와 맞는가"
# 🛑 팔레트를 고치고 `make_theme.py` 를 안 돌리면 `.tres` 가 낡은 채로 남는다 — 눈에 안 띈다.
python3 "$ADDON/tools/check_generated.py" || FAILED=1

step "④-c 테마 스캐폴딩"
# 🛑 "테마를 더 들인다" 는 약속 — 파일 하나로 테마가 생기고 대비 검사를 통과하는지. 빠르니 늘 돌린다.
bash "$ADDON/tools/check_scaffold.sh" || FAILED=1

step "⑤ 패키징 버전 갱신 — 임시 사본에서 검사"
python3 "$ADDON/tools/check_package.py" || FAILED=1

# 🛑 **검사가 무엇을 잡는지**는 검사 개수로 알 수 없다. 느리므로(변이마다 전체 검사) 기본은 끄고,
#    검사를 더하거나 위젯 로직을 손댄 반복에서 켠다.
if [ -n "${GOHUD_CHECK_MUTATIONS:-}" ]; then
  step "④-b 검사의 포착력(변이)"
  GOHUD_PROJECT="${GOHUD_PROJECT:-}" bash "$ADDON/tools/check_mutations.sh" | tail -4 \
    || FAILED=1
fi

# 📸 데모 촬영은 느리고(30장) 창이 필요하니 기본은 끈다. 위젯 모양을 바꾼 반복에서 켜서 **눈으로 본다**.
if [ -n "${GOHUD_CHECK_DEMO_SHOTS:-}" ]; then
  step "④-d 데모 촬영"
  bash "$ADDON/tools/demo_shots.sh" "${GOHUD_DEMO_SHOTS_DIR:-/tmp/gohud_demo_shots}" 2>&1 | tail -1 || FAILED=1
fi

# 📸 사이트 촬영 — 표 폭·풍선·폰 폭의 가로 스크롤은 HTML 을 읽어서는 안 보인다. 사이트를 손댄 반복에서 켠다.
if [ -n "${GOHUD_CHECK_SITE_SHOTS:-}" ]; then
  step "④-e 사이트 촬영"
  bash "$ADDON/tools/site_shots.sh" "${GOHUD_SITE_SHOTS_DIR:-/tmp/gohud_site_shots}" 2>&1 | tail -1 || FAILED=1
fi

# 패키징 검사는 위에서 항상 실행한다. 예전 GOHUD_CHECK_PACKAGE 설정은 더 이상 필요 없다.

printf "\n"
if [ "$FAILED" -eq 0 ]; then echo "✅ 전부 통과"; else echo "🛑 실패한 검사가 있다"; fi
exit "$FAILED"
