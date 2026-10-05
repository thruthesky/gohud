## 💬 **A comic panel face** — a bold ink outline and a hard, faint shadow dropped down and to the right (the `comic_*`
## looks).
##
## ```gdscript
## var face := GoStyleBoxComic.new()
## face.bg_color = Color("#FFFFFF")
## face.border_color = Color("#1F2233")      # the ink
## face.shadow_color = Color("#1F2233", 0.22)
## face.radius = 12.0
## button.add_theme_stylebox_override(&"normal", face)
## ```
##
## ## 🔑 One setting changes every face
## The outline, the shadow's size and whether a shadow shows at all are **not baked into the face**: left at their
## defaults they are read from `GoConfig` each time the face is drawn — `comic_border_width`, `comic_shadow_size` and
## `comic_shadow`. So one line before (or after) building a screen restyles every comic part at once:
##
## ```gdscript
## GoUi.use_preset(&"comic_light")
## GoUi.config.comic_border_width = 2.0   # thinner ink everywhere
## GoUi.config.comic_shadow = false       # no shadows anywhere
## ```
##
## A face decides for itself with `outline` (dp, ≥ 0), `drop` (dp, ≥ 0) and `shadow` (`ON`/`OFF`) —
## `GoStyle.comic_shadow(node, on)` and `GoStyle.comic_border(node, width)` set them on one widget's faces.
##
## ## 🛑 Sizes never change
## The outline is drawn **inside** the rectangle and the shadow outside it (as `StyleBoxFlat` draws its shadow), so a
## thicker outline or a bigger shadow never moves a control. Padding is the built-in `content_margin_*`
## (`_get_style_margin()` is never called for a GDScript StyleBox — measured on 4.7).
##
## 🛑 The field names **match `StyleBoxFlat`** (`bg_color`, `border_color`, `border_width`, `draw_center`, `shadow_*`,
##    `expand_margin_*`) and `GoStyleBoxMedieval` (`radius`) — `GoSkin.fade_box`, `box_background`, `_edge_fill`,
##    `GoStyle._flat_like` and the layout audit look those names up. `border_width` and `shadow_size` read the size
##    actually drawn (the setting applied); writing them sets this face's own value.
## 🔑 Drawn from one `StyleBoxFlat`, only when the control redraws — no texture, no shader, no per-frame cost.
@tool
class_name GoStyleBoxComic
extends StyleBox

## Whether this face drops a shadow: `FOLLOW` the project setting (`GoConfig.comic_shadow`), always (`ON`) or never (`OFF`).
enum Shadow { FOLLOW, ON, OFF }

## Corner and side bits for `corners` and `sides`.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_RIGHT := 4
const BOTTOM_LEFT := 8
const LEFT := 1
const TOP := 2
const RIGHT := 4
const BOTTOM := 8
const ALL := 15

## The face — the colour text is measured against (`GoSkin.box_background`).
@export var bg_color := Color.WHITE:
	set(value):
		bg_color = value
		emit_changed()
## The ink of the outline.
@export var border_color := Color("#1F2233"):
	set(value):
		border_color = value
		emit_changed()
## This face's outline (dp). Negative: `GoConfig.comic_border_width` × `outline_scale` — the project-wide dial.
@export var outline := -1.0:
	set(value):
		outline = value
		emit_changed()
## How much of the project-wide outline this face takes (a list row's thinner line) — only while `outline` is negative.
@export_range(0.0, 3.0, 0.05) var outline_scale := 1.0:
	set(value):
		outline_scale = value
		emit_changed()
## Corner radius (dp). More than half the short side makes a pill or a disc.
@export var radius := 12.0:
	set(value):
		radius = value
		emit_changed()
## Which corners round.
@export_flags("Top left", "Top right", "Bottom right", "Bottom left") var corners := ALL:
	set(value):
		corners = value
		emit_changed()
## Which sides carry the outline (a folding title has no bottom line — its body continues there).
@export_flags("Left", "Top", "Right", "Bottom") var sides := ALL:
	set(value):
		sides = value
		emit_changed()
@export var draw_center := true:
	set(value):
		draw_center = value
		emit_changed()
## Whether this face drops a shadow — see `Shadow`.
@export var shadow := Shadow.FOLLOW:
	set(value):
		shadow = value
		emit_changed()
