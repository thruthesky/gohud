## ☑️ **A column of choices you tap once** — a short list that scrolls up and down a few rows at a time, where a tap
## acts on that row at once and any number of rows can stand out as chosen: the friends a player has called, the
## filters that are on, the tracks in a queue (Flutter's `FilterChip`s in a scrolling column).
##
## ```gdscript
## var friends := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 4, func(index: int) -> void: call_friend(index))
## friends.set_selected(2, true)          # the dog is out — its row stands out
## hud.add_child(friends)
## # Later, when the dog goes home:
## friends.set_selected(2, false)
## ```
##
## ## 🔑 One tap acts
## A press that lets go on the same row without moving fires `item_pressed(index)` — there is no "bring it to the
## middle, then tap again" as on a wheel (`GoWheelPicker`, which is for settling on one value). A press that moves a
## few dp scrolls instead; a flick keeps it going for a moment, and it comes to rest on a whole row. The mouse wheel
## scrolls one row. Fade bands with a small arrow at the top and the bottom say there is more that way.
##
## ## 🔑 Chosen rows are the app's to say
## The column never chooses on its own. `set_selected(index, true)` marks a row with a plate and a ring in
## `selection_color` (the accent by default), `set_selected(index, false)` clears it — what a tap means (call, toggle,
## open) stays in the game, and so does when a mark ends. `set_dimmed(index, true)` greys a row that cannot act now.
##
## ## 🔑 Rows that draw themselves
## A row is an icon, a short text, or both (`set_items([{"icon": GoIconSet.STAR, "text": "Star"}, "Plain"])`). For a
## picture no icon set holds — a face, a swatch — set `item_drawer`, called for every row in view:
## `func(canvas: CanvasItem, index: int, rect: Rect2, chosen: bool, dimmed: bool) -> void`; draw inside `rect`.
## Give such rows a `"text"` anyway: it is the tooltip and what a screen reader says.
##
## ## 🛑 Over gameplay
## Keyboard focus is off by default here (`focus_mode = FOCUS_NONE`): over a game the arrow keys keep walking the
## player. A menu that lists choices turns it on — Up and Down move a ring from row to row, Enter or Space presses it.
## 🛑 Every row is a touch target: `item_height` never goes under the `touch` token (48dp).
@tool
class_name GoChoiceColumn
extends Control

## A row was tapped (or pressed with Enter while focused).
signal item_pressed(index: int)

## A press that moves this far (dp) scrolls instead of tapping.
const DRAG_SLOP := 6.0

## The height of one row (dp) — never under the `touch` token.
@export var item_height := 48.0:
	set(value):
		item_height = value
		_relayout()
## How many rows show at once; the column is that tall.
@export var visible_items := 4:
	set(value):
		visible_items = maxi(value, 1)
		_relayout()
## Gap between rows (dp).
@export var item_gap := 4.0:
	set(value):
		item_gap = maxf(value, 0.0)
		_relayout()
## Room between the plate's edge and the rows (dp).
@export var padding := 4.0:
	set(value):
		padding = maxf(value, 0.0)
		_relayout()
## Draw a floating HUD plate behind the rows (off: the rows sit on whatever is behind).
@export var panel := true:
	set(value):
		panel = value
		queue_redraw()
## The colour of a chosen row's plate and ring. Transparent → the `accent` token.
@export var selection_color := Color.TRANSPARENT:
	set(value):
		selection_color = value
		queue_redraw()
## Treat the row texts as translation keys.
@export var translate := false:
	set(value):
		translate = value
		_relayout()

## Draws a row's content instead of its icon and text — see "Rows that draw themselves" above.
var item_drawer := Callable():
	set(value):
		item_drawer = value
		queue_redraw()

var _items: Array[Dictionary] = []
var _chosen := {}
var _dimmed := {}
## How far the rows have scrolled (dp, 0 = the first row at the top).
var _offset := 0.0
var _pressed_at := Vector2.INF
var _press_row := -1
var _dragging := false
## The press caught the rows while they were still moving — it stops them and presses nothing.
var _caught := false
var _velocity := 0.0
var _last_move := 0
var _focus_row := 0
var _tween: Tween
var _action := Callable()


