## 🍩 **Donut shares** — damage breakdown, inventory weight, currency split, party contribution.
##
## ```gdscript
## var share := GoDonut.make([
##     {"label": "Physical", "value": 620, "color": Color("e05a4a")},
##     {"label": "Magic", "value": 340, "color": Color("4a8fe0")},
##     {"label": "Pierce", "value": 90},        # with no color, the theme's are cycled through
## ])
## share.center_text = "1050"                    # the total in the middle
## ```
##
## ## 🔑 Never go past five slices
## From six on, the small ones look like threads and cannot be read. The rest are better **folded into an "other"** —
## give `collapse_to` and it folds them for you.
##
## ## 🛑 Never leave the middle empty
## The middle of a donut is the cheapest real estate in a game. Put a total, a share or an icon in it.
##
## ## ♿ Color alone never tells things apart
## Slice names and shares go into the screen-reader name. The legend you read with your eyes (`legend()`) keeps
## **the text beside the dot** — a legend of colored dots alone is no information at all to someone with a color vision deficiency.
@tool
class_name GoDonut
extends Control

## The text in the middle (a total, a share). Empty writes nothing.
@export var center_text := "":
	set(value):
		center_text = value
		queue_redraw()

## A small caption under the center text.
@export var center_hint := "":
	set(value):
		center_hint = value
		queue_redraw()

## Ring thickness as a fraction (0~1). 1 makes it a pie chart (no middle).
@export_range(0.1, 1.0, 0.01) var thickness_ratio := 0.34:
	set(value):
		thickness_ratio = value
		queue_redraw()

## Past this count the rest is **folded into one**. 0 folds nothing.
@export var collapse_to := 5:
	set(value):
		collapse_to = maxi(0, value)
		queue_redraw()

## The name of the folded slice (plain text, not a translation key).
@export var collapse_label := "…"

var _slices: Array[Dictionary] = []


func _init() -> void:
	name = "Donut"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(140, 140)


func _ready() -> void:
	GoUi.watch(_on_ui_changed)
	_sync_accessibility()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## A slice is `{"label":…, "value":…, "color":…}`. `value` is **the raw value, not a share** —
## the values need not add up to anything (the division happens here).
static func make(slices: Array) -> GoDonut:
	var node := GoDonut.new()
	node.set_slices(slices)
	return node


func set_slices(slices: Array) -> void:
	_slices.clear()
	for entry in slices:
		var row: Dictionary = entry if entry is Dictionary else {"value": float(entry)}
		_slices.append({
			"label": str(row.get("label", "")),
			"value": maxf(0.0, float(row.get("value", 0.0))),
			"color": row.get("color", Color.TRANSPARENT) as Color,
		})
	_sync_accessibility()
	queue_redraw()


func slices() -> Array[Dictionary]:
	return _slices


## The total (the sum of the raw values).
func total() -> float:
	var sum := 0.0
	for slice in _slices: sum += float(slice["value"])
	return sum


## The slices actually drawn — largest first, folded when there are too many.
func visible_slices() -> Array[Dictionary]:
	var sorted := _slices.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	if collapse_to <= 0 or sorted.size() <= collapse_to: return sorted
	var out := sorted.slice(0, collapse_to - 1)
	var rest := 0.0
	for slice in sorted.slice(collapse_to - 1): rest += float(slice["value"])
	out.append({"label": collapse_label, "value": rest, "color": GoUi.color(GoTheme.MUTED)})
	return out


func _draw() -> void:
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	var box := minf(size.x, size.y)
	var outer := box * 0.5
	var width := outer * clampf(thickness_ratio, 0.1, 1.0)
	var radius := outer - width * 0.5
	if radius <= 1.0: return
	var center := size * 0.5

	# With no values at all, just the empty ring — 🛑 drawing nothing is indistinguishable from "loading".
	if sum <= 0.0:
		draw_arc(center, radius, 0.0, TAU, 64, GoUi.color(GoTheme.TRACK), width, true)
		_draw_center()
		return

	var angle := -PI * 0.5   # from 12 o'clock, clockwise — the convention people read shares by
	for index in parts.size():
		var slice := parts[index]
		var portion := float(slice["value"]) / sum
		if portion <= 0.0: continue
		var sweep := TAU * portion
		var color: Color = slice["color"]
		if color.a <= 0.0: color = _palette(index)
		draw_arc(center, radius, angle, angle + sweep, maxi(8, roundi(64.0 * portion)), color, width, true)
		angle += sweep
	_draw_center()


func _draw_center() -> void:
	if center_text.is_empty() and center_hint.is_empty(): return
	var font := get_theme_font(&"font")
	if font == null: return
	var center := size * 0.5
	var big := GoUi.font_size(GoTheme.ROLE_SUBTITLE)
	var small := GoUi.font_size(GoTheme.ROLE_MICRO)
	if not center_text.is_empty():
		var measured := font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		var at := center - Vector2(measured.x * 0.5, 0.0)
		if not center_hint.is_empty(): at.y -= small * 0.4
		draw_string(font, at, center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, GoUi.color(GoTheme.TEXT))
	if center_hint.is_empty(): return
	var hint_size := font.get_string_size(center_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
	draw_string(font, center + Vector2(-hint_size.x * 0.5, small * 1.4), center_hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, GoUi.color(GoTheme.MUTED))


## The colors cycled through for slices given none. 🔑 Picked from theme tokens only — a hardcoded palette would not follow when the skin changes.
func _palette(index: int) -> Color:
	var wheel := [GoTheme.ACCENT, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.INFO, GoTheme.DANGER]
	return GoUi.color(wheel[index % wheel.size()])


## The legend you read with your eyes. 🛑 **Never colored dots alone** — the name and the share go beside them as text.
func legend() -> Control:
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	column.name = "Legend"
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	for index in parts.size():
		var slice := parts[index]
		var color: Color = slice["color"]
		if color.a <= 0.0: color = _palette(index)
		var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2.ONE * float(GoUi.font_size(GoTheme.ROLE_MICRO))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override(&"panel", GoUi.skin().badge_box(color))
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name := GoStyle.label(str(slice["label"]), GoTheme.ROLE_COMPACT)
		name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var portion := 0.0 if sum <= 0.0 else float(slice["value"]) / sum * 100.0
		var share := GoStyle.label(GoUi.text(&"bar_percent").format({"percent": roundi(portion)}),
			GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
		share.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		share.text_direction = Control.TEXT_DIRECTION_LTR
		row.add_child(share)
		column.add_child(row)
	return column


func _sync_accessibility() -> void:
	var parts := visible_slices()
	var sum := 0.0
	for slice in parts: sum += float(slice["value"])
	# 🛑 A percent format is text too (the same reason as `GoRadar` above) — it goes through the `bar_percent` key.
	var spoken: Array[String] = []
	for slice in parts:
		var portion := 0.0 if sum <= 0.0 else float(slice["value"]) / sum * 100.0
		var share := GoUi.text(&"bar_percent").format({"percent": roundi(portion)})
		spoken.append(GoUi.spoken([str(slice["label"]), share]))
	accessibility_name = GoUi.spoken(spoken)


func _on_ui_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: queue_redraw()
