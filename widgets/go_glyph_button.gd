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
## 🔑 `fit_label` shrinks a long label (a translation) until it fits beside the glyph — as each of Magnet Mayhem's
##    screens did by hand for its GlossButtons — on every resize, text, glyph and look change. Give the button its width
##    (`custom_minimum_size` or a container's share): the room is measured from it.
## 🔤 [member subtitle] puts a second, smaller line under the label, in the look's `subtitle_color`, `subtitle_font` and
##    `subtitle_font_size` for the variation (and `subtitle_gap` between the lines, `subtitle_outline_size`). The two
##    lines stand centred together; `fit_label` shrinks both by one ratio. Empty, the button is exactly a one-line key.
## 🔵 A look whose variation has a `glyph_disc` stylebox draws the glyph centred on that disc, at the button's left
##    (`glyph_disc_left` px in, `glyph_disc_size` % of the height, `glyph_disc_drop` px below the middle, the glyph
##    `glyph_disc_glyph` % of the disc), and the text left-aligned `glyph_disc_gap` px after it — a menu's hero key (`GoTheme.VAR_HERO_BUTTON`,
##    `VAR_GLASS_BUTTON`). While the disc is drawn the button's `alignment` is the start side.
##
## ```gdscript
## var play := GoGlyphButton.make("PLAY", GoIconSet.PLAY, GoTheme.VAR_HERO_BUTTON)
## play.subtitle = "CAMPAIGN"
## ```
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
## The disc's diameter as a share of the button's height when the look names no `glyph_disc_size`.
const DISC_SHARE := 0.74
## The glyph's size as a share of the disc when the look names no `glyph_disc_glyph`.
const DISC_GLYPH_SHARE := 0.62
## The faces that place the label (focus is drawn over them and places nothing).
const TEXT_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]

## Glyph height as a share of the button height; changing it also reserves the matching space beside the label.
@export_range(0.1, 1.0, 0.01) var glyph_share := GLYPH_SHARE:
	set(value):
		glyph_share = clampf(value, 0.1, 1.0)
		_update_shift()
		_queue_fit()
		queue_redraw()

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

## Mirror only the glyph, for paired directional keys using one texture. The label and the layout stay upright.
@export var glyph_flip_h := false:
	set(value):
		if glyph_flip_h == value: return
		glyph_flip_h = value
		queue_redraw()

## 🔤 A second line under the label, smaller and in its own colour (the look's `subtitle_color`, `subtitle_font`,
## `subtitle_font_size` for this variation). Translated like `text` (`atr()`); setting it lays the button out again.
## Empty: a one-line button, exactly as before.
@export var subtitle := "":
	set(value):
		if subtitle == value: return
		subtitle = value
		_update_shift()
		_queue_fit()
		update_minimum_size()
		queue_redraw()

## 🔤 Shrink the label to fit: from [member fit_base_size] (0: the look's size for this variation) down to
## `GoStyle.fit_floor()` at most, until it fits the button's width less its normal face's padding and the glyph's
## room (`glyph_allowance()`). With a [member subtitle] both lines shrink by one ratio until both fit. Off, the label
## keeps its size (what the button does today).
@export var fit_label := false:
	set(value):
		if fit_label == value: return
		fit_label = value
		if not value: _drop_fit()
		_queue_fit()

## The size [member fit_label] shrinks from. 0 takes the look's `font_size` for this button's variation.
@export_range(0, 128) var fit_base_size := 0:
	set(value):
		fit_base_size = value
		_queue_fit()

## 🔔 What the player's press says through `GoFeedback` (`GoFeedback.TAPPED`, `CONFIRMED`, `CANCELED`, …): a sound
## the project plays and a short buzz on a phone. Empty: silent. A press from code (`button_pressed =`) says nothing.
@export var feedback: StringName = GoFeedback.TAPPED

