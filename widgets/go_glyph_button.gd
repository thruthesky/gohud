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
## ✅ `check_badge` pins a round badge (a check) over the top-right corner and `glow` lays a soft light round the
##    button — the picked one of a row of pills (a difficulty):
##    `easy.check_badge = GoUi.skin().widget_art(&"check_green")` (null in a look without that art: no badge).
## 🔑 `fit_label` shrinks a long label (a translation) until it fits beside the glyph — as each of Magnet Mayhem's
##    screens did by hand for its GlossButtons — on every resize, text, glyph and look change. Give the button its width
##    (`custom_minimum_size` or a container's share): the room is measured from it.
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
## The check badge's diameter as a share of the button's height, and where its centre sits: in from the right edge
## and down from the top, as shares of the height (it overlaps the corner, as a sticker would).
const BADGE_SHARE := 0.74
const BADGE_CENTRE := Vector2(0.2, 0.1)
## How far the glow reaches out of the button, as a share of its height.
const GLOW_SHARE := 0.22
## How far a text outline reaches past the glyphs' own outlines, as a share of `outline_size`: FreeType strokes it
## `outline_size` × 16 / 64 px out (`text_server_adv.cpp`, `FT_Stroker_Set`).
const OUTLINE_REACH := 0.25
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

## 🔤 Shrink the label to fit: from [member fit_base_size] (0: the look's size for this variation) down to
## `GoStyle.fit_floor()` at most, until it fits the button's width less its normal face's padding and the glyph's
## room (`glyph_allowance()`). Off, the label keeps its size (what the button does today).
## 🔑 Still too long at the floor, a button in a container is held as wide as its label there with the glyph and the
##    padding (`custom_minimum_size.x` raised, the width a caller asked kept under it) — the label never runs past the
##    face, and a `SCALE` window it sits in shrinks as one piece instead (German MÜNZEN VERDIENEN). A button placed by
##    hand (its parent no container) keeps its size: its label is condensed instead, down to
##    `GoConfig.fit_condense_min` of its width (glyphs drawn narrower, the advances closed up to match).
##    A button whose label may trim (`text_overrun_behavior` not `OVERRUN_NO_TRIMMING`, or `clip_text`) keeps its
##    size too: condensed the same way, then trimmed (GoRewardRow's claim pill).
## 🔑 On a pill with a painted top gloss (`GoSkin.button_gloss_bottom`) a label whose accents would reach into it —
##    French ÉQUIPER, Polish ODRZUĆ, ZAŁÓŻ — moves down until its ink is under the gloss, its size kept; an unaccented
##    label keeps its size and place (`_gloss_drop`). Only a key too short to drop them that far steps down, by the
##    least that clears them, and only that key (its row keeps its size).
@export var fit_label := false:
	set(value):
		if fit_label == value: return
		fit_label = value
		if not value: _drop_fit()
		_queue_fit()

## 🔤 With [member fit_label]: share the fit with the other `fit_with_row` keys of the same parent. Each holds the
## width the row's longest label needs at its full size (`base_width()`), so a row that stretches them alike
## (`SIZE_EXPAND_FILL`) always gives them one width and every label its full size: the window widens for its longest
## key (a `SCALE` window then shrinks as one piece when it outgrows the screen) instead of its labels shrinking. Only
## when the row still cannot give them that room (a key held narrower by its parent) do they share one label size,
## the smallest any of them fits at. Their labels stand on one baseline: an accented key's drop under the gloss
## (`_gloss_drop`) moves its row's labels with it. `GoSurface.add_gloss` turns it on for a window's row of keys.
## In a `GoSurface`, the hold never passes the key's share of the card's standard width (`GoSurface.free_width`):
## a long translation shrinks the row's labels (Latin condenses first, `condensed_floor_width()`) before it widens the
## window, and only a label too long even at the floor widens it (German SCHLIESSEN / MÜNZEN VERDIENEN: 14 % wider).
## 🛑 Held only at the floor's width, the window widened just enough for its longest label at the floor, the fit
##    landed there and its row shared it: German KAUFEN, Turkish İPTAL, Japanese 閉じる came out at 70 %.
@export var fit_with_row := false:
	set(value):
		if fit_with_row == value: return
		fit_with_row = value
		_queue_fit()
		for peer in _fit_peers(): if peer != self: peer._queue_fit()

