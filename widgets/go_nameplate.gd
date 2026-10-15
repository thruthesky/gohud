## 🏷️ **A name plate** — a small rounded tag with a name on it that floats over a character in a 3D world, the same
## size on screen however far away the character is. The player's own plate has its own fill and ink.
##
## ```gdscript
## var plate := GoNameplate.make(character.shown_name(), character.color, character.is_player)
## overlay.add_child(plate)
## # each frame, after the camera has moved:
## plate.follow(camera, character.name_anchor.global_position)   # hidden while the point is behind the camera
## ```
##
## The plate is `base_width` wide, widening to the whole name up to `max_width` (a longer name is clipped). Its box is
## `GoSkin.nameplate_box(fill)` — `fill` is `tint`, or `GoSkin.nameplate_own_fill()` on the own plate — and its name
## `GoSkin.nameplate_ink(own)` with a `GoSkin.nameplate_outline(own)` edge in `GoSkin.nameplate_outline_ink()`.
## 🛑 Display only: the plate shows the name and place it is given.
@tool
class_name GoNameplate
extends PanelContainer

## The name on the plate (shown as given: a player's name is never translated).
@export var text := "":
	set(value):
		text = value
		if is_instance_valid(_label): _label.text = value
		_fit()

## The plate's colour (a character's colour). Transparent means the theme's accent.
@export var tint := Color.TRANSPARENT:
	set(value):
		tint = value
		_restyle()

## The player's own plate — drawn in `GoSkin.nameplate_own_fill()` with its own ink.
@export var own := false:
	set(value):
		own = value
		_restyle()

## The narrowest the plate gets (dp).
@export_range(8, 512) var base_width := 64:
	set(value):
		base_width = value
		_fit()

## The widest the plate gets (dp): a longer name is clipped.
@export_range(8, 512) var max_width := 100:
	set(value):
		max_width = value
		_fit()

## The plate's height (dp).
@export_range(8, 128) var plate_height := 24:
	set(value):
		plate_height = value
		_fit()

## The name's font size (dp).
@export_range(6, 64) var font_size := 14:
	set(value):
		font_size = value
		_restyle()

var _label: Label


## A plate reading [param name_text] in [param color] — [param is_own] for the player's own.
static func make(name_text: String, color := Color.TRANSPARENT, is_own := false) -> GoNameplate:
	var node := GoNameplate.new()
	node.text = name_text
	node.tint = color
	node.own = is_own
	return node


func _init() -> void:
	name = "Nameplate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Name"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.text = text
	add_child(_label)


func _ready() -> void:
	theme = GoUi.theme()
	GoUi.watch(_restyle)
	_restyle()


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## Centres the plate on [param point] (in its parent's coordinates).
func place_at(point: Vector2) -> void:
	position = point - size / 2.0


## Centres the plate on where [param camera] draws [param world_point]; hides it (and returns false) while the point is
## behind the camera or there is no camera.
func follow(camera: Camera3D, world_point: Vector3) -> bool:
	if camera == null or not is_instance_valid(camera) or camera.is_position_behind(world_point):
		visible = false
		return false
	visible = true
	place_at(camera.unproject_position(world_point))
	return true


func _restyle() -> void:
	if not is_instance_valid(_label) or not is_inside_tree(): return
	var skin := GoUi.skin()
	var fill := skin.nameplate_own_fill() if own else (tint if tint.a > 0.0 else GoUi.color(GoTheme.ACCENT))
	add_theme_stylebox_override(&"panel", skin.nameplate_box(fill))
	_label.add_theme_font_size_override(&"font_size", font_size)
	_label.add_theme_color_override(&"font_color", skin.nameplate_ink(own))
	_label.add_theme_color_override(&"font_outline_color", skin.nameplate_outline_ink())
	_label.add_theme_constant_override(&"outline_size", skin.nameplate_outline(own))
	_fit()


func _fit() -> void:
	if not is_instance_valid(_label) or not is_inside_tree(): return
	var font := _label.get_theme_font(&"font")
	var need := 0.0
	if font != null:
		need = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	need += _label.get_theme_constant(&"outline_size")
	var box := get_theme_stylebox(&"panel")
	if box != null: need += box.get_minimum_size().x
	custom_minimum_size = Vector2(clampf(need, base_width, max_width), plate_height)
	size = custom_minimum_size