func _init() -> void:
	name = "ChoiceColumn"
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# 🔑 Scrolling the rows is this control's own drag — a page around it does not take it.
	set_meta(GoScroll.OWNS_GESTURE, true)


func _ready() -> void:
	theme = GoUi.theme()
	_name_it()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A column of [param choices] (texts, or `{"icon", "text", "tooltip"}` dictionaries) showing [param rows] at a time.
## [param action] is called with the index of each tapped row.
static func make(choices: Array, rows := 4, action := Callable()) -> GoChoiceColumn:
	var node := GoChoiceColumn.new()
	node.visible_items = rows
	node._action = action
	node.set_items(choices)
	return node


## Replaces the rows. Marks on rows past the new end go; the rest stay, and the column keeps its place when it can.
func set_items(choices: Array) -> void:
	_items.clear()
	for choice: Variant in choices:
		if choice is Dictionary:
			_items.append((choice as Dictionary).duplicate())
		else:
			_items.append({"text": str(choice)})
	for index: int in _chosen.keys():
		if index >= _items.size(): _chosen.erase(index)
	for index: int in _dimmed.keys():
		if index >= _items.size(): _dimmed.erase(index)
	_focus_row = clampi(_focus_row, 0, maxi(0, _items.size() - 1))
	_relayout()


## The number of rows.
func item_count() -> int:
	return _items.size()


## Marks row [param index] as chosen (or clears it). Fires nothing — the app decides what is chosen.
func set_selected(index: int, chosen := true) -> void:
	if index < 0 or index >= _items.size() or _chosen.has(index) == chosen: return
	if chosen: _chosen[index] = true
	else: _chosen.erase(index)
	_name_it()
	queue_redraw()


func is_selected(index: int) -> bool:
	return _chosen.has(index)


## The chosen rows, top to bottom.
func selected_indices() -> PackedInt32Array:
	var found := PackedInt32Array()
	for index in _items.size():
		if _chosen.has(index): found.append(index)
	return found


## Clears every mark.
func clear_selected() -> void:
	if _chosen.is_empty(): return
	_chosen.clear()
	_name_it()
	queue_redraw()


## Greys row [param index] (it still fires when tapped — the app says why it cannot act).
func set_dimmed(index: int, dimmed := true) -> void:
	if index < 0 or index >= _items.size() or _dimmed.has(index) == dimmed: return
	if dimmed: _dimmed[index] = true
	else: _dimmed.erase(index)
	queue_redraw()


func is_dimmed(index: int) -> bool:
	return _dimmed.has(index)


## Scrolls the least it takes to show row [param index] whole (gliding when [param animate]).
func scroll_to(index: int, animate := true) -> void:
	if _items.is_empty(): return
	index = clampi(index, 0, _items.size() - 1)
	var top := index * _step()
	var view := _view_height()
	var target := _offset
	if top < _offset: target = top
	elif top + _row_height() > _offset + view: target = top + _row_height() - view
	_glide(target, animate)


## Where row [param index] is drawn now (local rect, scroll included — it may be partly or wholly out of view).
func row_rect(index: int) -> Rect2:
	return Rect2(padding, padding + index * _step() - _offset, maxf(0.0, size.x - padding * 2.0), _row_height())


## The row under [param at] (local position), or -1 — the gaps and the padding belong to no row.
func row_at(at: Vector2) -> int:
	if at.y < padding or at.y > size.y - padding or at.x < 0.0 or at.x > size.x: return -1
	var along := at.y - padding + _offset
	var index := int(floor(along / _step()))
	if index < 0 or index >= _items.size(): return -1
	if along - index * _step() > _row_height(): return -1
	return index


## How far the rows have scrolled (dp) — 0 at the top, `max_scroll()` at the bottom.
func get_scroll() -> float:
	return _offset


func max_scroll() -> float:
	var rows := _items.size()
	if rows == 0: return 0.0
	return maxf(0.0, rows * _row_height() + (rows - 1) * item_gap - _view_height())


