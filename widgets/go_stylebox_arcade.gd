## 🕹 **An arcade key** — the buttons, boards and fields of the `arcade_*` looks.
##
## A thick dark ink outline; a body whose colour runs from light at the top to deeper below (a vertical gradient); a
## deeper lip under the body inside the outline; and a candy gloss — a white sheen over the upper half, a glint round
## both top corners and a dash between them (`gloss`; `STROKE` is one stroke round the top-left corner). Pressed, the lip
## goes and the body sinks into its place. A panel is a **board**: the body is a thick coloured frame (`frame`) round
## a pale well — the well is `bg_color` → `bottom_color`, so text measured on the face is measured on the well — with
## a thin ink line round it (`inner_line`). A text field is the same face turned in (`sunken`): a shadow inside along
## its top, no lip, no gloss.
##
## ```gdscript
## var key := GoStyleBoxArcade.new()
## key.bg_color = Color("#7BE36A")            # the light top of the body
## key.bottom_color = Color("#3CBF3A")        # …running down to this
## key.border_color = Color("#1B2146")        # the ink outline
## key.radius = 18.0
## key.lip = 4.0                              # the deeper band under the body (shade_color, or a deep tone of the body)
## button.add_theme_stylebox_override(&"normal", key)
## var down := key.duplicate() as GoStyleBoxArcade
## down.pressed = true                        # the lip goes, the body sinks — the button keeps its size
## button.add_theme_stylebox_override(&"pressed", down)
## ```
##
## ## 🛑 Sizes never change
## Everything is drawn **inside** the rectangle (a shadow, when one is set, outside it) and nothing here adds to the
## minimum size: the padding is `content_margin_*`, as on `GoStyleBoxJelly`, whose fields, `keep_margins()` and `pad()`
## this face inherits — so every reader of a jelly face (`GoSkin.fade_box`, `box_background`, `GoStyle._flat_like`, the
## layout audit's `border_width` and `radius`) reads this one too.
## 🛑 Fading (`bg_color.a`) fades every colour of the body, the frame, the well and the gloss together; the ink then
##    becomes a ring, so a see-through panel never shows a block of ink through it.
## 🔑 Drawn from a few `StyleBoxFlat`s, two gradient polygons and one polyline, only when the control redraws — no
##    texture, no shader, no per-frame cost.
@tool
class_name GoStyleBoxArcade
extends GoStyleBoxJelly

## Where the body's gradient ends, at the bottom (on a board: the well's). Transparent: `bg_color` a little deeper.
@export var bottom_color := Color(0, 0, 0, 0):
	set(value):
		bottom_color = value
		emit_changed()
## A board's frame between the ink and the well (dp). 0: a key — the body is the face.
@export var frame := 0.0:
	set(value):
		frame = value
		emit_changed()
## The top of a board's frame. Its lip (`shade_color`) and its bottom follow it.
@export var frame_color := Color(0, 0, 0, 0):
	set(value):
		frame_color = value
		emit_changed()
## The bottom of a board's frame. Transparent: `frame_color` a little deeper.
@export var frame_bottom := Color(0, 0, 0, 0):
	set(value):
		frame_bottom = value
		emit_changed()
## The ink line round a board's well (dp) — drawn in `inner_line` when that is not transparent.
@export var line_width := 2.0:
	set(value):
		line_width = value
		emit_changed()

## How the gloss is laid on a key.
enum Gloss {
	## A candy key: a soft white sheen over the upper half of the body, a glint round **both** top corners and a short
	## dash at the top's middle — the glossy pill of an arcade menu. Symmetric, so it reads the same right to left.
	CANDY,
	## One white stroke round the top-left corner, fading along the top (gohud 1.3.0's arcade key).
	STROKE,
}
## The gloss a key wears (`shine` sets how strong). A board's frame always takes a glint at each top corner.
@export var gloss := Gloss.CANDY:
	set(value):
		gloss = value
		emit_changed()
## 🎀 A ribbon: this much at each end (dp) is a swallow-tailed fold behind a body that stands in from the ends — the
## banner over an arcade window (`GoSkinArcade.title_plate_box`). 0: a plain key. The body keeps the text: pad the
## face at least `tails` more at each end (`GoSkinArcade` does).
@export var tails := 0.0:
	set(value):
		tails = value
		emit_changed()
## How far a ribbon's body stands above its tails' lower edge (dp) — the tails hang that much below it. Pad the face
## so the text sits in the body: half of it off the bottom, onto the top (the sum, the size, stays).
@export var tail_drop := 4.0:
	set(value):
		tail_drop = value
		emit_changed()