var _shift := 0.0
## The label's start-side padding while the disc is drawn (-1: no disc).
var _lead := -1.0
## The room added under the label for the subtitle.
var _below := 0.0
## `alignment` was set to the start side by the disc (put back to centre when the disc goes).
var _disc_aligned := false
## The subtitle size [member fit_label] chose (0: the look's).
var _sub_fitted := 0
var _shifting := false
## The `font_size` override [member fit_label] put on (0: none of ours).
var _fitted := 0
var _fit_queued := false
## The fit is peeking under its own override (the theme notices that brings are its own, not a change).
var _peeking := false
## What the last fit change was made for (text, subtitle, width) and the sizes it left (see `fit_now()`).
var _fit_key := ""
var _fit_prev := Vector2i(-1, -1)
## A resize or theme change came while the faces were being re-wrapped (that re-wrap may have caused it).
var _missed := false


## A face drawn as [param from] with [param shift] of content margin moved from its right side to its left (from its
## left side to its right when [param mirrored], for a right-to-left button).
class ShiftedBox:
	extends StyleBox

	var base: StyleBox
	## The face it wraps was the button's own override (put back when the wrapper comes off).
	var was_override := false

	## [param lead] ≥ 0 sets the start-side padding outright (the disc's room) instead of moving [param shift];
	## [param below] adds that much padding under the label (the subtitle's line).
	func _init(from: StyleBox = null, shift := 0.0, mirrored := false, edge := 0.0, lead := -1.0, below := 0.0) -> void:
		base = from
		if from == null: return
		content_margin_top = from.get_margin(SIDE_TOP)
		content_margin_bottom = from.get_margin(SIDE_BOTTOM) + below
		if lead >= 0.0:
			set_content_margin(SIDE_RIGHT if mirrored else SIDE_LEFT, lead)
			set_content_margin(SIDE_LEFT if mirrored else SIDE_RIGHT, from.get_margin(SIDE_LEFT if mirrored else SIDE_RIGHT))
			return
		# The label's centre moves away from the glyph by `shift`. On a face with real padding (the far side at least
		# `edge` and the full shift) that much padding goes from the far side to the near one, exactly as the
		# game's GlossButton does; past the far padding the button grows (a negative margin would read as "unset").
		# A thin face (a flat look's few pixels) instead keeps the group centred and the glyph `edge` off its side.
		var start := SIDE_RIGHT if mirrored else SIDE_LEFT
		var trail := SIDE_LEFT if mirrored else SIDE_RIGHT
		var near := from.get_margin(start)
		var far := from.get_margin(trail)
		if shift <= 0.0:
			set_content_margin(start, near)
			set_content_margin(trail, far)
		elif far >= maxf(edge, shift):
			set_content_margin(start, near + shift)
			set_content_margin(trail, maxf(far - shift, 0.0))
		else:
			var outside := maxf(near - minf(shift, far), edge)
			set_content_margin(start, outside + 2.0 * shift)
			set_content_margin(trail, outside - near + far)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if base != null: base.draw(to_canvas_item, rect)

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return base.get_draw_rect(rect) if base != null else rect


func _init() -> void:
	theme_type_variation = GoTheme.VAR_BUTTON
	GoStyle.skin_focus(self)   # arcade_light: out of the focus order like the game's GlossButton
	# A new text changes the minimum size — the one notice a `Button.text` change gives.
	minimum_size_changed.connect(_queue_fit)
	pressed.connect(_on_feedback_pressed)


func _on_feedback_pressed() -> void:
	if not Engine.is_editor_hint(): GoFeedback.play(feedback)


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


## The glyph's height as a share of the button's: [member glyph_share], or the look's `glyph_share` (percent) for this
## variation while [member glyph_share] is left at its default.
func effective_glyph_share() -> float:
	if is_equal_approx(glyph_share, GLYPH_SHARE) and has_theme_constant(&"glyph_share"):
		return clampf(get_theme_constant(&"glyph_share") / 100.0, 0.1, 1.0)
	return glyph_share


