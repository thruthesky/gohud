# gohud — Godot 4 커스터마이징 HUD·UI 키트

영문판은 [README.md](README.md) 다. 이 문서는 같은 내용의 한국어 설명서다.

떠 있는 창, 바텀 시트, 확인창, 폼, 스낵바, 안내 카드, 코치마크, HUD 막대, 퀵슬롯, 가상 조이스틱을
**테마 한 장과 교체 가능한 아이콘 세트 한 장**으로 굴린다. 안전영역·가상 키보드·RTL 언어·터치를
스스로 챙긴다.

> 넣으면 그냥 동작한다. 에디터 플러그인을 켜는 것은 편의 기능일 뿐이다.

- **아이콘을 갈아 끼워도 코드는 그대로.** 위젯은 아이콘을 이름으로 부른다(`GoIconSet.CLOSE`).
  `GoConfig.icons` 를 내 SVG 세트나 아이콘 폰트로 바꾸면 모든 위젯이 따라온다 — 몇 개만 바꿔도 된다.
- **설정은 리소스 한 장.** 테마·아이콘·크기·브레이크포인트·표면 동작·햅틱·소리·문구가 전부
  `GoConfig` 하나에 있고, 애드온을 업데이트해도 살아남는다.
- **모바일 우선, 데스크톱도.** 작게 보이는 버튼 뒤에 48dp 터치 영역, 안전영역과 키보드 회피,
  가로·세로 배치, Android 뒤로 가기, 키보드 사용자에게만 보이는 포커스 링.
- **요즘 엔진 기능을 쓴다.** `DPITexture` 아이콘은 UI 배율을 키워도 선명하고,
  `FoldableContainer` 접이식 섹션, 화면 낭독기를 위한 `accessibility_name`,
  알림이 입력을 먹지 않게 하는 `mouse_behavior_recursive`, 흐르는 줄의 `last_wrap_alignment`.
- **순수 GDScript.** 오토로드 불필요, 엔진 모듈·GDExtension 없음.
- **MIT** — 함께 들어 있는 아이콘 84종 포함.

## 요구 사항

Godot **4.5 이상**. `DPITexture`·`FoldableContainer`·접근성 속성 등 4.5 에서 들어온 API 를 쓴다.
개발과 검증은 **4.7.2** 에서 했다.

## 설치

### Asset Store 또는 배포 ZIP