## The pale well a board's content keeps round it, inside the frame (dp) — `tools/theme_arcade.py` `WELL_ROOM`.
const WELL_ROOM := 3.0


## The thinnest frame worth drawing (dp). Under it a board is drawn as a key cap: the well's colours inside the ink.
const MIN_FRAME := 3.0


## The frame as drawn: never over the content. A board's padding holds the ink, the frame, `WELL_ROOM` and (at the
## bottom) the lip — padded less (`GoStyle.hud_panel(…, pad_x, pad_y)`, a card padded by hand), the frame gives way; with
## no room for `MIN_FRAME` it goes (0), and the board is a key cap in the well's colours. 🛑 A sliver of frame was worse:
## the well's ink line then ran right along the text. A board with no padding at all (a window's card, which pads its
## content itself) keeps its whole frame.
func frame_drawn() -> float:
	if frame <= 0.0 or frame_color.a <= 0.0: return 0.0
	var sides := [content_margin_left, content_margin_top, content_margin_right, content_margin_bottom]
	if sides.max() <= 0.0: return frame
	var room := minf(minf(content_margin_left, content_margin_right),
		minf(content_margin_top, content_margin_bottom - maxf(0.0, lip)))
	var rim := minf(room - maxf(0.0, border_width) - WELL_ROOM, frame)
	return rim if rim >= MIN_FRAME else 0.0


## The body's top colour — on a board, the frame's.
func top() -> Color:
	return frame_color if frame_drawn() > 0.0 else bg_color


## The colour the body's gradient ends on — on a board, the frame's.
func bottom() -> Color:
	if frame_drawn() > 0.0:
		return frame_bottom if frame_bottom.a > 0.0 else _deeper(frame_color, 0.14)
	return bottom_color if bottom_color.a > 0.0 else _deeper(bg_color, 0.14)


## The well's bottom on a board (the body's on a key).
func well_bottom() -> Color:
	return bottom_color if bottom_color.a > 0.0 else _deeper(bg_color, 0.06)


## The lip under the body. 🛑 Towards the ink, not black: a green key's lip stays green, only deeper.
func shade() -> Color:
	# A board drawn as a cap (no room for its frame) takes a lip of its well, not the frame's.
	if shade_color.a > 0.0 and not (frame > 0.0 and frame_drawn() <= 0.0): return shade_color
	return Color(bottom().lerp(edge(), 0.3), 1.0)


## [param colour] a little towards black, keeping its alpha.
static func _deeper(colour: Color, amount: float) -> Color:
	return Color(colour.lerp(Color.BLACK, amount), colour.a)


## 🎨 The three tones of a key painted [param colour]: its light top, the bottom its gradient runs to and its lip —
## what `GoStyle.arcade_paint()` and the arcade skin lay on a face (`tools/theme_arcade.py` `tones()` is the same rule).
static func tones(colour: Color) -> Array[Color]:
	var solid := Color(colour, 1.0)
	return [solid.lerp(Color.WHITE, 0.18), solid.lerp(Color.BLACK, 0.06), solid.lerp(Color.BLACK, 0.3)]


## The bar a white, ink-outlined label clears at every height of a painted key (`tools/theme_arcade.py` `NEED`).
const LABEL_NEED := 4.6


## [param colour] moved until a white label with a [param line] outline reads at every height of the key it paints:
## a paint the ink reads on better goes lighter, one the white reads on better goes deeper. WCAG's note on 1.4.3 counts
## a letter's outline as part of the letter, so the label reads on whichever of the two stands off the paint more
## (`tools/theme_arcade.py` `fit()` is the same rule; `tools/check_contrast.py` measures it so).
static func fit(colour: Color, line: Color) -> Color:
	var solid := Color(colour, 1.0)
	if worst_label(solid, line) >= LABEL_NEED: return solid
	var three := tones(solid)
	var middle := three[0].lerp(three[1], 0.5)
	var towards := Color.WHITE if GoSkin.contrast_ratio(line, middle) >= GoSkin.contrast_ratio(Color.WHITE, middle) \
		else Color.BLACK
	for step in range(1, 40):
		var moved := solid.lerp(towards, float(step) * 0.025)
		if worst_label(moved, line) >= LABEL_NEED: return moved
	return solid