## Does the look draw a disc under the glyph (its `glyph_disc` stylebox) — and is there a glyph to put on it?
func has_glyph_disc() -> bool:
	return glyph_texture() != null and has_theme_stylebox(&"glyph_disc")


## The disc's diameter on a button [param height] tall (negative: its height now).
func glyph_disc_size(height := -1.0) -> float:
	var share := get_theme_constant(&"glyph_disc_size") / 100.0 if has_theme_constant(&"glyph_disc_size") else DISC_SHARE
	return (size.y if height < 0.0 else height) * share


## The label's start-side padding while the disc is drawn: the disc's inset, its diameter and the gap after it.
func disc_lead(height := -1.0) -> float:
	var inset := float(get_theme_constant(&"glyph_disc_left")) if has_theme_constant(&"glyph_disc_left") else MIN_EDGE
	var gap := float(get_theme_constant(&"glyph_disc_gap")) if has_theme_constant(&"glyph_disc_gap") else GAP
	return inset + glyph_disc_size(height) + gap


## Where the disc is drawn now (an empty rect without one).
func glyph_disc_rect() -> Rect2:
	if not has_glyph_disc(): return Rect2()
	var d := glyph_disc_size()
	var inset := float(get_theme_constant(&"glyph_disc_left")) if has_theme_constant(&"glyph_disc_left") else MIN_EDGE
	var x := size.x - inset - d if is_layout_rtl() else inset
	var drop := float(get_theme_constant(&"glyph_disc_drop")) if has_theme_constant(&"glyph_disc_drop") else 0.0
	return Rect2(Vector2(x, (size.y - d) * 0.5 + drop + _press_drop()), Vector2(d, d))


## The space between a plain glyph and the label: the look's `glyph_gap` for this variation, else [constant GAP].
func glyph_gap() -> float:
	return float(get_theme_constant(&"glyph_gap")) if has_theme_constant(&"glyph_gap") else GAP


## The width the glyph takes beside the label on a button [param height] tall (negative: its height now). With a disc:
## how much more than the normal face's own start padding the disc takes.
func glyph_allowance(height := -1.0) -> float:
	var art := glyph_texture()
	if art == null: return 0.0
	if has_glyph_disc():
		var face := _base_face(&"normal")
		var near := face.get_margin(SIDE_RIGHT if is_layout_rtl() else SIDE_LEFT) if face != null else 0.0
		return maxf(0.0, disc_lead(height) - near)
	var tall := (size.y if height < 0.0 else height) * effective_glyph_share()
	return tall * art.get_width() / maxf(1.0, maxf(art.get_width(), art.get_height())) + glyph_gap()


## Where the glyph is drawn now, in the button's space.
func glyph_rect() -> Rect2:
	var art := glyph_texture()
	if art == null: return Rect2()
	var longest := maxf(1.0, maxf(art.get_width(), art.get_height()))
	if has_glyph_disc():
		var disc := glyph_disc_rect()
		var share := get_theme_constant(&"glyph_disc_glyph") / 100.0 if has_theme_constant(&"glyph_disc_glyph") \
			else DISC_GLYPH_SHARE
		var fitted := Vector2(art.get_width(), art.get_height()) * (disc.size.y * share / longest)
		return Rect2(disc.get_center() - fitted * 0.5, fitted)
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
	var box := size.y * effective_glyph_share()
	var ratio := box / longest
	var drawn := Vector2(art.get_width(), art.get_height()) * ratio
	# The button centres the label in the state face's content rect; the glyph goes just left of it.
	var face := get_theme_stylebox(_state_name())
	var left := face.get_margin(SIDE_LEFT) if face != null else 0.0
	var right := face.get_margin(SIDE_RIGHT) if face != null else 0.0
	var middle := (left + size.x - right) * 0.5
	var x := middle - text_width * 0.5 - glyph_gap() - drawn.x
	if is_layout_rtl(): x = middle + text_width * 0.5 + glyph_gap()
	if text.is_empty(): x = (size.x - drawn.x) * 0.5
	# Only the glyph's own side is clamped (the game's maxf): a cramped button lets the glyph meet the label.
	x = minf(x, size.x - MIN_EDGE - drawn.x) if is_layout_rtl() else maxf(x, MIN_EDGE)
	# With a subtitle the glyph stands by the two lines' middle, which is the face's middle.
	return Rect2(Vector2(x, (size.y - drawn.y) * 0.5 - 1.0 + _press_drop()), drawn)


