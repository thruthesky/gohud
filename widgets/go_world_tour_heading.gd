## The detail card's blue stage pill over a pink ribbon. The caller supplies localized captions and sizing.
@tool
class_name GoWorldTourHeading
extends Control

var stage_label: Label
var title_label: Label
var _title := ""
## Base sizes selected for the available space before the theme's fit floor is applied.
var title_base_size := 8
var stage_base_size := 8
var _stage_art: TextureRect
var _ribbon_art: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon_art = _picture()
	add_child(_ribbon_art)
	title_label = _label()
	add_child(title_label)
	_stage_art = _picture()
	add_child(_stage_art)
	stage_label = _label()
	add_child(stage_label)
	resized.connect(_layout)


func _ready() -> void:
	refresh()


func configure(stage_caption: String, title: String) -> void:
	stage_label.text = stage_caption
	_title = title
	title_label.text = title
	refresh()


func refresh() -> void:
	_stage_art.texture = GoUi.skin().widget_art(&"world_tour_heading_blue")
	_ribbon_art.texture = GoUi.skin().widget_art(&"world_tour_ribbon_pink")
	_layout()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	_ribbon_art.position = Vector2(0.0, size.y * 0.35)
	_ribbon_art.size = Vector2(size.x, size.y * 0.65)
	title_label.position = Vector2(size.x * 0.09, size.y * 0.38)
	title_label.size = Vector2(size.x * 0.82, size.y * 0.5)
	_stage_art.position = Vector2(size.x * 0.21, 0.0)
	_stage_art.size = Vector2(size.x * 0.58, size.y * 0.44)
	stage_label.position = _stage_art.position
	var stage_size := _stage_art.size * Vector2(1.0, 0.9)
	# Fit before applying the rect: a prior large font otherwise forces Label's minimum size to grow it.
	stage_base_size = _fit(stage_label, stage_size.x * 0.82, stage_size.y * 0.62, stage_size.y)
	stage_label.size = stage_size
	var title_height := minf(title_label.size.y * 0.68, title_label.size.x / 7.0)
	var title_font := title_label.get_theme_font(&"font")
	var title_base := maxi(8, roundi(title_height))
	title_label.text = _wrap_if_needed(_title, title_font, title_label.size.x, title_base)
	if title_label.text.contains("\n"): title_height = minf(title_height * 0.45, title_label.size.y * 0.29)
	title_base_size = _fit(title_label, title_label.size.x, title_height)


func _fit(label: Label, width: float, height: float, max_height := INF) -> int:
	# The design base comes from the ribbon's geometry; GoStyle alone shrinks it down to the configured floor.
	var base := maxi(8, roundi(height))
	var font := label.get_theme_font(&"font")
	# Baloo's rounded letters have a taller line box than their nominal font size. Keep the base inside
	# the actual ribbon before width-fitting, so the label cannot expand below its art.
	while base > 8 and font.get_height(base) > max_height:
		base -= 1
	label.add_theme_font_size_override(&"font_size", GoStyle.fit_font_size(PackedStringArray([label.text]), base, width, font))
	return base


## Long translations use two lines rather than violating the floor. Prefer splitting at a word boundary; scripts
## without spaces can split between characters. The original caption is kept in `_title` for the next resize.
func _wrap_if_needed(text: String, font: Font, width: float, base: int) -> String:
	if text.is_empty() or GoStyle.row_width(font, PackedStringArray([text]), GoStyle.fit_floor(base)) <= width:
		return text
	var best := ""
	var best_width := INF
	var spaces := text.contains(" ")
	for index in range(1, text.length()):
		if spaces and text[index] != " ": continue
		var left := text.substr(0, index).strip_edges()
		var right := text.substr(index + (1 if spaces else 0)).strip_edges()
		if left.is_empty() or right.is_empty(): continue
		var measure := maxf(GoStyle.row_width(font, PackedStringArray([left]), base), GoStyle.row_width(font, PackedStringArray([right]), base))
		if measure < best_width:
			best_width = measure
			best = left + "\n" + right
	return best if not best.is_empty() else text


func _picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	return picture


func _label() -> Label:
	var label := Label.new()
	label.theme_type_variation = &"GoWorldTourTitle"
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