func _row_height() -> float:
	return maxf(item_height, float(GoUi.metric(GoTheme.TOUCH)))


func _step() -> float:
	return _row_height() + item_gap


func _view_height() -> float:
	return maxf(0.0, size.y - padding * 2.0)


func _text_of(index: int) -> String:
	var words := str(_items[index].get("text", ""))
	return tr(words) if translate else words


func _get_minimum_size() -> Vector2:
	var touch := float(GoUi.metric(GoTheme.TOUCH))
	var widest := 0.0
	var font := get_theme_font(&"font", &"Label")
	var font_size := GoUi.font_size(GoTheme.ROLE_BODY)
	for index in _items.size():
		var row := _items[index]
		var wide := 0.0
		if not str(row.get("icon", "")).is_empty(): wide += _icon_size()
		var words := _text_of(index)
		if not words.is_empty() and font != null and not item_drawer.is_valid():
			wide += font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if wide > 0.0 and row.has("icon"): wide += float(GoUi.metric(GoTheme.GAP_SMALL))
			wide += float(GoUi.metric(GoTheme.GAP)) * 2.0
		widest = maxf(widest, wide)
	var rows := visible_items
	var tall := padding * 2.0 + rows * _row_height() + (rows - 1) * item_gap
	return Vector2(maxf(touch, widest) + padding * 2.0, tall)


func _icon_size() -> float:
	return roundf(_row_height() * 0.5)


func _draw() -> void:
	var skin := GoUi.skin()
	var plate: StyleBox = _plate(skin) if panel else null
	if plate != null: draw_style_box(plate, Rect2(Vector2.ZERO, size))
	var accent := selection_color if selection_color.a > 0.0 else GoUi.color(GoTheme.ACCENT)
	var radius := GoUi.metric(GoTheme.RADIUS_SMALL)
	var first := maxi(0, int(floor(_offset / _step())))
	var last := mini(_items.size() - 1, int(ceil((_offset + _view_height()) / _step())))
	for index in range(first, last + 1):
		var rect := row_rect(index)
		var chosen := _chosen.has(index)
		var dimmed := _dimmed.has(index)
		if chosen:
			var mark := StyleBoxFlat.new()
			mark.bg_color = Color(accent, 0.22)
			mark.border_color = accent
			mark.set_border_width_all(2)
			mark.set_corner_radius_all(radius)
			mark.corner_detail = 8
			mark.anti_aliasing = true
			draw_style_box(mark, rect)
		elif index == _press_row and not _dragging:
			# The row under the finger answers before it lets go.
			var wash := StyleBoxFlat.new()
			wash.bg_color = Color(GoUi.color(GoTheme.TEXT), 0.08)
			wash.set_corner_radius_all(radius)
			draw_style_box(wash, rect)
		if item_drawer.is_valid():
			item_drawer.call(self, index, rect, chosen, dimmed)
		else:
			_draw_row(index, rect, chosen, dimmed)
		# Only keyboard and gamepad focus shows the ring — the focus a tap hands out is hidden.
		if has_focus(true) and index == _focus_row:
			var ring := get_theme_stylebox(&"focus", &"Button")
			if ring != null: draw_style_box(ring, _inside(ring, rect))
	_draw_edges(plate)


## The HUD plate with no shadow or glow. 🛑 The column clips (rows scroll under its edges), and a shadow or glow drawn
## past the plate was cut to the corners left outside its rounded or chamfered outline — dark or grey squares at the
## four corners on the dark, Material and sci-fi presets (2026-10-03 review).
func _plate(skin: GoSkin) -> StyleBox:
	var face := skin.surface_box(GoTheme.BOX_HUD)
	if face == null: return null
	if &"shadow_size" in face: face.set(&"shadow_size", 0)
	if &"glow_size" in face: face.set(&"glow_size", 0.0)
	return face