## The size [member fit_label] shrinks from. 0 takes the look's `font_size` for this button's variation.
@export_range(0, 128) var fit_base_size := 0:
	set(value):
		fit_base_size = value
		_queue_fit()

## The width [member fit_label] leaves free beside the label and the glyph's room. Negative (the default) takes the
## normal face's minimum width; a painted pill's minimum counts its whole rounded ends, so a wide label on a short
## pill (the World Tour's PLAY MULTIPLAYER) sets its own padding: the content margins and the outline, say.
@export var fit_padding := -1.0:
	set(value):
		fit_padding = value
		_queue_fit()

## 🔔 What the player's press says through `GoFeedback` (`GoFeedback.TAPPED`, `CONFIRMED`, `CANCELED`, …): a sound
## the project plays and a short buzz on a phone. Empty: silent. A press from code (`button_pressed =`) says nothing.
@export var feedback: StringName = GoFeedback.TAPPED

## ✅ A round badge over the top-right corner (a check on the picked pill). Null: none. It is drawn over the face and
## past its edge, so leave the button room above and to the right (or let it overlap its neighbour, as a sticker).
@export var check_badge: Texture2D:
	set(value):
		check_badge = value
		queue_redraw()

## ✨ A soft light round the button, behind its face (the skin's `button_glow_color`) — the picked pill of a row.
@export var glow := false:
	set(value):
		if glow == value: return
		glow = value
		_update_glow()

var _shift := 0.0
## How far [member fit_label] moves the label down, so its accents clear the key's top gloss (`_gloss_drop`).
var _drop := 0.0
## The canvas item the glow is drawn on, behind the button's own (created on the first glow).
var _glow_item := RID()
var _shifting := false
## The `font_size` override [member fit_label] put on (0: none of ours).
var _fitted := 0
var _fit_queued := false
## The width the fit holds the button at (`custom_minimum_size.x` as the fit set it; 0: none), and the caller's own.
var _held_width := 0.0
var _asked_width := 0.0
## The condensed font the fit put on as the `font` override (null: none of ours). Shared per base font and step.
var _condensed: FontVariation = null
## Condensed fonts by base font and step, so a fit never makes a font of its own.
static var _condense_cache := {}
## The text the fit last measured: a held width hides a new text's minimum size, but never its redraw.
var _fit_text := ""
## The fit is peeking under its own override (the theme notices that brings are its own, not a change).
var _peeking := false
## A resize or theme change came while the faces were being re-wrapped (that re-wrap may have caused it).
var _missed := false


## A face drawn as [param from] with [param shift] of content margin moved from its right side to its left (from its
## left side to its right when [param mirrored], for a right-to-left button).
class ShiftedBox:
	extends StyleBox

	var base: StyleBox
	## The face it wraps was the button's own override (put back when the wrapper comes off).
	var was_override := false

	func _init(from: StyleBox = null, shift := 0.0, mirrored := false, edge := 0.0, drop := 0.0) -> void:
		base = from
		if from == null: return
		# `drop` moves the label down by moving that much padding from the bottom to the top (`_gloss_drop`).
		content_margin_top = from.get_margin(SIDE_TOP) + drop
		content_margin_bottom = maxf(from.get_margin(SIDE_BOTTOM) - drop, 0.0)
		if shift <= 0.0:
			content_margin_left = from.get_margin(SIDE_LEFT)
			content_margin_right = from.get_margin(SIDE_RIGHT)
			return
		# The label's centre moves away from the glyph by `shift`. On a face with real padding (the far side at least
		# `edge` and the full shift) that much padding goes from the far side to the near one, exactly as the
		# game's GlossButton does; past the far padding the button grows (a negative margin would read as "unset").
		# A thin face (a flat look's few pixels) instead keeps the group centred and the glyph `edge` off its side.
		var lead := SIDE_RIGHT if mirrored else SIDE_LEFT
		var trail := SIDE_LEFT if mirrored else SIDE_RIGHT
		var sides := margins(from, shift, mirrored, edge)
		set_content_margin(lead, sides.x)
		set_content_margin(trail, sides.y)

	## The near and far content margins a face [param from] gets with [param shift] (see the class).
	static func margins(from: StyleBox, shift: float, mirrored := false, edge := 0.0) -> Vector2:
		var near := from.get_margin(SIDE_RIGHT if mirrored else SIDE_LEFT)
		var far := from.get_margin(SIDE_LEFT if mirrored else SIDE_RIGHT)
		if far >= maxf(edge, shift): return Vector2(near + shift, maxf(far - shift, 0.0))
		var outside := maxf(near - minf(shift, far), edge)
		return Vector2(outside + 2.0 * shift, outside - near + far)

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