## How well a white label with a [param line] outline reads at the weakest height of a key painted [param colour].
static func worst_label(colour: Color, line: Color) -> float:
	var three := tones(colour)
	var worst := INF
	for step in 5:
		var back := three[0].lerp(three[1], float(step) / 4.0)
		worst = minf(worst, maxf(GoSkin.contrast_ratio(Color.WHITE, back), GoSkin.contrast_ratio(line, back)))
	return worst


## Paints this face [param colour]: the body's top, bottom and lip (on a board, the frame's). Returns the face.
func paint(colour: Color) -> GoStyleBoxArcade:
	var three := tones(colour)
	if frame > 0.0:
		frame_color = three[0]
		frame_bottom = three[1]
	else:
		bg_color = Color(three[0], bg_color.a)
		bottom_color = three[1]
	shade_color = three[2]
	return self


## This face as a `StyleBoxFlat` — for the calls that promise one (`GoStyle.box()`, `GoStyle.floating()`). A board
## keeps what makes it a board: its frame becomes the border (the frame's middle colour, as wide as the frame and the
## ink together) round the well. A key keeps its ink outline round its top colour. The gradient, the gloss and the lip
## are lost; the padding, the corner and the shadow stay.
func to_flat() -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = bg_color
	flat.draw_center = draw_center
	if frame_drawn() > 0.0:
		flat.border_color = Color(top().lerp(bottom(), 0.5), 1.0)
		flat.set_border_width_all(roundi(frame_drawn() + border_width))
	else:
		flat.border_color = edge()
		flat.set_border_width_all(roundi(border_width))
	flat.set_corner_radius_all(roundi(minf(radius, 999.0)))
	flat.shadow_color = shadow_color
	flat.shadow_size = shadow_size
	flat.shadow_offset = shadow_offset
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: flat.set_content_margin(side, get_margin(side))
	flat.expand_margin_left = expand_margin_left
	flat.expand_margin_top = expand_margin_top
	flat.expand_margin_right = expand_margin_right
	flat.expand_margin_bottom = expand_margin_bottom
	return flat


func _draw(canvas: RID, rect: Rect2) -> void:
	rect = rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0: return
	if max_size.x > 0.0 and rect.size.x > max_size.x:
		rect = Rect2(rect.position.x + (rect.size.x - max_size.x) * 0.5, rect.position.y, max_size.x, rect.size.y)
	if max_size.y > 0.0 and rect.size.y > max_size.y:
		rect = Rect2(rect.position.x, rect.position.y + (rect.size.y - max_size.y) * 0.5, rect.size.x, max_size.y)
	# A ribbon: the folded tails first, behind; the body is then a key standing in from the ends.
	var tail := ribbon_tails(rect)
	if tail > 0.0 and draw_center:
		var drop := minf(maxf(0.0, tail_drop), rect.size.y * 0.25)
		var body_rect := Rect2(rect.position.x + tail, rect.position.y, rect.size.x - tail * 2.0, rect.size.y - drop)
		_tails(canvas, rect, body_rect)
		rect = body_rect
	var outline := maxf(0.0, border_width)
	var base := maxf(0.0, lip) if not sunken else 0.0
	var outer := rect
	if pressed and base > 1.0:
		var drop := minf(base - 1.0, sink) if sink >= 0.0 else base - 1.0
		outer.position.y += drop
		outer.size.y -= drop
		base -= drop
	var corner := minf(radius, minf(outer.size.x, outer.size.y) * 0.5)
	var ink := edge()
	if not draw_center:
		# A ring only — a focus ring, or a face that leaves its middle to what is under it.
		if outline > 0.0: _box(canvas, outer, Color.TRANSPARENT, corner, ink, outline)
		return
	var alpha := bg_color.a
	# 1 · The ink: one rounded block under everything, with the shadow a floating panel or a raised key casts.
	#     🛑 A see-through face gets no block (it would show through the body); its ring comes last, as on every face.
	if alpha >= 0.999: _box(canvas, outer, ink, corner, Color.TRANSPARENT, 0.0, 0.0, true)
	elif shadow_size > 0 and shadow_color.a > 0.0: _box(canvas, outer, Color.TRANSPARENT, corner, ink, outline, 0.0, true)
	var inner := outer.grow(-outline)
	if inner.size.x <= 1.0 or inner.size.y <= 1.0:
		if outline > 0.0: _box(canvas, outer, Color.TRANSPARENT, corner, ink, outline)
		return
	var inner_corner := maxf(0.0, corner - outline)
	# The body reaches a little under the ring drawn over its edge, so that edge is the ring's smooth one.
	var reach := minf(outline * 0.5, 1.0)
	if sunken:
		# 2 · A well: the deep tone fills it and shows along the top as the shadow inside; the body lies below it.
		_box(canvas, inner.grow(reach), Color(shade(), alpha), inner_corner + reach)
		var dip := clampf(inner.size.y * 0.08, 2.0, 4.0)
		var lower := Rect2(inner.position + Vector2(0.0, dip), inner.size - Vector2(0.0, dip))
		_gradient(canvas, lower, inner_corner, lower.end.y, Color(bg_color, alpha), Color(well_bottom(), alpha), reach)
	else:
		# 2 · The lip: the inner shape in the lip's tone; the body is laid over all of it but the bottom `base`.
		if base > 0.0: _box(canvas, inner.grow(reach), Color(shade(), alpha), inner_corner + reach)
		var cut := inner.end.y - base
		_gradient(canvas, inner, inner_corner, cut, Color(top(), alpha), Color(bottom(), alpha), reach)
		# 3 · A board's well inside its frame, with an ink line round it.
		var rim := frame_drawn()
		if rim > 0.0:
			var body := Rect2(inner.position, Vector2(inner.size.x, cut - inner.position.y))
			var well := body.grow(-rim)
			if well.size.x > 2.0 and well.size.y > 2.0:
				var well_corner := maxf(0.0, inner_corner - rim)
				var lined := inner_line.a > 0.0 and line_width > 0.0
				_gradient(canvas, well, well_corner, well.end.y, Color(bg_color, alpha), Color(well_bottom(), alpha),
					minf(line_width * 0.5, 1.0) if lined else 0.0)
				if lined:
					_box(canvas, well.grow(line_width * 0.5), Color.TRANSPARENT, well_corner + line_width * 0.5,
						Color(inner_line, inner_line.a * alpha), line_width)
		# 4 · The gloss round the top-left corner — on a board, inside its frame, never over the text in the well.
		if shine > 0.0:
			var lit := Rect2(inner.position, Vector2(inner.size.x, cut - inner.position.y))
			if rim <= 0.0:
				if gloss == Gloss.CANDY: _candy(canvas, lit, inner_corner, alpha)
				else: _gloss(canvas, lit, inner_corner, alpha)
			elif rim >= 4.0: _gloss_frame(canvas, lit, inner_corner, alpha)
	# 5 · The ink ring last, its smooth inner edge over the edges of everything under it.
	if outline > 0.0: _box(canvas, outer, Color.TRANSPARENT, corner, ink, outline)


