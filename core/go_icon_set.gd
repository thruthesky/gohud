## 🎨 갈아 끼우는 **아이콘 세트**. gohud 의 모든 위젯은 아이콘을 *이름*으로만 부르고,
## 그 이름이 무엇으로 그려지는지는 이 리소스 하나가 정한다.
##
## ## 왜 리소스인가
## 아이콘을 코드에 `preload` 로 박으면 쓰는 쪽이 바꿀 길이 없다. 그래서 **`.tres` 한 장**으로
## 빼 두고, 프로젝트가 자기 세트를 만들어 `GoConfig.icons` 에 꽂으면 위젯 코드를 한 줄도
## 고치지 않고 아이콘이 통째로 바뀐다.
##
## ## 두 가지 방식을 모두 받는다
## | 방식 | 채우는 칸 | 쓰는 곳 |
## |---|---|---|
## | **텍스처**(SVG·PNG) | `textures` | gohud 기본 세트. 색은 `modulate` 로 입힌다 |
## | **아이콘 폰트**(Font Awesome·Material Symbols 등) | `font` + `codepoints` | 이미 폰트를 쓰는 프로젝트 |
##
## 둘을 섞어도 된다 — `textures` 를 먼저 보고, 없으면 `codepoints`, 그래도 없으면 `fallback`
## 세트로 내려간다. 그래서 **기본 세트를 fallback 으로 두고 바꾸고 싶은 몇 개만 덮어쓰는**
## 부분 교체가 가능하다.
##
## ## 쓰는 법
## ```gdscript
## # ① 이름으로 노드 하나 — 텍스처든 폰트든 같은 호출이다.
## var mark := icons.node(GoIconSet.CLOSE, 20, Color.WHITE)
##
## # ② 버튼에 붙이기(텍스처면 Button.icon, 폰트면 자식 Label 로 알아서 간다)
## GoStyle.apply_icon(button, GoIconSet.SETTINGS)
##
## # ③ 부분 교체 세트 만들기
## var mine := GoIconSet.new()
## mine.fallback = GoUi.icons()            # 나머지는 기본 세트 그대로
## mine.textures = {GoIconSet.CLOSE: preload("res://my_close.svg")}
## ```
##
## 🛑 이 리소스는 **위젯을 참조하지 않는다** — `GoStyle`·`GoSurface` 가 이것을 참조하므로,
##    반대 방향을 만들면 순환 의존이 되어 `.new()` 부터 무너진다(라리엔 공용UX 가 실제로
##    `UiStyle → HudIcons → HudIconButton → UiStyle` 로 그렇게 죽었다).
@tool
class_name GoIconSet
extends Resource

# ── 의미 이름 상수 ──────────────────────────────────────────────────────
# 위젯과 게임 코드는 이 이름만 쓴다. 세트를 갈아 끼워도 이름은 그대로다.
# 🛑 여기에 없는 이름을 써도 된다 — `textures`/`codepoints` 에 넣기만 하면 그대로 찾는다.
#    상수는 오타를 막고 에디터 자동완성을 받기 위한 것이지 흰 목록이 아니다.

const CLOSE := &"close"
const BACK := &"back"
const FORWARD := &"forward"
const UP := &"up"
const DOWN := &"down"
const CHEVRON_LEFT := &"chevron_left"
const CHEVRON_RIGHT := &"chevron_right"
const CHEVRON_UP := &"chevron_up"
const CHEVRON_DOWN := &"chevron_down"
const MENU := &"menu"
const MORE := &"more"
const EXTERNAL := &"external"
const EXPAND := &"expand"
const COLLAPSE := &"collapse"

const CHECK := &"check"
const INFO := &"info"
const WARNING := &"warning"
const ERROR := &"error"
const SUCCESS := &"success"
const HELP := &"help"
const BELL := &"bell"
const CLOCK := &"clock"
const HOURGLASS := &"hourglass"

const USER := &"user"
const USERS := &"users"
const USER_PLUS := &"user_plus"
const CHAT := &"chat"
const HEART := &"heart"
const STAR := &"star"
const CROWN := &"crown"

