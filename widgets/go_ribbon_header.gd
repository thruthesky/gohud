## 🎀 **A screen's title ribbon** — the look's title plate with a glyph and the title on it, hanging over the top edge
## of the card it heads, with the look's art in one corner. Magnet Mayhem's `RibbonHeader` (the PAUSED and SETTINGS
## banners): put it first in a card's column.
##
## ```gdscript
## var header := GoRibbonHeader.make("PAUSED", GoIconSet.PAUSE)
## column.add_child(header)                 # the first row of a PanelContainer card
## header.ribbon_variation = &"GoRibbonRed" # a red ribbon (the game-over card)
## ```
##
## The look decides its shape through the same `GoSkin` hooks a `GoSurface` title uses: the plate
## (`title_plate_box()`, or the theme variation `ribbon_variation`), its height and the title's size
## (`title_plate_height()`, `title_plate_font_size()`, shrinking to fit no lower than `fit_floor`), how far it hangs over
## the card (`title_plate_overhang()`: 17 above, 14 past each side in `arcade_light`) and the corner art
## (`window_corner()` `&"art"`, `window_corner_art()`, `window_corner_rect()`: the red magnet). A look with no plate
## and no overhang gets a plain title row inside the card.
##
## 🔑 It keeps in its column only the part of the ribbon inside the card (`title_plate_height() − overhang − the
##    card's top margin`); the rest draws upward over the card's edge, so nothing in the column moves.
## 🛑 The card is the nearest `PanelContainer` above it — its panel's top margin sets how far up the ribbon reaches.
class_name GoRibbonHeader
extends Control

## Between the glyph and the words (dp) — the game's ribbon row.
const GLYPH_GAP := 10

## The title. A translation's line break is dropped: the ribbon is one line.
@export var title := "":
	set(value):
		title = value.replace("\n", " ")
		if title_label != null: title_label.text = title
		_queue()
## The glyph left of the title — a texture, which wins over…
@export var glyph: Texture2D:
	set(value):
		glyph = value
		_queue()
## …an icon set name (`GoIconSet.PAUSE`). Neither: no glyph, the words alone centred.
@export var glyph_icon: StringName = &"":
	set(value):
		glyph_icon = value
		_queue()
## The theme variation the ribbon wears (`&"GoRibbonRed"`). Empty: the look's title plate (`GoSkin.title_plate_box()`).
@export var ribbon_variation: StringName = &"":
	set(value):
		ribbon_variation = value
		_queue()
## Whether the look's corner art shows.
@export var corner := true:
	set(value):
		corner = value
		_queue()
## Which top corner the art stands on (mirrored on the right).
@export var corner_on_left := true:
	set(value):
		corner_on_left = value
		_queue()
## The corner art. Null: the look's (`GoSkin.window_corner_art()` when `window_corner()` is `&"art"`).
@export var corner_art: Texture2D:
	set(value):
		corner_art = value
		_queue()

## The plate (a PanelContainer) and what is on it.
var ribbon: PanelContainer
var title_label: Label
var glyph_rect: TextureRect
var corner_rect: TextureRect

var _row: HBoxContainer
var _queued := false


static func make(text: String, icon: StringName = &"", on_left := true) -> GoRibbonHeader:
	var node := GoRibbonHeader.new()
	node.title = text
	node.glyph_icon = icon
	node.corner_on_left = on_left
	return node


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon = PanelContainer.new()
	ribbon.name = "Ribbon"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon, false, Node.INTERNAL_MODE_FRONT)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", GLYPH_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(_row)
	glyph_rect = TextureRect.new()
	glyph_rect.name = "Glyph"
	glyph_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(glyph_rect)
	title_label = GoStyle.label("", GoTheme.ROLE_SUBTITLE)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One line: the title shrinks to fit instead of wrapping.
	GoStyle.one_line(title_label)
	title_label.size_flags_horizontal = Control.SIZE_FILL
	title_label.text = title
	_row.add_child(title_label)
	corner_rect = TextureRect.new()
	corner_rect.name = "Corner"
	corner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	corner_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner_rect, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_layout)


func _enter_tree() -> void:
	GoUi.watch(refresh)
	refresh()