## The width the glyph takes beside the label on a button [param height] tall (negative: its height now).
func glyph_allowance(height := -1.0) -> float:
	var art := glyph_texture()
	if art == null: return 0.0
	var tall := (size.y if height < 0.0 else height) * glyph_share
	return tall * art.get_width() / maxf(1.0, maxf(art.get_width(), art.get_height())) + GAP


## Where the glyph is drawn now, in the button's space.
func glyph_rect() -> Rect2:
	var art := glyph_texture()
	if art == null: return Rect2()
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
	var box := size.y * glyph_share
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
	_drop_condense() # the look's font may be another one: the fit condenses it again
	_update_shift()
	GoStyle.skin_focus(self)
	_queue_fit()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			if not is_equal_approx(_shift, glyph_allowance() * 0.5): _update_shift()
			_queue_fit()
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			if _peeking: return
			if not _shifting: _update_shift()
			_queue_fit()
		NOTIFICATION_TRANSLATION_CHANGED:
			_queue_fit()
		NOTIFICATION_DRAW:
			if fit_label and text != _fit_text: _queue_fit()
			_draw_glyph()
			_draw_badge()
			if glow: _update_glow()
		NOTIFICATION_PREDELETE:
			if _glow_item.is_valid(): RenderingServer.free_rid(_glow_item)


## With [member fit_label]: the label's size for the button as it is now — the room is its width less the normal face's
## minimum width and the look's clear pad (`GoSkin.button_fit_pad()`; or [member fit_padding]) and `glyph_allowance()`,
## as Magnet Mayhem's screens measured it; with [member fit_with_row], the smallest of its row's. Off: the size it is drawn at.
## The row's share is the width's alone; the gloss then steps this key down by itself, if it must (`_gloss_size`).
func fitted_font_size() -> int:
	if not fit_label: return get_theme_font_size(&"font_size")
	var fitted := own_fit_size()
	for peer in _fit_peers():
		if peer != self and peer.is_inside_tree() and peer.size.x > 0.0: fitted = mini(fitted, peer.own_fit_size())
	return _gloss_size(fitted)


## The size this button's own label fits its width at, its row and the gloss left out ([method fitted_font_size]).
func own_fit_size() -> int:
	return GoStyle.fit_font_size(PackedStringArray([atr(text)]), _fit_base(), _fit_room(), _base_font())


## [param from], or the largest size under it whose accents the drop can still clear the gloss at (`_gloss_drop`) —
## in practice the drop alone clears them and the size stays; never under the floor.
func _gloss_size(from: int) -> int:
	var fitted := from
	var floor_size := GoStyle.fit_floor(_fit_base())
	while fitted > floor_size and _gloss_drop(fitted) < 0.0:
		fitted -= 1
	return fitted


## 🔤 How far the label at [param font_size] moves down so its ink — accents and outline included — stays under the
## key's painted top gloss (`GoSkin.button_gloss_bottom`): 0 for a label already under it (an unaccented word, which
## keeps its place), negative when the room under the label (its lowest ink to the face's bottom padding) is too small
## to drop it that far. 🛑 Measured on the normal face as the theme gives it, never on this button's wrapped one —
##    a drop read from the dropped face would undo itself.
func _gloss_drop(font_size: int) -> float:
	var need := _gloss_need(font_size)
	if need.x <= 0.0: return 0.0
	return need.x if need.x <= need.y else -1.0


