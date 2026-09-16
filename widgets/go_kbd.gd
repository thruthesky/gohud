## ⌨️ **Key caps** — show "press this key" in PC and Steam builds.
##
## ```gdscript
## row.add_child(GoKbd.make("F"))                    # F
## row.add_child(GoKbd.make("Ctrl", "S"))            # Ctrl + S
## hint.add_child(GoKbd.for_action(&"interact"))     # reads the key that is actually bound
## ```
##
## ## 🔑 With `for_action()` the hint follows a rebind
## Hardcode the text and the old key keeps being advertised after the player rebinds — **the most common lie in a UI**.
## Read it out of `InputMap` and that never happens.
##
## ## 🛑 Hidden in touch builds
## A phone has no keyboard. With `hide_on_handheld` (on by default) it removes itself on handheld devices —
## no need for `if OS.has_feature("android")` on every screen.
##
## ## 🛑 Key names are never translated
## `Ctrl`, `Shift` and `F` can only be found if they read exactly as engraved on the keyboard. Auto-translation is off.
@tool
class_name GoKbd
extends HBoxContainer

## Whether it hides itself on handheld devices (Android, iOS).
@export var hide_on_handheld := true:
	set(value):
		hide_on_handheld = value
		_sync_visible()

var _keys: PackedStringArray = []


func _init() -> void:
	name = "Kbd"
	# 🛑 A key combo is a **physical order** — Ctrl does not move to the right just because the language is Arabic.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	# 🛑 **Never eat the leftover width.** This row only needs to be as wide as two or three keys — let it stretch and
	#    the caps get pushed apart inside it (shot 2026-09-16: `Ctrl` sat at the far left, `S` against the right edge of the screen).
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_rebuild()
	_sync_visible()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## One key cap, or a combo (`Ctrl` + `S`). For more pieces, hand an array to `set_keys()`.
## 🛑 GDScript has no varargs — three slots cover every combo that actually occurs (`Ctrl`+`Shift`+`S`).
static func make(first: String, second := "", third := "") -> GoKbd:
	var node := GoKbd.new()
	node.set_keys([first, second, third])
	return node


## Reads the key **actually bound** to an `InputMap` action and builds caps out of it.
##
## 🛑 If the action does not exist, or is not bound to the keyboard, it returns an **empty** one (which hides) —
##    putting a word like "none" on a gamepad-only action would be its own kind of lie.
static func for_action(action: StringName) -> GoKbd:
	var node := GoKbd.new()
	node.set_keys(action_keys(action))
	return node


## The first keyboard event bound to the action, as human-readable pieces. Empty array if there is none.
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


## The keys to show. An empty array hides it.
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
	# ♿ A screen reader does better with one phrase, "control s" — read cap by cap it comes out chopped up.
	# 🔑 `+` is the **convention for reading** a key combo, so it stays between the pieces (unlike `GoUi.spoken`, which joins with spaces).
	var spoken: Array[String] = []
	for key in _keys: spoken.append(key)
	accessibility_name = " + ".join(spoken)


## A cap with one key engraved on it.
func _cap(word: String) -> Control:
	var box := PanelContainer.new()
	box.name = "Cap"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override(&"panel", GoUi.skin().chip_box(GoUi.color(GoTheme.BORDER)))
	var text := GoStyle.label(word, GoTheme.ROLE_MICRO, GoUi.color(GoTheme.SECONDARY))
	# 🛑 Key names are **never translated** — they can only be found if they read exactly as engraved on the keyboard.
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.text_direction = Control.TEXT_DIRECTION_LTR
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 🛑 **Never wrap.** `Ctrl` split into `Ctr` / `l` and the cap became two lines (shot 2026-09-16).
	#    A key name is not a word but the **symbol engraved on the key** — it must not break anywhere.
	#    `GoStyle.natural_width()` is the canonical form of this rule (it turns wrapping off and stops it eating leftover width, together).
	GoStyle.natural_width(text)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Single-letter keys stay square too — caps of different widths for `W` and `I` make the row ragged.
	# 🛑 **Measure the width the text needs.** Give only a minimum width and leave the rest to natural sizing, and the
	#    moment panel padding squeezes the text cell it is back to two lines — wrapping off still clips or folds when the width falls short.
	var size := GoUi.font_size(GoTheme.ROLE_MICRO)
	var side := float(size) * 1.6
	var font := text.get_theme_font(&"font")
	var natural := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if font != null else side
	text.custom_minimum_size.x = maxf(side, natural)
	box.add_child(text)
	return box


## The `+` between caps.
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