## [param rect] pulled in so [param ring] — which may reach past the rect it is drawn for — stays inside the column,
## which clips: a ring wider than the padding lost its sides.
func _inside(ring: StyleBox, rect: Rect2) -> Rect2:
	var flat := ring as StyleBoxFlat
	if flat == null: return rect
	return rect.grow_individual(-maxf(0.0, flat.expand_margin_left - rect.position.x),
		-maxf(0.0, flat.expand_margin_top - maxf(0.0, rect.position.y)),
		-maxf(0.0, flat.expand_margin_right - (size.x - rect.end.x)),
		-maxf(0.0, flat.expand_margin_bottom - maxf(0.0, size.y - rect.end.y)))


## The default row: the icon, then the text (the text first in a right-to-left layout), centred together.
func _draw_row(index: int, rect: Rect2, chosen: bool, dimmed: bool) -> void:
	var row := _items[index]
	var ink := GoUi.color(GoTheme.TEXT)
	if dimmed: ink = Color(GoUi.color(GoTheme.MUTED), 0.6)
	elif chosen: ink = GoUi.color(GoTheme.TEXT)
	var icon := StringName(str(row.get("icon", "")))
	var words := _text_of(index)
	var font := get_theme_font(&"font", &"Label")
	var font_size := GoUi.font_size(GoTheme.ROLE_BODY)
	var icon_size := _icon_size() if not icon.is_empty() else 0.0
	var gap := float(GoUi.metric(GoTheme.GAP_SMALL)) if icon_size > 0.0 and not words.is_empty() else 0.0
	var text_width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
		if font != null and not words.is_empty() else 0.0
	var start := rect.position.x + maxf(0.0, (rect.size.x - icon_size - gap - text_width) * 0.5)
	var icon_x := start
	var text_x := start + icon_size + gap
	if is_layout_rtl():
		text_x = start
		icon_x = start + text_width + gap
	if icon_size > 0.0:
		var box := Rect2(icon_x, rect.get_center().y - icon_size * 0.5, icon_size, icon_size)
		var icons := GoUi.icons()
		var texture := icons.texture(icon)
		if texture != null:
			draw_texture_rect(texture, box, false, ink)
		else:
			var glyph := icons.glyph(icon)
			var glyph_font := icons.glyph_font(icon)
			if not glyph.is_empty() and glyph_font != null:
				var glyph_size := int(icon_size)
				var glyph_box := glyph_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size)
				draw_string(glyph_font, Vector2(box.get_center().x - glyph_box.x * 0.5,
					box.get_center().y + glyph_font.get_ascent(glyph_size) - glyph_box.y * 0.5), glyph,
					HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, ink)
	if text_width > 0.0:
		draw_string(font, Vector2(text_x, rect.get_center().y + font.get_ascent(font_size) - font.get_height(font_size) * 0.5),
			words, HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - text_x, font_size, ink)


## Fade bands at an edge with more rows past it, and a small arrow that says so. The band fades into the plate's own
## colour — an opaque surface band on a see-through HUD plate read as a stripe; with no plate only the arrow shows.
func _draw_edges(plate: StyleBox) -> void:
	var band := minf(14.0, size.y * 0.25)
	var under := GoSkin.box_background(plate) if plate != null else Color.TRANSPARENT
	# A frame that paints no face has nothing for the rows to fade into — the arrow alone says there is more.
	if plate != null and &"draw_center" in plate and not plate.get(&"draw_center"): under = Color.TRANSPARENT
	var arrow := Color(GoUi.color(GoTheme.MUTED), 0.9)
	var middle := size.x * 0.5
	if _offset > 0.5:
		if under.a > 0.0: _band(plate, true, band, under)
		draw_colored_polygon(PackedVector2Array([Vector2(middle - 5, 8), Vector2(middle + 5, 8), Vector2(middle, 3)]), arrow)
	if _offset < max_scroll() - 0.5:
		var bottom := size.y
		if under.a > 0.0: _band(plate, false, band, under)
		draw_colored_polygon(PackedVector2Array([Vector2(middle - 5, bottom - 8), Vector2(middle + 5, bottom - 8),
			Vector2(middle, bottom - 3)]), arrow)