func _press_drop() -> float:
	var pressed := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	return PRESS_DROP if pressed else 0.0


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## The look or the icon set changed: the glyph may be another size, so the shift is measured again.
func _on_ui_changed() -> void:
	_update_shift()
	GoStyle.skin_focus(self)
	_queue_fit()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if _layout_stale(): _update_shift()
			_queue_fit()
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			if _peeking: return
			if not _shifting: _update_shift()
			_queue_fit()
		NOTIFICATION_TRANSLATION_CHANGED:
			_queue_fit()
			queue_redraw()
		NOTIFICATION_DRAW:
			_draw_disc()
			_draw_glyph()
			_draw_subtitle()


## With [member fit_label]: the label's size for the button as it is now — the room is its width less the normal face's
## minimum width and `glyph_allowance()`, as Magnet Mayhem's screens measured it. Off: the size it is drawn at.
func fitted_font_size() -> int:
	if not fit_label: return get_theme_font_size(&"font_size")
	return _fit_sizes().x


## The subtitle's size now: the look's `subtitle_font_size`, shrunk by [member fit_label] in the label's ratio.
func subtitle_font_size() -> int:
	if fit_label and _sub_fitted > 0: return _sub_fitted
	return _subtitle_base()


## The look's subtitle size for this variation (the theme's default size when it names none).
func _subtitle_base() -> int:
	return maxi(1, get_theme_font_size(&"subtitle_font_size"))


## The subtitle's font: the look's `subtitle_font` (the theme's default font when it names none).
func subtitle_font() -> Font:
	return get_theme_font(&"subtitle_font")


## The subtitle's colour in the current state: the look's `subtitle_color`, else the label's; a disabled button's at
## [constant DISABLED_ALPHA].
func subtitle_color() -> Color:
	var tint := get_theme_color(&"subtitle_color") if has_theme_color(&"subtitle_color") \
		else get_theme_color(&"font_color")
	if get_draw_mode() == DRAW_DISABLED: tint.a *= DISABLED_ALPHA
	return tint


## The room for the text: the button's width less the normal face's padding and the glyph's (or disc's) room.
func _text_room() -> float:
	return size.x - _face_width() - glyph_allowance()


## (title size, subtitle size) that fit the room: one ratio for both, from the bases down to the floor.
func _fit_sizes() -> Vector2i:
	var base := _fit_base()
	var sub_base := _subtitle_base()
	var room := _text_room()
	var font := get_theme_font(&"font")
	var title := GoStyle.fit_font_size(PackedStringArray([atr(text)]), base, room, font)
	if subtitle.is_empty(): return Vector2i(title, sub_base)
	var floor_size := GoStyle.fit_floor(base)
	var sub_font := subtitle_font()
	var line := PackedStringArray([atr(subtitle)])
	while title > floor_size and GoStyle.row_width(sub_font, line, _sub_for(title, base, sub_base)) > room:
		title -= 1
	return Vector2i(title, _sub_for(title, base, sub_base))


func _sub_for(title: int, base: int, sub_base: int) -> int:
	if title >= base: return sub_base
	return maxi(1, roundi(float(sub_base) * title / maxf(1.0, base)))