## The shadow — keep it faint: it is a block of ink behind the face, not a blur.
@export var shadow_color := Color(0.12, 0.13, 0.2, 0.22):
	set(value):
		shadow_color = value
		emit_changed()
## How far the shadow sits down and to the right (dp). Negative: `GoConfig.comic_shadow_size` × `drop_scale`.
@export var drop := -1.0:
	set(value):
		drop = value
		emit_changed()
## How much of the project-wide shadow this face takes (a chip's smaller one) — only while `drop` is negative.
@export_range(0.0, 3.0, 0.05) var drop_scale := 1.0:
	set(value):
		drop_scale = value
		emit_changed()
## A ring drawn **just inside the ink** of the face under it — `inset` in — so a focus ring keeps the key's outline
## instead of covering it. Draw it hollow (`draw_center` off).
@export var inner := false:
	set(value):
		inner = value
		emit_changed()
## How far in an `inner` ring sits (dp). Negative: the project's outline (`comic_border_width`) plus 1 — the ink of the
## key under it. `GoStyle.comic_border()` sets it on a widget whose own ink is wider or thinner.
@export var inset := -1.0:
	set(value):
		inset = value
		emit_changed()
## Pressed: the shadow goes and the face sinks a little towards where it was (never more than `PRESS_SINK`).
@export var pressed := false:
	set(value):
		pressed = value
		emit_changed()
## Grows the drawn face past the control's edges, or shrinks it (negative) — `StyleBoxFlat`'s names.
@export var expand_margin_left := 0.0:
	set(value):
		expand_margin_left = value
		emit_changed()
@export var expand_margin_top := 0.0:
	set(value):
		expand_margin_top = value
		emit_changed()
@export var expand_margin_right := 0.0:
	set(value):
		expand_margin_right = value
		emit_changed()
@export var expand_margin_bottom := 0.0:
	set(value):
		expand_margin_bottom = value
		emit_changed()

## The furthest a pressed face sinks (dp) — the label does not move with it, so it stays small.
const PRESS_SINK := 2.0

## The outline actually drawn (dp). Writing it sets this face's own `outline`.
var border_width: float:
	get: return outline_width()
	set(value): outline = maxf(0.0, value)
## The shadow actually drawn (dp, 0 = none). Writing 0 turns this face's shadow off; more sets its own `drop` and
## lets a face that was off follow the setting again (as `StyleBoxFlat`, a size asked for is a shadow asked for).
var shadow_size: int:
	get: return roundi(drop_size())
	set(value):
		if value <= 0:
			shadow = Shadow.OFF
		else:
			drop = value
			if shadow == Shadow.OFF: shadow = Shadow.FOLLOW
## Where the shadow sits — always down and to the right, `drop_size()` each way.
var shadow_offset: Vector2:
	get:
		var size := drop_size()
		return Vector2(size, size)
	set(value):
		if value != Vector2.ZERO: drop = maxf(absf(value.x), absf(value.y))

var _flat := StyleBoxFlat.new()


func _init() -> void:
	_flat.anti_aliasing = true


## The outline drawn (dp) — this face's `outline`, or the project's `comic_border_width` × `outline_scale`.
func outline_width() -> float:
	if outline >= 0.0: return outline
	return maxf(0.0, float(GoUi.config.comic_border_width) * outline_scale)


## Does this face drop a shadow — its own `shadow`, or the project's `comic_shadow`? (A pressed face still says yes:
## it is the same part, only pushed in.)
func shows_shadow() -> bool:
	match shadow:
		Shadow.ON: return true
		Shadow.OFF: return false
	return GoUi.config.comic_shadow


## The shadow drawn (dp) — 0 when it is off or pressed in.
func drop_size() -> float:
	if pressed: return 0.0
	return _drop()


func _drop() -> float:
	if not shows_shadow() or shadow_color.a <= 0.0: return 0.0
	if drop >= 0.0: return drop
	return maxf(0.0, float(GoUi.config.comic_shadow_size) * drop_scale)


## `StyleBoxFlat`'s names — one outline width for every side, one radius for every corner.
func set_border_width_all(width: int) -> void:
	outline = width


func set_corner_radius_all(value: int) -> void:
	radius = value


