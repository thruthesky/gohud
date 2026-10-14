## 🗺️ **A level-select tile** — the thumbnail on the left, the level's title and a subtitle row (a person icon and
## "OPPONENTS: 3", say) beside it, and on the right the state: a check on a cleared level, a padlock with LOCKED on a
## locked one, a tilted PLAY! tag on the level to play next. A gold ring marks the selected tile.
##
## ```gdscript
## var card := GoLevelCard.make("STAGE 3", "OPPONENTS: 3", GoLevelCard.State.CURRENT)
## card.thumbnail = preload("res://levels/3.png")       # or put your own node in card.thumbnail_slot
## card.selected = true
## card.pressed.connect(_play.bind(3))
## ```
##
## The face comes from the theme variation for the state: `GoLevelCard` (open and cleared), `GoLevelCardCurrent`
## and `GoLevelCardLocked` — the painted stage cards in arcade_light. A theme without them falls back to `GoButton`
## (and `GoPrimaryButton` for the current level). The art (check, lock, person, play_tag, pointer) comes from the
## exported textures, else the skin (`GoSkin.widget_art`), else the icon set — a look with no art still works.
##
## 🛑 The texts come from the caller (they depend on the language); `locked_text` and `play_text` too. Every text is
##    shrunk to fit (`GoStyle.fit_font_size`), so a long translation never runs under the lock.
## 🛑 The setters batch their work: the tile is rebuilt once, at the end of the frame (or at once by `refresh()`).
## 🛑 A locked tile is `disabled` — it takes no press. The card only takes back the `disabled` it set itself: a tile
##    the caller disabled stays disabled when it unlocks. `tooltip_text` is the caller's too.
@tool
class_name GoLevelCard
extends Button

enum State { OPEN, CLEARED, CURRENT, LOCKED }

const VAR_CARD := &"GoLevelCard"
const VAR_CURRENT := &"GoLevelCardCurrent"
const VAR_LOCKED := &"GoLevelCardLocked"
## The label look the texts wear when the theme has it (the outlined display font in arcade_light).
const VAR_TITLE := &"GoTitle"
## The thumbnail's well when the theme has it.
const VAR_WELL := &"GoWell"
## The thumbnail of a locked level is greyed with this (the game greys its map preview).
const LOCKED_TINT := Color(0.62, 0.64, 0.7)

## The level's name ("STAGE 3").
@export var title := "":
	set(value):
		title = value
		_queue_refresh()

## The line under it ("OPPONENTS: 3"), with the person icon. Empty hides the row.
@export var subtitle := "":
	set(value):
		subtitle = value
		_queue_refresh()

@export var state := State.OPEN:
	set(value):
		state = value
		_queue_refresh()

## The gold ring round the tile.
@export var selected := false:
	set(value):
		selected = value
		_queue_refresh()

## The caption under the padlock.
@export var locked_text := "LOCKED":
	set(value):
		locked_text = value
		_queue_refresh()

## The word on the tilted tag of the current level.
@export var play_text := "PLAY!":
	set(value):
		play_text = value
		_queue_refresh()

## The thumbnail, drawn to cover its slot (`GoCoverImage`). Leave it empty to put your own node in `thumbnail_slot`.
@export var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		_queue_refresh()

## Which part of the thumbnail stays in view.
@export var thumbnail_focus := Vector2(0.5, 0.5):
	set(value):
		thumbnail_focus = value
		_queue_refresh()

@export_group("Art")
## The check on a cleared tile. Empty: the skin's `check` art, else the icon set's check on a sticker.
@export var check_texture: Texture2D:
	set(value):
		check_texture = value
		_queue_refresh()
## The padlock on a locked tile. Empty: the skin's `lock` art, else the icon set's lock.
@export var lock_texture: Texture2D:
	set(value):
		lock_texture = value
		_queue_refresh()
## The icon before the subtitle. Empty: the skin's `person` art, else the icon set's user.
@export var person_texture: Texture2D:
	set(value):
		person_texture = value
		_queue_refresh()
## The tag behind `play_text`. Empty: the skin's `play_tag` art, else a sticker plate.
@export var play_tag_texture: Texture2D:
	set(value):
		play_tag_texture = value
		_queue_refresh()
## A pointer at the current tile's bottom-right corner (the game's magnet). Empty: the skin's `pointer` art, else none.
@export var pointer_texture: Texture2D:
	set(value):
		pointer_texture = value
		_queue_refresh()

@export_group("Size")
## Every size below is multiplied by this (1 = the design size).
@export var scale_factor := 1.0:
	set(value):
		scale_factor = maxf(0.1, value)
		_queue_refresh()
