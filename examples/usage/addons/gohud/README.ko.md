# gohud — Godot 4 커스터마이징 HUD·UI 키트

**설명 사이트:** [English (기본)](https://thruthesky.github.io/gohud/) · [한국어](https://thruthesky.github.io/gohud/ko/) · [배포 안내](docs/README.md)

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
- **Godot 4.6 이상.** 4.6 stable 과 4.7 에서 검사 전부를 통과시켜 확인했다.
- **순수 GDScript.** 오토로드 불필요, 엔진 모듈·GDExtension 없음.
- **MIT** — 함께 들어 있는 아이콘 84종 포함.

## 요구 사항

Godot **4.6 이상**. `DPITexture`·`FoldableContainer`·접근성 속성 등 4.5 에서 들어온 API 를 쓰고,
지원 하한은 4.6 이다 — 바뀔 때마다 **4.6 stable 과 4.7.2 양쪽**에서 검사 전부를 돌리고
갤러리 스크린샷까지 대조한다.

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

스크롤되는 본문이 그 HUD 와 한 화면에 있다면, 폼에게 자리를 비우라고 일러 준다 — 그러지 않으면
본문이 HUD 뒤로 흘러 글자끼리 겹친다:

```gdscript
form.avoid_hud = true                 # 보이는 GoHudAnchor 를 모두 피한다
joystick_anchor.reserve_space = false # 손을 얹을 때만 나타나는 것은 빼고
```

칸마다 **잃는 면적이 가장 작은 방향**으로 피한다 — 오른쪽 위의 체력바는 세로 화면에서는 아래로,
가로 화면에서는 옆으로 비껴간다.

아홉 자리는 화면을 나눌 뿐 **서로 안 겹친다는 보장은 아니다.** 위쪽 가운데에 뜨는 넓은 스낵바는
오른쪽 위 체력바 위에 그대로 얹힌다. 잠깐 뜨는 쪽에게 비키라고 한다:

```gdscript
notice_anchor.avoid_peers = true      # 고정 HUD 아래로 내려앉는다(좌우 정렬은 그대로)
notice_anchor.reserve_space = false   # 떠 있는 동안 본문을 밀지도 않는다
```

## 설정 — `GoConfig` 한 장

```gdscript
var settings := GoConfig.new()
settings.theme = preload("res://my_theme.tres")   # 내 테마
var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: Color("#7c5cff")}
settings.color_overrides = colors                 # 강조색만 바꿔도 된다
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
컨트롤 SVG(체크박스·라디오·화살표·토글·탭 등)까지 테마별로 생성한다. 🛑 돌린 뒤 프로젝트에서
`godot --headless --path . --import` 를 한 번 — 새 SVG 는 실제 임포트를 거쳐야 읽힌다.

### 생김새 묶음 — 색뿐 아니라 **모양**까지

`Theme` 는 **엔진이 그려 주는 것**의 모양만 바꾼다. `StyleBoxFlat` 의 모서리는 둥근 것뿐이고,
조이스틱·퀵슬롯·코치마크는 코드가 직접 그리므로 테마를 아무리 갈아 끼워도 모양이 안 바뀐다.
그래서 gohud 는 **묶음(preset)** 을 쓴다 — 테마 + 스킨 + 아이콘을 한 단위로 고른다.

| 묶음 | 생김새 |
|---|---|
| `default_dark` | gohud 원래 모습 — 둥근 모서리, 부드러운 파란 강조 |
| `default_light` | 같은 모양에 밝은 팔레트 |
| `scifi_dark` | 모서리를 사선으로 자른 판, 시안 네온 테두리와 발광, 육각 조이스틱, 조준 표식 |
| `scifi_light` | 같은 각진 모양에 밝은 설계도 팔레트 |

```gdscript
GoUi.use_preset(GoThemePresets.SCIFI_DARK)     # 한 줄 — 테마·스킨·아이콘이 함께 바뀐다
```

**테마를 하나 더 만들려면** 파일 하나면 된다 — 내장 테마를 물려받고 바꿀 것만 적는다:

```bash
python3 addons/gohud/tools/new_theme.py neon --from scifi_dark --title "Neon"
python3 addons/gohud/tools/make_theme.py neon      # 테마 .tres + 컨트롤 그림
godot --headless --path . --import                  # 새 그림을 한 번 임포트
```

`themes/palettes/neon.json` 에 부모 값이 전부 풀어 적혀 있어 그것이 곧 "바꿀 수 있는 것" 목록이다.
`themes/presets/` 는 폴더를 스캔하므로 새 프리셋이 코드 수정 없이 고르개에 뜬다. 모양을 바꿨으면 `bash addons/gohud/tools/demo_shots.sh /tmp/shots --play` 로 데모 15 섹션을 봇이 돌며 찍은 그림(코치마크 단계·알림·시트가 뜬 순간 포함)을 눈으로 본다. 스킨의 숫자(슬롯 테두리·배지 여백·조이스틱 링·sci-fi 잘린 모서리)도 JSON 의 `skin.dials` 에서 바꾼다 — 스킨 코드는 손대지 않는다. 다이얼 전부의 이름·기본값·뜻은 사이트 [테마 페이지](docs/www/ko/theming.html)에 스크립트에서 뽑아 적혀 있다. 글자·테두리·강조색은
생성기가 읽히는 자리까지 밀어 주므로 색만 바꿔도 가독성 검사를 통과한다(`tools/check_scaffold.sh` 가 지킨다).

```gdscript
```

에디터에서 고르려면 **프로젝트 설정 → Gohud → Theme → Preset**, 설정 리소스에서는 `preset` 칸.
🔑 `theme`·`skin`·`icons` 를 직접 채우면 그쪽이 묶음보다 **우선한다** — 묶음을 고른 뒤 한 칸만
자기 것으로 바꿔 끼울 수 있다.

`GoSkin` 이 테마가 닿지 못하는 모양을 맡는다 — 조이스틱, 퀵슬롯 판, 코치마크 링, 칩, 스켈레톤,
알림 상자, 분절 선택. 상속해서 **바꾸고 싶은 것만** 덮어쓰면 나머지는 기본 모양 그대로다.

```gdscript
class_name MySkin extends GoSkin

func slot_box(accent: Color, lit: bool) -> StyleBox:
    var box := GoStyleBoxCut.new()
    box.bg_color = accent
    return box
```

`StyleBoxFlat` 로 못 만드는 모양을 위해 두 가지를 담았다 — `GoStyleBoxCut`(모서리를 자른 판 ·
강조 변 · 바깥 발광)과 `GoStyleBoxBracket`(네 모서리 표식). 둘 다 여느 StyleBox 처럼 `Theme`
리소스 안에 그대로 저장된다.

🛑 `GoStyle.surface()` 는 스킨이 만든 모양을 **그대로** 넘긴다. `box()`·`floating()`·`disc()` 는
돌려받아 `bg_color` 를 고치는 옛 호출부와의 약속 때문에 **언제나 `StyleBoxFlat`** 이다 —
그 길로는 각진 모양이 살아남지 못한다.

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

### 자식 클래스 훅

하위 위젯을 만드는 곳은 전부 덮어쓸 수 있는 메서드를 거친다. gohud 타입을 상속한 호스트(자기 타입 힌트·자기 닫기
그림·자기 모달 체계)는 코드를 복사하지 않고도 위젯 *안에* 자기 서브클래스를 끼울 수 있다:

| 훅 | 위젯 | 기본 |
|---|---|---|
| `_make_scroll()` | `GoCoachMark`, `GoSurface` | `GoScroll.new()` |
| `_make_close_button()` | `GoPromptCard`, `GoSurface` | `GoIconButton.new()` |
| `_make_surface()` | `GoSheet` (`GoDialogs` 다음) | `GoSurface.new()` |
| `_should_pause()` | `GoCoachMark` | `GoSurface.is_any_open()` — 모달이 열려 있는 동안 카드를 숨긴다 |
| `GoScroll.as_horizontal(node)` | 정적 | `horizontal()` 의 설정 단계 — `static func horizontal() -> MyScroll` 을 자식이 다시 만들 때 |

`GoIconButton.native_texture_size = true` 는 텍스처 아이콘을 `visual_size` 의 58% 로 늘리지 않고 원래 픽셀 크기로 그린다.

## 플러그인

켜면 `GoRuntime` 오토로드가 등록된다 — 화면 크기 변화·안전영역·가상 키보드를 매 프레임 지켜보며
`GoUi` 에 알린다. **켜지 않아도 모든 위젯이 동작한다**(스스로 필요한 시점에 갱신한다).
배율 적용은 기본 꺼짐이다 — 프로젝트에 이미 UI 배율 주인이 있다면 그대로 두면 된다.

## 반응형

`GoScale` 이 dp 좌표계와 브레이크포인트(576 / 991)를 다룬다. 폼은 좁으면 한 열이 되고,
표면은 화면 비율로 크기를 잡으며, 안전영역과 키보드 높이를 피한다.
터치 목표는 시각적으로 작아도 **48dp 아래로 내려가지 않는다**.

## 번역

문구 16개가 **21개 언어**로 들어 있다 (`i18n/gohud.csv`) — 영어·한국어·일본어·
중국어(간체 `zh`·번체 `zh_TW`)·스페인어·포르투갈어·독일어·프랑스어·이탈리아어·네덜란드어·
폴란드어·러시아어·우크라이나어·터키어·베트남어·인도네시아어·태국어·힌디어·아랍어·히브리어.
`load_builtin_translations = false` 로 내장 번역을 끈다.
RTL(`ar`·`he`)은 `LAYOUT_DIRECTION_APPLICATION_LOCALE` 로 자동 처리된다.

### 화면의 모든 글자를 호스트가 바꾼다

🛑 **위젯은 문구를 코드에 박지 않는다.** `widgets/`·`core/`·`services/` 어디에도
`label.text = "Retry"` 같은 줄이 없고, 생기면 검사가 실패한다. 화면에 글자가 오는 길은 둘뿐이다.

| 어디서 오나 | 바꾸는 법 |
|---|---|
| **당신이 넘긴다** — 대화상자 제목·본문, 버튼 라벨, 폼 항목, 목록 줄, 빈 상태 | 그냥 원하는 문자열이나 번역 키를 넘긴다 |
| **gohud 가 준다** — 아래 이름 16개 | `text_overrides`(원문) 또는 `text_keys`(프로젝트의 키) |

```gdscript
# 번역 테이블 없이 내 문구로
GoUi.config.text_overrides = {&"confirm": "예", &"cancel": "아니오"}

# 또는 프로젝트에 이미 있는 키로 연결
GoUi.config.text_keys[&"confirm"] = "MY_DIALOG_YES"
```

이름 16개: `close` `back` `next` `done` `skip` `confirm` `cancel` `search` `loading` `empty`
`retry` 와 **형식 문자열** 다섯 — `bar_fraction`(`{value} / {max}`) · `bar_percent`(`{percent}%`) ·
`coach_progress`(`{step} / {total}`) · `slot_quantity`(`×{count}`) · `slot_unknown`(`…`).

🔑 **형식도 번역 대상이다** — 구두점은 만국 공통이 아니다. 터키어는 백분율 기호를 **앞**에 붙이고
(`%50`), 프랑스어는 띄운다(`50 %`). 자리표시자는 `{이름}` 이라, 번역자가 하나 빠뜨려도 화면이
죽지 않고 그대로 나온다.

🔑 **숫자 축약은 형식이 아니라 훅이다** — 한국어·일본어·중국어는 천이 아니라 만(10,000)·억에서
끊는다. 글자만이 아니라 계산이 다르므로 함수를 꽂는다.

```gdscript
GoUi.config.number_formatter = func(amount: float) -> String:
    if absf(amount) >= 10_000.0: return "%.1f만" % (amount / 10_000.0)
    return str(roundi(amount))
```

> 🛑 **gohud 는 폰트를 담지 않는다.** 태국어·아랍어·히브리어·힌디어·CJK 는 호스트 프로젝트의
> 테마 폰트가 글리프를 덮어야 한다 — 라틴 전용 폰트면 두부(□)로 그려지고 **오류는 나지 않는다**.
> 번체도 마찬가지다: 간체 서브셋에는 번체 자형이 없다.

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

## 데모 — 자동 시연과 직접 탐색

`examples/demo/project.godot`을 실행한다. **Start demo**를 누르면 15개 장면이 순서대로 진행되며,
커서가 실제 입력으로 버튼·메뉴를 선택하고, 글자를 입력하고, 슬라이더·조이스틱을 끌고, 목록을 스크롤한다.
**Explore widgets** 또는 왼쪽 사이드바의 항목을 누르면 그 위젯 하나만 무대에 지어져 **직접 만져 볼 수 있고**,
오른쪽 **Play this widget** 버튼으로 그 위젯만 봇이 시연하게 할 수 있다. 시연 중 사이드바를 누르면
시연을 접고 그 위젯을 연다. 좁은 창에서는 사이드바 대신 상단의 **Widgets** 메뉴가 나온다.
표시 문구는 모두 영어이며, 큰 데스크톱 창에서는 글자와 위젯도 함께 커진다.

```bash
bash examples/demo/run.sh
bash examples/demo/run.sh --record /tmp/gohud-demo.avi # 전체 시연 1080p / 60fps 녹화
bash examples/demo/run.sh --shot /tmp/gohud-start.png
bash examples/demo/run.sh -- --explore=surfaces        # 위젯 하나를 탐색 모드로 바로 연다
```

**C**는 촬영 모드, **F11**은 전체 화면, **Space**는 일시정지(탐색 중에는 현재 위젯 시연), **←/→**는 장면·위젯 이동,
**Esc**는 시작 화면이다.
촬영 모드는 좌우 패널을 숨기고 시작 전에 3초를 센다. 일반 실행은 시작 버튼을 누를 때까지 대기한다.
설치·촬영·검증 명령은 [데모 안내](examples/demo/README.md)를 참고한다.

## 개발

```bash
bash tools/run_tests.sh                         # 147 검사
bash tools/new_project_check.sh --export        # 빈 프로젝트에 설치 + Web 내보내기
bash tools/new_project_check.sh --with-runtime  # 오토로드를 켠 상태로
bash tools/package.sh                           # patch +1; builds/<버전>/gohud-<버전>.zip
bash tools/package.sh --increase-minor-version  # minor +1, patch는 0
python3 tools/check_package.py                 # 임시 사본에서 패키징 회귀 검사
```

`package.sh`는 Python 3가 필요하며, 성공할 때마다 패치 버전을 자동으로 올린다.
예를 들어 `1.2.9`는 `1.2.10`이 되고, `--increase-minor-version`을 주면 `1.3.0`이 된다.
`--out DIR`로 출력 폴더를 바꿔도 버전은 올라간다. 버전은 `major.minor.patch` 형식을 사용한다.

`plugin.cfg`의 `version`, `core/go_ui.gd`의 `VERSION`, `CHANGELOG.md`를 함께 갱신한다.
`Unreleased` 변경 내역은 날짜가 붙은 새 버전 항목으로 옮기고 빈 `Unreleased` 항목을 남긴다.
패키징이 실패하면 버전 파일은 바뀌지 않고, 같은 버전의 기존 ZIP도 덮어쓰지 않는다.
버전 불일치·문서 누락·애드온 밖 참조는 계속 검사한다.
`check_all.sh`의 패키징 검사는 임시 사본에서 실행하므로 작업 중인 버전은 올라가지 않는다.

## 라이선스

MIT — 아이콘 포함. 상업 게임에 쓰고, 고치고, 재배포해도 된다.
자세한 고지는 [LICENSE](LICENSE)·[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