## The label at [param font_size] on the normal face as the theme gives it: x how far it must move down to clear the
## gloss (0 or less: it is under it already, or the face has no gloss), y how far it can (its lowest ink, outline
## included, to the face's bottom padding).
func _gloss_need(font_size: int) -> Vector2:
	var face := _theme_face()
	var font := _base_font()
	if face == null or font == null or text.is_empty() or size.y <= 0.0: return Vector2.ZERO
	var gloss := GoUi.skin().button_gloss_bottom(face, size.y)
	if gloss <= 0.0: return Vector2.ZERO
	var baseline := _label_baseline(font_size)
	var ink := GoStyle.ink_box(atr(text), font, font_size)
	var reach := float(get_theme_constant(&"outline_size")) * OUTLINE_REACH
	return Vector2(ceilf(gloss - (baseline + ink.position.y - reach)),
		(size.y - face.get_margin(SIDE_BOTTOM)) - (baseline + ink.end.y + reach))


## Where the label's baseline sits at [param font_size] on the normal face as the theme gives it (Button centres the
## line in the face's content height).
func _label_baseline(font_size: int) -> float:
	var face := _theme_face()
	var font := _base_font()
	if face == null or font == null: return 0.0
	var top := face.get_margin(SIDE_TOP)
	var bottom := face.get_margin(SIDE_BOTTOM)
	return top + (size.y - top - bottom - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)


## How far the label at [param font_size] moves down: as far as its own accents need (`_gloss_drop`), and with
## [member fit_with_row] as far as it takes to stand on its row's lowest baseline, so the row reads as one line
## (French ÉQUIPER sat 3 px under PLUS TARD) — never past its own room.
func _row_drop(font_size: int) -> float:
	var own := maxf(0.0, _gloss_drop(font_size))
	var peers := _fit_peers()
	if peers.size() < 2 or size.y <= 0.0: return own
	var line := _label_baseline(font_size) + own
	for peer in peers:
		if peer == self or not peer.is_inside_tree() or peer.size.y <= 0.0: continue
		var at := peer.fitted_font_size()
		line = maxf(line, peer._label_baseline(at) + maxf(0.0, peer._gloss_drop(at)))
	var room := _gloss_need(font_size).y if GoUi.skin().button_gloss_bottom(_theme_face(), size.y) > 0.0 else 0.0
	return maxf(own, minf(line - _label_baseline(font_size), maxf(own, room)))


## The normal face as the theme gives it — under the `ShiftedBox` this button wraps it in.
func _theme_face() -> StyleBox:
	var face := get_theme_stylebox(&"normal")
	var wrapped := face as ShiftedBox
	return wrapped.base if wrapped != null and wrapped.base != null else face


## The width the label may take: the button's (or the width the fit holds it at) less the padding and the glyph.
func _fit_room() -> float:
	var width := maxf(size.x, _held_width) if get_parent() is Container else _given_width()
	return width - _fit_padding_now() - glyph_allowance(_fit_tall())


## The height the fit gives the glyph room for: the button's, but never under its height at the size the fit starts
## from — a smaller label made a button sized by its label shorter, its glyph narrower and the label room wider, which
## fitted it bigger again (a key row without a fixed height swung between two sizes forever).
func _fit_tall() -> float:
	var font := _base_font()
	var face := get_theme_stylebox(&"normal")
	var tall := (face.get_minimum_size().y if face != null else 0.0) + (font.get_height(_fit_base()) if font != null else 0.0)
	return maxf(maxf(size.y, custom_minimum_size.y), tall)


## The other `fit_with_row` keys this one fits with (itself included): its parent's visible ones.
func _fit_peers() -> Array[GoGlyphButton]:
	var peers: Array[GoGlyphButton] = [self]
	var parent := get_parent()
	if not fit_with_row or parent == null: return peers
	for child in parent.get_children():
		var key := child as GoGlyphButton
		if key != null and key != self and key.fit_label and key.fit_with_row and key.visible: peers.append(key)
	return peers


## The width the label never takes: [member fit_padding], else the normal face's padding and the clear pad each side.
func _fit_padding_now() -> float:
	return _face_width() + 2.0 * fit_clear_pad() if fit_padding < 0.0 else fit_padding