@export var card_size := Vector2(300, 98):
	set(value):
		card_size = value
		_queue_refresh()
@export var thumbnail_size := 74.0:
	set(value):
		thumbnail_size = value
		_queue_refresh()
## The space left of the thumbnail.
@export var thumbnail_inset := 12.0:
	set(value):
		thumbnail_inset = value
		_queue_refresh()
## The inner padding on the other three sides.
@export var card_padding := 12.0:
	set(value):
		card_padding = value
		_queue_refresh()
## The padding inside the thumbnail's well.
@export var well_padding := 12.0:
	set(value):
		well_padding = value
		_queue_refresh()
@export var row_gap := 8.0:
	set(value):
		row_gap = value
		_queue_refresh()
@export var text_gap := 6.0:
	set(value):
		text_gap = value
		_queue_refresh()
## The least width of the lock column; it grows to hold its caption.
@export var right_slot := 56.0:
	set(value):
		right_slot = value
		_queue_refresh()
## Room kept back when the texts are fitted.
@export var fit_slack := 4.0:
	set(value):
		fit_slack = value
		_queue_refresh()
@export var title_font_size := 22:
	set(value):
		title_font_size = value
		_queue_refresh()
@export var subtitle_font_size := 15:
	set(value):
		subtitle_font_size = value
		_queue_refresh()
@export var locked_font_size := 13:
	set(value):
		locked_font_size = value
		_queue_refresh()
## The LOCKED caption never shrinks under this.
@export var min_font_size := 8:
	set(value):
		min_font_size = value
		_queue_refresh()
@export var tag_font_size := 21:
	set(value):
		tag_font_size = value
		_queue_refresh()
@export var person_size := 18.0:
	set(value):
		person_size = value
		_queue_refresh()
@export var check_size := 46.0:
	set(value):
		check_size = value
		_queue_refresh()
@export var lock_size := 34.0:
	set(value):
		lock_size = value
		_queue_refresh()
@export var tag_size := Vector2(104, 44):
	set(value):
		tag_size = value
		_queue_refresh()
@export var tag_tilt_degrees := -9.0:
	set(value):
		tag_tilt_degrees = value
		_queue_refresh()
@export var pointer_size := 50.0:
	set(value):
		pointer_size = value
		_queue_refresh()
@export_group("")

## Put your own thumbnail here (a live map preview, say); it fills the slot.
var thumbnail_slot: Control
var title_label: Label
var subtitle_label: Label
var locked_label: Label
var tag_label: Label
## The parts by state: the check (cleared), the lock column (locked), the tag and the pointer (current).
var check: Control
var lock: Control
var play_tag: Control
var pointer: TextureRect
var selection_ring: Panel

var _margin: MarginContainer
var _row: HBoxContainer
var _well: Panel
var _cover: GoCoverImage
var _text_box: VBoxContainer
var _subtitle_row: HBoxContainer
var _person: Control
var _lock_box: VBoxContainer
var _lock_art: Control
var _tag_art: Control
var _built := false
var _queued := false
## The card set `disabled` because the tile is locked (it was not disabled already).
var _lock_disabled := false


func _init() -> void:
	name = "LevelCard"
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build()
	_built = true
	_refresh()


## 🔑 Watched on every entry, not once in `_ready` — `reparent()` takes the node out and back, and a watch set only in
##    `_ready` was dropped by the first `_exit_tree` for good. Back in the tree, it catches up with the look.
func _enter_tree() -> void:
	GoUi.watch(_on_ui_changed)
	if is_node_ready(): _on_ui_changed()


func _ready() -> void:
	_refresh()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## Applies the pending changes now instead of at the end of the frame.
func refresh() -> void:
	_refresh()


static func make(text: String, sub := "", level_state := State.OPEN) -> GoLevelCard:
	var node := GoLevelCard.new()
	node.title = text
	node.subtitle = sub
	node.state = level_state
	return node


## What the tile says: the title, the subtitle and LOCKED when locked — for tests, tooltips and screen readers.
func summary() -> String:
	var parts := PackedStringArray([title])
	if not subtitle.is_empty(): parts.append(subtitle)
	if state == State.LOCKED: parts.append(locked_text)
	return "\n".join(parts)


## The theme variation the tile wears now — the state's own, or the fallback when the theme lacks it.
func card_variation() -> StringName:
	var wanted := VAR_LOCKED if state == State.LOCKED else (VAR_CURRENT if state == State.CURRENT else VAR_CARD)
	if _theme_has(wanted): return wanted
	return GoTheme.VAR_PRIMARY_BUTTON if state == State.CURRENT else GoTheme.VAR_BUTTON


