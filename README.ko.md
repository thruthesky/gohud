# gohud — Godot 4 커스터마이징 HUD·UI 키트

**홈페이지:** [https://thruthesky.github.io/gohud/](https://thruthesky.github.io/gohud/)

[한국어 사이트](https://thruthesky.github.io/gohud/ko/) ·
[생김새 안내](https://thruthesky.github.io/gohud/ko/theming.html) ·
[위젯 안내](https://thruthesky.github.io/gohud/ko/widgets.html) ·
[English README](README.md) ·
[변경 기록](CHANGELOG.md) ·
[GitHub](https://github.com/thruthesky/gohud)

영문판은 [README.md](README.md) 다. 이 문서는 같은 내용의 한국어 설명서다.

떠 있는 창, 바텀 시트, 확인창, 폼, 스낵바, 안내 카드, 코치마크, HUD 막대, 퀵슬롯, 가상 조이스틱을
**테마 한 장과 교체 가능한 아이콘 세트 한 장**으로 굴린다. 안전영역·가상 키보드·RTL 언어·터치를
스스로 챙긴다. 기본 제공 프리셋 여섯 — 기본·sci-fi·중세, 각각 어둡고 밝은 판 — 이 코드 한 줄로
색과 **모양**을 함께 바꾼다.

<p>
  <img src="https://thruthesky.github.io/gohud/img/preset-default-dark.png" alt="default_dark 프리셋의 gohud 갤러리" width="250">
  <img src="https://thruthesky.github.io/gohud/img/preset-scifi-dark.png" alt="scifi_dark 프리셋의 같은 갤러리" width="250">
</p>

> 넣으면 그냥 동작한다. 에디터 플러그인을 켜는 것은 편의 기능일 뿐이다.

**버전 1.1.0.** 위젯 열다섯 개(스낵바·스피너·표·출석 보상 …), 게임 아이콘 187개와 인벤토리 격자
`GoSlotGrid`, 아이템 카드, 판 뒤로 게임이 비치는 컨테이너 불투명도, 23장짜리 안내 투어가 들어 있다 —
목록은 [변경 기록](CHANGELOG.md)에 있다. 그 뒤의 작업은 거기 *Unreleased* 에 모인다 — `package.json` 의
버전을 올리고 `tools/package.sh` 를 실행하면 배포에 들어간다.

- **프리셋 여섯, 코드 한 줄.** `GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` 가 테마·스킨·아이콘을
  함께 바꾼다 — 둥근 기본 판, 네온이 번지는 사선 모서리의 sci-fi, 각인 아이콘과 단조 프레임의 중세.
- **아이콘을 갈아 끼워도 코드는 그대로.** 위젯은 아이콘을 이름으로 부른다(`GoIconSet.CLOSE`).
  `GoConfig.icons` 를 내 SVG 세트나 아이콘 폰트로 바꾸면 모든 위젯이 따라온다 — 몇 개만 바꿔도 된다.
- **테마는 데이터다.** `new_theme.py` 가 내장 테마를 물려받는 JSON 파일 하나를 만든다. 생성기가 테마·컨트롤
  그림·스킨 다이얼을 만들고, 글자·테두리·강조색을 WCAG 대비 기준을 넘을 때까지 민다.
- **설정은 리소스 한 장.** 프리셋·테마·아이콘·크기·브레이크포인트·표면 동작·햅틱·소리·문구가 전부
  `GoConfig` 하나에 있고, 애드온을 업데이트해도 살아남는다.
- **모바일 우선, 데스크톱도.** 작게 보이는 버튼 뒤에 48dp 터치 영역, 안전영역과 키보드 회피,
  가로·세로 배치, Android 뒤로 가기, 키보드 사용자에게만 보이는 포커스 링.
- **요즘 엔진 기능을 쓴다.** `DPITexture` 아이콘은 UI 배율을 키워도 선명하고,
  `FoldableContainer` 접이식 섹션, 화면 낭독기를 위한 `accessibility_name`,
  알림이 입력을 먹지 않게 하는 `mouse_behavior_recursive`, 흐르는 줄의 `last_wrap_alignment`.
- **순수 GDScript.** 오토로드 불필요, 엔진 모듈·GDExtension 없음.
- **MIT** — 코드와 그림 전부, 기본 아이콘 84종·중세 각인 아이콘 16종·게임 아이콘 187종·아이콘 라이브러리 1,000종 포함. 중세 제목에 쓰는
  Cinzel 글꼴은 SIL Open Font License 1.1 로 함께 들어 있다.

## 요구 사항

Godot **4.6 이상**. `DPITexture`·`FoldableContainer`·접근성 속성 등 4.5 에서 들어온 API 를 쓰므로
그보다 낮은 엔진에서는 파싱 단계에서 죽는다. 지원 하한은 4.6 이고 `GoUi.MIN_ENGINE` 에 적혀 있다.
`tools/check_all.sh` 는 4.7 에서 검사를 돌리고, `GODOT_46` 에 4.6 실행 파일을 주면 4.6 에서도 돌린다.

## 설치

### Asset Store 또는 배포 ZIP

프로젝트 루트에 풀어 `res://addons/gohud/` 가 되게 한다. 그게 전부다.
필요하면 **프로젝트 → 프로젝트 설정 → 플러그인 → gohud** 를 켠다([플러그인](#플러그인)).

### git submodule (게임과 함께 gohud 를 개발할 때)

저장소 루트가 곧 애드온 폴더라 Godot 이 기대하는 자리에 그대로 떨어진다.

```bash
git submodule add https://github.com/thruthesky/gohud.git addons/gohud
git submodule update --init
```

그 자리에서 고치고 `addons/gohud` **안에서** 커밋·push 한 뒤, 게임 저장소에서 서브모듈 포인터를
커밋한다. 재현 가능한 빌드를 원하면 태그나 커밋에 고정한다(`git -C addons/gohud checkout v1.0.0`).

## 빠른 시작

```gdscript
extends Node

func _ready() -> void:
	var dialogs := GoDialogs.new()
	add_child(dialogs)
	if await dialogs.confirm("저장 삭제", "되돌릴 수 없습니다."):
		print("삭제됨")
```

되돌릴 수 없는 일에는 `confirm()` 의 마지막 인자 `destructive` 를 `true` 로 준다 — 확인 버튼이 채워진
위험 버튼으로 그려진다.

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

요약이 있는 두 줄 항목은 위아래 여백이 같고, 줄이 더 높게 늘어나도 제목·요약 묶음이 아이콘 옆 세로
가운데에 선다.

HUD 모서리:

```gdscript
var corner := GoHudAnchor.new()
corner.spot = GoHudAnchor.Spot.TOP_LEFT
corner.landscape_spot = GoHudAnchor.Spot.TOP_RIGHT   # 가로 화면에서는 다른 자리로
add_child(corner)

var hp := GoBar.new()
hp.label_text = "HP"
hp.ink = GoUi.color(GoTheme.DANGER_FILL)             # 채움 전용 토큰 — 밝은 테마에서도 선명하다
hp.custom_minimum_size.x = 180
corner.add_child(hp)
hp.set_values(320, 500)
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

## 프리셋 — 색뿐 아니라 **모양**까지

`Theme` 는 **엔진이 그려 주는 것**의 모양만 바꾼다. `StyleBoxFlat` 의 모서리는 둥근 것뿐이고,
조이스틱·퀵슬롯·코치마크는 코드가 직접 그리므로 테마를 아무리 갈아 끼워도 모양이 안 바뀐다.
그래서 gohud 는 **프리셋**을 쓴다 — 테마 + 스킨 + 아이콘을 한 단위로 고른다.

```gdscript
GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)   # UI 를 만들기 전에 — 테마·스킨·아이콘이 함께 바뀐다
```

| 프리셋 | 생김새 | 스킨 |
|---|---|---|
| `default_dark` | gohud 원래 모습 — 둥근 모서리, 부드러운 파란 강조, 단계별 그림자 | `GoSkin` |
| `default_light` | 같은 모양에 밝은 팔레트 | `GoSkin` |
| `scifi_dark` | 모서리를 사선으로 자른 판, 시안 네온 테두리와 발광, 육각 조이스틱, 조준 표식 포커스 | `GoSkinSciFi` |
| `scifi_light` | 같은 각진 모양에 밝은 설계도 팔레트 | `GoSkinSciFi` |
| `medieval_dark` | 어두운 철·가죽, 고금색 프레임, 리벳, 각인풍 아이콘, Cinzel 제목 | `GoSkinMedieval` |
| `medieval_light` | 양피지·잉크·청동 색상의 같은 단조 프레임 | `GoSkinMedieval` |

에디터에서 고르려면 **프로젝트 설정 → gohud → Theme → Preset**, 설정 리소스에서는 `preset` 칸.
🔑 `theme`·`skin`·`icons` 를 직접 채우면 그쪽이 프리셋보다 **우선한다** — 프리셋을 고른 뒤 한 칸만
자기 것으로 바꿔 끼울 수 있다.

### 중세

<img src="https://thruthesky.github.io/gohud/img/medieval-dark.png" alt="medieval_dark — 기본 위젯으로 만든 캐릭터 정보·가방·퀘스트 일지" width="640">

[중세 예제](examples/medieval/medieval.tscn)를 열고 F6 으로 실행하면 캐릭터 정보, 퀵슬롯 가방, 퀘스트 일지를
볼 수 있다 — 전부 기본 위젯으로 만들었다. 버튼으로 철·양피지를 바꾸고, 아이템을 누르면 `GoDialogs` 알림으로
설명이 뜬다.

- 메뉴 판에는 리벳과 작은 모서리 장식을 두고, 상시 보이는 HUD 판은 테두리를 절제했다.
- 체력·마나·스태미나는 빨강·파랑·올리브색 채움으로 읽힌다.
- 각인풍 세트는 `bag`·`book`·`box`·`coin`·`crown`·`flag`·`heart`·`key`·`map`·`potion`·`shield`·`star`·
  `sword`·`user` 를 다시 그리고 `scroll`·`seal` 을 더한다. 나머지 이름(`close` 등)은 기본 세트로 떨어진다.
- 포함된 Cinzel 글꼴은 제목·부제에만 쓰고 본문은 테마 글꼴을 유지한다. Cinzel 은 라틴 문자만 담으므로
  다른 문자의 제목에는 `shape.fonts` 로 글꼴을 따로 준다.

### 테마 하나 더 — 파일 하나

내장 테마를 물려받고 바꿀 것만 적는다:

```bash
python3 addons/gohud/tools/new_theme.py kingdom --from medieval_dark --title "Kingdom"
python3 addons/gohud/tools/make_theme.py kingdom   # 테마 .tres + 컨트롤 그림 + 스킨 리소스
godot --headless --path . --import                 # 새 그림을 한 번 임포트
```

```gdscript
GoUi.use_preset(&"kingdom")   # themes/presets/ 를 스캔하므로 프리셋 고르개에도 저절로 뜬다
```

`themes/palettes/kingdom.json` 에 부모 값이 전부 풀어 적혀 있어 그것이 곧 "바꿀 수 있는 것" 목록이다.
키를 지우면 부모 값이 쓰인다.

| 블록 | 정하는 것 |
|---|---|
| `from` | 부모 — `dark`·`light`·`scifi_dark`·`medieval_dark`·… 또는 다른 JSON 테마. 순환 상속은 오류로 알린다. |
| `palette` | 바탕·표면 3단·테두리·글자 3단·강조·상태색 4·스크림·그림자·막대 바탕, 그리고 막대 채움 전용 `*_vivid`. 글자·테두리·강조색은 생성기가 읽히는 대비까지 민다. |
| `shape` | `kind`(`flat`·`cut`·`medieval`)와 치수(`radius`·`radius_small`·`radius_large`·`gap`·`gap_small`·`gap_large`·`padding`·`button_height`·`button_padding`). `cut` 은 `cut_ratio`·`cut_max`·`corners`·`glow`·`edge` 를, `medieval` 은 `material`(0 철·1 가죽·2 양피지)·`grain_alpha`·`ornament_scale`·`bevel_strength`·`fonts`(`title`·`subtitle`·`caption`·`body`·`button` → 애드온 내부 `res://` 글꼴 경로)를 더한다. |
| `skin` | `base`(`default`·`scifi`·`medieval`)와 `dials` — 슬롯 테두리·배지 여백·조이스틱 링·잘린 모서리·`slot_rivets` 같은 숫자 32개. 생성기가 `themes/skins/gohud_skin_<id>.tres` 로 내려보내므로 스킨 코드를 안 만진다. |
| `icons` | 아이콘 세트 리소스. 적지 않으면 JSON 부모의 세트를 따른다. |
| `dark`·`title` | 고르개 표시. |

다이얼 전부의 이름·기본값·뜻은 스킨 스크립트에서 뽑아 사이트
[생김새 페이지](https://thruthesky.github.io/gohud/ko/theming-own.html#own)에 적혀 있다.
`tools/check_scaffold.sh` 가 매번 임시 테마를 만들어 강조색과 반경을 바꾸고 생성·토큰 반영·대비 통과를
확인한다. 그림 자체를 바꿔야 할 때만 `new_theme.py --new-skin` 을 쓰고, 만든 것을 지우려면
`new_theme.py --remove kingdom`.

애드온 밖, 내 프로젝트에 둔 프리셋은 코드에서 등록한다:

```gdscript
GoThemePresets.register(preload("res://ui/my_preset.tres"))
```

🛑 새 SVG 를 생성한 뒤에는 `godot --headless --path . --import` 를 한 번 — 임포트를 거치기 전에는 새 테마를
읽지 못한다.

## 설정 — `GoConfig` 한 장

```gdscript
var settings := GoConfig.new()
settings.preset = GoThemePresets.MEDIEVAL_LIGHT
var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: Color("#7c5cff")}
settings.color_overrides = colors                 # 강조색만 바꿔도 된다
settings.base_font_size = 15
settings.container_alpha = 0.7                    # 판 전부를 70% 불투명 (음수면 테마 값)
GoUi.config = settings
```

설정을 `.tres` 로 저장해 **프로젝트 설정 → gohud → Config → Resource** 에 경로를 적어 두면(플러그인을 켜면
칸이 생긴다) 자동으로 불린다. 비워 둔 칸은 gohud 기본 동작 그대로다 — 채워야 하는 칸은 없다.

| 묶음 | 칸 |
|---|---|
| 겉모습 | `preset`, `theme`, `token_fallback`, `skin`, `icons`, `color_overrides`, `metric_overrides`, `base_font_size`, `shrink_type_on_mobile` |
| 반응형 | `scale_enabled`(1 unit = 1 dp, **기본 꺼짐**), `mobile_max_dp`, `tablet_max_dp`, `read_gain_*`, `desktop_ui_gain`, `form_max_width_*`, `respect_safe_area` |
| 표면 | `surface_max_width`, `surface_max_height`, `surface_height_ratio`, `surface_max_height_ratio`, `surface_width_ratio_portrait/landscape`, **`container_alpha`**, **`container_alpha_overrides`**, `dismiss_on_scrim`, `surface_fade_in`, `fade_seconds`, `close_button_visual`, `suppress_pointer_focus_ring`, `close_on_back` |
| 피드백 | `haptics_enabled`, `haptic_tap/light/medium_ms` 와 세기, `sound_cues` |
| 번역 | `text_keys`, `text_overrides`, `number_formatter`, `load_builtin_translations` |
| 접근성 | `min_touch_size`, `reduce_motion`, `autowrap_text` |

`theme`·`icons` 를 넣으면 열려 있는 위젯이 알아서 다시 배치된다. 다른 칸을 코드에서 바꿨다면
`GoUi.refresh()` 를 부른다.

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

# 아이콘 폰트
var fa := GoIconSet.new()
fa.font = preload("res://fonts/icons.otf")
fa.codepoints = {GoIconSet.CLOSE: 0xf00d, GoIconSet.SETTINGS: 0xf013}
fa.fallback = GoUi.DEFAULT_ICONS
```

텍스처든 폰트든 **쓰는 쪽 코드는 같다**.

```gdscript
var node := GoUi.icons().node(GoIconSet.CLOSE, 20)         # 알아서 TextureRect 또는 Label
GoStyle.icon_button(GoIconSet.CLOSE, _on_close, -1, "close") # 36dp 그림 · 48dp 터치 · 툴팁 = 접근성 이름
```

믿고 쓸 수 있는 이름은 `GoIconSet` 의 상수 84개다. 찾는 길 위의 세트가 그리기만 하면 다른 이름도 된다 — 중세 세트의
`scroll`·`seal` 이 그렇다. `icons/gohud_icons_medieval.tres` 가 "몇 개만 교체" 의 실제 예다(기본 세트 위에 16장).
그림 전부는 [아이콘 페이지](https://thruthesky.github.io/gohud/ko/icons.html)에서 검색하고 이름을 복사할 수 있다.
기본 84종과 중세 16종은 gohud 를 위해 그린 원본이고, 모든 아이콘은 `DPITexture` 로 임포트돼 UI 배율을 올려도 다시 래스터화된다.

```gdscript
# 폴더 하나를 통째로 — 파일 이름이 아이콘 이름이 되고, 처음 그릴 때 읽는다
GoUi.config.icons = GoIconSet.from_folder("res://icons", GoUi.icons())
```

### 세트 넷, 찾는 길 하나 — 그림 1,287장

| 세트 | 이름 | 상수 | 켜는 법 |
|---|---|---|---|
| 기본 | 84 | `GoIconSet` | 늘 켜져 있다 |
| 중세 | 각인 16 | — | `GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)` |
| 게임 — 인벤토리·상점·아이템 | 아홉 묶음 187 | `GoGameIcons` | `GoUi.add_icons(GoGameIcons.icon_set())` |
| 라이브러리 — 화살표·장치·날씨·운동·표정 … | 32 묶음 1,000 | `GoIconLibrary` | `GoUi.add_icons(GoIconLibrary.icon_set())` |

```gdscript
GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)
GoUi.add_icons(GoIconLibrary.icon_set())        # 라이브러리는 게임 세트로 넘어간다 — 한 줄로 이름 1,271개

var grid := GoSlotGrid.new()                    # GoSlot 칸으로 된 인벤토리 격자
grid.slot_count = 30
grid.set_cell(0, {"icon": GoGameIcons.APPLE, "quantity": 12, "tooltip": "사과"})
menu.add_child(GoStyle.list_button(GoIconLibrary.CLOUD_RAIN, "날씨", open_weather, Color.TRANSPARENT, "", false))
```

`GoUi.add_icons()` 는 세트를 `GoConfig.extra_icons` 에 넣는다. `use_preset()` 은 이 목록을 남기므로, 프리셋의 자기
그림(위의 각인된 칼)은 그대로 위에 있고 더한 세트는 프리셋에 없는 이름만 채운다.
(`GoUi.config.icons = GoGameIcons.icon_set()` 도 여전히 되지만, 프리셋의 세트를 통째로 갈아 끼운다.)

큰 세트는 텍스처가 아니라 **경로**를 들고 있다 — 그림은 그 이름을 처음 그릴 때 읽는다. 라이브러리를 더하는 비용은
텍스처 1,000장이 아니라 경로 표 하나다(데스크톱에서 한 번 약 30 ms). 🛑 경로는 문자열이지 의존성이 아니다 —
리소스를 골라 내보내는 export 는 `addons/gohud/icons/` 를 넣어야 한다(기본값 "모든 리소스 내보내기"는 따로 할 것이 없다).

게임 그림 171장과 라이브러리 1,000장은 [Tabler Icons](https://tabler.io/icons) 3.46.0(MIT, © Paweł Kuna)의 경로
데이터를 쓴다 — 기본 세트와 같은 24px 격자·2px 둥근 선이라 나란히 놓아도 어긋나지 않는다. 게임 그림 16장(반지·목걸이·
장갑·광석·수정·산소통·돔 …)은 gohud 를 위해 그렸다. 표는 `tools/make_game_icons.py` 와 `tools/icon_library_data.py`
이고, `tools/make_game_icons.py`·`tools/make_icon_library.py` 를 실행하면 SVG·세트·상수를 한 번에 다시 만든다.

### 이름을 찾는 순서

1. **모든 세트의 자기 그림이 먼저다** — 지금 쓰는 세트, 그다음 더한 세트들, 그다음 그 세트들의 fallback 을 한 단씩 본다.
   자기 그림이란 텍스처·경로·아이콘 폰트 글리프다.
2. 아무도 그리지 못하면 **별칭**을 본다(`gear` → `settings`, `x` → `close`). 한 번만 건너간다.
3. 그래도 없으면 자리를 지키는 빈 상자가 되고, 디버그 빌드에서는 경고가 뜬다.

### 이름 찾기 — 검색·묶음·별칭

```gdscript
var icons := GoUi.icons()
icons.search("arrow left", 5)        # 잘 맞는 것부터: back, arrow_bar_left …
icons.group_names()                  # 묶음 키 전부
icons.names_in_group(&"weather")     # 한 묶음 — 모든 세트의 몫을 모아서
icons.canonical(&"gear")             # &"settings"
```

이름은 lower_snake_case 로, 그린 것을 먼저 쓰고 상태를 뒤에 붙인다(`volume_off`, `battery_charging`). 묶음 접두사는
붙이지 않는다. 라이브러리 이름은 Tabler 이름의 `-` 를 `_` 로 바꾼 것이고, gohud 에 이미 있던 그림의 Tabler 이름은
별칭으로 그 그림에 닿는다(`map_pin` → `location`).

> 상용 아이콘 폰트는 보통 게임 안에서 쓰는 것만 허락하고 재배포는 막는다. gohud 를 공개 포크할 때는
> 그 폰트를 넣지 말고 게임 프로젝트에 둔다. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 참고.

## 테마

토큰은 전부 테마 타입 **`GoHud`** 아래에 있다.

| 갈래 | 토큰 |
|---|---|
| 색 | `background`, `surface`, `surface_soft`, `surface_high`, `border`, `text`, `secondary`, `muted`, `accent`, `on_accent`, `success`, `warning`, `danger`, `info`, `scrim`, `shadow`, `track` |
| 채움 색 | `success_fill`, `warning_fill`, `danger_fill`, `info_fill`, `accent_fill` — 막대처럼 넓은 면적용. 테마에 없으면 `_fill` 을 뗀 이름으로 떨어진다 |
| 치수(dp) | `touch`, `button_height`, `gap_tiny`, `gap_small`, `gap`, `gap_large`, `padding`, `padding_compact`, `compact_padding_x`, `compact_padding_y`, `radius_small`, `radius`, `radius_large`, `screen_margin`, `scroll_deadzone`, `scroll_edge`, `scrollbar_width`, `list_glyph`, `icon_size`, `notice_duration_ms` |
| 판 불투명도(%) | `panel_alpha`, `card_alpha`, `hud_alpha`, `notice_alpha`, `popup_alpha` — 컨테이너 바탕이 얼마나 꽉 찬 색인가. 기본 80(팝업 메뉴만 100). 테마에 없으면 100 으로 떨어진다 |
| StyleBox | `panel`, `card`, `hud`, `notice`, `popup`, `empty`, `focus`, `focus_soft` |
| 글자 역할 | `micro`, `compact`, `caption`, `body`, `button`, `subtitle`, `title` |

타입 변형: `GoPanel`, `GoCard`, `GoButton`, `GoPrimaryButton`, `GoDangerButton`, `GoDangerSolidButton`,
`GoBareButton`, `GoCompactButton`, `GoIconButton`, `GoListButton`, `GoTitleLabel`, `GoSubtitleLabel`,
`GoCaptionLabel`, `GoCompactLabel`, `GoMicroLabel`.

`GoHud` 토큰이 없는 테마를 꽂아도 동작한다 — `token_fallback` 이 켜져 있는 동안 빠진 토큰은 기본 테마에서 채운다.

```gdscript
GoUi.color(GoTheme.DANGER)                  # 색 토큰
GoUi.metric(GoTheme.PADDING)                # 치수 토큰
GoUi.font_size(GoTheme.ROLE_CAPTION)        # 글자 역할 크기
GoUi.surface_alpha(GoTheme.BOX_PANEL)       # 판 불투명도 — 비율 0.0~1.0 로 돌려준다
```

### 판 투명도 — 컨테이너 뒤로 게임이 보인다

**팝업·다이얼로그·시트·카드·HUD 판은 기본 80% 불투명**이다. 뒤 20% 가 배어 나와, 확인창 뒤에서 전투가
계속되는 것이 보이고 가방 시트 아래로 지도가 비친다. 게임 UI 에서 이것은 장식이 아니라 **맥락을 잃지 않게
하는 장치**다 — 판이 꽉 찬 색이면 창을 여는 순간 플레이어는 자기가 어디에 서 있었는지 알 수 없다.

🛑 **묽어지는 것은 판의 바탕뿐이다.** 글자·아이콘·버튼·배지·퀵슬롯은 선명한 채로 남는다. 내용까지 함께
흐려지면 읽을 수 없는 UI 가 되고, 그것은 투명한 창이 아니라 고장이다. 테두리와 그림자도 그대로다 —
윤곽이 선명해야 반투명한 판이 유리처럼 읽히고, 흐려지면 판이 어디서 끝나는지 알 수 없다.

#### 다섯 층 — 구체적인 것이 이긴다

| 순서 | 어디서 | 단위 | 쓰는 때 |
|---|---|---|---|
| ① | 그 자리의 인자·칸 — `surface.alpha`, `sheet.alpha`, `GoStyle.card(…, alpha)` | 비율 `0.0~1.0` | **이 창 하나만** 다르게 |
| ② | `GoConfig.container_alpha_overrides[종류]` | 비율 `0.0~1.0` | 이 프로젝트에서 **이 종류만** 다르게 |
| ③ | `GoConfig.metric_overrides[<종류>_alpha]` | **퍼센트** `0~100` | 치수를 한 곳에 모아 두는 프로젝트의 관습을 따를 때 |
| ④ | `GoConfig.container_alpha` | 비율 `0.0~1.0` | 프로젝트의 **판 전부**를 한 번에 |
| ⑤ | 테마의 `GoHud/constants/<종류>_alpha` | **퍼센트** `0~100` | 생김새 묶음이 정한 값 — **정본** |

다섯 다 비어 있으면 1.0(꽉 찬 색)이다 — 이 토큰을 모르는 옛 테마·남의 테마를 그대로 꽂아도 화면이 예전과 같다.

🔑 **불투명도를 다루는 자리는 전부 비율(0.0~1.0)이다.** 위젯의 `alpha` 칸(인스펙터에 나가는 것까지),
`GoStyle` 인자, `GoConfig` 의 두 칸, `GoUi.surface_alpha()` 의 반환값 — `Color.a`·`modulate.a` 와 같은
엔진 관례를 따른다. 음수는 "정하지 않았다" 로, 아래 층으로 넘어간다.

🛑 **퍼센트는 테마 상수 한 층에만 있다** — `Theme` 의 constant 가 정수만 담을 수 있기 때문이다.
그래서 테마의 `<종류>_alpha` 와 **그것을 덮는 통로**(`metric_overrides` — 이름도 타입도 테마 치수와 같다)
두 자리만 `80` 처럼 적는다. 나머지는 모두 `0.8` 이다.

```gdscript
# ① 창 하나만 — 뒤의 전투가 보여야 하는 확인창
surface.alpha = 0.6
sheet.alpha = 0.7
dialogs.alpha = 0.9
drawer.alpha = 0.7
GoPopover.open(slot, body, {"alpha": 0.9})
var glass := GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, 0.5)

# ② 종류별 — HUD 만 거의 꽉 차게(월드 위에서 글자가 읽혀야 한다)
GoUi.config.container_alpha_overrides = {
    GoTheme.BOX_PANEL: 0.7,   # 대화상자·시트는 시원하게
    GoTheme.BOX_HUD: 0.95,
}
GoUi.refresh()                # 🛑 떠 있는 위젯까지 다시 그리려면 부른다

# ③ 프로젝트 전부 — 그림이 복잡한 게임은 꽉 찬 색으로 되돌린다
GoUi.config.container_alpha = 1.0
GoUi.refresh()

# ④ 테마에서(정본) — 팔레트 JSON 의 shape 에 적으면 생성기가 토큰까지 내려 준다
#    또는 .tres 를 직접: GoHud/constants/panel_alpha = 70
```

#### 어느 판이 따르고, 어느 것이 따르지 않는가

| 따른다 — 컨테이너 | 따르지 않는다 — 누르는 것·표식 |
|---|---|
| `GoSurface`(다이얼로그·시트·드롭다운의 근원) · `GoSheet` · `GoDialogs` · `GoDrawer` · `GoPopover` · `GoNotice` · `GoSnackbar` · `GoPromptCard` · `GoCoachMark` · `GoConsole` | 버튼 전부 · `GoSlot`(퀵슬롯) · `GoBadge`(배지) · 분절 선택 · 고르는 칸 · 칩 · 원판·아바타 |
| `GoStyle.card()` · `hud_panel()` · `overlay_panel()` · `alert()` · `plate()` · `edge_card_panel()` · `style_notice_panel()` · `floating()` · `box()` · `surface()` | 글자·아이콘 일체 |

- **팝업 메뉴(`PopupMenu`)는 기본이 꽉 찬 색**이다(`popup_alpha` 100). 엔진이 그것을 **창**으로 띄울 수 있고,
  그때는 OS 가 게임 화면과 합성해 주지 않아 반투명이 "뒤가 보이는 대신 검게" 나온다. 게임 안에 박아 띄우는
  프로젝트(`gui_embed_subwindows`)라면 값을 내려도 좋다.
- `GoStyle.plate()` 에 **채움 색을 직접 주면 그 색 그대로**다 — `Color(ink, 0.14)` 처럼 알파까지 적어 준 색에
  판 불투명도를 또 곱하면 부르는 쪽의 의도가 두 번 깎인다.
- `GoStyle.floating(…, opaque = true)` 는 이 값을 쓰지 않는다 — "월드가 비쳐 글자가 안 읽히는 자리" 를 위해
  **일부러 꽉 채우는** 것이 그 인자의 뜻이다.

#### gohud 가 만들지 않은 판에도

```gdscript
var frame := PanelContainer.new()
add_child(frame)                   # 🛑 트리에 붙인 뒤에 — 부모에서 물려받은 테마를 읽는다
GoStyle.fade_panel(frame)          # 테마·설정이 정한 값
GoStyle.fade_panel(frame, 0.6)     # 이 판만 60%
GoStyle.fade_panel(frame, 1.0)     # 되돌린다(판 덮기를 걷어낸다)
```

여러 번 불러도 한 번만 묽어진다 — 원래 판을 메타에 적어 두고 언제나 그것에서 다시 계산한다. 테마를 갈아
끼운 뒤에는 `GoStyle.forget_face(node)` 로 그 기억을 버려야 새 테마의 판을 잡는다.

#### 커스텀 StyleBox 에서도 같다

사선 판(`GoStyleBoxCut`)·철판(`GoStyleBoxMedieval`)처럼 `_draw()` 로 직접 그리는 판도 바탕만 묽어진다.
발광·리벳·모서리 각인·베벨은 세기를 그대로 지키고, 중세 판의 질감과 베벨은 원래부터 바탕 알파에 비례하므로
판이 묽어지면 함께 묽어진다.

#### 실제로 만져 보기 — 데모 네 곳

값을 글로 읽는 것과 손으로 끄는 것은 다르다. 슬라이더를 끌면 **그 자리에서** 판이 묽어지는 자리를 네 곳에 두었다.

| 어디 | 무엇을 보는가 |
|---|---|
| **홈 → Try it right here → SEEING THROUGH PANELS** | 홈은 이미 뒤에 무늬를 그린다 — 값을 내리면 격자와 빛이 카드를 통해 배어 나온다. `Apply to every panel` 은 `GoConfig.container_alpha` 를 심고 화면을 다시 지어, 목록 줄·알림·떠 있는 판까지 함께 바뀐다 |
| **가이드 투어 16번 `Container opacity`** | 봇이 값을 끌어내리고, 바닥은 목표가 아니라고 말한 뒤 되돌린다. 손잡이가 아니라 **판에 박힌 값**을 읽어 확인한다 |
| **위젯 갤러리 `Container opacity`** | 같은 실험실에 `Busy background` 토글이 더 있다 — 화면 전체 뒤에 무늬를 깔아, HUD 가 게임 위에 얹힌 모습에 가장 가깝게 본다 |
| **중세 예제** | `_draw()` 로 직접 그리는 철판에서도 같은가 — 바탕만 묽어지고 리벳·베벨은 그대로다 |

네 곳이 **같은 위젯 하나**를 쓴다(`examples/gallery/opacity_lab.gd`). 그 안에 값을 주는 네 가지 길이 나란히
있다 — 팩토리 인자, 이미 만든 노드에 다시 입히기, `GoStyle.fade_panel()`, 프로젝트 설정.
🛑 데모마다 슬라이더를 따로 만들지 않았다 — 한쪽만 고쳐지면 무엇이 맞는 사용법인지 알 수 없게 된다.

🔑 **뒤에 무늬가 없으면 이 기능은 보이지 않는다.** 단색 배경 위에서는 판이 "조금 다른 색" 이 된 것과
구별되지 않는다 — 그래서 실험실은 미리보기 칸 안에 스스로 무늬를 깐다. 반대로 그 무늬를 **화면 전체**에
선명하게 깔면 판 밖에 놓인 글자가 한 줄도 읽히지 않는다(첫 촬영에서 실측). 화면용 무늬는 옅게 깐다.

### 스킨과 커스텀 StyleBox

`GoSkin` 이 테마가 닿지 못하는 모양을 맡는다 — 조이스틱, 퀵슬롯 판, 코치마크 링, 칩, 스켈레톤,
알림 상자, 분절 선택, 구분선, 섹션 머리말. `GoSkinSciFi`·`GoSkinMedieval` 이 함께 들어 있는 상속 예다.
상속해서 **바꾸고 싶은 것만** 덮어쓰면 나머지는 그대로다.

```gdscript
class_name MySkin extends GoSkin

func slot_box(accent: Color, lit: bool) -> StyleBox:
    var box := GoStyleBoxCut.new()
    box.bg_color = accent
    return box
```

`StyleBoxFlat` 로 못 만드는 모양을 위해 셋을 담았다. 모두 여느 StyleBox 처럼 `Theme` 리소스 안에 그대로
저장된다.

| 클래스 | 그리는 것 |
|---|---|
| `GoStyleBoxCut` | 모서리를 자른 판 · 한 변만 굵은 강조 변 · 바깥 발광 |
| `GoStyleBoxBracket` | 변을 두르지 않는 네 모서리 표식 |
| `GoStyleBoxMedieval` | 리벳·모서리 각인·베벨 반사·재질 질감이 있는 단조 프레임 |

🛑 `GoStyle.surface()` 는 스킨이 만든 모양을 **그대로** 넘긴다. `box()`·`floating()`·`disc()` 는
돌려받아 `bg_color` 를 고치는 옛 호출부와의 약속 때문에 **언제나 `StyleBoxFlat`** 이다 —
그 길로는 커스텀 모양이 살아남지 못한다.

### 가독성은 재서 지킨다

`python3 addons/gohud/tools/check_contrast.py` 가 테마 전부를 WCAG 로 잰다: 본문 4.5:1, 큰 글자·강조 테두리·
아이콘·포커스 링 3:1, 장식 테두리 2:1, 맞닿은 표면 1.12:1. 버튼 글자는 그것이 얹힌 상태별 판 위에서 재고,
반투명 판은 순백·순흑 위에 합성해서 잰다 — HUD 는 어떤 게임 화면 위에도 얹힐 수 있기 때문이다. 스킨이
실행 중에 섞는 색(칩·슬롯)은 검사 스위트의 `skin contrast` 섹션이 Godot 안에서 잰다.

## 위젯

| 클래스 | 바탕 | 하는 일 |
|---|---|---|
| `GoSurface` | Control | 떠 있는 카드 껍데기 — `CENTER`·`BOTTOM`·`ANCHOR` 배치, 고정 머리말·툴바·바닥, 스크롤 본문, Escape/뒤로 가기는 가장 위 창만, 포커스 복원, 끌어서 크기 조절 |
| `GoSheet` | CanvasLayer | 뒤로 가기가 있는 바텀 시트 페이지, 고정 툴바·푸터. `max_height_ratio` 로 그 시트만 전역 상한 0.72 를 넘겨 키운다(비율이 깎이면 디버그 빌드에서 경고) |
| `GoDialogs` | Node | `await confirm()`·`await alert()` — 문구·번역 키 두 방식, `destructive` 면 채워진 위험 버튼, `action_layout` 으로 버튼 세로·한 줄·자동 |
| `GoForm` | MarginContainer | 브레이크포인트마다 폭을 제한하고 가상 키보드를(`avoid_hud` 면 HUD 까지) 피하며 라벨 줄바꿈을 보장하는 폼 |
| `GoScroll` | ScrollContainer | 손가락 스크롤, 스크롤바가 카드 여백 자리로 들어간다, RTL 대응 |
| `GoNotice` | PanelContainer | 입력도 포커스도 가져가지 않는 스낵바 |
| `GoPromptCard` | PanelContainer | 화면을 막지 않는 질문 카드. 새로 그려도 눌린 버튼이 살아 있다 |
| `GoCoachMark` | Control | 실제 컨트롤을 가리키는 안내 투어. 대상을 누르면 다음으로, 카드는 HUD 앵커와 `keep_clear` 를 피한다 |
| `GoHudAnchor` | Control | HUD 를 안전영역 아홉 자리 중 하나에 붙인다. 가로 자리·`reserve_space`·`avoid_peers`. `keyboard_focus = false` 면 그 모서리의 버튼이 스페이스·엔터를 가로채지 않는다 |
| `GoBar` | Control | 체력·마나·경험치 막대. 값·분수·퍼센트 표시와 부드러운 보간 |
| `GoSlot` | Button | 아이콘·수량·쿨다운·단축키를 판 한 장에 담은 퀵슬롯. 촘촘한 줄에서 터치 영역 공유, `keyboard_focus` 로 Tab 순회 포함 |
| `GoJoystick` | Control | 고정·따라오기·상대 모드의 가상 조이스틱, 데드존 |
| `GoIconButton` | Button | 작게 보이고 크게 눌리는 아이콘 버튼, 접근성 이름. 툴팁에 직접 만든 번역 키를 그대로 쓴다. 게임 화면 위에서는 `keyboard_focus = false` |
| `GoStyle` | 팩토리 | 버튼·라벨·목록 줄(고른 줄 표시는 `restyle_list_row`)·입력·선택·드롭다운·아이콘 분절 선택·칩·카드·항목 상세 카드(`item_card`)·표·탭·흐르는 줄·반응형 격자·접이식 섹션·빈 상태 |
| `GoUi` | 정적 | 현재 설정·프리셋·테마·스킨·아이콘·색·치수·문구 |
| `GoThemePresets` | 정적 | 기본 프리셋 여섯, `themes/presets/` 에서 찾은 프리셋, 내 것을 더하는 `register()` |
| `GoSkin` · `GoSkinSciFi` · `GoSkinMedieval` | Resource | 코드가 그리는 모양과 숫자 다이얼 |
| `GoSafeArea` | Control / 정적 | 노치·둥근 모서리·키보드를 뺀 쓸 수 있는 사각형 |
| `GoScale` | 정적 | 브레이크포인트와 dp 계산 |
| `GoFeedback` | 정적 | 소리·햅틱 연결 |
| `GoBackPolicy` | 정적 | Android 뒤로 가기의 소유권 |

### 기다리기·알리기·세기

| 클래스 | 바탕 | 하는 일 |
|---|---|---|
| `GoSnackbar` | Node | 화면 아래에 뜨는 알림 줄, 제 레이어를 가진다. 줄을 서고, 같은 글이 또 오면 세어서 합치고, 안전영역과 키보드를 피한다. 버튼을 달 수 있고 `await post()` 가 **눌린 버튼의 번호**를 준다(만료는 `-1`). 버튼이 없으면 입력을 아예 받지 않는다 |
| `GoSpinner` | Control | 끝을 알 수 없는 기다림. `GoSpinner.busy(button, true)` 는 버튼을 **제자리에서** 스피너로 바꾼다 — 크기가 그대로고 눌리지 않으므로, 느린 요청이 두 번 날아가지 않는다 |
| `GoBadge` | PanelContainer | 안 읽은 점, `NEW` 딱지, `99+`. `attach()` 가 앵커로 오른쪽 위 모서리에 절반 걸치므로 그 컨트롤이 움직이거나 커져도 따라간다. `0` 이면 숨는다 |

### 폼과 목록

| 클래스 | 바탕 | 하는 일 |
|---|---|---|
| `GoField` | VBoxContainer | 라벨·컨트롤·힌트, 그리고 **칸별 오류**. `set_error()` 가 그 칸을 표시하고 아래에 무엇이 틀렸는지 적으며 그 말을 접근성 설명으로도 준다. 라벨·힌트는 번역되고 오류는 되지 않는다(서버가 준 문장은 번역 키가 아니다) |
| `GoInputGroup` | HBoxContainer | 입력칸과 버튼을 한 덩어리로 — 앞에 아이콘이 붙은 검색, 보내기가 달린 말 줄, − 와 + 가 붙은 수량. 테두리와 포커스 고리를 함께 쓴다 |
| `GoCombobox` | Button | 이름의 **가운데**를 찾는 고르개 — "검"으로 "녹슨 검"이 나온다. 제게 붙은 `GoSurface` 를 열고, 고른 줄을 표시해 두며, 항목이 적으면 평범한 목록으로 떨어진다 |
| `GoCodeInput` | VBoxContainer | 쿠폰·선물 코드를 칸칸이. 글자는 **숨은 `LineEdit` 하나**가 들고 있어 붙여넣기·자동완성·한글 입력기가 그대로 동작한다(칸은 그린 것이다). 폰에서는 넘치는 대신 줄을 바꾼다 |
| `GoTable` | VBoxContainer | 머리글로 정렬하고 줄을 고른다. **숫자는 숫자로 정렬한다**(`2, 10` 이 `10, 2` 가 되지 않는다). 정렬된 머리글은 방향을 색뿐 아니라 글리프로도 보이고, 줄은 48dp 터치 높이를 지킨다 |
| `GoPagination` | HBoxContainer | 현재 쪽을 가운데 두고 양끝을 줄임표로 접는 쪽 번호, 또는 `mode = MORE` 로 *더 보기* 한 줄 — 폰 목록이 실제로 원하는 것은 뒤쪽이다 |

### 게임이 실제로 쓰는 모양

| 클래스 | 바탕 | 하는 일 |
|---|---|---|
| `GoRewardCalendar` | VBoxContainer | 출석 보상 — 받은 날, 오늘, 아직 오지 않은 날. **오늘만 눌린다**. 연속 출석은 이어진 칸으로 그리고, 각 날의 상태를 색이 아니라 말로도 준다 |
| `GoRadar` | Control | 능력치 오각형 — 힘·민첩·지능·체력·행운을 한 모양으로. `set_compare()` 가 바꿔 낄 장비를 **점선**으로 겹친다(점선이라 색각 이상인 사람도 두 줄로 본다) |
| `GoDonut` | Control | 피해량 분포·재화 비율·파티 기여도. `collapse_to` 를 넘는 조각은 하나로 묶고, 가운데에 합계를 두며, `legend()` 가 조각마다 이름과 비율을 **글자로** 말한다 |
| `GoCarousel` | VBoxContainer | 이벤트 배너와 캐릭터 선택. **저절로 넘어가지 않는다** — 자동으로 넘어가는 배너는 사람이 누르려던 것을 가로챈다. 점은 눌리고, 몇 번째인지 소리로 읽힌다 |
| `GoKbd` | HBoxContainer | 키 안내. `GoKbd.for_action(&"interact")` 가 InputMap 에서 **실제 배치**를 읽으므로 키를 바꾸면 안내도 바뀐다. `hide_on_handheld` 가 폰에서는 감춘다 |

### 화면 위에

| 클래스 | 바탕 | 하는 일 |
|---|---|---|
| `GoDrawer` | CanvasLayer | 양옆에서 밀려 나오는 판 — 폰보다 넓은 화면을 위한 것. 안전영역을 지키고, 뒤로 가기와 막에서 닫히며, RTL 에서 좌우가 뒤집힌다 |
| `GoPopover` | RefCounted | 누른 것 **옆에** 붙는 설명 카드 — 아이템 툴팁, "이 능력치가 뭐지" 카드. 한 번에 하나만 뜨고, 화면 밖으로 나갈 자리면 반대쪽으로 넘어가며, 창 크기가 바뀌면 따라간다 |
| `GoContextMenu` | RefCounted | 어떤 컨트롤에든 길게 누르기(0.5초)·오른쪽 클릭. 손가락이 12dp 넘게 움직이면 **취소한다** — 그래야 긴 목록이 그대로 스크롤된다 |
| `GoConsole` | CanvasLayer | 개발자 콘솔 — 등록한 명령, 인자, 기록, 자동완성. `debug_only` 가 기본 `true` 라 **배포 빌드에서는 열리지 않는다** |

### 자식 클래스 훅

하위 위젯을 만드는 곳은 전부 덮어쓸 수 있는 메서드를 거친다. gohud 타입을 상속한 호스트(자기 타입 힌트·자기 닫기
그림·자기 모달 체계)는 코드를 복사하지 않고도 위젯 *안에* 자기 서브클래스를 끼울 수 있다:

| 훅 | 위젯 | 기본 |
|---|---|---|
| `_make_scroll()` | `GoCoachMark`, `GoSurface` | `GoScroll.new()` |
| `_make_close_button()` | `GoPromptCard`, `GoSurface` | `GoIconButton.new()` |
| `_make_surface()` | `GoSheet`, `GoDialogs` | `GoSurface.new()` |
| `_should_pause()` | `GoCoachMark` | `GoSurface.is_any_open()` — 모달이 열려 있는 동안 카드를 숨긴다 |
| `GoScroll.as_horizontal(node)` | 정적 | `horizontal()` 의 설정 단계 — `static func horizontal() -> MyScroll` 을 자식이 다시 만들 때 |

`GoIconButton.native_texture_size = true` 는 텍스처 아이콘을 `visual_size` 의 58% 로 늘리지 않고 원래 픽셀 크기로 그린다.

## 플러그인

켜면 세 가지가 더해진다. 모두 선택이다.

1. 프로젝트 설정에 **gohud → Config → Resource** 와 **gohud → Theme → Preset** 칸이 생긴다.
2. **`GoRuntime`** 오토로드가 등록된다 — `breakpoint_changed`·`viewport_resized`·`keyboard_changed` 를 보내고,
   폰에서 본문 글자를 한 단계 줄이며, `scale_enabled` 가 켜져 있을 때만 `content_scale_factor` 로 1 unit = 1 dp 를 맞춘다.
3. 내장 번역을 프로젝트 번역 목록에 넣는다.

**켜지 않아도 모든 위젯이 동작한다** — 키보드는 위젯이 스스로 살피고, 글자 크기는 테마 값 그대로 쓴다.

## 반응형

- 브레이크포인트는 화면 **짧은 변의 dp** 로 정한다 — 576 까지 모바일, 991 까지 태블릿, 그 위는 데스크톱. 둘 다 바꿀 수 있다.
- 표면은 기본으로 쓸 수 있는 영역 높이의 72% 에서 멈춘다 — 떠 있는 창이 늘 떠 있어 보이게. 가로 화면에서는 폭을 더 좁게 쓴다.
- 위젯은 전부 `GoSafeArea.usable_rect()` 를 기준으로 잰다 — Android·iOS 의 노치와 제스처 바를 뺀 영역이다.
- `GoStyle.responsive_grid(min_cell_width)` 는 폭이 바뀔 때마다 열 수를 다시 계산한다.
- 터치 목표는 시각적으로 작아도 **48dp 아래로 내려가지 않는다**.

## 번역

문구 16개가 **21개 언어**로 들어 있다 (`i18n/gohud.csv`) — 영어·한국어·일본어·
중국어(간체 `zh`·번체 `zh_TW`)·스페인어·포르투갈어·독일어·프랑스어·이탈리아어·네덜란드어·
폴란드어·러시아어·우크라이나어·터키어·베트남어·인도네시아어·태국어·힌디어·아랍어·히브리어.
자동으로 읽히고, `load_builtin_translations = false` 로 끈다.
RTL(`ar`·`he`)에서도 숫자·조이스틱·스크롤 레일은 왼쪽에서 오른쪽을 지키고, 내용은 애플리케이션 로캘을 따른다.

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

> 🛑 **언어에 맞는 글꼴은 호스트가 준다.** 함께 든 글꼴은 Cinzel 하나이고, 중세 프리셋만 제목·부제에 쓴다.
> 태국어·아랍어·히브리어·힌디어·CJK 는 호스트 프로젝트의 테마 폰트가 글리프를 덮어야 한다 — 라틴 전용
> 폰트면 두부(□)로 그려지고 **오류는 나지 않는다**. 번체도 마찬가지다: 간체 서브셋에는 번체 자형이 없다.

## 소리·진동

gohud 는 오디오를 담지 않는다. 신호를 프로젝트 오디오 시스템에 한 번 연결한다:

```gdscript
GoFeedback.sound_handler = func(cue: String) -> void: MyAudio.play(cue)
```

신호 이름은 `GoConfig.sound_cues`(`ui_open`, `ui_click`, …)에서 오므로 코드를 고치지 않고 내 소리 파일에 맞춘다.
진동은 Android·iOS 에서만, 세 단계 세기로 울리고 설정으로 끌 수 있다.

## 접근성

- 보이는 컨트롤이 작아도 터치 영역은 `min_touch_size`(48dp) 아래로 내려가지 않는다.
- 아이콘만 있는 버튼은 툴팁 문구를 `accessibility_name` 으로 내보낸다.
- `reduce_motion` 을 켜면 페이드와 깜빡이는 강조가 꺼진다.
- 포커스 링은 키보드·게임패드 사용자에게만 보이고, 누르거나 클릭한 뒤에는 뜨지 않는다. 채워진 버튼에는
  그 판과 대비되는 링이 붙고, 대비 검사가 그 자리에서 잰다.
- 창이 열리면 포커스가 창 안으로 들어가고, 밖으로 새지 않으며, 닫히면 원래 자리로 돌아간다.
- 퀵슬롯은 기본으로 Tab 순회에서 빠진다. 키보드·게임패드가 유일한 입력이면 `GoSlot.keyboard_focus` 로 넣는다.
- `GoStyle.Tone.DANGER_SOLID`(와 `GoDialogs.confirm(..., destructive = true)`)는 밝은 테마에서도 되돌릴 수 없는
  동작을 위험으로 읽히게 한다 — 옅게 물든 위험 버튼의 글자는 검은 글자처럼 보이기 때문이다.

## 검증한 것

`tools/check_all.sh` 하나가 진입점이다. 검사마다 볼 수 있는 범위가 다르다:

| 검사 | 잡는 것 |
|---|---|
| `run_tests.sh` — 390×844·844×390·768×1024·1280×800 | 위젯 동작·배치, RTL 위치, 키보드 포커스, 실행 중 스킨 대비, 프리셋 전부 |
| `new_project_check.sh`(`--with-runtime`·`--zip`·`--export`) | 호스트 프로젝트에 몰래 기대는 것, 배포 ZIP 그대로의 동작, Web 내보내기 |
| `check_contrast.py` | 테마 파일 전부의 WCAG 대비 — 버튼 상태와 반투명 판 포함 |
| `check_generated.py` · `check_scaffold.sh` | 생성된 테마가 팔레트와 맞는가, 임시 테마가 만들어지고 대비를 통과하는가 |
| `check_package.py` | 버전 올림·CHANGELOG 이동·ZIP 내용을 임시 사본에서 |
| `check_site.py` | 사이트 링크·절 앵커·문서 언어·용어 사전·생성된 다이얼 표 |
| `check_mutations.sh`(선택) | 규칙을 일부러 깨뜨렸을 때 검사가 알아채는가 |

최근 기록 — **2026-09-13**, Godot 4.7.2 (macOS, Apple Silicon, Compatibility 렌더러). 이 리비전의 애드온
파일을 빈 프로젝트에 복사해 돌렸다:

| 항목 | 결과 |
|---|---|
| 빈 프로젝트 헤드리스 검사 — 390×844·844×390·768×1024·1280×800 | 크기마다 438/438 |
| 같은 검사 — `GoRuntime` 오토로드를 켠 상태 | 438/438 |
| 그 빈 프로젝트의 Web 내보내기 | 성공(`index.pck` 728 KB) |
| `check_contrast.py` — 여섯 테마 | 미달 0 |
| `check_generated.py` | 생성물 149개가 소스와 일치 |
| `check_scaffold.sh` — 중세 부모 포함 | 통과 |
| `check_package.py` | 테스트 13개 통과 |

**이번 실행에 포함되지 않은 것**: Godot 4.6(`GODOT_46` 미지정), 배포 ZIP 자체(`--zip`), Android·iOS 실기기,
Forward+/Mobile 렌더러. 안전영역·햅틱 코드는 휴대 기기에서만 켜지므로 검사로는 지나가지만 실기기에서는 확인하지 않았다.

## 예제

| 예제 | 여는 법 | 보여 주는 것 |
|---|---|---|
| 갤러리 | `res://addons/gohud/examples/gallery/gallery.tscn` 을 F6 | 모든 위젯, 설치된 프리셋 전부를 고르는 선택기, 아이콘 전체. 서버·오토로드·프로젝트 설정이 필요 없다. |
| 중세 | `res://addons/gohud/examples/medieval/medieval.tscn` 을 F6 | `medieval_dark`·`medieval_light` 의 캐릭터 정보·가방·퀘스트 일지 |
| 아이콘 버튼 | `res://addons/gohud/examples/icon_buttons/icon_buttons.tscn` 을 F6 | 라이브러리 아이콘을 버튼에 다는 모든 방법 — 아이콘만 있는 도구 막대, 글자와 아이콘 버튼, 상태에 따라 아이콘이 바뀌는 토글, 메뉴 행, 세그먼트 선택, 한 묶음 통째로, 검색어로 찾은 버튼. |
| 데모 앱 | `cd examples/demo && godot` | 갤러리·23장면 자동 시연·쇼케이스·중세 화면·20초 쇼릴을 한 창에서 고르는 홈 화면. 만져 보는 위젯 카드와 클래스별 한 줄 소개가 함께 있다. |

### 데모 앱 — 홈에서 고르고, 그 자리에서 본다

```bash
cd examples/demo && godot
```

준비할 것이 없다. 애드온 링크나 임포트 캐시가 없으면 앱이 그 사실을 화면에 적고, 링크를 만들고
한 번 임포트한 뒤 스스로 창을 다시 연다. 그다음부터는 바로 **홈 화면**이다. 홈의 카드 다섯 장이
위젯 갤러리·자동 시연·쇼케이스 화면·중세 화면·쇼릴을 **같은 창 안에서** 연다(`1`~`5` 키도 같다).
그 둘레가 곧 이 키트의 안내다 — 소개 옆에 살아 있는 HUD, 직접 눌러 보는 위젯 카드 여섯 장,
그리고 하는 일별로 묶은 19개 클래스가 저마다 코드 한 줄을 달고 깔린다. 전부 애드온 위젯으로만
지었고, 글줄은 읽히는 폭 안에 머물며, 폰에서는 한 줄로 접히고, 테마 선택기로 통째로 다시 칠해진다.

자동 시연에서 **Start demo**를 누르면 23개 장면이 순서대로 진행되며, 커서가 실제 입력으로
버튼·메뉴를 선택하고, 글자를 입력하고, 슬라이더·조이스틱을 끌고, 목록을 스크롤한다.
**Explore widgets** 또는 왼쪽 사이드바의 항목을 누르면 그 위젯 하나만 무대에 지어져 **직접 만져 볼 수 있고**,
오른쪽 **Play this widget** 버튼으로 그 위젯만 봇이 시연하게 할 수 있다. 시연 중 사이드바를 누르면
시연을 접고 그 위젯을 연다. 좁은 창에서는 사이드바 대신 상단의 **Widgets** 메뉴가 나온다.
표시 문구는 모두 영어이며, 큰 데스크톱 창에서는 글자와 위젯도 함께 커진다.

```bash
bash examples/demo/run.sh                             # 애드온 루트에서 같은 앱을 연다
bash examples/demo/run.sh -- --open=gallery           # 홈을 건너뛰고 바로 그 화면으로
bash examples/demo/run.sh --record /tmp/gohud-demo.avi # 전체 시연 1080p / 60fps 녹화
bash examples/demo/run.sh --record-showreel /tmp/reel.avi # 20초 쇼릴 1080p / 60fps — 0.5초마다 위젯 하나, 단계마다 테마가 바뀐다
bash examples/demo/run.sh --shot /tmp/gohud-home.png
bash examples/demo/run.sh -- --explore=surfaces        # 위젯 하나를 탐색 모드로 바로 연다
```

**C**는 촬영 모드, **F11**은 전체 화면, **Space**는 일시정지(탐색 중에는 현재 위젯 시연), **←/→**는 장면·위젯 이동,
**Esc**는 시작 화면이다.
촬영 모드는 좌우 패널을 숨기고 시작 전에 3초를 센다. 일반 실행은 시작 버튼을 누를 때까지 대기한다.
설치·촬영·검증 명령은 [데모 안내](examples/demo/README.md)를 참고한다.

## 설명 사이트

**[https://thruthesky.github.io/gohud/](https://thruthesky.github.io/gohud/)** 는
[`www/`](www/index.html) 의 평범한 HTML 이다 — 루트가 영문이고 나머지 열여섯 언어는 제 폴더에 있다.
용어에 마우스를 올리거나 누르거나 키보드로 포커스하면 뜻이 뜬다. 언어마다 같은 다섯 쪽이 있다 —
소개 · [설치](www/install.html) · [**AI SKILL**](www/ai.html) · [위젯](www/widgets.html) ·
[테마](www/theming.html). 머리띠 메뉴와 AI SKILL 쪽 전부는 **생성물**이다
([`tools/site_nav.py`](tools/site_nav.py) · [`tools/site_ai_text.py`](tools/site_ai_text.py)) —
HTML 85 장이 아니라 그 두 파일을 고친다. GitHub Actions 워크플로
([`.github/workflows/pages.yml`](.github/workflows/pages.yml))가 `www/` 자체를 사이트 최상위로 배포한다.
옛 `docs/www/` 주소도 그대로 쓸 수 있다 — 페이지는 `www/404.html` 이 새 주소로 넘겨주고, 그림은 옛 자리에도
한 벌 올라가 이미 배포된 ZIP 의 README 에서도 보인다.

```bash
python3 addons/gohud/tools/make_site.py            # 용어 사전과 다이얼 표를 소스에서 다시 만든다
python3 addons/gohud/tools/check_site.py           # 링크·앵커·언어·용어 사전·생성 표 검사
bash addons/gohud/tools/site_shots.sh /tmp/shots   # 페이지마다 데스크톱·폰 폭 촬영
```

배포 세부는 [docs/README.md](docs/README.md) 에 있다.

## 개발

```bash
bash tools/check_all.sh                         # 검사 전부를 한 번에
bash tools/run_tests.sh                         # 현재 프로젝트 안에서 헤드리스 검사
bash tools/new_project_check.sh --export        # 빈 프로젝트에 설치 + Web 내보내기
bash tools/new_project_check.sh --with-runtime  # 오토로드를 켠 상태로
python3 tools/check_contrast.py                 # 테마 전부의 WCAG 대비
python3 tools/new_theme.py kingdom --from medieval_dark   # 테마 스캐폴딩
python3 tools/make_theme.py                     # 테마 전부 재생성 — id 를 주면 그 테마만
python3 tools/make_icons.py                     # 기본 아이콘 SVG 재생성
bash tools/release.sh                           # 배포 한 번: 검사 전부 → ZIP → 그 ZIP 을 빈 프로젝트에서 검증
bash tools/package.sh                           # ZIP 만; package.json 의 버전
python3 tools/check_package.py                  # 임시 사본에서 패키징 회귀 검사
```

`release.sh`는 배포 절차 전체를 순서대로 실행한다 — 검사 전부 → ZIP → 그 ZIP 을 빈 프로젝트에 설치해 검증하며,
처음 실패하는 곳에서 멈춘다. 커밋·태그·업로드는 사람이 한다.

`package.sh`는 Python 3가 필요하며, `package.json`에 적힌 버전(`{"version": "1.2.3"}`)으로 패키징한다.
그 숫자를 올리지 않는다 — 새 버전을 내려면 먼저 `package.json`을 고친다.
`--out DIR`로 출력 폴더를 바꾼다. 버전은 `major.minor.patch` 형식을 사용한다.

성공하면 `plugin.cfg`의 `version`과 `core/go_ui.gd`의 `VERSION`을 그 버전으로 맞춘다.
그 버전을 처음 패키징할 때 `Unreleased` 변경 내역을 날짜가 붙은 버전 항목으로 옮기고 빈 `Unreleased` 항목을 남긴다.
`CHANGELOG.md`에 이미 있는 버전을 다시 패키징하면 변경 기록은 그대로 두고 그 버전의 ZIP을 새로 만들어 이전 것과 바꾼다.
패키징이 실패하면 버전 파일은 바뀌지 않는다.
`package.json`이 없거나 형식이 틀린 경우·README 가 다른 버전을 말하는 경우·문서 누락·애드온 밖 참조는 계속 검사한다.
ZIP 에는 사이트·검사·도구·`package.json`과 독립 프로젝트 `examples/usage` 가 들어가지 않는다.
`check_all.sh`의 패키징 검사는 임시 사본에서 실행하므로 작업 사본은 바뀌지 않는다.

## 라이선스

MIT — [LICENSE](LICENSE). 코드와 함께 든 그림(기본 아이콘 84종, 중세 아이콘 16종, 생성된 컨트롤 그림)은
gohud 를 위해 만든 것이라 역시 MIT 다. 상업 게임에 쓰고, 고치고, 재배포해도 된다.
게임 아이콘 세트 187종과 아이콘 라이브러리 1,000종도 MIT 다 — 게임 171종과 라이브러리 전부는 Tabler Icons(MIT, Copyright (c) 2020-2026 Paweł Kuna)의 경로 데이터를 쓰고, 게임 16종은 gohud 를 위해 그렸다.
Cinzel 글꼴은 수정하지 않은 채 SIL Open Font License 1.1 로 함께 배포한다(`assets/fonts/cinzel/OFL.txt`).
자세한 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
