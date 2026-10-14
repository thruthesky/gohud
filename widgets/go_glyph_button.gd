## 🔘 **A button with a glyph right beside its label** — the glossy pills of an arcade menu: the glyph is
## [constant GLYPH_SHARE] of the button's height, and glyph + gap + label stand centred together.
##
## ```gdscript
## var play := GoGlyphButton.make("Play", GoIconSet.PLAY, GoTheme.VAR_PRIMARY_BUTTON)
## var own := GoGlyphButton.make("Shop", &"", GoTheme.VAR_BUTTON, preload("res://ui/cart.png"))
## ```
##
## 🛑 `Button.icon` cannot do this: LEFT pins the glyph to the button's edge and CENTER draws it over the text. The
##    label stays a plain `text`, so translation and tests work as on any button. The label moves right by half the
##    glyph's room (the faces are wrapped to move that much content margin from the right side to the left), so the
##    button's minimum size does not change unless the shift is wider than the right padding.
@tool
class_name GoGlyphButton
extends Button

## Glyph size as a share of the button's height.
const GLYPH_SHARE := 0.62
## The space between glyph and label.
const GAP := 8.0
## The glyph never comes closer to the left edge than this.
const MIN_EDGE := 12.0
## How far the glyph drops while pressed (the face's press travel).
const PRESS_DROP := 2.0
## The faces that place the label (focus is drawn over them and places nothing).
const TEXT_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]

## The glyph. Empty: the icon set's [member glyph_icon].
@export var glyph: Texture2D:
	set(value):
		glyph = value
		_update_shift()
		queue_redraw()

## An icon-set name used when [member glyph] is empty (`GoIconSet.PLAY`…). 🛑 It needs a texture icon set — a font
## icon has no texture, and the button then shows its label alone.
@export var glyph_icon: StringName = &"":
	set(value):
		glyph_icon = value
		_update_shift()
		queue_redraw()

var _shift := 0.0
var _shifting := false


## A face drawn as [param from] with [param shift] of content margin moved from its right side to its left.
class ShiftedBox:
	extends StyleBox

	var base: StyleBox
	## The face it wraps was the button's own override (put back when the wrapper comes off).
	var was_override := false

	func _init(from: StyleBox = null, shift := 0.0) -> void:
		base = from
		if from == null: return
		# The label's centre moves right by `shift`. A negative margin would read as "unset", so what the right padding
		# cannot give goes on the left twice over: the label still lands centred with its glyph, and the button grows.
		var taken := minf(shift, from.get_margin(SIDE_RIGHT))
		content_margin_left = from.get_margin(SIDE_LEFT) + 2.0 * shift - taken
		content_margin_right = from.get_margin(SIDE_RIGHT) - taken
		content_margin_top = from.get_margin(SIDE_TOP)
		content_margin_bottom = from.get_margin(SIDE_BOTTOM)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if base != null: base.draw(to_canvas_item, rect)

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return base.get_draw_rect(rect) if base != null else rect


func _init() -> void:
	theme_type_variation = GoTheme.VAR_BUTTON


static func make(label: String, icon: StringName = &"", variation: StringName = GoTheme.VAR_BUTTON,
		texture: Texture2D = null) -> GoGlyphButton:
	var node := GoGlyphButton.new()
	node.text = label
	node.theme_type_variation = variation
	node.glyph_icon = icon
	node.glyph = texture
	return node


## The texture drawn: [member glyph], else the icon set's [member glyph_icon] (null when neither gives one).
func glyph_texture() -> Texture2D:
	if glyph != null: return glyph
	if glyph_icon.is_empty(): return null
	return GoUi.icons().texture(glyph_icon)


## The width the glyph takes beside the label on a button [param height] tall (negative: its height now).
func glyph_allowance(height := -1.0) -> float:
	var art := glyph_texture()
	if art == null: return 0.0
	var tall := (size.y if height < 0.0 else height) * GLYPH_SHARE
	return tall * art.get_width() / maxf(1.0, maxf(art.get_width(), art.get_height())) + GAP


## Where the glyph is drawn now, in the button's space.
func glyph_rect() -> Rect2:
	var art := glyph_texture()
	if art == null: return Rect2()
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
	var box := size.y * GLYPH_SHARE
	var ratio := box / maxf(1.0, maxf(art.get_width(), art.get_height()))
	var drawn := Vector2(art.get_width(), art.get_height()) * ratio
	# The button centres the label in the state face's content rect; the glyph goes just left of it.
	var face := get_theme_stylebox(_state_name())
	var left := face.get_margin(SIDE_LEFT) if face != null else 0.0
	var right := face.get_margin(SIDE_RIGHT) if face != null else 0.0
	var x := (left + size.x - right) * 0.5 - text_width * 0.5 - GAP - drawn.x
	if text.is_empty(): x = (size.x - drawn.x) * 0.5
	x = maxf(x, MIN_EDGE)
	var pressed := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	return Rect2(Vector2(x, (size.y - drawn.y) * 0.5 - 1.0 + (PRESS_DROP if pressed else 0.0)), drawn)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if not is_equal_approx(_shift, glyph_allowance() * 0.5): _update_shift()
		NOTIFICATION_THEME_CHANGED:
			if not _shifting: _update_shift()
		NOTIFICATION_DRAW:
			_draw_glyph()


## Re-wraps the theme's faces with the current shift (or drops the wrappers when there is no glyph).
func _update_shift() -> void:
	if _shifting: return
	_shifting = true
	_shift = glyph_allowance() * 0.5
	begin_bulk_theme_override()
	for state in TEXT_STATES:
		if has_theme_stylebox_override(state) and get_theme_stylebox(state) is ShiftedBox:
			var wrapper := get_theme_stylebox(state) as ShiftedBox
			remove_theme_stylebox_override(state)
			if wrapper.was_override and wrapper.base != null: add_theme_stylebox_override(state, wrapper.base)
	if _shift > 0.0:
		for state in TEXT_STATES:
			var face := get_theme_stylebox(state)
			if face == null: continue
			var wrapper := ShiftedBox.new(face, _shift)
			wrapper.was_override = has_theme_stylebox_override(state)
			add_theme_stylebox_override(state, wrapper)
	end_bulk_theme_override()
	_shifting = false


func _draw_glyph() -> void:
	var art := glyph_texture()
	if art == null: return
	draw_texture_rect(art, glyph_rect(), false, _glyph_tint())


## The glyph's colour: the theme's icon colour for the state (white glyphs read as drawn on the arcade pills).
func _glyph_tint() -> Color:
	var key := &"icon_normal_color"
	match get_draw_mode():
		DRAW_PRESSED: key = &"icon_pressed_color"
		DRAW_HOVER: key = &"icon_hover_color"
		DRAW_HOVER_PRESSED: key = &"icon_hover_pressed_color"
		DRAW_DISABLED: key = &"icon_disabled_color"
	return get_theme_color(key) if has_theme_color(key) else Color.WHITE


func _state_name() -> StringName:
	match get_draw_mode():
		DRAW_PRESSED: return &"pressed"
		DRAW_HOVER: return &"hover"
		DRAW_HOVER_PRESSED: return &"hover_pressed"
		DRAW_DISABLED: return &"disabled"
	return &"normal"
