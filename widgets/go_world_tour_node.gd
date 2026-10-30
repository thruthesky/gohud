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
## Set by the map: the badge centre (local) and diameter. The island art then fills the node's own rect.
var badge_center := Vector2.INF
var badge_side := 0.0
## Off: no numbered badge; the caption alone sits at the foot of the island, and focus rings the caption.
var show_number := true:
	set(value):
		show_number = value
		if _badge != null: refresh()
## The stars earned on this stop, a small row centred just above the caption; under 0 (the default) shows none.
var stars := -1:
	set(value):
		stars = value
		if _star_row != null: refresh()
## A star's side as a share of the caption plate's height.
const STAR_SHARE := 0.8
var _badge: Panel
var _badge_art: TextureRect
var _caption: Panel
var _ring: Panel
var _star_row: GoStarRow
## Holds the badge, caption and focus ring. A map moves it into its own label layer, drawn after every island, so the
## labels sit above the art without a z_index (which would also lift them above dialogs opened over the map).
var labels: Control


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
	labels = Control.new()
	labels.name = "Labels"
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(labels)
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(_ring)
	_badge = Panel.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(_badge)
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
	labels.add_child(_caption)
	title_label = _label("Caption", &"GoWorldTourCaption")
	_caption.add_child(title_label)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_star_row = GoStarRow.make(0, 3)
	_star_row.visible = false
	labels.add_child(_star_row)
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
	_star_row.visible = stars >= 0
	_star_row.stars = maxi(stars, 0)
	_sync_focus()
	# A skin with a locked picture already shows the lock; others dim the stage's own picture.
	var dim := disabled and GoUi.skin().world_tour_locked_picture() == null
	thumbnail_slot.modulate = Color(0.62, 0.64, 0.7) if dim else Color.WHITE
	for child in thumbnail_slot.get_children():
		if child.has_method(&"set_selected"): child.set_selected(selected)
		if child is CanvasItem: (child as CanvasItem).queue_redraw()
	_layout()


func _layout() -> void:
	if thumbnail_slot == null or size.x <= 0.0 or size.y <= 0.0: return
	# Pictures may spread beyond the touch target, like scenery islands on the world map. Their controls ignore input;
	# the button keeps its own bounds so adjacent islands remain independently selectable.
	if badge_center != Vector2.INF:
		_layout_on_map()
		return
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
	_place_stars()


func _layout_on_map() -> void:
	# The island's painted rect is a little larger than its touch target, as the reference art overhangs it.
	thumbnail_slot.size = size * 1.06
	thumbnail_slot.position = (size - thumbnail_slot.size) * 0.5
	var side := badge_side
	_badge.size = Vector2.ONE * side
	_badge.position = badge_center - _badge.size * 0.5
	_ring.position = _badge.position - Vector2.ONE * 3.0
	_ring.size = _badge.size + Vector2.ONE * 6.0
	number_label.add_theme_font_size_override(&"font_size", maxi(8, roundi(side * 0.62)))
	var caption_h := side * 0.5
	var base := maxi(8, roundi(caption_h * 0.7))
	var font := title_label.get_theme_font(&"font")
	var text_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x if font != null else 0.0
	var caption_w := clampf(text_w + caption_h * 1.2, side * 1.45, side * 2.4)
	_caption.size = Vector2(caption_w, caption_h)
	_caption.position = Vector2(badge_center.x - caption_w * 0.5, badge_center.y + side * 0.6 - caption_h * 0.5)
	if not show_number: # the name alone, centred under the island and overlapping its foot
		_caption.position = Vector2((size.x - caption_w) * 0.5, thumbnail_slot.position.y + thumbnail_slot.size.y - caption_h * 1.15)
		_ring.position = _caption.position - Vector2.ONE * 3.0
		_ring.size = _caption.size + Vector2.ONE * 6.0
	title_base_size = base
	title_label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(PackedStringArray([title]), base, caption_w - caption_h * 0.8, font))
	_place_stars()


## The star row sits centred on the caption, its foot just clear of the plate's top edge.
func _place_stars() -> void:
	if not _star_row.visible: return
	var side := _caption.size.y * STAR_SHARE
	_star_row.star_size = side
	_star_row.gap = side * 0.08
	_star_row.size = _star_row.get_combined_minimum_size()
	_star_row.position = Vector2(_caption.position.x + (_caption.size.x - _star_row.size.x) * 0.5,
			_caption.position.y - _star_row.size.y - side * 0.06)


func _place_thumbnail(child: Node) -> void:
	if child is Control:
		(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if child.has_method(&"set_selected"): child.set_selected(selected)


func _sync_focus() -> void:
	_badge.visible = show_number
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
