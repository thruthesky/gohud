## 🔘 **아이콘만 있는 버튼.** 보이는 크기는 작게, 누를 수 있는 범위는 48dp 로.
##
## ## 왜 둘을 나누나
## 헤더의 닫기 버튼이 제목보다 커 보이면 안 된다. 그렇다고 36dp 짜리 사각형으로 만들면
## 손가락으로 못 누른다. 그래서 **노드는 `visual_size`(작게), 히트 판정은 노드 밖까지** 넓힌다.
##
## ```gdscript
## var mark := GoIconButton.new()
## mark.visual_size = 36          # 보이는 크기
## mark.set_icon_name(GoIconSet.CLOSE)
## # 터치는 GoConfig.min_touch_size(기본 48)까지 자동으로 넓어진다
## ```
##
## 🛑 이 방식은 **형제가 입력을 받지 않을 때만** 안전하다 — 넓힌 영역이 옆 버튼을 덮으면
##    옆 버튼이 안 눌린다. 헤더의 제목 라벨처럼 입력을 받지 않는 형제 옆에 두는 것이 전제다.
##    아이콘 버튼을 **나란히 여러 개** 둘 때는 `touch_peers` 로 서로를 알려 준다.
@tool
class_name GoIconButton
extends Button

## 보이는 정사각형의 한 변(dp). 히트 판정은 이보다 클 수 있다.
@export var visual_size := 36:
	set(value):
		visual_size = maxi(8, value)
		custom_minimum_size = Vector2.ONE * visual_size
		_refresh_icon()

## 아이콘 이름(`GoIconSet.CLOSE` 등).
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_refresh_icon()

## 아이콘 색. 투명이면 테마의 `GoIconButton` 색을 따른다.
@export var icon_tint := Color.TRANSPARENT:
	set(value):
		icon_tint = value
		_refresh_icon()

## 텍스처 아이콘을 **원래 픽셀 크기**로 그린다 — 기본은 `visual_size` 의 58% 로 늘린다(폰트 글리프와 같은 크기).
## 호스트가 자기 SVG 크기를 그대로 쓰고 싶을 때 켠다: 늘리고 줄이면 1px 차이가 난다(픽셀 대조 실측).
@export var native_texture_size := false:
	set(value):
		native_texture_size = value
		_refresh_icon()

## 툴팁으로 쓸 gohud 문구 이름(`GoUi.text` 로 번역한다). 비우면 툴팁 없음.
@export var tooltip_text_name: StringName = &"":
	set(value):
		tooltip_text_name = value
		_refresh_tooltip()

## 나란히 놓인 형제 아이콘 버튼들. 넓힌 히트 영역이 겹치면 **중심이 더 가까운 쪽**이 가져간다.
var touch_peers: Array[Control] = []

var _glyph: Control


func _init() -> void:
	theme_type_variation = GoTheme.VAR_ICON_BUTTON
	custom_minimum_size = Vector2.ONE * visual_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	clip_text = false


func _ready() -> void:
	theme = GoUi.theme()
	_refresh_icon()
	_refresh_tooltip()


## 아이콘을 이름으로 정한다(`icon_name` 과 같지만 코드에서 부르기 좋은 이름).
func set_icon_name(value: StringName) -> void:
	icon_name = value


func _refresh_icon() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint(): return
	if is_instance_valid(_glyph):
		_glyph.queue_free()
		_glyph = null
	icon = null
	if icon_name.is_empty(): return
	var glyph_size := maxi(8, roundi(visual_size * 0.58))
	var icon_set := GoUi.icons()
	var found := icon_set.texture(icon_name)
	if found != null:
		# 텍스처 세트 — 엔진의 `Button.icon` 경로가 색·상태까지 테마로 처리한다.
		icon = found
		# 🛑 아이콘만 있는 버튼은 가운데 — `Button` 기본은 왼쪽 정렬이라, 늘리지 않으면 아이콘이 왼쪽에 붙는다
		#    (2026-09-12 픽셀 대조 실측: 원래 크기 텍스처가 가로로 밀렸다).
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if native_texture_size:
			expand_icon = false
			remove_theme_constant_override(&"icon_max_width")
		else:
			expand_icon = true
			# 🛑 `expand_icon` 만 켜면 아이콘이 버튼을 꽉 채운다 — 테마 상수 `icon_max_width` 로 글리프 크기에 묶는다.
			add_theme_constant_override(&"icon_max_width", glyph_size)
		custom_minimum_size = Vector2.ONE * visual_size
		if icon_tint.a > 0: add_theme_color_override(&"icon_normal_color", icon_tint)
		return
	# 폰트 세트 — 자식 라벨로 그린다. 가운데 정렬은 전체 사각형 기준이다.
	# 🛑 자식 라벨에는 버튼 테마의 `icon_normal_color` 가 **닿지 않는다.** 색을 안 넘기면 아이콘
	#    세트가 흰색으로 그리므로, 밝은 테마에서는 흰 판에 흰 글리프가 된다 — 퀵슬롯에서 실제로
	#    그랬다(2026-09-13). 텍스처 경로가 쓰는 색과 같은 것을 넘긴다.
	var glyph_ink := icon_tint
	if glyph_ink.a <= 0:
		glyph_ink = get_theme_color(&"icon_normal_color") if has_theme_color(&"icon_normal_color") \
			else GoUi.color(GoTheme.SECONDARY)
	_glyph = icon_set.node(icon_name, glyph_size, glyph_ink)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph)


## 🛑 엔진 기본 툴팁은 폭 계산이 어긋나면 글자를 **한 자씩 세로로** 쪼갠다 — 아이콘 버튼에게
##    툴팁은 유일한 설명인데 그러면 읽을 수가 없다. gohud 규격으로 직접 만든다.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	return GoStyle.tooltip_node(for_text)


func _refresh_tooltip() -> void:
	var words := GoUi.text(tooltip_text_name) if not tooltip_text_name.is_empty() else ""
	tooltip_text = words
	# ♿ 아이콘만 있는 버튼은 화면 낭독기가 읽을 글자가 없다 — Godot 4.5+ 접근성 이름에 같은 문구를 준다.
	accessibility_name = words


## 노드 밖 여유까지 누름으로 받는다 — 보이는 크기와 별개로 실제 터치는 `min_touch_size` 다.
func _has_point(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)
	if not Rect2(Vector2.ZERO, size).grow(reach).has_point(point): return false
	if touch_peers.is_empty(): return true
	# 넓힌 영역이 겹쳤다 — 중심이 더 가까운 쪽이 가져간다. 그래야 한 점이 두 버튼을 누르지 않는다.
	var here := (point + global_position - get_global_rect().get_center()).length()
	for peer in touch_peers:
		if peer == self or not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		if (point + global_position - peer.get_global_rect().get_center()).length() < here: return false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh_tooltip()