## Fits the label now instead of on the next frame (a test, or a screen measuring itself right after a change).
func fit_now() -> void:
	_fit_queued = false
	if not fit_label or not is_inside_tree() or size.x <= 0.0: return
	var wanted := _fit_sizes()
	var now := Vector2i(get_theme_font_size(&"font_size"), subtitle_font_size())
	if wanted != now:
		# 🛑 A button as tall as its two lines: a smaller subtitle makes it shorter, a shorter glyph leaves the text more
		#    room, the text grows, the button grows… For the same text, subtitle and width, a fit that only goes back
		#    to the sizes it just left is that loop: the smaller sizes stay.
		var key := "%s|%s|%d" % [atr(text), atr(subtitle), roundi(size.x)]
		if key == _fit_key and wanted == _fit_prev and wanted.x >= now.x and wanted.y >= now.y: return
		_fit_key = key
		_fit_prev = now
	if wanted.y != _sub_fitted:
		_sub_fitted = wanted.y
		_update_shift()
		queue_redraw()
	if wanted.x == _fitted and has_theme_font_size_override(&"font_size"): return
	_fitted = wanted.x
	add_theme_font_size_override(&"font_size", wanted.x)


func _queue_fit() -> void:
	if not fit_label or _fit_queued or _peeking: return
	_fit_queued = true
	fit_now.call_deferred()


## The size the fit starts from: [member fit_base_size], else the look's — read under the override the fit put on.
func _fit_base() -> int:
	if fit_base_size > 0: return fit_base_size
	if _fitted == 0 or not has_theme_font_size_override(&"font_size"): return get_theme_font_size(&"font_size")
	# 🔑 The override goes off and back on inside one bulk change: the one theme notice that closes it is ignored
	#    (`_peeking`), and the minimum size is the same after, so nothing relayouts and no fit is queued again.
	_peeking = true
	begin_bulk_theme_override()
	remove_theme_font_size_override(&"font_size")
	var base := get_theme_font_size(&"font_size")
	add_theme_font_size_override(&"font_size", _fitted)
	end_bulk_theme_override()
	_peeking = false
	return base


## The normal face's minimum width, the padding the label never takes.
func _face_width() -> float:
	var face := get_theme_stylebox(&"normal")
	if face is ShiftedBox and has_glyph_disc():
		# The disc's room is counted by `glyph_allowance()`; the wrapper's start padding already holds it.
		face = (face as ShiftedBox).base
	return face.get_minimum_size().x if face != null else 0.0


## The theme's own face for [param state], under the wrapper this button puts on.
func _base_face(state: StringName) -> StyleBox:
	var face := get_theme_stylebox(state)
	return (face as ShiftedBox).base if face is ShiftedBox else face


func _drop_fit() -> void:
	_fit_key = ""
	if _fitted != 0 and has_theme_font_size_override(&"font_size"): remove_theme_font_size_override(&"font_size")
	_fitted = 0
	if _sub_fitted != 0:
		_sub_fitted = 0
		_update_shift()
		queue_redraw()


## The room the subtitle's line takes under the label (0 without one): its height and the gap above it.
func _subtitle_room() -> float:
	if subtitle.is_empty(): return 0.0
	var font := subtitle_font()
	if font == null: return 0.0
	return maxf(0.0, font.get_height(subtitle_font_size()) + get_theme_constant(&"subtitle_gap"))


## Does the wrapping on the faces still match the button's height, glyph, disc and subtitle?
func _layout_stale() -> bool:
	var lead := disc_lead() if has_glyph_disc() else -1.0
	var shift := 0.0 if has_glyph_disc() else glyph_allowance() * 0.5
	return not (is_equal_approx(_shift, shift) and is_equal_approx(_lead, lead) and is_equal_approx(_below, _subtitle_room()))