## The clear room a fitted label keeps inside the face's padding on each side (dp): the look's `GoSkin.button_fit_pad()`
## at its window key height (`GoSkin.window_button_height()`), less half of how much shorter this key is — the face's
## padding is fixed while a shorter key's rounded ends are narrower, so they are clear sooner. 🔑 A 28 dp lobby chip
## (EASY / NORMAL / HARD, 90 dp) needs none: the 46 dp key's 6 dp shrank it to 10 dp and held it 100 dp wide.
func fit_clear_pad() -> float:
	var pad := GoUi.skin().button_fit_pad()
	var key := GoUi.skin().window_button_height()
	if pad <= 0.0 or key <= 0.0: return pad
	return maxf(0.0, pad - maxf(0.0, key - _fit_tall()) * 0.5)


## Fits the label now instead of on the next frame (a test, or a screen measuring itself right after a change).
func fit_now() -> void:
	_fit_queued = false
	if not fit_label or not is_inside_tree() or size.x <= 0.0: return
	_fit_text = text
	var wanted := fitted_font_size()
	_hold_floor_width()
	# 🔑 Every key of the row works its size and drop out from the same keys: one that differs is fitted again, and
	#    once they agree nothing is queued (no ping-pong).
	for peer in _fit_peers():
		if peer == self: continue
		var at := peer.fitted_font_size()
		if peer._fitted != at or not is_equal_approx(peer._held_width, _held_width) \
				or not is_equal_approx(peer._drop, peer._row_drop(at)):
			peer._queue_fit()
	_condense(wanted)
	var drop := _row_drop(wanted)
	if not is_equal_approx(drop, _drop):
		_drop = drop
		_update_shift()
	if wanted == _fitted and has_theme_font_size_override(&"font_size"): return
	_fitted = wanted
	add_theme_font_size_override(&"font_size", wanted)


## Holds the button as wide as its label at the fit floor beside the glyph and inside the padding (see [member fit_label]),
## when a container lays it out; a button placed by hand keeps the width it was given.
func _hold_floor_width() -> void:
	if not is_equal_approx(custom_minimum_size.x, _held_width): _asked_width = custom_minimum_size.x # the caller's
	var need := 0.0
	# 🔑 A row's keys hold the widest one's full-size width (`base_width()`), so they stay one width even when a key's
	#    label and glyph need more than its half (Spanish CANCELAR beside a coin and COMPRAR came out 256 and 269 dp
	#    wide), and no label shrinks for want of a window wide enough.
	# 🔑 A label the caller lets trim (`text_overrun_behavior` or `clip_text`) ends in an ellipsis in the width it
	#    was given instead: GoRewardRow's claim pill is a fixed slot (ABHOLEN UND SOFORT BEHALTEN held it 373 dp wide
	#    in a 336 dp row).
	if get_parent() is Container and not _trims_label():
		if fit_with_row:
			var share := _row_share()
			var least := 0.0
			for peer in _fit_peers():
				need = maxf(need, peer.base_width())
				least = maxf(least, peer.condensed_floor_width() if share > 0.0 else peer.floor_width())
			# 🔑 …but never past the row's share of its window's standard width (`GoSurface.free_width`): there the
			#    labels shrink (to one size, `fitted_font_size`), then condense (`_condense`), instead — German
			#    MÜNZEN VERDIENEN beside a coin held both keys 309 dp and the card 628 dp, far wider than every other
			#    language. Only a label too long even condensed at the floor widens the window, by that much.
			if share > 0.0: need = maxf(least, minf(need, share))
		else:
			need = floor_width()
	var want := maxf(_asked_width, need)
	_held_width = want
	if not is_equal_approx(custom_minimum_size.x, want): custom_minimum_size.x = want