func _exit_tree() -> void:
	GoUi.unwatch(refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree(): _queue()


func _queue() -> void:
	if _queued or not is_inside_tree(): return
	_queued = true
	refresh.call_deferred()


## Dresses and lays it out now (the setters batch to the end of the frame).
func refresh() -> void:
	_queued = false
	if ribbon == null: return
	var skin := GoUi.skin()
	# The plate: a variation the caller picked, else the look's title plate, else nothing (a plain title row).
	if not ribbon_variation.is_empty():
		ribbon.theme_type_variation = ribbon_variation
		ribbon.remove_theme_stylebox_override(&"panel")
	else:
		ribbon.theme_type_variation = &""
		var plate := skin.title_plate_box()
		ribbon.add_theme_stylebox_override(&"panel", plate if plate != null else StyleBoxEmpty.new())
	var ink := skin.title_plate_ink()
	if ink.a > 0.0: title_label.add_theme_color_override(&"font_color", ink)
	else: title_label.remove_theme_color_override(&"font_color")
	title_label.remove_theme_color_override(&"font_outline_color")
	title_label.remove_theme_constant_override(&"outline_size")
	skin.dress_title(title_label)
	var texture := glyph if glyph != null else (GoUi.icons().texture(glyph_icon) if not glyph_icon.is_empty() else null)
	glyph_rect.texture = texture
	glyph_rect.visible = texture != null
	glyph_rect.self_modulate = ink if ink.a > 0.0 else title_label.get_theme_color(&"font_color")
	var side := roundf(float(_natural_size()) * 26.0 / 34.0)
	glyph_rect.custom_minimum_size = Vector2(side, side)
	var art := corner_art
	if art == null and skin.window_corner() == &"art": art = skin.window_corner_art()
	corner_rect.texture = art
	corner_rect.visible = corner and art != null
	corner_rect.flip_h = not corner_on_left
	_layout()


## 📐 How far a card headed by the look's ribbon draws past its own rect — left, top, right, bottom (dp, at scale 1):
## the plate past the card's sides and over its top edge (`GoSkin.title_plate_overhang()`), and the corner art past the
## plate (`window_corner_rect()`) when [param corner] is on and the look has corner art. Either corner may carry the
## art, so both sides reserve it and the card stays centred — the game's `RibbonHeader.card_overhang()`: 20 each side
## and 41 above the painted card in `arcade_light`. [param card] gives the face's margins (null: the look's window
## card, `window_card_variation()`). A look with no overhang returns `Vector4.ZERO`. `GoFitBox` reserves this.
## [param close_key]: a close key sits in the other corner (`GoSurface.show_close_key`) — its reach
## (`GoSkin.window_close_key_rect()`) is reserved too, on both sides.
static func card_overhang(card: Control = null, corner := true, close_key := false) -> Vector4:
	var skin := GoUi.skin()
	var reach := skin.title_plate_overhang()
	var face: StyleBox = null
	if card != null:
		face = card.get_theme_stylebox(&"panel")
	else:
		var look := GoUi.theme()
		var wear := skin.window_card_variation()
		if look != null and look.has_stylebox(&"panel", wear): face = look.get_stylebox(&"panel", wear)
	var card_top := face.get_margin(SIDE_TOP) if face != null else 0.0
	var side_margin := minf(face.get_margin(SIDE_LEFT), face.get_margin(SIDE_RIGHT)) if face != null else 0.0
	# The plate's top-left from the card's: over the edge when the look hangs it, else inside the face's padding.
	var plate := Vector2(side_margin - reach.x, -reach.y if reach.y > 0.0 else card_top)
	var spot := skin.window_corner_rect() if corner and skin.window_corner() == &"art" else Rect2()
	var side := maxf(0.0, maxf(-plate.x, -(plate.x + spot.position.x)))
	var top := maxf(0.0, maxf(-plate.y, -(plate.y + spot.position.y)))
	if close_key:
		var key := skin.window_close_key_rect()
		side = maxf(side, -(plate.x + key.position.x))
		top = maxf(top, -(plate.y + key.position.y))
	return Vector4(side, top, side, 0.0)


## The title's size before it shrinks: the look's plate size, else the subtitle role's.
func _natural_size() -> int:
	var look := GoUi.skin().title_plate_font_size()
	return look if look > 0 else GoUi.font_size(GoTheme.ROLE_SUBTITLE)


## The card's top margin: the panel of the nearest PanelContainer above.
func _card_top() -> float:
	var node := get_parent()
	while node != null:
		if node is PanelContainer:
			var face := (node as PanelContainer).get_theme_stylebox(&"panel")
			return face.get_margin(SIDE_TOP) if face != null else 0.0
		node = node.get_parent()
	return 0.0


func _layout() -> void:
	if ribbon == null or not is_inside_tree(): return
	var skin := GoUi.skin()
	var reach := skin.title_plate_overhang()
	var rise := (_card_top() + reach.y) if reach.y > 0.0 else 0.0
	_fit_title(reach)
	var high := skin.title_plate_height()
	if high <= 0.0: high = ribbon.get_combined_minimum_size().y
	ribbon.position = Vector2(-reach.x, -rise)
	ribbon.size = Vector2(size.x + 2.0 * reach.x, high)
	var hold := maxf(0.0, high - rise)
	if not is_equal_approx(custom_minimum_size.y, hold): custom_minimum_size = Vector2(0.0, hold)
	if corner_rect.visible:
		var rect := skin.window_corner_rect()
		if rect == Rect2(): rect = Rect2(Vector2.ZERO, corner_rect.texture.get_size())
		var x := ribbon.position.x + rect.position.x if corner_on_left \
				else ribbon.position.x + ribbon.size.x - rect.position.x - rect.size.x
		corner_rect.position = Vector2(x, ribbon.position.y + rect.position.y)
		corner_rect.size = rect.size


## The largest size from the look's down to `fit_floor` at which the title fits the ribbon less its ends and the glyph.
func _fit_title(reach: Vector2) -> void:
	var natural := _natural_size()
	var plate := ribbon.get_theme_stylebox(&"panel")
	var room := size.x + 2.0 * reach.x - (plate.get_minimum_size().x if plate != null else 0.0)
	if glyph_rect.visible: room -= glyph_rect.custom_minimum_size.x + GLYPH_GAP
	var fitted := natural
	if size.x > 0.0 and not title.is_empty():
		fitted = GoStyle.fit_font_size(PackedStringArray([title_label.atr(title)]), natural, room,
				title_label.get_theme_font(&"font"))
	if title_label.get_theme_font_size(&"font_size") != fitted or not title_label.has_theme_font_size_override(&"font_size"):
		title_label.add_theme_font_size_override(&"font_size", fitted)
