## 🔘 **A button that is only an icon.** Small on screen, 48dp to the finger.
##
## ## Why the two are separated
## A close button in a header must not look bigger than the title. But make it a 36dp square and a finger
## cannot hit it. So **the node is `visual_size` (small) and the hit test reaches beyond the node**.
##
## ```gdscript
## var mark := GoIconButton.new()
## mark.visual_size = 36          # the size on screen
## mark.set_icon_name(GoIconSet.CLOSE)
## # touch widens automatically to GoConfig.min_touch_size (48 by default)
## ```
##
## 🛑 This is only safe **while the siblings do not take input** — where the widened area covers the button
##    next to it, that button stops being pressable. It assumes siblings that take no input, like a header's
##    title label. When you put **several icon buttons side by side**, tell them about each other with `touch_peers`.
@tool
class_name GoIconButton
extends Button

## Side of the visible square (dp). The hit test can be larger than this.
@export var visual_size := 36:
	set(value):
		visual_size = maxi(8, value)
		custom_minimum_size = Vector2.ONE * visual_size
		_refresh_icon()

## Icon name (`GoIconSet.CLOSE` and so on).
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_refresh_icon()

## Icon colour. Transparent follows the theme's `GoIconButton` colour.
@export var icon_tint := Color.TRANSPARENT:
	set(value):
		icon_tint = value
		_refresh_icon()

## Draw a texture icon at **its native pixel size** — the default scales it to 58% of `visual_size` (the same size as a font glyph).
## Turn it on where the host wants its own SVG size kept: scaling up and down differs by 1px (measured by pixel comparison).
@export var native_texture_size := false:
	set(value):
		native_texture_size = value
		_refresh_icon()

## The gohud string name to use as the tooltip (translated through `GoUi.text`). Empty means no tooltip.
@export var tooltip_text_name: StringName = &"":
	set(value):
		tooltip_text_name = value
		_refresh_tooltip()

## The sibling icon buttons placed alongside. Where the widened hit areas overlap, **whichever centre is nearer** takes the press.
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
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **only the widgets already on screen stay on the old theme** (measured 2026-09-16).
## 🔑 The icon **set** can change entirely — the same name becomes a different picture and a different mechanism (texture ↔ font).
func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_refresh_icon()
	_refresh_tooltip()


## Set the icon by name (the same as `icon_name`, under a name that reads better from code).
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
		# A texture set — the engine's `Button.icon` path handles colour and state through the theme.
		icon = found
		# 🛑 An icon-only button centres — `Button` aligns left by default, so without expanding, the icon sticks
		#    to the left (measured by pixel comparison 2026-09-12: a native-size texture was pushed sideways).
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if native_texture_size:
			expand_icon = false
			remove_theme_constant_override(&"icon_max_width")
		else:
			expand_icon = true
			# 🛑 `expand_icon` on its own makes the icon fill the button — tie it to the glyph size with the `icon_max_width` theme constant.
			add_theme_constant_override(&"icon_max_width", glyph_size)
		custom_minimum_size = Vector2.ONE * visual_size
		if icon_tint.a > 0: add_theme_color_override(&"icon_normal_color", icon_tint)
		return
	# A font set — drawn as a child label. Centring is measured against the whole rect.
	# 🛑 The button theme's `icon_normal_color` **does not reach** a child label. Pass no colour and the icon
	#    set draws in white, which on a light theme gives a white glyph on a white panel — that really happened
	#    on the quick slots (2026-09-13). Pass the same colour the texture path uses.
	var glyph_ink := icon_tint
	if glyph_ink.a <= 0:
		glyph_ink = get_theme_color(&"icon_normal_color") if has_theme_color(&"icon_normal_color") \
			else GoUi.color(GoTheme.SECONDARY)
	_glyph = icon_set.node(icon_name, glyph_size, glyph_ink)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph)


## 🛑 When its width calculation goes wrong, the engine's default tooltip breaks the text into **one character
##    per line** — and the tooltip is an icon button's only explanation, so it becomes unreadable. Build our own to gohud's spec.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	return GoStyle.tooltip_node(for_text)


func _refresh_tooltip() -> void:
	var words := GoUi.text(tooltip_text_name) if not tooltip_text_name.is_empty() else ""
	tooltip_text = words
	# ♿ An icon-only button has no text for a screen reader — give the Godot 4.5+ accessibility name the same wording.
	accessibility_name = words


## Take presses in the slack beyond the node — whatever the visible size, the real touch target is `min_touch_size`.
func _has_point(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)
	if not Rect2(Vector2.ZERO, size).grow(reach).has_point(point): return false
	if touch_peers.is_empty(): return true
	# The widened areas overlap — whichever centre is nearer takes it. That keeps one point from pressing two buttons.
	var here := (point + global_position - get_global_rect().get_center()).length()
	for peer in touch_peers:
		if peer == self or not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		if (point + global_position - peer.get_global_rect().get_center()).length() < here: return false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh_tooltip()
