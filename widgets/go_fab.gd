## ➕ **Floating action button** — the one most important action of a screen (compose, add to cart, new chat),
## floating in the bottom corner above the content. Give it a label and it is the **extended FAB**.
##
## ```gdscript
## var fab := GoFab.make(GoIconSet.EDIT, "", compose, GoFab.Size.REGULAR)
## fab.tooltip_text_name = &"Compose"      # an icon-only FAB needs its name
## screen.add_child(fab)
## fab.float_in(screen, nav_bar.size.y)    # bottom end corner, clear of the navigation bar and the gesture bar
##
## var buy := GoFab.make(GoIconSet.PLUS, "Add to cart", add_to_cart)
## buy.follow(list_scroll)                 # folds to its icon while the list scrolls down, unfolds on the way up
## ```
##
## ## 🔑 One per screen
## A FAB says "this is what you came here to do". Two of them say nothing — use a `GoSplitButton` or a toolbar instead.
##
## ## 🔑 Four sizes
## `SMALL` 40 · `REGULAR` 56 · `MEDIUM` 80 · `LARGE` 96 dp (Material's FAB sizes). A 40dp FAB still takes presses 48dp
## wide (`GoConfig.min_touch_size`). The skin draws the face (`GoSkin.fab_box`): the theme's own primary button grown
## into a floating square by default, M3's `primary-container` with its size's corner under Material.
@tool
class_name GoFab
extends Button

## Material's FAB sizes.
enum Size {
	SMALL,    ## 40dp
	REGULAR,  ## 56dp
	MEDIUM,   ## 80dp
	LARGE,    ## 96dp
}

## The size. An extended FAB (one with a label) is always 56dp tall.
@export var fab_size := Size.REGULAR:
	set(value):
		fab_size = value
		_refresh()

## Icon name (`GoIconSet.PLUS` and so on).
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_refresh()

## The label of an extended FAB. Empty is a plain (icon-only) FAB.
@export var label_text := "":
	set(value):
		label_text = value
		_refresh()

## The tooltip of an icon-only FAB, through `GoUi.text`: a gohud string name, your translation key, or plain words.
## 🛑 Give one — it is the only name a screen reader has for a FAB without a label.
@export var tooltip_text_name: StringName = &"":
	set(value):
		tooltip_text_name = value
		_refresh_name()

## Whether an extended FAB shows its label. `follow()` folds it to the icon while the list scrolls down.
@export var expanded := true:
	set(value):
		if expanded == value: return
		expanded = value
		_refresh()

## Side of each size (dp).
const EXTENTS := {Size.SMALL: 40.0, Size.REGULAR: 56.0, Size.MEDIUM: 80.0, Size.LARGE: 96.0}
## Icon size of each size (dp) — `_md-comp-fab*.scss` icon-size.
const GLYPHS := {Size.SMALL: 24, Size.REGULAR: 24, Size.MEDIUM: 28, Size.LARGE: 36}
## Height of an extended FAB (dp).
const EXTENDED := 56.0

var _row: HBoxContainer
var _glyph: Control
var _words: Label
var _followed: ScrollContainer
var _last_scroll := 0.0


func _init() -> void:
	name = "Fab"
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_END
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	GoScroll.scroll_through(self)
	_row = HBoxContainer.new()
	_row.name = "Content"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 8)
	add_child(_row)


func _ready() -> void:
	theme = GoUi.theme()
	_refresh()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A FAB with [param icon] — and [param text], an extended FAB. [param action] runs on press.
static func make(icon: StringName, text := "", action := Callable(), size := Size.REGULAR) -> GoFab:
	var node := GoFab.new()
	node.fab_size = size
	node.icon_name = icon
	node.label_text = text
	if action.is_valid(): node.pressed.connect(action)
	return node


