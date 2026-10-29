## 🗂 **A category key** — the big plates down the side of a leaderboard (WEEKLY WINS, TOTAL WINS, ELIMINATIONS,
## FASTEST CLEARS): an icon on the left, the words beside it, and the one picked shows gold with a chevron on its right.
##
## ```gdscript
## var weekly := GoCategoryButton.make("WEEKLY WINS", GoUi.skin().widget_art(&"icon_calendar"))
## weekly.custom_minimum_size = Vector2(320, 100)
## weekly.selected = true                     # gold plate, navy words, chevron
## weekly.pressed.connect(_show_board.bind(&"weekly"))
## ```
##
## The face is the theme's `GoCategoryButton` (a blue glossy plate with an ink rim and white outlined words) or
## `GoCategoryButtonSelected` (gold, an orange rim, navy words); a look that paints the plates (`GoSkin.category_button_art`,
## arcade_light's `category_blue` / `category_gold`) lays its picture over that face and keeps the face's padding. A
## theme without the variations falls back to its `Button`.
## 🔤 The words are the button's own `text` (translation and tests work as on any button). They fit the room between
##    the icon and the right edge (`GoStyle.fit_font_size`, never under `GoConfig.fit_min_scale`); words that would
##    shrink too far break onto a second line ("FASTEST / CLEARS"), and the two lines are fitted again.
## 🛑 `selected` is the caller's: a press does not select the key (the screen picks one category and unpicks the rest).
## 🔑 Right to left, the icon stands on the right and the chevron on the left.
@tool
class_name GoCategoryButton
extends Button

const VAR_CATEGORY := &"GoCategoryButton"
const VAR_SELECTED := &"GoCategoryButtonSelected"
## The icon's height as a share of the button's height, and its distance from the near edge (share of the height).
const ICON_SHARE := 0.74
const ICON_INSET := 0.1
## The space between the icon and the words.
const GAP := 6.0
## The chevron's height as a share of the button's height, and its distance from the far edge.
const CHEVRON_SHARE := 0.4
const CHEVRON_INSET := 0.1
## The words break onto two lines when one line would have to shrink below this share of the look's size, or would
## overflow even at the fit floor. Above it one line shrinks to fit, as on the painted board (WEEKLY WINS and
## ELIMINATIONS stand on one line, FASTEST / CLEARS breaks).
const WRAP_BELOW := 0.78
## The faces that place the words.
const TEXT_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]

## The picture on the left (a calendar, a trophy…). Null: none, and the words take the room.
@export var icon_art: Texture2D:
	set(value):
		icon_art = value
		_queue_refresh()

## 🥇 The picked category: the gold plate, navy words and the chevron.
@export var selected := false:
	set(value):
		if selected == value: return
		selected = value
		theme_type_variation = VAR_SELECTED if value else VAR_CATEGORY
		_queue_refresh()

## The chevron on the picked key. Null: the skin's `chevron` art, else the icon set's chevron.
@export var chevron_art: Texture2D:
	set(value):
		chevron_art = value
		_queue_refresh()

## 🔔 What the player's press says through `GoFeedback`. Empty: silent.
@export var feedback: StringName = GoFeedback.TAPPED

var _refresh_queued := false
var _refreshing := false
## The `font_size` the fit put on (0: none of ours).
var _fitted := 0
## The words the fit was measured for (a new `text` is noticed when the button redraws).
var _fitted_text := ""


## A padded face: the theme's (or the skin's painted) face with the icon's and chevron's room added to its padding.
class PaddedBox:
	extends StyleBox

	var base: StyleBox

	func _init(from: StyleBox = null, lead := 0.0, trail := 0.0, mirrored := false) -> void:
		base = from
		if from == null: return
		var near := SIDE_RIGHT if mirrored else SIDE_LEFT
		var far := SIDE_LEFT if mirrored else SIDE_RIGHT
		set_content_margin(near, from.get_margin(near) + lead)
		set_content_margin(far, from.get_margin(far) + trail)
		content_margin_top = from.get_margin(SIDE_TOP)
		content_margin_bottom = from.get_margin(SIDE_BOTTOM)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if base != null: base.draw(to_canvas_item, rect)

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return base.get_draw_rect(rect) if base != null else rect


