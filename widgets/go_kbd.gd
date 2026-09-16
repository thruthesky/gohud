## ⌨️ **키 캡** — PC·Steam 빌드에서 "이 키를 누르세요" 를 보여 준다.
##
## ```gdscript
## row.add_child(GoKbd.make("F"))                    # F
## row.add_child(GoKbd.make("Ctrl", "S"))            # Ctrl + S
## hint.add_child(GoKbd.for_action(&"interact"))     # 실제로 묶여 있는 키를 읽어 온다
## ```
##
## ## 🔑 `for_action()` 을 쓰면 키를 바꿔도 안내가 따라온다
## 글자를 손으로 박아 두면 플레이어가 키를 바꾼 뒤에도 옛 키가 안내된다 — **가장 흔한 거짓말**이다.
## `InputMap` 에서 읽어 오면 그 일이 없다.
##
## ## 🛑 터치 빌드에서는 숨긴다
## 폰에는 키보드가 없다. `hide_on_handheld`(기본 켜짐)이면 손에 드는 기기에서 스스로 사라진다 —
## 화면마다 `if OS.has_feature("android")` 를 쓰지 않아도 된다.
##
## ## 🛑 키 이름은 번역하지 않는다
## `Ctrl`·`Shift`·`F` 는 키보드에 새겨진 그대로여야 찾을 수 있다. 자동 번역을 끈다.
@tool
class_name GoKbd
extends HBoxContainer

## 손에 드는 기기(Android·iOS)에서 스스로 숨을 것인가.
@export var hide_on_handheld := true:
	set(value):
		hide_on_handheld = value
		_sync_visible()

var _keys: PackedStringArray = []


func _init() -> void:
	name = "Kbd"
	# 🛑 키 조합은 **물리적 순서**다 — 아랍어라고 Ctrl 이 오른쪽으로 가지 않는다.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	# 🛑 **남는 폭을 먹지 않는다.** 이 줄은 키 두세 개만큼만 넓으면 된다 — 늘어나면 그 안에서
	#    캡들이 서로 밀려난다(2026-09-16 촬영: `Ctrl` 은 왼쪽 끝, `S` 는 화면 오른쪽 끝에 붙었다).
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_rebuild()
	_sync_visible()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 키 캡 하나 또는 조합(`Ctrl` + `S`). 조각이 더 필요하면 `set_keys()` 에 배열을 준다.
## 🛑 GDScript 에는 가변 인자가 없다 — 세 자리면 실제 조합(`Ctrl`+`Shift`+`S`)을 다 덮는다.
static func make(first: String, second := "", third := "") -> GoKbd:
	var node := GoKbd.new()
	node.set_keys([first, second, third])
	return node


## `InputMap` 의 액션에 **실제로 묶여 있는** 키를 읽어 캡으로 만든다.
##
## 🛑 그 액션이 없거나 키보드에 묶여 있지 않으면 **빈 것**을 돌려준다(숨는다) — 게임패드 전용
##    액션에 "없음" 같은 글자를 띄우면 그것대로 거짓말이다.
static func for_action(action: StringName) -> GoKbd:
	var node := GoKbd.new()
	node.set_keys(action_keys(action))
	return node


## 액션에 묶인 첫 키보드 입력을 사람이 읽는 조각들로. 없으면 빈 배열.
static func action_keys(action: StringName) -> Array:
	if not InputMap.has_action(action): return []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null: continue
		var parts: Array = []
		if key.ctrl_pressed: parts.append("Ctrl")
		if key.alt_pressed: parts.append("Alt")
		if key.shift_pressed: parts.append("Shift")
		if key.meta_pressed: parts.append("Cmd" if OS.has_feature("macos") else "Meta")
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var name := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code)) \
			if key.physical_keycode != KEY_NONE else OS.get_keycode_string(code)
		if not name.is_empty(): parts.append(name)
		if not parts.is_empty(): return parts
	return []


## 보여 줄 키들. 빈 배열이면 숨는다.
func set_keys(keys: Array) -> void:
	_keys = PackedStringArray()
	for key in keys:
		var word := str(key).strip_edges()
		if not word.is_empty(): _keys.append(word)
	_rebuild()
	_sync_visible()


func keys() -> PackedStringArray:
	return _keys


func _rebuild() -> void:
	for child in get_children(): child.queue_free()
	for index in _keys.size():
		if index > 0: add_child(_joiner())
		add_child(_cap(_keys[index]))
	# ♿ 스크린리더에게는 "컨트롤 에스" 처럼 한 마디로 읽히는 편이 낫다 — 캡 하나하나를 따로 읽으면 끊긴다.
	accessibility_name = " + ".join(_keys)


## 키 하나가 새겨진 캡.
func _cap(word: String) -> Control:
	var box := PanelContainer.new()
	box.name = "Cap"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override(&"panel", GoUi.skin().chip_box(GoUi.color(GoTheme.BORDER)))
	var text := GoStyle.label(word, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.SECONDARY))
	# 🛑 키 이름은 **번역하지 않는다** — 키보드에 새겨진 글자 그대로여야 찾을 수 있다.
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.text_direction = Control.TEXT_DIRECTION_LTR
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 🛑 **줄바꿈하지 않는다.** `Ctrl` 이 `Ctr` / `l` 로 쪼개져 캡 두 줄이 되었다(2026-09-16 촬영).
	#    키 이름은 낱말이 아니라 **키에 새겨진 기호**다 — 어디서도 끊으면 안 된다.
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 한 글자 키도 정사각형으로 — `W` 와 `I` 의 캡 폭이 다르면 줄이 들쭉날쭉해진다.
	# 🔑 **최소**만 준다 — `Ctrl` 처럼 긴 이름은 글자 폭만큼 넓어진다.
	var side := float(GoUi.font_size(GoTheme.ROLE_MICRO)) * 1.6
	text.custom_minimum_size.x = side
	# 🛑 캡은 글자만큼만 — `GoStyle.label()` 은 남는 폭을 먹게(EXPAND_FILL) 만들어져 있어,
	#    그대로 두면 캡 하나가 줄 전체를 차지하고 나머지가 밀려난다.
	text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(text)
	return box


## 캡 사이의 `+`.
func _joiner() -> Control:
	var plus := GoStyle.label("+", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	plus.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.autowrap_mode = TextServer.AUTOWRAP_OFF
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return plus


func _sync_visible() -> void:
	visible = not _keys.is_empty() and not (hide_on_handheld and GoUi.is_handheld_platform())


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rebuild()
	_sync_visible()