## A rounded box [param at] filled with a vertical gradient from [param from] (its top) to [param to] (at
## [param cut_y]), cut off flat at [param cut_y]. [param reach] grows it under a line drawn over its edge.
func _gradient(canvas: RID, at: Rect2, corner: float, cut_y: float, from: Color, to: Color, reach := 0.0) -> void:
	if at.size.x <= 1.0 or at.size.y <= 1.0 or cut_y <= at.position.y + 0.5: return
	var shape := _round_rect(at.grow(reach), corner + reach)
	var parts: Array[PackedVector2Array] = [shape]
	if cut_y < at.end.y + reach - 0.01:
		var keep := PackedVector2Array([at.position - Vector2(4, 4), Vector2(at.end.x + 4, at.position.y - 4),
			Vector2(at.end.x + 4, cut_y), Vector2(at.position.x - 4, cut_y)])
		parts = Geometry2D.intersect_polygons(shape, keep)
	var span := maxf(1.0, cut_y - at.position.y)
	for points in parts:
		if points.size() < 3: continue
		var colours := PackedColorArray()
		colours.resize(points.size())
		for index in points.size():
			colours[index] = from.lerp(to, clampf((points[index].y - at.position.y) / span, 0.0, 1.0))
		RenderingServer.canvas_item_add_polygon(canvas, points, colours)


