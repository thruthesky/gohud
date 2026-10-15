## 🎮 **A match-HUD card** — one board of a party game's top row: an icon, then a gold name banner over a few bars (the
## player card), a title beside a count (the opponents card), a caption over a big value (the clock), or a gauge whose
## rim lights when an ability is ready (a cooldown readout).
##
## ```gdscript
## var player := GoHudCard.make(GoUi.skin().widget_art(&"avatar_head"), 56.0)
## player.banner_text = "YOU"
## var power := player.add_bar("POWER", Color("#1fb5f0"), Color("#6ff0ff"), GoUi.skin().widget_art(&"bolt"))
## power.set_values(30, 100, false)
##
## var foes := GoHudCard.make(GoUi.skin().widget_art(&"opponents_badge"))
## foes.layout = GoHudCard.Layout.INLINE
## foes.title = "OPPONENTS"
## foes.value = "7"
##
## var clock := GoHudCard.make(GoUi.skin().widget_art(&"stopwatch"))
## clock.title = "TIME"
## clock.set_clock(seconds_left, seconds_left <= 30)   # 🛑 the caller (the server's clock) decides; the card shows it
##
## var repulse := GoHudCard.new()
## repulse.gauge = true
## repulse.title = "REPULSE"
## repulse.value = "READY"
## repulse.set_lit(true)                              # lit rim, full opacity, a pop — or dimmed while cooling
## ```
##
## The board is the theme's `GoHudPanel` (arcade_light: the game's white board with the blue rim) and the banner its
## `GoBannerGold`; a gauge is `GoSkin.hud_gauge_box(lit)`. A theme without them falls back to `PanelContainer`.
## 🛑 Display only — every text, value and state comes from the caller. Nothing here counts, times or decides.
## 🔑 Place it with `GoHudAnchor`, or anchor it yourself; give it a width with `custom_minimum_size.x`.
@tool
class_name GoHudCard
extends PanelContainer

## How the title and the value sit: one over the other in a column (a clock), or side by side in the row (a count).
enum Layout { STACKED, INLINE }

const VAR_PANEL := &"GoHudPanel"
const VAR_BANNER := &"GoBannerGold"
## The caption over a stacked value is the label ink at this opacity.
const CAPTION_ALPHA := 0.75
## A gauge that is not lit shows at this opacity.
const DIM_ALPHA := 0.55
## The pop when a gauge lights: up to this scale, then back.
const POP_SCALE := 1.15
const POP_UP := 0.14
const POP_DOWN := 0.21

## The picture at the start of the row. null hides it.
@export var icon: Texture2D:
	set(value):
		icon = value
		_apply()

## The icon's square size (dp).
@export_range(8.0, 160.0, 1.0) var icon_size := 36.0:
	set(value):
		icon_size = value
		_apply()

## true: the icon is shrunk to its size and centred on whole pixels. false: it stretches to the row's height and
## draws itself centred in it — on a half pixel when the row is an odd number taller (the game's clock and badge).
@export var icon_snap := true:
	set(next):
		icon_snap = next
		_apply()

## The room between the icon and what follows (dp).
@export_range(0, 48) var gap := 8:
	set(value):
		gap = value
		_apply()

## A gold name banner at the top of the column. Empty hides it.
@export var banner_text := "":
	set(value):
		banner_text = value
		_apply()

## The banner's font size.
@export_range(8, 64) var banner_size := 16:
	set(value):
		banner_size = value
		_apply()

## The caption ("TIME", "OPPONENTS"). Empty hides it.
@export var title := "":
	set(value):
		title = value
		_apply()

## The big value ("01:23", "7", "READY"). Empty hides it.
@export var value := "":
	set(next):
		value = next
		_apply()

@export var layout := Layout.STACKED:
	set(next):
		layout = next
		_apply()

## The caption's size. -1: 12 stacked, 19 inline.
@export_range(-1, 64) var title_size := -1:
	set(next):
		title_size = next
		_apply()

## The value's size. -1: 24 stacked, 19 inline.
@export_range(-1, 96) var value_size := -1:
	set(next):
		value_size = next
		_apply()

## The value's colour. Transparent: the theme's label ink.
@export var value_ink := Color.TRANSPARENT:
	set(next):
		value_ink = next
		_apply()

## The clear space inside the board's rim (dp) — a phone HUD packs tighter. -1: the theme's.
@export var padding := -1.0:
	set(next):
		padding = next
		_apply()

## The clear space inside the banner's rim (dp). -1: the theme's.
@export var banner_padding := -1.0:
	set(next):
		banner_padding = next
		_apply()

## A gauge: the board is `GoSkin.hud_gauge_box(lit)` and dims while not lit (`set_lit`).
@export var gauge := false:
	set(next):
		gauge = next
		_apply()

## The warning colour `set_clock` paints a clock in. Transparent: `GoSkin.hud_alert_ink()`.
@export var warn_ink := Color.TRANSPARENT:
	set(next):
		warn_ink = next
		_apply()

var _lit := true
var _warn := false
var _row: HBoxContainer
var _icon: TextureRect
var _body: VBoxContainer
var _banner: PanelContainer
var _banner_label: Label
var _bars: VBoxContainer
var _title_label: Label
var _value_label: Label
var _pop: Tween


func _init() -> void:
	name = "HudCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = VAR_PANEL
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_icon)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 0)
	_row.add_child(_body)
	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.theme_type_variation = VAR_BANNER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_body.add_child(_banner)
	_banner_label = _make_label("BannerLabel")
	_banner.add_child(_banner_label)
	_bars = VBoxContainer.new()
	_bars.name = "Bars"
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_theme_constant_override(&"separation", 0)
	_body.add_child(_bars)
	_title_label = _make_label("Title")
	_value_label = _make_label("Value")
	# 🛑 A clock or a count reads left to right in every language.
	_value_label.text_direction = Control.TEXT_DIRECTION_LTR
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	_apply()