## Copies [param source]'s padding — the control keeps its size when its face becomes comic.
func keep_margins(source: StyleBox) -> GoStyleBoxComic:
	if source != null:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			set_content_margin(side, source.get_margin(side))
	return self


## This face as a `StyleBoxFlat` with the outline, corners, padding and a crisp shadow **as they are now** — for code
## that needs a flat face (`GoStyle.box()`). 🛑 It no longer follows the settings: a later change does not reach it.
func to_flat() -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	_shape(flat, outline_width(), minf(radius, 999.0))
	flat.bg_color = bg_color
	flat.draw_center = draw_center
	flat.border_color = border_color
	var size := drop_size()
	if size > 0.0:
		# A blur of 1 is the crisp block; the offset carries the size.
		flat.shadow_color = shadow_color
		flat.shadow_size = 1
		flat.shadow_offset = Vector2(size, size)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: flat.set_content_margin(side, get_margin(side))
	flat.expand_margin_left = expand_margin_left
	flat.expand_margin_top = expand_margin_top
	flat.expand_margin_right = expand_margin_right
	flat.expand_margin_bottom = expand_margin_bottom
	return flat


func _draw(canvas: RID, rect: Rect2) -> void:
	rect = rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	var radius_drawn := radius
	if inner:
		var gap := inset if inset >= 0.0 else float(GoUi.config.comic_border_width) + 1.0
		rect = rect.grow(-gap)
		radius_drawn = maxf(0.0, radius - gap)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0: return
	var corner := minf(radius_drawn, minf(rect.size.x, rect.size.y) * 0.5)
	var width := outline_width()
	var size := drop_size()
	if size > 0.0:
		_flat.shadow_size = 0
		_flat.border_color = shadow_color
		_flat.bg_color = shadow_color
		var solid := draw_center and bg_color.a >= 0.999
		if solid:
			# An opaque face hides all but the part of the block that sticks out.
			_shape(_flat, 0.0, corner)
			_flat.draw_center = true
		else:
			# 🛑 A see-through face (a faded HUD panel, an outlined button) would show the block through it — draw only
			#    what sticks out: a band down the right side and along the bottom.
			_shape(_flat, 0.0, corner)
			_flat.draw_center = false
			_flat.border_width_right = int(ceilf(size)) if sides & RIGHT else 0
			_flat.border_width_bottom = int(ceilf(size)) if sides & BOTTOM else 0
		_flat.draw(canvas, Rect2(rect.position + Vector2(size, size), rect.size))
	elif pressed:
		# Pushed in: the face sinks a little towards where its shadow was.
		var sink := minf(_drop() * 0.5, PRESS_SINK)
		rect.position += Vector2(sink, sink)
	_shape(_flat, width, corner)
	_flat.bg_color = bg_color
	_flat.draw_center = draw_center and bg_color.a > 0.0
	_flat.border_color = border_color
	_flat.shadow_size = 0
	if not _flat.draw_center and (width <= 0.0 or border_color.a <= 0.0): return
	_flat.draw(canvas, rect)


## Puts the outline of [param width] on the chosen sides and [param corner] on the chosen corners of [param flat].
func _shape(flat: StyleBoxFlat, width: float, corner: float) -> void:
	var side := int(roundf(width))
	flat.border_width_left = side if sides & LEFT else 0
	flat.border_width_top = side if sides & TOP else 0
	flat.border_width_right = side if sides & RIGHT else 0
	flat.border_width_bottom = side if sides & BOTTOM else 0
	var arc := int(corner)
	flat.corner_radius_top_left = arc if corners & TOP_LEFT else 0
	flat.corner_radius_top_right = arc if corners & TOP_RIGHT else 0
	flat.corner_radius_bottom_right = arc if corners & BOTTOM_RIGHT else 0
	flat.corner_radius_bottom_left = arc if corners & BOTTOM_LEFT else 0
	flat.corner_detail = clampi(int(corner * 0.5), 3, 16)


func _get_draw_rect(rect: Rect2) -> Rect2:
	rect = rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	var size := maxf(drop_size(), _drop() * 0.5 if pressed else 0.0)
	if size <= 0.0: return rect
	return rect.merge(Rect2(rect.position + Vector2(size, size), rect.size))