## One fade band [param band] tall, inside the plate's border and cut at its corners. 🛑 A band the full width of
## the column poked out of the rounded or chamfered corners as squares and covered the border line (2026-10-03).
func _band(plate: StyleBox, top: bool, band: float, under: Color) -> void:
	var inner := Rect2(Vector2.ZERO, size)
	var left := 0.0
	var right := 0.0
	var flat := plate as StyleBoxFlat
	var cut := plate as GoStyleBoxCut
	var forged := plate as GoStyleBoxMedieval
	var inked := plate as GoStyleBoxComic
	if flat != null:
		inner = inner.grow_individual(-flat.border_width_left, -flat.border_width_top, -flat.border_width_right,
			-flat.border_width_bottom)
		left = (flat.corner_radius_top_left if top else flat.corner_radius_bottom_left) - flat.border_width_left
		right = (flat.corner_radius_top_right if top else flat.corner_radius_bottom_right) - flat.border_width_right
	elif cut != null:
		# The accent line on one side is thicker than the border — the band keeps clear of it on any side.
		var line := cut.edge_width if cut.edge_color.a > 0.0 else 0.0
		inner = inner.grow(-cut.border_width)
		inner = inner.grow_side(cut.edge_side, -maxf(0.0, line - cut.border_width))
		var chamfer := minf(cut.cut, minf(size.x, size.y) * 0.5)
		left = chamfer if cut.cut_corners & (GoStyleBoxCut.TOP_LEFT if top else GoStyleBoxCut.BOTTOM_LEFT) else 0.0
		right = chamfer if cut.cut_corners & (GoStyleBoxCut.TOP_RIGHT if top else GoStyleBoxCut.BOTTOM_RIGHT) else 0.0
	elif inked != null:
		# The comic panel: a rounded face whose ink width is read from the setting as it is drawn.
		var ink := inked.outline_width()
		inner = inner.grow(-ink)
		var corner := minf(inked.radius, minf(size.x, size.y) * 0.5) - ink
		var top_bit := GoStyleBoxComic.TOP_LEFT if top else GoStyleBoxComic.BOTTOM_LEFT
		var right_bit := GoStyleBoxComic.TOP_RIGHT if top else GoStyleBoxComic.BOTTOM_RIGHT
		left = corner if inked.corners & top_bit else 0.0
		right = corner if inked.corners & right_bit else 0.0
	elif forged != null:
		# The forged frame: a rounded face with a border, and rivets set in from each corner — the cut leaves them
		# uncovered (`GoStyleBoxMedieval._draw`: inset 6 × ornament_scale).
		inner = inner.grow(-forged.border_width)
		var round_corner := minf(forged.radius, minf(size.x, size.y) * 0.5) - forged.border_width
		var rivets := 0.0
		if forged.ornament > 0 and forged.draw_center:
			rivets = 2.0 * minf(6.0 * forged.ornament_scale, minf(size.x, size.y) * 0.2) + 3.0
		left = maxf(round_corner, rivets)
		right = left
	left = clampf(left, 0.0, inner.size.x * 0.5 - 1.0)
	right = clampf(right, 0.0, inner.size.x * 0.5 - 1.0)
	var edge := inner.position.y if top else inner.end.y
	var away := 1.0 if top else -1.0
	var clear := Color(under, 0.0)
	# A chord across each corner stays inside the arc, and inside a chamfer it is the chamfer itself.
	var points := PackedVector2Array([Vector2(inner.position.x + left, edge), Vector2(inner.end.x - right, edge)])
	var colors := PackedColorArray([under, under])
	if right >= band:
		points.append(Vector2(inner.end.x - right + band, edge + away * band))
		colors.append(clear)
	else:
		if right > 0.0:
			points.append(Vector2(inner.end.x, edge + away * right))
			colors.append(Color(under, under.a * (1.0 - right / band)))
		points.append(Vector2(inner.end.x, edge + away * band))
		colors.append(clear)
	if left >= band:
		points.append(Vector2(inner.position.x + left - band, edge + away * band))
		colors.append(clear)
	else:
		points.append(Vector2(inner.position.x, edge + away * band))
		colors.append(clear)
		if left > 0.0:
			points.append(Vector2(inner.position.x, edge + away * left))
			colors.append(Color(under, under.a * (1.0 - left / band)))
	draw_polygon(points, colors)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null:
		if click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var rows := 1.0 if click.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
			_glide(_snapped(_offset + rows * _step()), true)
			accept_event()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				if focus_mode != Control.FOCUS_NONE: grab_focus(true)
				# 🛑 A finger that lands on moving rows means "stop", not "this one" — pressing the row it happened to
				#    land on summoned what nobody chose and left the rows resting between two (review, 2026-10-03).
				_caught = _tween != null and _tween.is_running()
				if _tween != null: _tween.kill()
				_pressed_at = click.position
				_dragging = false
				_velocity = 0.0
				_last_move = Time.get_ticks_msec()
				_press_row = -1 if _caught else row_at(click.position)
				queue_redraw()
			elif _pressed_at != Vector2.INF:
				var row := _press_row
				_pressed_at = Vector2.INF
				_press_row = -1
				if _dragging:
					_fling()
				elif not _caught and row >= 0 and row == row_at(click.position):
					_focus_row = row
					_press(row)
				else:
					# A tap that caught the rows mid-glide lands them on a whole row.
					_glide(_snapped(_offset), true)
				_caught = false
				queue_redraw()
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed_at != Vector2.INF and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _dragging and absf(motion.position.y - _pressed_at.y) < DRAG_SLOP: return
		if not _dragging:
			_dragging = true
			_press_row = -1
		var now := Time.get_ticks_msec()
		var moved := -motion.relative.y
		var seconds := maxf(0.001, (now - _last_move) / 1000.0)
		_velocity = lerpf(_velocity, moved / seconds, 0.6)
		_last_move = now
		_set_offset(_offset + moved)
		accept_event()
		return
	if not has_focus() or _items.is_empty(): return
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"ui_down", true):
		_focus_row = clampi(_focus_row + (1 if event.is_action_pressed(&"ui_down", true) else -1), 0, _items.size() - 1)
		scroll_to(_focus_row)
		_name_it()
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		_press(_focus_row)
		accept_event()