프로젝트 루트에 풀어 `res://addons/gohud/` 가 되게 한다. 그게 전부다.
필요하면 **프로젝트 → 프로젝트 설정 → 플러그인 → gohud** 를 켠다([플러그인](#플러그인)).

### git submodule (게임과 함께 gohud 를 개발할 때)

저장소 루트가 곧 애드온 폴더라 Godot 이 기대하는 자리에 그대로 떨어진다.

```bash
git submodule add <gohud-저장소-주소> addons/gohud
git submodule update --init
```

그 자리에서 고치고 `addons/gohud` **안에서** 커밋·push 한 뒤, 게임 저장소에서 서브모듈 포인터를
커밋한다. 재현 가능한 빌드를 원하면 태그에 고정한다(`git -C addons/gohud checkout v1.0.0`).

## 빠른 시작

```gdscript
extends Node

func _ready() -> void:
	var dialogs := GoDialogs.new()
	add_child(dialogs)
	if await dialogs.confirm("저장 삭제", "되돌릴 수 없습니다."):
		print("삭제됨")
```

검색 칸과 바닥 버튼이 고정된 바텀 시트:

```gdscript
var sheet := GoSheet.new()
add_child(sheet)
sheet.open("가방")
sheet.toolbar().add_child(GoStyle.line_edit("검색…"))
sheet.toolbar().visible = true
for item in items:
	sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, item.name, _use.bind(item),
		Color.TRANSPARENT, item.description, false))
sheet.footer().add_child(GoStyle.button("닫기", sheet.close, GoStyle.Tone.PRIMARY))
sheet.footer().visible = true
```

HUD 모서리:

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.TOP_LEFT
corner.landscape_spot = GoHudAnchor.Spot.TOP_RIGHT   # 가로 화면에서는 다른 자리로
add_child(corner)

var hp := GoBar.new()
hp.setup("HP", GoTheme.DANGER)
corner.add_child(hp)
hp.set_values(72, 100)
```

## 설정 — `GoConfig` 한 장

```gdscript
var settings := GoConfig.new()
settings.theme = preload("res://my_theme.tres")   # 내 테마
settings.accent = Color("#7c5cff")                # 강조색만 바꿔도 된다
settings.base_font_size = 15
settings.icons = my_icons                         # 아이콘 세트 교체
settings.metric_overrides = {GoTheme.BUTTON_HEIGHT: 56}
GoUi.config = settings
```

값을 바꾼 뒤에는 `GoUi.refresh()` 를 부른다 — 살아 있는 위젯이 전부 다시 그려진다.
설정을 `.tres` 로 저장해 프로젝트 설정에 경로를 적어 두면 자동으로 불린다.

여섯 묶음이 있다 — 겉모습 · 반응형 · 표면 동작 · 피드백(소리·진동) · 번역 · 접근성.

## 아이콘 — 세 가지 교체 방법

| 방법 | 하는 법 |
|---|---|
| 통째로 교체 | `GoConfig.icons` 에 내 SVG 세트를 꽂는다 |
| 아이콘 폰트 | `font` + `codepoints` 를 채운다 (Font Awesome·Material Symbols 등) |
| **몇 개만** 교체 | `fallback = GoUi.DEFAULT_ICONS` 로 두고 바꿀 이름만 채운다 |

```gdscript
# 내 SVG 세트
var mine := GoIconSet.new()
mine.textures = {GoIconSet.CLOSE: preload("res://icons/close.svg"),
	GoIconSet.SETTINGS: preload("res://icons/gear.svg")}
mine.fallback = GoUi.DEFAULT_ICONS          # 나머지는 기본 세트
GoUi.config.icons = mine
GoUi.refresh()

# 아이콘 폰트
var fa := GoIconSet.new()
fa.font = preload("res://fonts/icons.otf")
fa.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}
fa.fallback = GoUi.DEFAULT_ICONS
```

텍스처든 폰트든 **쓰는 쪽 코드는 같다**.

```gdscript
var node := GoUi.icons().node(GoIconSet.CLOSE, 20)   # 알아서 TextureRect 또는 Label
GoStyle.icon_button(GoIconSet.CLOSE, _on_close)      # 36dp 그림 · 48dp 터치
```

기본 84종은 선·원·사각형만으로 그린 원본이고 **MIT** 라 재배포에 제약이 없다.
`DPITexture` 로 임포트돼 UI 배율을 올려도 다시 래스터화된다.

## 테마

테마 타입 `GoHud` 아래에 색·여백·글자 크기 토큰이 있고, 14가지 타입 변형(`GoHudPrimary`,
`GoHudDanger` …)이 버튼·라벨의 역할을 정한다. 다크·라이트 두 벌이 들어 있다.

```gdscript
GoUi.color(GoTheme.DANGER)        # 색 토큰
GoUi.metric(GoTheme.PADDING)      # 여백 토큰
GoUi.font_size(GoTheme.BODY)      # 글자 크기 토큰
```

내 팔레트로 테마를 새로 만들려면 `tools/make_theme.py` 에 색을 넣고 돌린다 —
컨트롤 SVG(체크박스·화살표·토글 등)까지 테마별로 생성한다.

## 위젯

| | |
|---|---|
| `GoSurface` | 끌어 옮기고 크기를 바꾸는 모달 창 — 스크림·헤더·스크롤 본문 |
| `GoSheet` | 바텀 시트 — 고정 툴바·푸터, 끌어내려 닫기 |
| `GoDialogs` | `await` 로 받는 알림·확인·입력·선택 |
| `GoForm` | 좁은 화면에서 한 열로 접히는 라벨 행 |
| `GoNotice` | 스낵바·토스트 — 입력을 절대 먹지 않는다 |
| `GoPromptCard` · `GoCoachMark` | 화면 안 안내 카드, 스포트라이트 튜토리얼 |
| `GoHudAnchor` · `GoBar` · `GoSlot` · `GoJoystick` | HUD 모서리, 자원 막대, 퀵슬롯, 가상 스틱 |
| `GoScroll` · `GoIconButton` | 스크롤 영역, 아이콘 버튼 |
| `GoStyle` | 버튼·칩·목록 행·흐르는 줄·접이식 섹션을 한 줄로 만드는 팩토리 |

## 플러그인

켜면 `GoRuntime` 오토로드가 등록된다 — 화면 크기 변화·안전영역·가상 키보드를 매 프레임 지켜보며
`GoUi` 에 알린다. **켜지 않아도 모든 위젯이 동작한다**(스스로 필요한 시점에 갱신한다).
배율 적용은 기본 꺼짐이다 — 프로젝트에 이미 UI 배율 주인이 있다면 그대로 두면 된다.

## 반응형

`GoScale` 이 dp 좌표계와 브레이크포인트(576 / 991)를 다룬다. 폼은 좁으면 한 열이 되고,
표면은 화면 비율로 크기를 잡으며, 안전영역과 키보드 높이를 피한다.
터치 목표는 시각적으로 작아도 **48dp 아래로 내려가지 않는다**.

## 번역

버튼 문구 11개(닫기·뒤로·확인·취소·다음·완료·건너뛰기 …)가 11개 언어로 들어 있다.
프로젝트의 번역 키를 쓰고 싶으면 `GoConfig.text_keys` 로 연결하고
`load_builtin_translations = false` 로 내장 번역을 끈다.
RTL 은 `LAYOUT_DIRECTION_APPLICATION_LOCALE` 로 자동 처리된다.

## 소리·진동

`GoConfig.sound_cues` 에 이름을 적고 `GoFeedback.sound_handler` 에 재생 함수를 꽂는다.
프로젝트의 오디오 시스템이 무엇이든 상관하지 않는다.

```gdscript
GoFeedback.sound_handler = func(cue: String) -> void: MyAudio.play(cue)
```

햅틱은 모바일에서만 울리고 설정으로 끌 수 있다.

## 접근성

상호작용 컨트롤에 `accessibility_name` 이 붙는다. 포커스 링은 키보드·게임패드 사용자에게만 보인다.
`reduce_motion` 을 켜면 애니메이션이 줄어든다.

## 검증한 것

| 항목 | 결과 |
|---|---|
| 헤드리스 검사 147개 (빈 프로젝트) | 147/147 |
| 같은 검사 — 오토로드를 켠 프로젝트 | 147/147 |
| 배포 ZIP 을 빈 프로젝트에 설치해 재검사 | 147/147 |
| Web 내보내기 | 성공 |
| 갤러리 화면 — 폰 세로·가로·데스크톱 | 18장 육안 확인 |

**검증하지 않은 것**: Android·iOS 실기기, Forward+/Mobile 렌더러, 4.7.2 외 버전.

## 개발

```bash
bash tools/run_tests.sh                         # 147 검사
bash tools/new_project_check.sh --export        # 빈 프로젝트에 설치 + Web 내보내기
bash tools/new_project_check.sh --with-runtime  # 오토로드를 켠 상태로
bash tools/package.sh                           # 배포 ZIP (게이트 4개)
```

버전을 올릴 때는 `plugin.cfg` 의 `version` 과 `core/go_ui.gd` 의 `VERSION` 을 함께 올리고,
`CHANGELOG.md` 에 항목을 쓴 뒤 위 네 명령을 통과시킨다. `package.sh` 가 버전 불일치·문서 누락·
애드온 밖 참조를 잡아 거부한다.

## 라이선스

MIT — 아이콘 포함. 상업 게임에 쓰고, 고치고, 재배포해도 된다.
자세한 고지는 [LICENSE](LICENSE)·[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