## The width each `fit_with_row` key of this row has with its window (the nearest `GoSurface`) at its standard width:
## the row's free width (`GoSurface.free_width`) less its gaps and its other content, split evenly. 0: no window, or not laid out yet.
func _row_share() -> float:
	var row := get_parent() as Container
	var surface: GoSurface = null
	var node := get_parent()
	while node != null and surface == null:
		surface = node as GoSurface
		node = node.get_parent()
	if row == null or surface == null: return 0.0
	var free := surface.free_width(row)
	if free <= 0.0: return 0.0
	var keys := 0
	var shown := 0
	for child in row.get_children():
		var control := child as Control
		if control == null or not control.visible: continue
		shown += 1
		var key := control as GoGlyphButton
		if key != null and key.fit_label and key.fit_with_row: keys += 1
		else: free -= control.get_combined_minimum_size().x # a row's other content keeps its own width
	if keys == 0: return 0.0
	var gap := float(row.get_theme_constant(&"separation")) if row is BoxContainer else 0.0
	return floorf((free - gap * maxf(0.0, shown - 1)) / keys)


## The caller lets the label trim (an ellipsis, or clipped) instead of widening the button.
func _trims_label() -> bool:
	return clip_text or text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING


## The width a button placed by hand was given — its anchors and offsets, before its minimum size widens it — so a
## label too long even condensed never feeds its own width back into the room.
func _given_width() -> float:
	var given := (anchor_right - anchor_left) * get_parent_area_size().x + offset_right - offset_left
	return minf(size.x, given) if given > 0.0 else size.x