func _ready() -> void:
	theme = GoUi.theme()
	GoUi.watch(_on_ui_changed)
	_apply()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	_apply()


## A card with [param picture] at [param picture_size] dp.
static func make(picture: Texture2D = null, picture_size := 36.0) -> GoHudCard:
	var card := GoHudCard.new()
	card.icon = picture
	card.icon_size = picture_size
	return card


## Adds a HUD bar under the banner (`GoBar` laid out as the painted HUD's: 14 dp, an 11 dp name, no readout) and
## returns it — set its value with `set_values`.
func add_bar(label: String, ink: Color, ink_end := Color.TRANSPARENT, bar_icon: Texture2D = null) -> GoBar:
	var bar := GoBar.new()
	bar.label_text = label
	bar.readout = GoBar.Readout.NONE
	bar.ink = ink
	bar.ink_end = ink_end
	bar.icon = bar_icon
	bar.thickness = 14
	bar.label_size = 11
	bar.label_ink = _label_ink()
	bar.label_gap = 0
	bar.lead = 2.0
	_bars.add_child(bar)
	_apply()
	return bar


## The bars `add_bar` made, in order.
func bars() -> Array[GoBar]:
	var found: Array[GoBar] = []
	for child in _bars.get_children():
		if child is GoBar: found.append(child)
	return found


## Shows [param seconds] as `MM:SS`; [param warn] paints it in `warn_ink` (the caller decides when — the last 30 s
## of a countdown, say).
func set_clock(seconds: float, warn := false) -> void:
	_warn = warn
	value = format_clock(seconds)


## `MM:SS` — whole seconds, never below zero.
static func format_clock(seconds: float) -> String:
	var whole := maxi(0, floori(seconds))
	@warning_ignore("integer_division")
	return "%02d:%02d" % [whole / 60, whole % 60]


## A gauge's state: lit (the skin's lit rim, full opacity — and a pop when [param animate] and it was not lit) or not
## (the plain rim, dimmed to `DIM_ALPHA`).
func set_lit(lit: bool, animate := true) -> void:
	var was := _lit
	_lit = lit
	_apply()
	if is_instance_valid(_pop) and _pop.is_valid(): _pop.kill()
	scale = Vector2.ONE
	if lit and not was and animate and is_inside_tree() and not GoUi.config.reduce_motion:
		_pop = create_tween()
		_pop.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_UP).set_ease(Tween.EASE_OUT)
		_pop.tween_property(self, "scale", Vector2.ONE, POP_DOWN).set_ease(Tween.EASE_OUT)


func is_lit() -> bool:
	return _lit


func is_warning() -> bool:
	return _warn


func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label


func _label_ink() -> Color:
	return get_theme_color(&"font_color", &"Label")


## A copy of [param box] whose clear space is [param pad] inside each side's border.
static func _padded(box: StyleBox, pad: float) -> StyleBox:
	if box == null or pad < 0.0: return box
	var copy := box.duplicate() as StyleBox
	var flat := copy as StyleBoxFlat
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		copy.set_content_margin(side, pad + (flat.get_border_width(side) if flat != null else 0.0))
	return copy


func _apply() -> void:
	if not is_instance_valid(_row): return
	var skin := GoUi.skin()
	_row.add_theme_constant_override(&"separation", gap)
	_icon.texture = icon
	_icon.visible = icon != null
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER if icon_snap else Control.SIZE_FILL

	remove_theme_stylebox_override(&"panel")
	if gauge:
		add_theme_stylebox_override(&"panel", _padded(skin.hud_gauge_box(_lit), padding))
		modulate.a = 1.0 if _lit else DIM_ALPHA
	else:
		modulate.a = 1.0
		if padding >= 0.0:
			add_theme_stylebox_override(&"panel", _padded(get_theme_stylebox(&"panel", VAR_PANEL), padding))
	_banner.remove_theme_stylebox_override(&"panel")
	if banner_padding >= 0.0:
		_banner.add_theme_stylebox_override(&"panel", _padded(_banner.get_theme_stylebox(&"panel", VAR_BANNER), banner_padding))

	_banner.visible = not banner_text.is_empty()
	_banner_label.text = banner_text
	_banner_label.add_theme_font_size_override(&"font_size", banner_size)

	var inline := layout == Layout.INLINE
	var home: Container = _row if inline else _body
	for label: Label in [_title_label, _value_label]:
		if label.get_parent() != home:
			if label.get_parent() != null: label.get_parent().remove_child(label)
			home.add_child(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if inline else HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_value_label.text = value
	_value_label.visible = not value.is_empty()
	_title_label.add_theme_font_size_override(&"font_size", title_size if title_size > 0 else (19 if inline else 12))
	_value_label.add_theme_font_size_override(&"font_size", value_size if value_size > 0 else (19 if inline else 24))
	var ink := _label_ink()
	if inline: _title_label.remove_theme_color_override(&"font_color")
	else: _title_label.add_theme_color_override(&"font_color", Color(ink, ink.a * CAPTION_ALPHA))
	var shown := value_ink
	if _warn: shown = warn_ink if warn_ink.a > 0.0 else skin.hud_alert_ink()
	if shown.a > 0.0: _value_label.add_theme_color_override(&"font_color", shown)
	else: _value_label.remove_theme_color_override(&"font_color")
	for bar in bars(): bar.label_ink = ink
	_bars.visible = _bars.get_child_count() > 0
	_body.visible = _banner.visible or _bars.visible or (not inline and (_title_label.visible or _value_label.visible))
