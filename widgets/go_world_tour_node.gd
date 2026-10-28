## One selectable stop on a world-tour map. Put a picture or live preview in `thumbnail_slot`;
## the skin supplies the numbered badge and the caption plate. The caller supplies translated text.
@tool
class_name GoWorldTourNode
extends Button

var thumbnail_slot: Control
var number_label: Label
var title_label: Label
var selected := false
var title := ""
var number := 1
var title_base_size := 8
var _badge: Panel
var _badge_art: TextureRect
var _caption: Panel
var _ring: Panel


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	thumbnail_slot = Control.new()
	thumbnail_slot.name = "Thumbnail"
	thumbnail_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_slot.clip_contents = false
	add_child(thumbnail_slot)
	thumbnail_slot.child_entered_tree.connect(_place_thumbnail)
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_badge = Panel.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_badge_art = TextureRect.new()
	_badge_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(_badge_art)
	_badge_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number_label = _label("Number", &"GoWorldTourTitle")
	_badge.add_child(number_label)
	number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = Panel.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	title_label = _label("Caption", &"GoWorldTourCaption")
	_caption.add_child(title_label)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	focus_entered.connect(_sync_focus)
	focus_exited.connect(_sync_focus)


func _ready() -> void:
	refresh()


## Update the caller-owned stage data; a locked node is inert even if `pressed` is emitted from code.
func configure(stage_number: int, caption: String, locked: bool, is_selected: bool) -> void:
	number = stage_number
	title = caption
	disabled = locked
	selected = is_selected and not locked
	refresh()


func refresh() -> void:
	accessibility_name = "%d, %s" % [number, title]
	number_label.text = str(number)
	title_label.text = title
	_badge_art.texture = GoUi.skin().widget_art(&"world_tour_badge_red" if selected else &"world_tour_badge_blue")
	_badge_art.visible = _badge_art.texture != null
	_badge.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new() if _badge_art.visible else GoUi.skin().badge_box(GoUi.color(GoTheme.ACCENT)))
	_caption.add_theme_stylebox_override(&"panel", GoUi.skin().world_tour_caption_box())
	_ring.add_theme_stylebox_override(&"panel", GoUi.skin().selection_ring_box())
	title_label.add_theme_color_override(&"font_color", GoUi.color(GoTheme.TEXT))
	_sync_focus()
	thumbnail_slot.modulate = Color(0.62, 0.64, 0.7) if disabled else Color.WHITE
	for child in thumbnail_slot.get_children():
		if child.has_method(&"set_selected"): child.set_selected(selected)
	_layout()


func _layout() -> void:
	if thumbnail_slot == null or size.x <= 0.0 or size.y <= 0.0: return
	# Pictures may spread beyond the touch target, like scenery islands on the world map. Their controls ignore input;
	# the button keeps its own bounds so adjacent islands remain independently selectable.
	var stage_scales := [0.91, 0.92, 0.96, 0.94, 1.00, 0.96, 0.91, 0.98, 1.04]
	var art_scale: float = stage_scales[clampi(number - 1, 0, stage_scales.size() - 1)]
	if selected: art_scale = maxf(art_scale, 1.10)
	thumbnail_slot.size = Vector2(size.x * art_scale, size.y * 0.95 * art_scale)
	thumbnail_slot.position = Vector2((size.x - thumbnail_slot.size.x) * 0.5, (size.y * 0.85 - thumbnail_slot.size.y) * 0.5)
	var side := minf(size.x * 0.34, size.y * 0.38)
	_badge.position = Vector2((size.x - side) * 0.5, size.y * 0.64 - side * 0.5)
	_badge.size = Vector2.ONE * side
	_ring.position = _badge.position - Vector2.ONE * 3.0
	_ring.size = _badge.size + Vector2.ONE * 6.0
	var caption_share := clampf(title.length() * 0.065, 0.50, 0.85)
	var caption_size := Vector2(size.x * caption_share, size.y * 0.18)
	_caption.position = Vector2((size.x - caption_size.x) * 0.5, size.y - caption_size.y)
	_caption.size = caption_size
	var number_size := maxi(8, roundi(side * 0.52))
	number_label.add_theme_font_size_override(&"font_size", number_size)
	# A geometry-based design size, not a text-based pre-shrink: GoStyle alone decides the fit within its floor.
	var base := maxi(8, roundi(caption_size.y * 0.66))
	var font := title_label.get_theme_font(&"font")
	title_base_size = base
	title_label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(PackedStringArray([title]), base, caption_size.x * 0.85, font))


func _place_thumbnail(child: Node) -> void:
	if child is Control:
		(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if child.has_method(&"set_selected"): child.set_selected(selected)


func _sync_focus() -> void:
	_ring.visible = has_focus() or (selected and not _badge_art.visible)


func _label(part: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = part
	label.theme_type_variation = variation
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