## The text colour on the tile's face.
func ink() -> Color:
	match state:
		State.CURRENT: return GoUi.theme_color(&"font_color", GoTheme.VAR_PRIMARY_BUTTON, Color.WHITE)
		State.LOCKED:
			# The game's grey locked card reads in white; a plain theme's disabled button in its own colour.
			if _theme_has(VAR_LOCKED): return Color.WHITE
			return GoUi.theme_color(&"font_disabled_color", GoTheme.VAR_BUTTON, GoUi.color(GoTheme.MUTED))
	return GoUi.color(GoTheme.TEXT)


## The outline round light text — the theme's button outline colour (ink in arcade_light). Transparent: none.
func outline_ink() -> Color:
	var look := GoUi.theme()
	for type in [card_variation(), VAR_TITLE, GoTheme.VAR_BUTTON]:
		if look != null and GoTheme.has_color_in_chain(look, &"font_outline_color", type):
			var found := GoTheme.color_in_chain(look, &"font_outline_color", type)
			if found.a > 0.0: return found
	return Color.TRANSPARENT


static func _theme_has(type: StringName) -> bool:
	var look := GoUi.theme()
	if look == null: return false
	return look.get_type_list().has(type) or not String(look.get_type_variation_base(type)).is_empty()


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.name = "Margin"
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin, false, Node.INTERNAL_MODE_FRONT)
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The ring sits under the badges (check, tag, pointer), which are added after it.
	selection_ring = Panel.new()
	selection_ring.name = "SelectionRing"
	selection_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection_ring, false, Node.INTERNAL_MODE_FRONT)
	selection_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_row)

	thumbnail_slot = Control.new()
	thumbnail_slot.name = "Thumbnail"
	thumbnail_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(thumbnail_slot)
	_well = Panel.new()
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_slot.add_child(_well, false, Node.INTERNAL_MODE_FRONT)
	_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover = GoCoverImage.new()
	thumbnail_slot.add_child(_cover, false, Node.INTERNAL_MODE_FRONT)
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)

	_text_box = VBoxContainer.new()
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_text_box)
	title_label = _text("Title")
	_text_box.add_child(title_label)
	_subtitle_row = HBoxContainer.new()
	_subtitle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_child(_subtitle_row)
	_person = Control.new()
	_person.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_person.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_subtitle_row.add_child(_person)
	subtitle_label = _text("Subtitle")
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_row.add_child(subtitle_label)

	_lock_box = VBoxContainer.new()
	_lock_box.name = "Lock"
	_lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_child(_lock_box)
	lock = _lock_box
	_lock_art = Control.new()
	_lock_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lock_box.add_child(_lock_art)
	locked_label = _text("Locked")
	locked_label.clip_text = false
	locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_box.add_child(locked_label)

	check = Control.new()
	check.name = "Check"
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(check, false, Node.INTERNAL_MODE_FRONT)
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pointer = TextureRect.new()
	pointer.name = "Pointer"
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pointer, false, Node.INTERNAL_MODE_FRONT)
	pointer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	play_tag = Control.new()
	play_tag.name = "PlayTag"
	play_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play_tag, false, Node.INTERNAL_MODE_FRONT)
	play_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tag_art = Control.new()
	_tag_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_tag.add_child(_tag_art)
	_tag_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag_label = _text("Tag")
	tag_label.clip_text = false
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The title look's negative line spacing would clip a lone line.
	tag_label.add_theme_constant_override(&"line_spacing", 0)
	play_tag.add_child(tag_label)
	tag_label.set_anchors_preset(Control.PRESET_FULL_RECT)


func _text(part: String) -> Label:
	var label := Label.new()
	label.name = part
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	return GoStyle.one_line(label)


## Puts [param art] in [param holder] filling it, else the icon set's [param icon] (on a sticker when [param plate]
## has colour). Neither: the holder stays empty.
func _fill(holder: Control, art: Texture2D, icon: StringName, side: float, plate := Color.TRANSPARENT,
		icon_ink := Color.TRANSPARENT) -> void:
	for child in holder.get_children(): child.free()
	if art != null:
		var picture := TextureRect.new()
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		return
	if icon.is_empty() or not GoUi.icons().has_icon(icon): return
	var ink_color := icon_ink
	if plate.a > 0.0:
		var face := Panel.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_theme_stylebox_override(&"panel", GoUi.skin().sticker_box(plate))
		holder.add_child(face)
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		ink_color = GoSkin.readable_on(GoUi.color(GoTheme.ON_ACCENT), Color(plate, 1.0))
	var px := maxi(1, roundi(side * (0.6 if plate.a > 0.0 else 1.0)))
	var glyph := GoUi.icons().node(icon, px, ink_color)
	holder.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	glyph.offset_left = -px * 0.5
	glyph.offset_right = px * 0.5
	glyph.offset_top = -px * 0.5
	glyph.offset_bottom = px * 0.5