func _init() -> void:
	theme_type_variation = VAR_CATEGORY
	autowrap_mode = TextServer.AUTOWRAP_OFF
	# One line unless the fit breaks it (GoForm leaves a key marked go_no_wrap alone).
	set_meta(&"go_no_wrap", true)
	# 🔑 The words never widen the key: the column sets its width and the fit shrinks or wraps the words into it.
	clip_text = true
	GoStyle.skin_focus(self)
	pressed.connect(_on_feedback_pressed)


static func make(label: String, art: Texture2D = null, picked := false) -> GoCategoryButton:
	var node := GoCategoryButton.new()
	node.text = label
	node.icon_art = art
	node.selected = picked
	return node


func _on_feedback_pressed() -> void:
	if not Engine.is_editor_hint(): GoFeedback.play(feedback)


func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	_queue_refresh()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	GoStyle.skin_focus(self)
	_queue_refresh()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
			_queue_refresh()
		NOTIFICATION_THEME_CHANGED:
			if not _refreshing: _queue_refresh()
		NOTIFICATION_DRAW:
			if text != _fitted_text: _queue_refresh()
			_draw_parts()


## The chevron drawn on the picked key: [member chevron_art], else the skin's, else the icon set's.
func chevron_texture() -> Texture2D:
	if chevron_art != null: return chevron_art
	var art := GoUi.skin().widget_art(&"chevron")
	if art != null: return art
	return GoUi.icons().texture(GoIconSet.CHEVRON_RIGHT)


## Where the icon is drawn, in the button's space (empty without one).
func icon_rect() -> Rect2:
	if icon_art == null or size.y <= 0.0: return Rect2()
	var drawn := _fit_into(icon_art, size.y * ICON_SHARE)
	var x := size.y * ICON_INSET
	if is_layout_rtl(): x = size.x - x - drawn.x
	return Rect2(Vector2(x, (size.y - drawn.y) * 0.5 + _press_drop()), drawn)


## Where the chevron is drawn (empty unless [member selected]).
func chevron_rect() -> Rect2:
	var art := chevron_texture() if selected else null
	if art == null or size.y <= 0.0: return Rect2()
	var drawn := _fit_into(art, size.y * CHEVRON_SHARE)
	var x := size.x - size.y * CHEVRON_INSET - drawn.x
	if is_layout_rtl(): x = size.y * CHEVRON_INSET
	return Rect2(Vector2(x, (size.y - drawn.y) * 0.5 + _press_drop()), drawn)


## The width the words may take now: the button less its face's padding (which holds the icon's and chevron's room).
func text_room() -> float:
	var face := get_theme_stylebox(&"normal")
	var padding := face.get_margin(SIDE_LEFT) + face.get_margin(SIDE_RIGHT) if face != null else 0.0
	# The outline stands half outside the glyphs at each end; clipping would cut it.
	return size.x - padding - get_theme_constant(&"outline_size")


## Lays the faces, the line break and the font size out now instead of at the end of the frame.
func refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree(): return
	_refreshing = true
	begin_bulk_theme_override()
	_apply_faces()
	end_bulk_theme_override()
	_fit_words()
	_refreshing = false
	queue_redraw()


func _queue_refresh() -> void:
	if _refresh_queued or _refreshing: return
	_refresh_queued = true
	refresh.call_deferred()