const SETTINGS := &"settings"
const SLIDERS := &"sliders"
const DISPLAY := &"display"
const MOBILE := &"mobile"
const VOLUME_HIGH := &"volume_high"
const VOLUME_LOW := &"volume_low"
const VOLUME_OFF := &"volume_off"
const EYE := &"eye"
const EYE_OFF := &"eye_off"
const SUN := &"sun"
const MOON := &"moon"
const GLOBE := &"globe"

const PLUS := &"plus"
const MINUS := &"minus"
const TRASH := &"trash"
const EDIT := &"edit"
const SAVE := &"save"
const REFRESH := &"refresh"
const SEARCH := &"search"
const FILTER := &"filter"
const SORT := &"sort"
const COPY := &"copy"
const DOWNLOAD := &"download"
const UPLOAD := &"upload"
const PLAY := &"play"
const PAUSE := &"pause"
const STOP := &"stop"
const POWER := &"power"
const LOGOUT := &"logout"
const LOGIN := &"login"

const LOCK := &"lock"
const UNLOCK := &"unlock"
const SHIELD := &"shield"
const SHIELD_CHECK := &"shield_check"
const KEY := &"key"

const HOME := &"home"
const MAP := &"map"
const LOCATION := &"location"
const BAG := &"bag"
const BOX := &"box"
const COIN := &"coin"
const GIFT := &"gift"
const BOOK := &"book"

const LIST := &"list"
const GRID := &"grid"
const COLUMNS := &"columns"
const CHART := &"chart"

const SWORD := &"sword"
const BOLT := &"bolt"
const TARGET := &"target"
const FLAG := &"flag"
const POTION := &"potion"
const SKULL := &"skull"
const RUN := &"run"

# ── 세트 내용 ──────────────────────────────────────────────────────────

## 사람이 읽는 세트 이름 — 에디터 인스펙터와 갤러리 예제가 보여 준다.
@export var set_name := ""

## 출처·라이선스 한 줄. 🛑 남의 아이콘을 넣었다면 **여기에 반드시 적는다** — 배포판의
##    `THIRD_PARTY_NOTICES.md` 가 이 칸을 근거로 쓰인다.
@export_multiline var attribution := ""

## 이름 → `Texture2D`. gohud 기본 세트가 쓰는 방식이다.
@export var textures: Dictionary[StringName, Texture2D] = {}

## 아이콘 폰트. `codepoints` 와 짝이다.
@export var font: Font

## 이름 → 유니코드 코드포인트(정수). Font Awesome 의 `0xf00d` 같은 값을 그대로 넣는다.
@export var codepoints: Dictionary[StringName, int] = {}

## 아이콘 폰트의 글리프는 보통 네모 칸보다 작게 그려진다 — 요청한 크기에 이 값을 곱해
## 텍스처 아이콘과 눈에 보이는 크기를 맞춘다. 1.0 이면 보정 없음.
@export_range(0.5, 2.0, 0.01) var font_size_ratio := 1.0

## 이 세트에 없는 이름을 찾아 볼 다음 세트. 기본 세트를 여기 두면 **몇 개만 덮어쓰는**
## 부분 교체가 된다. 🛑 순환으로 연결하지 말 것(A→B→A) — `_seen` 가드가 막지만 낭비다.
@export var fallback: GoIconSet

## 텍스처 아이콘에 곱할 기본 색. 투명이면 부르는 쪽이 준 색을 그대로 쓴다.
@export var tint := Color.TRANSPARENT


# ── 조회 ───────────────────────────────────────────────────────────────

## 이 이름을 그릴 수 있는가(폴백 포함).
func has_icon(icon: StringName) -> bool:
	return not _resolve(icon, {}).is_empty()


## 텍스처 아이콘. 폰트 전용 이름이면 `null` 이다 — 부르는 쪽은 `node()` 를 쓰는 편이 안전하다.
func texture(icon: StringName) -> Texture2D:
	return _resolve(icon, {}).get("texture")