func _art(given: Texture2D, part: StringName) -> Texture2D:
	return given if given != null else GoUi.skin().widget_art(part)


## Asks for one rebuild at the end of the frame, however many properties change before it.
func _queue_refresh() -> void:
	if not _built or _queued: return
	_queued = true
	_flush.call_deferred()


func _flush() -> void:
	if _queued: _refresh()


func _refresh() -> void:
	if not _built: return
	_queued = false
	var k := scale_factor
	var locked := state == State.LOCKED
	var current := state == State.CURRENT
	if locked and not disabled:
		disabled = true
		_lock_disabled = true
	elif not locked and _lock_disabled:
		disabled = false
		_lock_disabled = false
	theme_type_variation = card_variation()
	text = ""
	accessibility_name = summary().replace("\n", ", ")
	custom_minimum_size = Vector2(card_size.x * k, maxf(card_size.y * k, float(GoUi.config.min_touch_size)))

	_margin.add_theme_constant_override(&"margin_left", roundi(thumbnail_inset * k))
	for side in [&"margin_right", &"margin_top", &"margin_bottom"]:
		_margin.add_theme_constant_override(side, roundi(card_padding * k))
	_row.add_theme_constant_override(&"separation", roundi(row_gap * k))
	_text_box.add_theme_constant_override(&"separation", roundi(4.0 * k))
	_subtitle_row.add_theme_constant_override(&"separation", roundi(text_gap * k))

	# The thumbnail, in the theme's well when it has one.
	var thumb := thumbnail_size * k
	thumbnail_slot.custom_minimum_size = Vector2(thumb, thumb)
	var well: StyleBox = null
	if _theme_has(VAR_WELL): well = GoUi.theme().get_stylebox(&"panel", VAR_WELL)
	_well.visible = well != null
	if well != null: _well.add_theme_stylebox_override(&"panel", well)
	var inset := well_padding * k if well != null else 0.0
	_cover.offset_left = inset
	_cover.offset_top = inset
	_cover.offset_right = -inset
	_cover.offset_bottom = -inset
	_cover.texture = thumbnail
	_cover.focus = thumbnail_focus
	_cover.visible = thumbnail != null
	_cover.modulate = LOCKED_TINT if locked else Color.WHITE

	# Texts: the title look when the theme has it.
	var label_look := VAR_TITLE if _theme_has(VAR_TITLE) else &""
	for label in [title_label, subtitle_label, locked_label, tag_label]:
		label.theme_type_variation = label_look
	title_label.text = title
	subtitle_label.text = subtitle
	locked_label.text = locked_text
	tag_label.text = play_text
	_subtitle_row.visible = not subtitle.is_empty()

	var face_ink := ink()
	var edge := outline_ink()
	var light := face_ink.get_luminance() > 0.5 and edge.a > 0.0
	for pair in [[title_label, 4], [subtitle_label, 3], [locked_label, 3]]:
		var label: Label = pair[0]
		label.add_theme_color_override(&"font_color", face_ink)
		label.add_theme_color_override(&"font_outline_color", edge)
		label.add_theme_constant_override(&"outline_size", int(pair[1]) if light else 0)

	# The state parts.
	_person.custom_minimum_size = Vector2.ONE * person_size * k
	_fill(_person, _art(person_texture, &"person"), GoIconSet.USER, person_size * k, Color.TRANSPARENT, face_ink)

	_lock_box.visible = locked
	locked_label.visible = locked
	_lock_art.custom_minimum_size = Vector2.ONE * lock_size * k
	if locked: _fill(_lock_art, _art(lock_texture, &"lock"), GoIconSet.LOCK, lock_size * k, Color.TRANSPARENT, face_ink)

	var check_side := check_size * k
	check.visible = state == State.CLEARED
	check.offset_left = check_side * 0.28 - check_side
	check.offset_right = check_side * 0.28
	check.offset_top = -check_side * 0.28
	check.offset_bottom = check_side * 0.72
	if check.visible:
		_fill(check, _art(check_texture, &"check"), GoIconSet.CHECK, check_side,
				Color(GoUi.color(GoTheme.SUCCESS_FILL), 1.0))

	var tag := tag_size * k
	play_tag.visible = current
	play_tag.offset_left = -tag.x - 8.0 * k
	play_tag.offset_right = -8.0 * k
	play_tag.offset_top = -tag.y * 0.55
	play_tag.offset_bottom = tag.y * 0.45
	play_tag.pivot_offset = tag * 0.5
	play_tag.rotation_degrees = tag_tilt_degrees
	if current: _dress_tag(tag)

	var pointer_side := pointer_size * k
	pointer.texture = _art(pointer_texture, &"pointer")
	pointer.visible = current and pointer.texture != null
	pointer.offset_left = -pointer_side - 4.0 * k
	pointer.offset_right = -4.0 * k
	pointer.offset_top = -pointer_side * 0.7
	pointer.offset_bottom = pointer_side * 0.3

	selection_ring.visible = selected
	selection_ring.add_theme_stylebox_override(&"panel", GoUi.skin().selection_ring_box())
	_fit_texts()