## Condenses the label at [param font_size] to the room when it is still wider (see [member fit_label]); drops the
## condensing when it fits.
func _condense(font_size: int) -> void:
	var font := _base_font()
	var label := atr(text)
	var gaps := label.length() - 1 # the advances that close up (the last glyph's is trimmed off the line)
	var wide := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
	var step := 0
	var over := wide - _fit_room()
	if gaps > 0 and over > 0.5:
		# 🔑 A transform draws the glyphs narrower but keeps their advances: the advances close up by whole pixels
		#    (`spacing_glyph`), and the glyphs narrow by the same share, never below the condense floor.
		step = mini(ceili(over / gaps), floori(wide * (1.0 - GoUi.config.fit_condense_min) / gaps))
	if step <= 0:
		_drop_condense()
		return
	var share := snappedf(1.0 - float(step * gaps) / wide, 0.01)
	var by_font: Dictionary = _condense_cache.get(font, {})
	var key := Vector2i(step, roundi(share * 100.0))
	var condensed: FontVariation = by_font.get(key)
	if condensed == null:
		condensed = FontVariation.new()
		condensed.base_font = font
		condensed.spacing_glyph = -step
		condensed.variation_transform = Transform2D(Vector2(share, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
		by_font[key] = condensed
		_condense_cache[font] = by_font
	if condensed == _condensed and has_theme_font_override(&"font"): return
	_condensed = condensed
	add_theme_font_override(&"font", condensed)


func _drop_condense() -> void:
	if _condensed != null and has_theme_font_override(&"font") and get_theme_font(&"font") == _condensed:
		remove_theme_font_override(&"font")
	_condensed = null


## The width this button's label needs at the fit floor beside its glyph, inside its padding (0: no fit, no text).
func floor_width() -> float:
	return _width_at(GoStyle.fit_floor(_fit_base()))


## The width this button's label needs at the fit floor condensed as far as `_condense` goes
## (`GoConfig.fit_condense_min`), beside its glyph, inside its padding — the least a window's row key is held at.
## 🛑 A label any of whose characters a fallback draws (Japanese コインを集める) is the floor's width: the condensing
##    FontVariation's spacing and transform reach its own face only, never a fallback (as `variation_embolden`).
func condensed_floor_width() -> float:
	var font := _base_font()
	if not fit_label or font == null or text.is_empty(): return 0.0
	var label := atr(text)
	var rids := font.get_rids()
	if rids.is_empty(): return floor_width()
	var ts := TextServerManager.get_primary_interface()
	for i in label.length():
		var code := label.unicode_at(i)
		if code > 32 and not ts.font_has_char(rids[0], code): return floor_width()
	var wide := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, GoStyle.fit_floor(_fit_base())).x
	var gaps := label.length() - 1
	# The advances close up by whole pixels, as far as `_condense` takes them.
	var step := floori(wide * (1.0 - GoUi.config.fit_condense_min) / gaps) if gaps > 0 else 0
	return ceilf(wide - step * gaps + _fit_padding_now() + glyph_allowance(_fit_tall()))


## The width this button's label needs at its full size (the size the fit starts from) beside its glyph, inside its
## padding (0: no fit, no text) — what a `fit_with_row` key holds (see [member fit_with_row]).
func base_width() -> float:
	return _width_at(_fit_base())


func _width_at(font_size: int) -> float:
	var font := _base_font()
	if not fit_label or font == null or text.is_empty(): return 0.0
	return ceilf(font.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			+ _fit_padding_now() + glyph_allowance(_fit_tall()))


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


## The font the label is drawn in before any condensing — the one under the condensed override the fit put on.
func _base_font() -> Font:
	if _condensed != null and has_theme_font_override(&"font") and get_theme_font(&"font") == _condensed:
		return _condensed.base_font
	return get_theme_font(&"font")


## The normal face's minimum width, the padding the label never takes.
## 🔑 With a glyph, the face as shifted for the glyph at the fit's height (`_fit_tall()`), not the button's height now:
##    a thin face grows with the shift, so a width read at the fitted height swung the fit back and forth.
func _face_width() -> float:
	var face := get_theme_stylebox(&"normal")
	if face == null: return 0.0
	var wrapped := face as ShiftedBox
	var from := wrapped.base if wrapped != null and wrapped.base != null else face
	if wrapped == null: return face.get_minimum_size().x
	var sides := ShiftedBox.margins(from, glyph_allowance(_fit_tall()) * 0.5, is_layout_rtl(), MIN_EDGE)
	return from.get_minimum_size().x - from.get_margin(SIDE_LEFT) - from.get_margin(SIDE_RIGHT) + sides.x + sides.y


func _drop_fit() -> void:
	if _fitted != 0 and has_theme_font_size_override(&"font_size"): remove_theme_font_size_override(&"font_size")
	_fitted = 0
	if is_equal_approx(custom_minimum_size.x, _held_width) and _held_width > 0.0: custom_minimum_size.x = _asked_width
	_held_width = 0.0
	_drop_condense()
	if _drop > 0.0:
		_drop = 0.0
		_update_shift()


## Re-wraps the theme's faces with the current shift and gloss drop (or drops the wrappers when there is neither).
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
	if _shift > 0.0 or _drop > 0.0:
		for state in TEXT_STATES:
			var face := get_theme_stylebox(state)
			if face == null: continue
			var wrapper := ShiftedBox.new(face, _shift, is_layout_rtl(), MIN_EDGE, _drop)
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
	var rect := glyph_rect()
	# Custom textures (GoTextureSprite) draw their own destination rectangle and need not preserve the engine's
	# negative-width convention. Mirror the canvas instead, leaving every texture a normal positive rectangle.
	if glyph_flip_h:
		draw_set_transform(Vector2(rect.get_center().x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(art, rect, false, glyph_tint())
	if glyph_flip_h: draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where [member check_badge] is drawn, in the button's space (empty without a badge).
func badge_rect() -> Rect2:
	if check_badge == null: return Rect2()
	var side := size.y * BADGE_SHARE
	var centre := Vector2(size.x - size.y * BADGE_CENTRE.x, size.y * BADGE_CENTRE.y)
	return Rect2(centre - Vector2.ONE * side * 0.5, Vector2.ONE * side)


func _draw_badge() -> void:
	if check_badge == null: return
	draw_texture_rect(check_badge, badge_rect(), false)


## Draws (or clears) the glow on its own canvas item, behind the button's face.
func _update_glow() -> void:
	if not glow:
		if _glow_item.is_valid(): RenderingServer.canvas_item_clear(_glow_item)
		return
	if not is_inside_tree(): return
	if not _glow_item.is_valid():
		_glow_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(_glow_item, get_canvas_item())
		RenderingServer.canvas_item_set_draw_behind_parent(_glow_item, true)
	RenderingServer.canvas_item_clear(_glow_item)
	var light := StyleBoxFlat.new()
	# The body is hidden under the face; only its shadow, the light, shows past the edge.
	light.bg_color = GoUi.skin().button_glow_color()
	light.set_corner_radius_all(int(size.y * 0.5))
	light.shadow_color = light.bg_color
	light.shadow_size = maxi(1, int(size.y * GLOW_SHARE))
	light.draw(_glow_item, Rect2(Vector2.ZERO, size))


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
