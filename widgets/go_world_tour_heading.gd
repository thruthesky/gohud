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
var _stage_layout_pending := false
## The title's band (shares of the heading) and the share of the band's height its base font size takes.
const TITLE_BAND := Rect2(0.15, 0.47, 0.70, 0.35)
const TITLE_FILL := 1.0
const TITLE_TWO_LINE_FILL := 0.55
## Line pitch of a two-line title as a share of its font size.
const TITLE_LINE_PITCH := 0.95


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
	stage_label.minimum_size_changed.connect(_queue_stage_layout)
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
	# The ribbon's arched top rises behind the badge; its tails hang a little below the heading.
	_ribbon_art.position = Vector2(0.0, size.y * 0.28)
	_ribbon_art.size = Vector2(size.x, size.y * 0.76)
	_stage_art.position = Vector2(size.x * 0.248, 0.0)
	_stage_art.size = Vector2(size.x * 0.504, size.y * 0.40)
	stage_label.position = _stage_art.position
	var stage_size := _stage_art.size * Vector2(1.0, 0.9)
	var outline := clampi(roundi(_stage_art.size.y * 0.13), 1, 12)
	if not stage_label.has_theme_constant_override(&"outline_size") or stage_label.get_theme_constant(&"outline_size") != outline:
		stage_label.add_theme_constant_override(&"outline_size", outline)
	# Fit before applying the rect: a prior large font otherwise forces Label's minimum size to grow it.
	# Baloo's line box is far taller than its capitals: the label may overhang the badge's art, as the title does.
	stage_base_size = _fit(stage_label, stage_size.x * 0.8, stage_size.y * 0.6, stage_size.y * 1.35)
	var line_h := maxf(stage_size.y, stage_label.get_theme_font(&"font").get_height(stage_label.get_theme_font_size(&"font_size")))
	stage_label.position.y = (stage_size.y - line_h) * 0.5
	stage_label.size = Vector2(stage_size.x, line_h)
	_layout_title()


## The title stays inside the ribbon's flat centre band — clear of the arched edges and the folded tails, with padding
## on every side. Too long for the band: GoStyle shrinks it (never below the fit floor), then it takes two lines.
func _layout_title() -> void:
	var band := title_band()
	var font := title_label.get_theme_font(&"font")
	var outline := title_label.get_theme_constant(&"outline_size")
	var width := maxf(1.0, band.size.x - outline)
	# Baloo's capitals stand about 0.7 em tall: this base fills about three quarters of the band with lettering.
	var base := maxi(8, roundi(band.size.y * TITLE_FILL))
	title_label.text = _wrap_if_needed(_title, font, width, base)
	var lines := title_label.text.count("\n") + 1
	# Two lines share the band: each gets about half its height (caps plus a small gap between the lines).
	if lines > 1: base = maxi(8, roundi(band.size.y * TITLE_TWO_LINE_FILL))
	var fitted := GoStyle.fit_font_size(PackedStringArray([title_label.text]), base, width, font)
	if not title_label.has_theme_font_size_override(&"font_size") or title_label.get_theme_font_size(&"font_size") != fitted:
		title_label.add_theme_font_size_override(&"font_size", fitted)
	# Baloo's line box is much taller than its capitals: pull a second line up so both stay inside the band.
	var spacing := 0 if lines == 1 else roundi(fitted * TITLE_LINE_PITCH - font.get_height(fitted))
	title_label.add_theme_constant_override(&"line_spacing", spacing)
	title_base_size = base
	# The line box is taller than the lettering: centre it on the band rather than letting it grow the band.
	var block_h := font.get_height(fitted) * lines + spacing * (lines - 1)
	title_label.position = Vector2(band.position.x, band.get_center().y - block_h * 0.5)
	title_label.size = Vector2(band.size.x, block_h)


## The ribbon's flat centre band in the heading's space: inside the body's slanted ends and its arched top and foot.
func title_band() -> Rect2:
	return Rect2(size.x * TITLE_BAND.position.x, size.y * TITLE_BAND.position.y,
		size.x * TITLE_BAND.size.x, size.y * TITLE_BAND.size.y)


func _fit(label: Label, width: float, height: float, max_height := INF) -> int:
	# The design base comes from the ribbon's geometry; GoStyle alone shrinks it down to the configured floor.
	var base := maxi(8, roundi(height))
	var font := label.get_theme_font(&"font")
	# Baloo's rounded letters have a taller line box than their nominal font size. Keep the base inside
	# the actual ribbon before width-fitting, so the label cannot expand below its art.
	var outline := label.get_theme_constant(&"outline_size")
	while base > 8 and font.get_height(base) + 2.0 * outline > max_height:
		base -= 1
	var fitted := GoStyle.fit_font_size(PackedStringArray([label.text]), base, width, font)
	if not label.has_theme_font_size_override(&"font_size") or label.get_theme_font_size(&"font_size") != fitted:
		label.add_theme_font_size_override(&"font_size", fitted)
	return base


func _queue_stage_layout() -> void:
	if _stage_layout_pending: return
	_stage_layout_pending = true
	_finish_stage_layout.call_deferred()


func _finish_stage_layout() -> void:
	_stage_layout_pending = false
	_layout()


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