## Floats it in the bottom end corner of [param host] (bottom right, bottom left in a right-to-left language), 16dp in
## from the edges plus the safe-area insets, and [param above] dp higher still — the height of a navigation bar under it.
## 🛑 [param host] must not be a container — a container would lay the FAB out itself. Use the screen's root `Control`.
func float_in(host: Control, above := 0.0) -> void:
	if get_parent() != host:
		if get_parent() != null: get_parent().remove_child(self)
		host.add_child(self)
	var rtl := host.is_layout_rtl()
	anchor_left = 0.0 if rtl else 1.0
	anchor_right = anchor_left
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_END if rtl else Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var margin := float(GoUi.metric(GoTheme.GAP))
	var window := get_window() if is_inside_tree() else null
	var insets := Vector4.ZERO   # left, top, right, bottom
	if window != null and not Engine.is_editor_hint():
		var full := window.get_visible_rect()
		var area := GoSafeArea.usable_rect(window)
		insets = Vector4(area.position.x - full.position.x, 0.0, full.end.x - area.end.x, full.end.y - area.end.y)
	var side := margin + (insets.x if rtl else insets.z)
	var lift := margin + insets.w + above
	var extent := get_combined_minimum_size()
	offset_bottom = -lift
	offset_top = -lift - extent.y
	if rtl:
		offset_left = side
		offset_right = side + extent.x
	else:
		offset_right = -side
		offset_left = -side - extent.x


## An extended FAB folds to its icon while [param scroll] moves down and unfolds when it moves back up.
func follow(scroll: ScrollContainer) -> void:
	if is_instance_valid(_followed) and _followed.get_v_scroll_bar().value_changed.is_connected(_on_scroll):
		_followed.get_v_scroll_bar().value_changed.disconnect(_on_scroll)
	_followed = scroll
	if scroll == null: return
	_last_scroll = scroll.get_v_scroll_bar().value
	scroll.get_v_scroll_bar().value_changed.connect(_on_scroll)


func _on_scroll(value: float) -> void:
	# A few dp of hysteresis — a list settling by a pixel must not flick the label in and out.
	if absf(value - _last_scroll) < 4.0: return
	expanded = value < _last_scroll or value <= 0.5
	_last_scroll = value


func _extent() -> float:
	return EXTENDED if _is_extended() else float(EXTENTS[fab_size])


func _is_extended() -> bool:
	return not label_text.is_empty()


func _refresh() -> void:
	if _row == null or not is_inside_tree(): return
	var skin := GoUi.skin()
	var extent := _extent()
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, skin.fab_box(extent, &"pressed" if state == &"hover_pressed" else state))
	var ink := skin.fab_ink()
	if disabled: ink = Color(ink, 0.38)
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var glyph_size: int = GLYPHS[fab_size] if not _is_extended() else 24
	_glyph = GoUi.icons().node(icon_name, glyph_size, ink) if not icon_name.is_empty() else null
	if _glyph != null: _row.add_child(_glyph)
	_words = null
	var shows_label := _is_extended() and expanded
	if shows_label:
		_words = GoStyle.label(label_text, GoTheme.ROLE_BODY, ink)
		_words.name = "Label"
		_words.autowrap_mode = TextServer.AUTOWRAP_OFF
		_words.set_meta(&"go_no_wrap", true)
		_words.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# The button's own (medium-weight) font — the M3 extended FAB label is title-medium at weight 500.
		var font := get_theme_font(&"font", GoTheme.VAR_BUTTON)
		if font != null: _words.add_theme_font_override(&"font", font)
		_row.add_child(_words)
	# 🔑 A plain FAB is a square; an extended one is 16dp + icon + 8dp + label + 16dp, 56dp tall.
	var pad := 16.0 if _is_extended() else 0.0
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_left = pad
	_row.offset_right = -pad
	var width := extent
	if shows_label:
		width = pad * 2.0 + float(glyph_size) + 8.0 + _words.get_combined_minimum_size().x
	custom_minimum_size = Vector2(width, extent)
	_refresh_name()
	size = custom_minimum_size


## Take presses in the slack beyond a small FAB — the touch target is `min_touch_size` whatever the visible size.
func _has_point(point: Vector2) -> bool:
	var reach := maxf(0.0, (float(GoUi.config.min_touch_size) - minf(size.x, size.y)) * 0.5)
	return Rect2(Vector2.ZERO, size).grow(reach).has_point(point)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh_name()


## 🛑 The engine's tooltip can break into one character per line — gohud builds its own (`GoStyle.tooltip_node`).
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	return GoStyle.tooltip_node(for_text)


func _refresh_name() -> void:
	tooltip_text = GoUi.text(tooltip_text_name) if not tooltip_text_name.is_empty() else ""
	# ♿ A plain FAB has no text for a screen reader — its tooltip is its name; an extended FAB is named by its label.
	accessibility_name = label_text if not label_text.is_empty() else tooltip_text


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_refresh()
