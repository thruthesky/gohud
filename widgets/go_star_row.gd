## ⭐ **A row of rating stars** — `stars` of `max_stars` lit, the rest dim: a level's best clear (1 easy, 2 normal,
## 3 hard), a result screen's grade, a review score.
##
## ```gdscript
## var rating := GoStarRow.make(2)           # two of three lit
## rating.star_size = 40.0                   # a victory screen's big row
## rating.stars = 3
## ```
##
## The stars come from the exported textures, else the skin's art (`GoSkin.widget_art`: `star` and `star_empty`, the
## painted gold star and its grey slot in arcade_light), else the icon set's `GoIconSet.STAR` in the `warning_fill`
## colour for an earned star and a faded `muted_fill` for the others — a look with no art still works.
##
## 🔑 `GoLevelCard.stars` shows the same row on a level tile (`GoLevelCard.star_row`).
## 🛑 It ignores the mouse, so a card or button under it still takes the press. The stars never flip with the
##    language: the first lit star is always the left one.
@tool
class_name GoStarRow
extends HBoxContainer

## How much of the faded colour an unearned star keeps when it is drawn from the icon set (no art).
const EMPTY_ALPHA := 0.55

## The stars earned. More than `max_stars` shows them all lit; under 0 counts as 0.
@export_range(0, 10) var stars := 0:
	set(value):
		if stars == maxi(0, value): return   # the card sets every field on each refresh
		stars = maxi(0, value)
		_refresh()

## How many stars the row holds.
@export_range(1, 10) var max_stars := 3:
	set(value):
		if max_stars == maxi(1, value): return   # the card sets every field on each refresh
		max_stars = maxi(1, value)
		_refresh()

## One star's side, before `scale_factor`.
@export var star_size := 18.0:
	set(value):
		if star_size == maxf(1.0, value): return   # the card sets every field on each refresh
		star_size = maxf(1.0, value)
		_refresh()

## The space between two stars, before `scale_factor`.
@export var gap := 2.0:
	set(value):
		if gap == maxf(0.0, value): return   # the card sets every field on each refresh
		gap = maxf(0.0, value)
		_refresh()

## Every size is multiplied by this (1 = the design size).
@export var scale_factor := 1.0:
	set(value):
		if scale_factor == maxf(0.1, value): return   # the card sets every field on each refresh
		scale_factor = maxf(0.1, value)
		_refresh()

@export_group("Art")
## An earned star. Empty: the skin's `star` art, else the icon set's star in `warning_fill`.
@export var earned_texture: Texture2D:
	set(value):
		earned_texture = value
		_refresh()
## A star still to earn. Empty: the skin's `star_empty` art, else the icon set's star, faded.
@export var empty_texture: Texture2D:
	set(value):
		empty_texture = value
		_refresh()
@export_group("")

## One holder per star, left to right — each holds the star's picture (a TextureRect, or the icon set's glyph).
var star_nodes: Array[Control] = []

var _built := false


func _init() -> void:
	name = "StarRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_built = true
	_refresh()


static func make(earned_stars := 0, total := 3, side := 18.0) -> GoStarRow:
	var node := GoStarRow.new()
	node.max_stars = total
	node.stars = earned_stars
	node.star_size = side
	return node


## The lit stars: `stars`, held to `0..max_stars`.
func earned() -> int:
	return clampi(stars, 0, max_stars)


## Is the star at [param index] (0 = the left one) lit.
func is_earned(index: int) -> bool:
	return index >= 0 and index < earned()


## One star's side in pixels, `star_size` × `scale_factor`.
func star_side() -> float:
	return roundf(star_size * scale_factor)


## The row's width and height for these sizes — what it asks of its parent.
func row_size() -> Vector2:
	var side := star_side()
	return Vector2(side * max_stars + roundi(gap * scale_factor) * (max_stars - 1), side)


## Rebuilds the stars now (the setters already do).
func refresh() -> void:
	_refresh()


func _enter_tree() -> void:
	GoUi.watch(_refresh)
	if is_node_ready(): _refresh()


func _exit_tree() -> void:
	GoUi.unwatch(_refresh)


func _refresh() -> void:
	if not _built: return
	var side := star_side()
	add_theme_constant_override(&"separation", roundi(gap * scale_factor))
	while star_nodes.size() > max_stars:
		star_nodes.pop_back().free()
	while star_nodes.size() < max_stars:
		var holder := MarginContainer.new()
		holder.name = "Star%d" % (star_nodes.size() + 1)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(holder)
		star_nodes.append(holder)
	accessibility_name = "%d/%d" % [earned(), max_stars]
	for i in star_nodes.size():
		var holder := star_nodes[i]
		holder.custom_minimum_size = Vector2(side, side)
		_dress(holder, is_earned(i), side)


func _dress(holder: Control, lit: bool, side: float) -> void:
	var old: Control = holder.get_child(0) if holder.get_child_count() > 0 else null
	var art := earned_texture if lit else empty_texture
	if art == null: art = GoUi.skin().widget_art(&"star" if lit else &"star_empty")
	var fresh: Control = null
	if art != null:
		var picture := TextureRect.new()
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fresh = picture
	elif GoUi.icons().has_icon(GoIconSet.STAR):
		var ink := GoUi.color(GoTheme.WARNING_FILL)
		if not lit:
			ink = GoUi.color(GoTheme.MUTED_FILL)
			ink.a *= EMPTY_ALPHA
		fresh = GoUi.icons().node(GoIconSet.STAR, maxi(1, roundi(side)), ink)
	# 🛑 Restyle the star that is already there rather than free it and add another. A card re-dresses its row in its
	#    deferred refresh; swapping a glyph Label in that pass, under a `GoScroll`, never let the frame end (4.7.2, 2026-10-19).
	if old != null and fresh != null and _restyle(old, fresh):
		fresh.free()
		return
	for child in holder.get_children(): child.free()
	if fresh != null: holder.add_child(fresh)


## Copies the look of [param fresh] onto [param old] when they are the same kind of node; false when they are not.
func _restyle(old: Control, fresh: Control) -> bool:
	if old.get_class() != fresh.get_class(): return false
	old.custom_minimum_size = fresh.custom_minimum_size
	old.modulate = fresh.modulate
	if fresh is TextureRect:
		(old as TextureRect).texture = (fresh as TextureRect).texture
		return true
	var label := old as Label
	var source := fresh as Label
	label.text = source.text
	label.remove_theme_font_override(&"font")
	if source.has_theme_font_override(&"font"): label.add_theme_font_override(&"font", source.get_theme_font(&"font"))
	label.remove_theme_font_size_override(&"font_size")
	if source.has_theme_font_size_override(&"font_size"):
		label.add_theme_font_size_override(&"font_size", source.get_theme_font_size(&"font_size"))
	label.add_theme_color_override(&"font_color", source.get_theme_color(&"font_color"))
	return true