## The theme's face per state (or the skin's painted plate over it), padded with the icon's and chevron's room.
func _apply_faces() -> void:
	for state in TEXT_STATES:
		if has_theme_stylebox_override(state): remove_theme_stylebox_override(state)
	var lead := 0.0
	if icon_art != null and size.y > 0.0:
		lead = size.y * ICON_INSET + _fit_into(icon_art, size.y * ICON_SHARE).x + GAP
	var trail := 0.0
	var chevron := chevron_texture() if selected else null
	if chevron != null and size.y > 0.0:
		trail = size.y * CHEVRON_INSET + _fit_into(chevron, size.y * CHEVRON_SHARE).x
	for state in TEXT_STATES:
		var face := get_theme_stylebox(state)
		if face == null: continue
		var painted := GoUi.skin().category_button_art(selected, state)
		if painted != null:
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: painted.set_content_margin(side, face.get_margin(side))
			face = painted
		var near := face.get_margin(SIDE_RIGHT if is_layout_rtl() else SIDE_LEFT)
		var far := face.get_margin(SIDE_LEFT if is_layout_rtl() else SIDE_RIGHT)
		# The icon's room replaces the face's own padding on its side (the icon sits inside the plate's edge).
		add_theme_stylebox_override(state, PaddedBox.new(face, maxf(lead - near, 0.0) if lead > 0.0 else 0.0,
				maxf(trail - far * 0.5, 0.0) if trail > 0.0 else 0.0, is_layout_rtl()))


## One line at the look's size when it fits (or shrinks a little); else the words wrap onto two lines (the button's
## own `autowrap_mode`, so `text` stays the caller's) at the size the evener split of them fits.
func _fit_words() -> void:
	_fitted_text = text
	var words := atr(text)
	var font := get_theme_font(&"font")
	if _fitted != 0 and has_theme_font_size_override(&"font_size"): remove_theme_font_size_override(&"font_size")
	_fitted = 0
	var base := get_theme_font_size(&"font_size")
	var room := text_room()
	var wrap := TextServer.AUTOWRAP_OFF
	if font == null or room <= 0.0 or words.is_empty():
		autowrap_mode = wrap
		return
	var single := GoStyle.fit_font_size(PackedStringArray([words]), base, room, font)
	var size_now := single
	var spills := GoStyle.row_width(font, PackedStringArray([words]), single) > room
	if (single < floori(base * WRAP_BELOW) or spills) and words.strip_edges().contains(" "):
		var two := GoStyle.fit_font_size(PackedStringArray([_balanced_split(words, font, base)]), base, room, font)
		# Two lines must also stand in the plate's height.
		var face := get_theme_stylebox(&"normal")
		var tall := size.y - (face.get_margin(SIDE_TOP) + face.get_margin(SIDE_BOTTOM) if face != null else 0.0)
		var spacing := get_theme_constant(&"line_spacing")
		while two > GoStyle.fit_floor(base) and 2.0 * font.get_height(two) + spacing > tall:
			two -= 1
		# At the floor both ways, two lines still overflow less than one.
		var overflows := GoStyle.row_width(font, PackedStringArray([words]), single) > room
		if two > single or (two == single and overflows):
			wrap = TextServer.AUTOWRAP_WORD_SMART
			size_now = two
	autowrap_mode = wrap
	_fitted = size_now
	add_theme_font_size_override(&"font_size", size_now)


## Whether the words stand on two lines now.
func is_wrapped() -> bool:
	return autowrap_mode != TextServer.AUTOWRAP_OFF


## The words split at the space that leaves the two lines most even.
static func _balanced_split(words: String, font: Font, font_size: int) -> String:
	var best := words
	var best_width := INF
	var trimmed := words.strip_edges()
	for index in trimmed.length():
		if trimmed[index] != " ": continue
		var left := trimmed.substr(0, index).strip_edges()
		var right := trimmed.substr(index + 1).strip_edges()
		if left.is_empty() or right.is_empty(): continue
		var widest := maxf(font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
				font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if widest < best_width:
			best_width = widest
			best = left + "\n" + right
	return best


func _draw_parts() -> void:
	var tint := Color(1, 1, 1, 0.6) if disabled else Color.WHITE
	if icon_art != null: draw_texture_rect(icon_art, icon_rect(), false, tint)
	if selected:
		var chevron := chevron_texture()
		if chevron != null:
			var rect := chevron_rect()
			if is_layout_rtl():
				draw_set_transform(Vector2(rect.get_center().x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(chevron, rect, false, tint)
			if is_layout_rtl(): draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _fit_into(art: Texture2D, tall: float) -> Vector2:
	var ratio := tall / maxf(1.0, maxf(art.get_width(), art.get_height()))
	return Vector2(art.get_width(), art.get_height()) * ratio


func _press_drop() -> float:
	return 2.0 if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED else 0.0