func _press(row: int) -> void:
	item_pressed.emit(row)
	if _action.is_valid(): _action.call(row)


## Let go while moving: keeps going a little, then rests on a whole row.
func _fling() -> void:
	# A finger that stopped before letting go does not throw the rows.
	if Time.get_ticks_msec() - _last_move > 80: _velocity = 0.0
	_glide(_snapped(_offset + _velocity * 0.25), true)


## The scroll that puts a whole row at the top (or the very end).
func _snapped(at: float) -> float:
	return clampf(roundf(at / _step()) * _step(), 0.0, max_scroll())


func _glide(target: float, animate: bool) -> void:
	target = clampf(target, 0.0, max_scroll())
	if _tween != null: _tween.kill()
	if not animate or not is_inside_tree() or GoUi.config.reduce_motion:
		_set_offset(target)
		return
	var travel := absf(target - _offset) / maxf(1.0, _step())
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, target, clampf(0.12 + travel * 0.05, 0.12, 0.4)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_offset(value: float) -> void:
	var next := clampf(value, 0.0, max_scroll())
	if is_equal_approx(next, _offset): return
	_offset = next
	queue_redraw()


func _relayout() -> void:
	update_minimum_size()
	_offset = clampf(_offset, 0.0, max_scroll())
	_name_it()
	queue_redraw()


## Shows the hovered row's tooltip (or its text), then the column's own.
func _get_tooltip(at_position: Vector2) -> String:
	var row := row_at(at_position)
	if row >= 0:
		var tip := str(_items[row].get("tooltip", ""))
		if not tip.is_empty(): return tr(tip) if translate else tip
		var words := _text_of(row)
		if not words.is_empty(): return words
	return tooltip_text


## ♿ Says the focused row, and whether it is chosen.
func _name_it() -> void:
	if _items.is_empty():
		accessibility_name = ""
		return
	var row := clampi(_focus_row, 0, _items.size() - 1)
	accessibility_name = _text_of(row) + (" ✓" if _chosen.has(row) else "")


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_offset = clampf(_offset, 0.0, max_scroll())
		queue_redraw()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and translate:
		_relayout()


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_relayout()
