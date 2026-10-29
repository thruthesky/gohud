## 🏆 **A winners' podium** — the top three of a leaderboard on three blocks: gold in the middle and tallest, silver on
## the left, bronze on the right, a laurel medal with the place's number over each block, and a name plate on each
## block with the player's name over the value (a clear time, a win count). Behind the gold block: a soft sunburst and
## scattered confetti.
##
## ```gdscript
## var podium := GoPodium.new()
## podium.set_places([
## 	{name = "MagnetQueen", value = "00:31.20"},   # 1st
## 	{name = "Bolt", value = "00:33.90"},          # 2nd
## 	{name = "CrateCrusher", value = "00:36.60"},  # 3rd
## ])
## podium.show_decor = false                      # no sunburst, no confetti
## ```
##
## The art is the skin's (`GoUi.skin().widget_art(...)`): `podium_gold` / `podium_silver` / `podium_bronze` (a block
## with its empty name plate), `laurel_gold` / `laurel_silver` / `laurel_bronze` (the medal, its number painted in),
## `sunburst` and `confetti` — arcade_light ships them in `assets/arcade_light/leaderboard/`. A look without them draws
## plain token-coloured blocks and discs instead.
## 🛑 Display only — the caller (the server's answer) decides who stands where. A place with no entry is not shown:
##    never pad a short board with made-up winners.
## 🔑 The podium keeps its proportions: it draws its design canvas (`DESIGN_SIZE`) as large as fits its rect, centred
##    and standing on its bottom edge, and the text grows and shrinks with it. Texts shrink to fit their plate
##    (`GoStyle.fit_font_size`, down to `GoConfig.fit_min_scale`), then a name too long still ends in an ellipsis.
@tool
class_name GoPodium
extends Control

## The labels' looks: the name (medium weight) and the value (heavy) on a plate. Their `font_size` is the size at
## [member minimum_scale]; the podium scales it with itself.
const VAR_NAME := &"GoPodiumName"
const VAR_VALUE := &"GoPodiumValue"
## The design canvas every rect below is measured in (the reference layout's pixels).
const DESIGN_SIZE := Vector2(1035.0, 256.0)
## Per place (0 = 1st, 1 = 2nd, 2 = 3rd): the block, then its laurel medal, in design units.
const BLOCKS: Array[Rect2] = [Rect2(313, 106, 418, 150), Rect2(3, 142, 334, 114), Rect2(710, 142, 321, 114)]
const LAURELS: Array[Rect2] = [Rect2(423, 0, 202, 168), Rect2(93, 32, 174, 132), Rect2(778, 43, 164, 123)]
## The name plate inside each block, as shares of the block (x, y, width, height).
const PLATES: Array[Rect2] = [Rect2(0.128, 0.360, 0.743, 0.497), Rect2(0.127, 0.368, 0.746, 0.482),
		Rect2(0.109, 0.325, 0.780, 0.509)]
## The sunburst behind the gold block and the confetti over the whole podium, in design units.
const SUNBURST := Rect2(262, -40, 520, 208)
const CONFETTI := Rect2(-40, 0, 1115, 218)
## The art names per place.
const BLOCK_ART: Array[StringName] = [&"podium_gold", &"podium_silver", &"podium_bronze"]
const LAUREL_ART: Array[StringName] = [&"laurel_gold", &"laurel_silver", &"laurel_bronze"]
## The first place's text is this much larger than the others'.
const GOLD_TEXT := 1.12
## The share of the plate's height the name takes (the value takes the rest).
const NAME_SHARE := 0.44
## The room kept clear at each side of a plate's text (a share of the plate's width).
const PLATE_PAD := 0.05

## The sunburst and the confetti behind the podium.
@export var show_decor := true:
	set(value):
		if show_decor == value: return
		show_decor = value
		queue_redraw()

## The podium's smallest drawing, as a share of [constant DESIGN_SIZE] — its minimum size. The theme's font sizes
## are the sizes at this scale.
@export_range(0.2, 2.0, 0.01) var minimum_scale := 0.75:
	set(value):
		minimum_scale = clampf(value, 0.2, 2.0)
		update_minimum_size()
		_layout()

var _places: Array = []
var _names: Array[Label] = []
var _values: Array[Label] = []
var _laying := false


func _init() -> void:
	name = "Podium"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for place in 3:
		_names.append(_make_label("Name%d" % (place + 1), VAR_NAME))
		_values.append(_make_label("Value%d" % (place + 1), VAR_VALUE))
	resized.connect(_layout)
	_layout()


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _ready() -> void:
	theme = GoUi.theme()
	_layout()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_TRANSLATION_CHANGED: _layout()


func _get_minimum_size() -> Vector2:
	return (DESIGN_SIZE * minimum_scale).ceil()


## The top three in rank order (index 0 = 1st): up to three dictionaries `{name = "…", value = "…"}`. A missing or
## empty entry (`{}` or `null`) hides that place.
func set_places(places: Array) -> void:
	_places = []
	for place in 3:
		var entry: Variant = places[place] if place < places.size() else null
		_places.append(entry if entry is Dictionary and not (entry as Dictionary).is_empty() else null)
	_layout()


## Whether place [param index] (0 = 1st) stands on the podium.
func is_place_shown(index: int) -> bool:
	return index >= 0 and index < _places.size() and _places[index] != null


## The name label of place [param index] (0 = 1st).
func name_label(index: int) -> Label:
	return _names[index]


## The value label of place [param index] (0 = 1st).
func value_label(index: int) -> Label:
	return _values[index]