## 아이콘 폰트의 문자 한 개. 텍스처 전용 이름이면 빈 문자열이다.
func glyph(icon: StringName) -> String:
	var found := _resolve(icon, {})
	return String.chr(found.codepoint) if found.has("codepoint") else ""


## 이 이름을 그리는 폰트(폴백 세트의 폰트일 수 있다).
func glyph_font(icon: StringName) -> Font:
	return _resolve(icon, {}).get("font")


## 🎯 **통일 API** — 이름 하나로 그릴 준비가 된 `Control` 을 얻는다.
## 세트가 텍스처면 `TextureRect`, 아이콘 폰트면 `Label` 이 나온다. 부르는 쪽은 구별할 필요가 없다.
##
## `size` 는 dp(= Theme 상수와 같은 좌표계)이고, 노드는 정확히 그 정사각형을 최소 크기로 잡는다 —
## 아이콘마다 폭이 달라 글자 시작 위치가 줄마다 흔들리는 것을 막는다.
func node(icon: StringName, size: int, ink := Color.TRANSPARENT) -> Control:
	var found := _resolve(icon, {})
	var color := ink if ink.a > 0 else (tint if tint.a > 0 else Color.WHITE)
	if found.has("texture"):
		var rect := TextureRect.new()
		rect.name = "Icon"
		rect.texture = found.texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(size, size)
		rect.modulate = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 🛑 아이콘은 언어를 따라 좌우가 뒤집히면 안 된다(닫기 ×, 톱니). 방향을 뒤집어야 하는
		#    것은 `back`/`forward` 뿐이고, 그것은 부르는 쪽이 이름을 바꿔 고른다.
		rect.layout_direction = Control.LAYOUT_DIRECTION_LTR
		return rect
	var label := Label.new()
	label.name = "Icon"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(size, size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.add_theme_color_override(&"font_color", color)
	if found.has("codepoint"):
		label.text = String.chr(found.codepoint)
		if found.has("font"): label.add_theme_font_override(&"font", found.font)
		label.add_theme_font_size_override(&"font_size", maxi(1, roundi(size * float(found.get("ratio", 1.0)))))
	else:
		# 🛑 이름을 못 찾았다 — **빈 칸을 돌려주되 자리는 차지한다.** 아이콘 하나가 없다고
		#    줄 전체가 밀리면 원인을 찾기 어렵다. 개발 중에는 아래 경고로 알아챈다.
		label.text = ""
		if OS.is_debug_build() and not icon.is_empty():
			push_warning("[gohud] 아이콘 세트에 '%s' 이(가) 없습니다 (세트: %s)" % [icon, set_name if not set_name.is_empty() else resource_path])
	return label


## 이 세트가 담고 있는 모든 이름(폴백 포함, 정렬됨). 갤러리 예제와 검사가 쓴다.
func icon_names() -> PackedStringArray:
	var names := {}
	_collect(names, {})
	var list := PackedStringArray(names.keys())
	list.sort()
	return list


func _collect(into: Dictionary, seen: Dictionary) -> void:
	if seen.has(get_instance_id()): return
	seen[get_instance_id()] = true
	for key in textures: into[String(key)] = true
	for key in codepoints: into[String(key)] = true
	if fallback != null: fallback._collect(into, seen)


## 이름 하나를 어디서 어떻게 그릴지 결정한다. 텍스처 → 코드포인트 → 폴백 순이다.
## **빈 Dictionary 가 "그릴 수 없다"** 는 뜻이다(`-> Dictionary` 는 null 을 담지 못한다).
func _resolve(icon: StringName, seen: Dictionary) -> Dictionary:
	if seen.has(get_instance_id()): return {}   # 세트를 순환으로 엮었다 — 없는 것으로 본다
	seen[get_instance_id()] = true
	var found: Texture2D = textures.get(icon)
	if found != null: return {"texture": found}
	if codepoints.has(icon):
		var entry := {"codepoint": int(codepoints[icon]), "ratio": font_size_ratio}
		if font != null: entry["font"] = font
		return entry
	if fallback != null: return fallback._resolve(icon, seen)
	return {}
