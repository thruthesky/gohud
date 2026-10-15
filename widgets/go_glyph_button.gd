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
##    button's minimum size does not change unless the shift is wider than the right padding — then the button grows
##    instead, exactly as Magnet Mayhem's GlossButton. A face thinner than [constant MIN_EDGE] keeps the group centred
##    and the glyph that far from the edge.
## 🔑 Right to left, the whole layout is mirrored: the glyph stands at the label's right, where the reading starts.
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
## The glyph's opacity on a disabled button (the game's GlossButton), over the normal icon colour.
const DISABLED_ALPHA := 0.6
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
## A resize or theme change came while the faces were being re-wrapped (that re-wrap may have caused it).
var _missed := false


## A face drawn as [param from] with [param shift] of content margin moved from its right side to its left (from its
## left side to its right when [param mirrored], for a right-to-left button).
class ShiftedBox:
	extends StyleBox

	var base: StyleBox
	## The face it wraps was the button's own override (put back when the wrapper comes off).
	var was_override := false

	func _init(from: StyleBox = null, shift := 0.0, mirrored := false, edge := 0.0) -> void:
		base = from
		if from == null: return
		# The label's centre moves away from the glyph by `shift`. On a face with real padding (the far side at least
		# `edge`, as on the painted pills) that much padding goes from the far side to the near one, exactly as the
		# game's GlossButton does; past the far padding the button grows (a negative margin would read as "unset").
		# A thin face (a flat look's few pixels) instead keeps the group centred and the glyph `edge` off its side.
		var lead := SIDE_RIGHT if mirrored else SIDE_LEFT
		var trail := SIDE_LEFT if mirrored else SIDE_RIGHT
		var near := from.get_margin(lead)
		var far := from.get_margin(trail)
		if far >= edge:
			set_content_margin(lead, near + shift)
			set_content_margin(trail, maxf(far - shift, 0.0))
		else:
			var outside := maxf(near - minf(shift, far), edge)
			set_content_margin(lead, outside + 2.0 * shift)
			set_content_margin(trail, outside - near + far)
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
	var middle := (left + size.x - right) * 0.5
	var x := middle - text_width * 0.5 - GAP - drawn.x
	if is_layout_rtl(): x = middle + text_width * 0.5 + GAP
	if text.is_empty(): x = (size.x - drawn.x) * 0.5
	# Only the glyph's own side is clamped (the game's maxf): a cramped button lets the glyph meet the label.
	x = minf(x, size.x - MIN_EDGE - drawn.x) if is_layout_rtl() else maxf(x, MIN_EDGE)
	var pressed := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	return Rect2(Vector2(x, (size.y - drawn.y) * 0.5 - 1.0 + (PRESS_DROP if pressed else 0.0)), drawn)


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The look or the icon set changed: the glyph may be another size, so the shift is measured again.
func _on_ui_changed() -> void:
	_update_shift()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if not is_equal_approx(_shift, glyph_allowance() * 0.5): _update_shift()
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			if not _shifting: _update_shift()
		NOTIFICATION_DRAW:
			_draw_glyph()


## Re-wraps the theme's faces with the current shift (or drops the wrappers when there is no glyph).
func _update_shift() -> void:
	if _shifting:
		_missed = true
		return
	_missed = false
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
			var wrapper := ShiftedBox.new(face, _shift, is_layout_rtl(), MIN_EDGE)
			wrapper.was_override = has_theme_stylebox_override(state)
			add_theme_stylebox_override(state, wrapper)
	end_bulk_theme_override()
	_shifting = false
	# 🛑 Swapping the faces can resize the button at once (a taller minimum size, say): the height the shift was
	#    measured on is then stale. The glyph's room depends on the height alone, so one more pass settles it.
	if _missed and not is_equal_approx(_shift, glyph_allowance() * 0.5): _update_shift()
	_missed = false


func _draw_glyph() -> void:
	var art := glyph_texture()
	if art == null: return
	draw_texture_rect(art, glyph_rect(), false, glyph_tint())


## The glyph's colour: the theme's icon colour for the state (white glyphs read as drawn on the arcade pills). A
## disabled glyph is the normal colour at [constant DISABLED_ALPHA], as the game draws it.
func glyph_tint() -> Color:
	var key := &"icon_normal_color"
	match get_draw_mode():
		DRAW_PRESSED: key = &"icon_pressed_color"
		DRAW_HOVER: key = &"icon_hover_color"
		DRAW_HOVER_PRESSED: key = &"icon_hover_pressed_color"
	var tint := get_theme_color(key) if has_theme_color(key) else Color.WHITE
	if get_draw_mode() == DRAW_DISABLED: tint.a *= DISABLED_ALPHA
	return tint


func _state_name() -> StringName:
	match get_draw_mode():
		DRAW_PRESSED: return &"pressed"
		DRAW_HOVER: return &"hover"
		DRAW_HOVER_PRESSED: return &"hover_pressed"
		DRAW_DISABLED: return &"disabled"
	return &"normal"
