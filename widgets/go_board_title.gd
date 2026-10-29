## 🏷️ **A board title** — a big white outlined title with an icon on its left, and a navy pill under it ("Resets in
## 3d 4h", "Stage 4 · Hard"): the heading over a leaderboard.
##
## ```gdscript
## var title := GoBoardTitle.new()
## title.text = tr("WEEKLY CHALLENGE")
## title.icon = GoUi.skin().widget_art(&"icon_calendar")
## title.pill_text = tr("Resets in %s") % left
## ```
##
## The title is the theme's `GoBoardTitle` label, the pill a `GoBoardPill` panel holding a `GoBoardPillLabel` (and
## [member pill_icon] before it, when set). An empty [member pill_text] hides the pill; a null [member icon] hides the
## icon and centres the title alone.
## 🔤 The title and the pill shrink to fit the width they are given (`GoStyle.fit_font_size`, never under
##    `GoConfig.fit_min_scale`), so every language fits one line.
## 🔑 The pill tucks up under the title by [member pill_overlap] (a share of the pill's height), as on the painted
##    boards.
@tool
class_name GoBoardTitle
extends VBoxContainer

const VAR_TITLE := &"GoBoardTitle"
const VAR_PILL := &"GoBoardPill"
const VAR_PILL_LABEL := &"GoBoardPillLabel"
## The icon's height as a share of the title's font size, and the gap between them (same share).
const ICON_SHARE := 1.25
const ICON_GAP := 0.15
## How far the pill also rides up into the title line's empty descent, as a share of the title's font size (the display
## face sits high in its line; the painted pill hangs right under the letters).
const TITLE_TUCK_SHARE := 0.3

## The title.
@export var text := "":
	set(value):
		text = value
		if title_label != null: title_label.text = value
		_queue_fit()

## The picture left of the title (right of it, right to left). Null: none.
@export var icon: Texture2D:
	set(value):
		icon = value
		if icon_rect != null:
			icon_rect.texture = value
			icon_rect.visible = value != null
		_queue_fit()

## The pill's words. Empty: no pill.
@export var pill_text := "":
	set(value):
		pill_text = value
		if pill_label != null: pill_label.text = value
		if pill != null: pill.visible = not value.is_empty()
		_queue_fit()

## A small picture before the pill's words (a clock). Null: words alone.
@export var pill_icon: Texture2D:
	set(value):
		pill_icon = value
		if pill_icon_rect != null:
			pill_icon_rect.texture = value
			pill_icon_rect.visible = value != null

## How far the pill rides up under the title, as a share of the pill's height.
@export_range(0.0, 0.8, 0.01) var pill_overlap := 0.15:
	set(value):
		pill_overlap = value
		_queue_fit()

var title_row: HBoxContainer
var icon_rect: TextureRect
var title_label: Label
var pill: PanelContainer
var pill_icon_rect: TextureRect
var pill_label: Label
var _fit_queued := false


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row = HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_row)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	title_row.add_child(icon_rect)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = VAR_TITLE
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title_label)
	pill = PanelContainer.new()
	pill.name = "Pill"
	pill.theme_type_variation = VAR_PILL
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.visible = false
	add_child(pill)
	var pill_row := HBoxContainer.new()
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(pill_row)
	pill_icon_rect = TextureRect.new()
	pill_icon_rect.name = "PillIcon"
	pill_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pill_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pill_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_icon_rect.visible = false
	pill_row.add_child(pill_icon_rect)
	pill_label = Label.new()
	pill_label.name = "PillLabel"
	pill_label.theme_type_variation = VAR_PILL_LABEL
	pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(pill_label)


func _enter_tree() -> void:
	GoUi.watch(_queue_fit)
	_queue_fit()


func _exit_tree() -> void:
	GoUi.unwatch(_queue_fit)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSLATION_CHANGED: _queue_fit()


func _queue_fit() -> void:
	if _fit_queued: return
	_fit_queued = true
	fit_now.call_deferred()


## Sizes the icons and fits the title and the pill to the width now instead of at the end of the frame.
func fit_now() -> void:
	_fit_queued = false
	if not is_inside_tree(): return
	var room := size.x if size.x > 0.0 else get_parent_area_size().x
	_fit_label(title_label, room - _icon_room(_base_size(title_label)))
	var title_size := float(title_label.get_theme_font_size(&"font_size"))
	var icon_side := title_size * ICON_SHARE
	icon_rect.custom_minimum_size = Vector2.ONE * icon_side
	title_row.add_theme_constant_override(&"separation", int(title_size * ICON_GAP))
	var face := pill.get_theme_stylebox(&"panel")
	var pill_room := room - (face.get_minimum_size().x if face != null else 0.0)
	var pill_size := float(_base_size(pill_label))
	if pill_icon != null: pill_room -= pill_size * 1.2
	_fit_label(pill_label, pill_room)
	pill_size = float(pill_label.get_theme_font_size(&"font_size"))
	pill_icon_rect.custom_minimum_size = Vector2.ONE * pill_size * 1.1
	var pill_tall := pill_label.get_minimum_size().y + (face.get_minimum_size().y if face != null else 0.0)
	add_theme_constant_override(&"separation", -int(pill_tall * pill_overlap + title_size * TITLE_TUCK_SHARE))


func _icon_room(base: int) -> float:
	return float(base) * (ICON_SHARE + ICON_GAP) if icon != null else 0.0


func _base_size(label: Label) -> int:
	if label.has_theme_font_size_override(&"font_size"): label.remove_theme_font_size_override(&"font_size")
	return label.get_theme_font_size(&"font_size")


func _fit_label(label: Label, room: float) -> void:
	var base := _base_size(label)
	if room <= 0.0 or label.text.is_empty(): return
	var fitted := GoStyle.fit_font_size(PackedStringArray([atr(label.text)]), base, room, label.get_theme_font(&"font"))
	if fitted != base: label.add_theme_font_size_override(&"font_size", fitted)