## How large the design canvas is drawn now (1.0: one design unit per dp).
func draw_scale() -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y) if size.x > 0.0 and size.y > 0.0 else minimum_scale


## A design-space [param rect] in the podium's own space: the canvas centred across and standing on the bottom edge.
func design_rect(rect: Rect2) -> Rect2:
	var k := draw_scale()
	var origin := Vector2((size.x - DESIGN_SIZE.x * k) * 0.5, size.y - DESIGN_SIZE.y * k)
	return Rect2(origin + rect.position * k, rect.size * k)


## Where place [param index]'s block art is drawn (its art kept to its own proportions, standing on the block's
## bottom edge), in the podium's space.
func block_rect(index: int) -> Rect2:
	return _fit(design_rect(BLOCKS[index]), _art(BLOCK_ART[index]), true)


## Where place [param index]'s name plate is, in the podium's space.
func plate_rect(index: int) -> Rect2:
	var block := block_rect(index)
	var share := PLATES[index]
	return Rect2(block.position + share.position * block.size, share.size * block.size)


func _make_label(node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.visible = false
	add_child(label)
	return label


static func _art(art_name: StringName) -> Texture2D:
	var skin := GoUi.skin()
	return skin.widget_art(art_name) if skin != null else null


## [param art] fitted inside [param room] at its own proportions: centred across, and standing on the bottom edge
## when [param stand] (else centred up and down). No art: the room itself.
static func _fit(room: Rect2, art: Texture2D, stand: bool) -> Rect2:
	if art == null or art.get_width() <= 0 or art.get_height() <= 0: return room
	var k := minf(room.size.x / art.get_width(), room.size.y / art.get_height())
	var drawn := Vector2(art.get_width(), art.get_height()) * k
	var y := room.end.y - drawn.y if stand else room.position.y + (room.size.y - drawn.y) * 0.5
	return Rect2(Vector2(room.position.x + (room.size.x - drawn.x) * 0.5, y), drawn)


func _layout() -> void:
	if _laying or _names.is_empty(): return
	_laying = true
	var grow := draw_scale() / maxf(minimum_scale, 0.01)
	for place in 3:
		var entry: Variant = _places[place] if place < _places.size() else null
		var shown := entry != null
		var name_node := _names[place]
		var value_node := _values[place]
		name_node.visible = shown
		value_node.visible = shown
		if not shown: continue
		var plate := plate_rect(place)
		var pad := plate.size.x * PLATE_PAD
		var room := maxf(1.0, plate.size.x - pad * 2.0)
		var name_tall := plate.size.y * NAME_SHARE
		name_node.text = str((entry as Dictionary).get("name", ""))
		value_node.text = str((entry as Dictionary).get("value", ""))
		name_node.position = Vector2(plate.position.x + pad, plate.position.y)
		name_node.size = Vector2(room, name_tall)
		value_node.position = Vector2(plate.position.x + pad, plate.position.y + name_tall)
		value_node.size = Vector2(room, plate.size.y - name_tall)
		var bigger := GOLD_TEXT if place == 0 else 1.0
		for label: Label in [name_node, value_node]:
			label.remove_theme_font_size_override(&"font_size")
			var base := maxi(6, roundi(label.get_theme_font_size(&"font_size") * grow * bigger))
			var font := label.get_theme_font(&"font")
			label.add_theme_font_size_override(&"font_size",
					GoStyle.fit_font_size(PackedStringArray([label.text]), base, room, font))
	_laying = false
	queue_redraw()


func _draw() -> void:
	if show_decor:
		var burst := _art(&"sunburst")
		if burst != null and is_place_shown(0): draw_texture_rect(burst, design_rect(SUNBURST), false)
		var confetti := _art(&"confetti")
		if confetti != null and _places.any(func(p: Variant) -> bool: return p != null):
			draw_texture_rect(confetti, design_rect(CONFETTI), false)
	# The side blocks first, so the taller gold block stands in front of their inner edges.
	for place: int in [1, 2, 0]:
		if not is_place_shown(place): continue
		var block := block_rect(place)
		var art := _art(BLOCK_ART[place])
		if art != null:
			draw_texture_rect(art, block, false)
		else:
			draw_rect(block, _plain_fill(place))
			draw_rect(plate_rect(place), GoUi.color(GoTheme.SURFACE))
	for place: int in [1, 2, 0]:
		if not is_place_shown(place): continue
		var laurel := _art(LAUREL_ART[place])
		var room := design_rect(LAURELS[place])
		if laurel != null:
			draw_texture_rect(laurel, _fit(room, laurel, true), false)
		else:
			var radius := minf(room.size.x, room.size.y) * 0.36
			var centre := room.get_center()
			draw_circle(centre, radius, _plain_fill(place))
			var font := get_theme_default_font()
			var digits := str(place + 1)
			var px := roundi(radius * 1.1)
			var wide := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
			draw_string(font, centre + Vector2(-wide.x * 0.5, font.get_ascent(px) * 0.5 - font.get_descent(px) * 0.5),
					digits, HORIZONTAL_ALIGNMENT_LEFT, -1, px, GoUi.color(GoTheme.TEXT))


## A look without the art: gold, a light grey and a warm fill from the look's tokens.
func _plain_fill(place: int) -> Color:
	match place:
		0: return GoUi.color(GoTheme.WARNING_FILL)
		1: return GoUi.color(GoTheme.SURFACE_HIGH)
		_: return GoUi.color(GoTheme.DANGER_FILL)