## The outline of a rounded box as points, clockwise from its top-left corner.
static func _round_rect(at: Rect2, corner: float) -> PackedVector2Array:
	corner = clampf(corner, 0.0, minf(at.size.x, at.size.y) * 0.5)
	var points := PackedVector2Array()
	if corner < 0.5:
		points.append_array([at.position, Vector2(at.end.x, at.position.y), at.end, Vector2(at.position.x, at.end.y)])
		return points
	var steps := clampi(int(corner * 0.5), 3, 12)
	var centres := [at.position + Vector2(corner, corner), Vector2(at.end.x - corner, at.position.y + corner),
		at.end - Vector2(corner, corner), Vector2(at.position.x + corner, at.end.y - corner)]
	for quarter in 4:
		var start := PI + float(quarter) * PI * 0.5
		for step in steps + 1:
			var angle := start + PI * 0.5 * float(step) / float(steps)
			var point: Vector2 = centres[quarter] + Vector2(cos(angle), sin(angle)) * corner
			# 🛑 On a pill two corners meet in one point — a repeated point fails the triangulation and draws nothing.
			if points.is_empty() or points[points.size() - 1].distance_squared_to(point) > 0.01: points.append(point)
	if points.size() > 1 and points[0].distance_squared_to(points[points.size() - 1]) <= 0.01: points.remove_at(points.size() - 1)
	return points


## A board's gloss: a thin stroke along the middle of its frame round the top-left corner, and a short glint round the
## top-right one — the light falls on both shoulders of a glossy window.
func _gloss_frame(canvas: RID, body: Rect2, corner: float, alpha: float) -> void:
	var rim := frame_drawn()
	var bend := maxf(corner - rim * 0.5, rim)
	var white := Color(1, 1, 1, clampf(shine, 0.0, 1.0) * 0.85 * alpha)
	var width := maxf(1.2, rim * 0.4)
	for right: bool in [false, true]:
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		var run := minf(body.size.x * (0.1 if right else 0.25), 40.0 if right else 96.0)
		var drop := minf(body.size.y * (0.12 if right else 0.25), bend)
		var centre := body.position + Vector2(rim * 0.5 + bend, rim * 0.5 + bend)
		points.append(centre + Vector2(-bend, drop))
		colours.append(Color(white, 0.0))
		for step in 7:
			var angle := PI + PI * 0.5 * float(step) / 6.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * bend)
			colours.append(white if not right else Color(white, white.a * 0.8))
		points.append(Vector2(centre.x + run, centre.y - bend))
		colours.append(Color(white, 0.0))
		if right: points = _mirrored(points, body)
		RenderingServer.canvas_item_add_polyline(canvas, points, colours, width, true)


## [param points] reflected across the vertical middle of [param body].
static func _mirrored(points: PackedVector2Array, body: Rect2) -> PackedVector2Array:
	var axis := body.position.x * 2.0 + body.size.x
	var out := PackedVector2Array()
	for point: Vector2 in points: out.append(Vector2(axis - point.x, point.y))
	return out


## The candy gloss: a sheen over the upper half of the body (white, fading out towards the middle), a glint round each
## top corner and a short dash between them — a pill of an arcade menu. Kept off a key too small to carry it.
func _candy(canvas: RID, body: Rect2, corner: float, alpha: float) -> void:
	if body.size.y < 10.0 or body.size.x < 16.0: return
	var strength := clampf(shine, 0.0, 1.0) * alpha
	# The sheen: inside the body, as round as it, over its upper part; it melts away before the label's middle.
	var inset := clampf(body.size.y * 0.07, 1.5, 4.0)
	var sheen := Rect2(body.position + Vector2(inset, inset), Vector2(body.size.x - inset * 2.0, body.size.y * 0.52 - inset))
	if sheen.size.x > 4.0 and sheen.size.y > 3.0:
		_gradient(canvas, sheen, maxf(0.0, corner - inset), sheen.end.y, Color(1, 1, 1, 0.34 * strength),
			Color(1, 1, 1, 0.04 * strength))
	# The glints: a stroke up each side, round each top corner and a little way along the top.
	var width := clampf(body.size.y * 0.085, 1.6, 4.0)
	var edge := clampf(body.size.y * 0.17, 3.0, 9.0)
	var bend := clampf(corner - edge, width, body.size.y * 0.5)
	var white := Color(1, 1, 1, 0.92 * strength)
	var rise := minf(body.size.y * 0.1, bend * 0.5)
	var run := minf(body.size.x * 0.1, 28.0)
	var centre := body.position + Vector2(edge + bend, edge + bend)
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	points.append(centre + Vector2(-bend, rise))
	colours.append(Color(white, 0.0))
	for step in 7:
		var angle := PI * 1.02 + PI * 0.48 * float(step) / 6.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * bend)
		colours.append(white)
	points.append(Vector2(centre.x + run, centre.y - bend))
	colours.append(Color(white, 0.0))
	RenderingServer.canvas_item_add_polyline(canvas, points, colours, width, true)
	RenderingServer.canvas_item_add_polyline(canvas, _mirrored(points, body), colours, width, true)
	# The dash: a short capsule in the middle of the top, on the glints' line — only where the glints leave it room.
	var room := body.size.x - (edge + bend + run) * 2.0
	var dash := minf(clampf(body.size.x * 0.11, 8.0, 34.0), room - width * 4.0)
	if dash >= width * 2.5:
		var y := centre.y - bend
		var pill := Rect2(Vector2(body.position.x + (body.size.x - dash) * 0.5, y), Vector2(dash, width))
		RenderingServer.canvas_item_add_polygon(canvas, _round_rect(pill, width * 0.5),
			PackedColorArray([Color(white, white.a * 0.95)]))