func _dress_tag(tag: Vector2) -> void:
	var art := _art(play_tag_texture, &"play_tag")
	for child in _tag_art.get_children(): child.free()
	var tag_px := maxi(min_font_size, roundi(tag_font_size * scale_factor))
	if art != null:
		var picture := TextureRect.new()
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag_art.add_child(picture)
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		var edge := outline_ink()
		tag_label.add_theme_color_override(&"font_color", Color.WHITE)
		tag_label.add_theme_color_override(&"font_outline_color", edge)
		tag_label.add_theme_constant_override(&"outline_size", 4 if edge.a > 0.0 else 0)
	else:
		var plate := Color(GoUi.color(GoTheme.WARNING_FILL), 1.0)
		var face := Panel.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_theme_stylebox_override(&"panel", GoUi.skin().sticker_box(plate))
		_tag_art.add_child(face)
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		GoUi.skin().dress_sticker(tag_label, plate)
	var font := tag_label.get_theme_font(&"font") if tag_label.is_inside_tree() else null
	tag_label.add_theme_font_size_override(&"font_size",
			GoStyle.fit_font_size(PackedStringArray([atr(play_text)]), tag_px, tag.x * 0.8, font))


## Shrinks the texts so the longest translation fits beside the thumbnail (and the lock column when locked). The lock
## column is at least `right_slot` wide and grows to hold its caption, so a long LOCKED is never clipped.
func _fit_texts() -> void:
	var k := scale_factor
	# The labels show the translations, so those are what must fit (the keys may be far shorter).
	var shown_title := atr(title)
	var shown_subtitle := atr(subtitle)
	var shown_locked := atr(locked_text)
	var font := title_label.get_theme_font(&"font") if title_label.is_inside_tree() else _label_font()
	var slot := 0.0
	var gaps := row_gap
	if state == State.LOCKED:
		var lock_base := maxi(min_font_size, roundi(locked_font_size * k))
		var lock_px := maxi(min_font_size, GoStyle.fit_font_size(PackedStringArray([shown_locked]), lock_base,
				right_slot * k, font))
		locked_label.add_theme_font_size_override(&"font_size", lock_px)
		slot = maxf(right_slot * k, GoStyle.row_width(font, PackedStringArray([shown_locked]), lock_px))
		_lock_box.custom_minimum_size = Vector2(slot, 0.0)
		gaps *= 2.0
	var room := (card_size.x - thumbnail_inset - card_padding - thumbnail_size - gaps) * k - slot - fit_slack
	var title_base := maxi(9, roundi(title_font_size * k))
	title_label.add_theme_font_size_override(&"font_size",
			GoStyle.fit_font_size(PackedStringArray([shown_title]), title_base, room, font))
	var sub_base := maxi(min_font_size, roundi(subtitle_font_size * k))
	var icon_room := room - (person_size + text_gap) * k
	subtitle_label.add_theme_font_size_override(&"font_size",
			GoStyle.fit_font_size(PackedStringArray([shown_subtitle]), sub_base, icon_room, font))


func _label_font() -> Font:
	var look := GoUi.theme()
	if look != null and _theme_has(VAR_TITLE) and look.has_font(&"font", VAR_TITLE): return look.get_font(&"font", VAR_TITLE)
	if look != null and look.default_font != null: return look.default_font
	return ThemeDB.fallback_font


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _built: _fit_texts()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _built and is_inside_tree(): _fit_texts()


func _on_ui_changed() -> void:
	_queue_refresh()