## Re-wraps the theme's faces with the current shift, disc and subtitle room (or drops the wrappers when none is needed).
func _update_shift() -> void:
	if _shifting:
		_missed = true
		return
	_missed = false
	_shifting = true
	var disc := has_glyph_disc()
	_lead = disc_lead() if disc else -1.0
	_shift = 0.0 if disc else glyph_allowance() * 0.5
	_below = _subtitle_room()
	begin_bulk_theme_override()
	for state in TEXT_STATES:
		if has_theme_stylebox_override(state) and get_theme_stylebox(state) is ShiftedBox:
			var wrapper := get_theme_stylebox(state) as ShiftedBox
			remove_theme_stylebox_override(state)
			if wrapper.was_override and wrapper.base != null: add_theme_stylebox_override(state, wrapper.base)
	if _shift > 0.0 or _lead >= 0.0 or _below > 0.0:
		for state in TEXT_STATES:
			var face := get_theme_stylebox(state)
			if face == null: continue
			var wrapper := ShiftedBox.new(face, _shift, is_layout_rtl(), MIN_EDGE, _lead, _below)
			wrapper.was_override = has_theme_stylebox_override(state)
			add_theme_stylebox_override(state, wrapper)
	end_bulk_theme_override()
	# 🔑 The disc's text starts at the disc, so it stands at the start side; the centre comes back with the disc gone.
	if disc and alignment != HORIZONTAL_ALIGNMENT_LEFT:
		_disc_aligned = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	elif not disc and _disc_aligned:
		_disc_aligned = false
		alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shifting = false
	# 🛑 Swapping the faces can resize the button at once (a taller minimum size, say): the height the shift was
	#    measured on is then stale. The glyph's room depends on the height alone, so one more pass settles it.
	if _missed and _layout_stale(): _update_shift()
	_missed = false


func _draw_disc() -> void:
	if not has_glyph_disc(): return
	draw_style_box(get_theme_stylebox(&"glyph_disc"), glyph_disc_rect())


func _draw_glyph() -> void:
	var art := glyph_texture()
	if art == null: return
	var rect := glyph_rect()
	# Custom textures (GoTextureSprite) draw their own destination rectangle and need not preserve the engine's
	# negative-width convention. Mirror the canvas instead, leaving every texture a normal positive rectangle.
	if glyph_flip_h:
		draw_set_transform(Vector2(rect.get_center().x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(art, rect, false, glyph_tint())
	if glyph_flip_h: draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the subtitle's line is drawn now: its box (top-left and size; the baseline is `position.y` + the font's
## ascent). Empty without a subtitle.
func subtitle_rect() -> Rect2:
	if subtitle.is_empty(): return Rect2()
	var font := subtitle_font()
	var title_font := get_theme_font(&"font")
	var face := get_theme_stylebox(_state_name())
	if font == null or title_font == null or face == null: return Rect2()
	var line_size := font.get_string_size(atr(subtitle), HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_font_size())
	var top := face.get_margin(SIDE_TOP)
	var bottom := size.y - face.get_margin(SIDE_BOTTOM)
	var title_height := title_font.get_height(get_theme_font_size(&"font_size"))
	# The label is centred in the face's content (which holds the subtitle's room at its bottom); the line goes under.
	var y := top + (bottom - top - title_height) * 0.5 + title_height + get_theme_constant(&"subtitle_gap")
	var left := face.get_margin(SIDE_LEFT)
	var right := face.get_margin(SIDE_RIGHT)
	var x := (left + size.x - right - line_size.x) * 0.5
	if alignment == HORIZONTAL_ALIGNMENT_LEFT:
		x = size.x - right - line_size.x if is_layout_rtl() else left
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = left if is_layout_rtl() else size.x - right - line_size.x
	return Rect2(Vector2(x, y), Vector2(line_size.x, font.get_height(subtitle_font_size())))


func _draw_subtitle() -> void:
	var rect := subtitle_rect()
	if rect.size == Vector2.ZERO: return
	var font := subtitle_font()
	var font_size := subtitle_font_size()
	var line := atr(subtitle)
	var at := Vector2(rect.position.x, rect.position.y + font.get_ascent(font_size))
	var outline := get_theme_constant(&"subtitle_outline_size")
	if outline > 0:
		draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline,
			get_theme_color(&"font_outline_color"))
	draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, subtitle_color())


## The signed drawing rectangle: a negative width mirrors the art within the unchanged [method glyph_rect].
func glyph_draw_rect() -> Rect2:
	var rect := glyph_rect()
	if glyph_flip_h:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	return rect


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