## How wide each end of a ribbon is drawn in [param rect] (dp) — `tails`, cut back so the body keeps at least half
## the face, and 0 on a face too small to fold.
func ribbon_tails(rect: Rect2) -> float:
	if tails <= 0.0 or sunken or rect.size.y < 12.0: return 0.0
	return minf(tails, rect.size.x * 0.25)


## A ribbon's two folded tails behind its [param body]: each a band that hangs a little lower than the body, cut into a
## swallow's notch at its outer end, and a darker fold where it tucks under the body. Ink-outlined like the body.
func _tails(canvas: RID, rect: Rect2, body: Rect2) -> void:
	var tail := body.position.x - rect.position.x
	var outline := maxf(0.0, border_width)
	var alpha := bg_color.a
	var ink := edge()
	var top_y := rect.position.y + rect.size.y * 0.3
	var notch := tail * 0.5
	var face_top := Color(top().lerp(bottom(), 0.6), alpha)
	var face_bottom := Color(bottom().lerp(shade(), 0.55), alpha)
	var fold := Color(shade().lerp(ink, 0.2), alpha)
	var tuck := minf(radius, body.size.y * 0.5) + outline
	for right: bool in [false, true]:
		# The band, from the outer notch to under the body.
		var band := PackedVector2Array([
			Vector2(rect.position.x, top_y),
			Vector2(body.position.x + tuck, top_y),
			Vector2(body.position.x + tuck, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x + notch, (top_y + rect.end.y) * 0.5),
		])
		# The fold: where the band turns under the body's lower corner.
		var crease := PackedVector2Array([
			Vector2(body.position.x, body.end.y - outline),
			Vector2(body.position.x + tuck, rect.end.y),
			Vector2(body.position.x, rect.end.y),
		])
		if right:
			band = _mirrored(band, rect)
			crease = _mirrored(crease, rect)
		var shades := PackedColorArray()
		var span := maxf(1.0, rect.end.y - top_y)
		for point: Vector2 in band: shades.append(face_top.lerp(face_bottom, clampf((point.y - top_y) / span, 0.0, 1.0)))
		RenderingServer.canvas_item_add_polygon(canvas, band, shades)
		RenderingServer.canvas_item_add_polygon(canvas, crease, PackedColorArray([fold]))
		if outline > 0.0:
			for shape: PackedVector2Array in [band, crease]:
				var loop := shape.duplicate()
				loop.append(shape[0])
				RenderingServer.canvas_item_add_polyline(canvas, loop, PackedColorArray([Color(ink, ink.a * maxf(alpha, 0.0))]),
					outline, true)


## The white gloss: a stroke that comes up the left side, round the top-left corner and fades along the top.
func _gloss(canvas: RID, body: Rect2, corner: float, alpha: float) -> void:
	if body.size.y < 10.0 or body.size.x < 16.0: return
	var width := clampf(body.size.y * 0.09, 1.6, 4.5)
	var inset := clampf(body.size.y * 0.14, 3.0, 9.0)
	var bend := clampf(corner - inset, width, body.size.y * 0.5)
	var centre := body.position + Vector2(inset + bend, inset + bend)
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var white := Color(1, 1, 1, clampf(shine, 0.0, 1.0) * 0.9 * alpha)
	var rise := minf(body.size.y * 0.12, bend * 0.5)
	points.append(centre + Vector2(-bend, rise))
	colours.append(Color(white, 0.0))
	for step in 7:
		var angle := PI * 1.02 + PI * 0.48 * float(step) / 6.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * bend)
		colours.append(white)
	var run := minf(body.size.x * 0.24, 72.0)
	if centre.x + run < body.end.x - inset - bend:
		points.append(Vector2(centre.x + run, centre.y - bend))
		colours.append(Color(white, 0.0))
	RenderingServer.canvas_item_add_polyline(canvas, points, colours, width, true)
