## ⏸️ **A HUD corner button** — a picture button (a painted round pause button) with the key that does the same thing
## on a cap beside it ("Esc"), for keyboard players. Hide the hint on a touch screen with `show_hint = false`.
##
## ```gdscript
## var pause := GoHudButton.make(GoUi.skin().widget_art(&"pause_button"), 52.0, tr("HUD_PAUSE_KEY"))
## pause.pressed.connect(open_pause_menu)    # the game decides what a press does
## pause.show_hint = not touch_mode
## corner.add_child(pause)
## ```
##
## The button is a `GoIconButton` with `art` (no frame, darker while pressed) that never keeps focus — Space must still
## reach the game. The hint's cap is `GoSkin.hud_key_hint_box()` and its word `GoSkin.hud_key_hint_ink()`.
## 🛑 Display only: the button reports a press; it does not pause anything.
@tool
class_name GoHudButton
extends HBoxContainer

## The button was pressed.
signal pressed

## The picture that is the button.
@export var art: Texture2D = null:
	set(value):
		art = value
		if is_instance_valid(button): button.art = value

## The button's side (dp).
@export_range(16, 256) var button_size := 52:
	set(value):
		button_size = value
		if is_instance_valid(button): button.visual_size = value

## The key on the cap (a key name: never translated). Empty hides the cap.
@export var hint_text := "":
	set(value):
		hint_text = value
		_sync_hint()

## Whether the cap shows — off on a touch screen.
@export var show_hint := true:
	set(value):
		show_hint = value
		_sync_hint()

## The cap's font size (dp).
@export_range(6, 64) var hint_size := 14:
	set(value):
		hint_size = value
		_restyle()

## Room between the cap and the button (dp).
@export_range(0, 64) var gap := 8:
	set(value):
		gap = value
		add_theme_constant_override(&"separation", gap)

## The button — a `GoIconButton` showing `art`.
var button: GoIconButton
var _hint: Label


## A corner button showing [param picture] at [param side] dp, with [param key] on a cap beside it.
static func make(picture: Texture2D, side := 52.0, key := "") -> GoHudButton:
	var node := GoHudButton.new()
	node.art = picture
	node.button_size = int(side)
	node.hint_text = key
	return node


func _init() -> void:
	name = "HudButton"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", gap)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.text_direction = Control.TEXT_DIRECTION_LTR
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_hint)
	button = GoIconButton.new()
	button.name = "Button"
	button.keyboard_focus = false
	button.visual_size = button_size
	button.art = art
	button.pressed.connect(func() -> void: pressed.emit())
	add_child(button)
	_sync_hint()


func _ready() -> void:
	theme = GoUi.theme()
	GoUi.watch(_restyle)
	_restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


func _sync_hint() -> void:
	if not is_instance_valid(_hint): return
	_hint.text = hint_text
	_hint.visible = show_hint and not hint_text.is_empty()


func _restyle() -> void:
	if not is_instance_valid(_hint): return
	var skin := GoUi.skin()
	_hint.add_theme_stylebox_override(&"normal", skin.hud_key_hint_box())
	_hint.add_theme_color_override(&"font_color", skin.hud_key_hint_ink())
	_hint.add_theme_font_size_override(&"font_size", hint_size)
