## 📊 **Value bar** — one row that shows "how much is left": HP, MP, XP.
##
## ```gdscript
## var hp := GoBar.new()
## hp.label_text = "HP"
## hp.ink = GoUi.color(GoTheme.DANGER)
## hp.set_values(320, 500)      # "320 / 500"
## hp.segments = 6              # six chunks — the segmented gauge of an arcade HUD (-1, the default, asks the look)
## hp.ink_end = GoUi.color(GoTheme.WARNING_FILL)   # under the arcade looks the fill warms across to this paint
## ```
##
## ## 🔑 Choose how the number reads
## | `readout` | What you see |
## |---|---|
## | `NONE` | bar only |
## | `VALUE` | `320` |
## | `FRACTION` | `320 / 500` |
## | `PERCENT` | `64%` |
##
## ## 🎮 A match HUD's bar
## Under a look with a bar frame (`GoSkin.bar_frame_box()` — arcade_light's is the painted HUD's groove) the bar is a
## rounded frame whose `ink` → `ink_end` gradient is clipped to it. Name it like a HUD does:
## ```gdscript
## var power := GoBar.new()
## power.label_text = "POWER"
## power.readout = GoBar.Readout.NONE
## power.icon = GoUi.skin().widget_art(&"bolt")   # a 16 dp icon before the name
## power.thickness = 14
## power.label_size = 11
## power.label_gap = 0
## power.lead = 2
## ```
##
## ## 🛑 Values move smoothly — but it has to be switchable off
## When HP jumps in steps you cannot read how hard you were hit, so it interpolates over 0.18s by default.
## Under `GoConfig.reduce_motion` it changes instantly.
@tool
class_name GoBar
extends Control

enum Readout { NONE, VALUE, FRACTION, PERCENT }

## The name to the left of the bar. Empty hides it.
@export var label_text := "":
	set(value):
		label_text = value
		if is_instance_valid(_name_label):
			_name_label.text = value
			_name_label.visible = not value.is_empty()

## The bar color. Transparent means the theme's `accent`.
##
## 🔑 For status colors pass a **fill-only token** (`GoTheme.DANGER_FILL`, …) — `DANGER` is meant for text, so it is
##    set dark in light themes and painting it straight onto a bar looks muddy. Themes without a fill token fall
##    back to the base color of the same name automatically, so it is safe to use either way.
@export var ink := Color.TRANSPARENT:
	set(value):
		if ink == value: return
		ink = value
		_paint()

## 🌈 A second paint the fill runs **across** to, left to right — a power gauge going from orange to yellow. Under the
## looks that paint their fills (the arcade looks: `GoStyleBoxArcade.end_color`) the tube changes colour along its
## length; the other looks keep the single `ink`. Transparent: one paint.
@export var ink_end := Color.TRANSPARENT:
	set(value):
		if ink_end == value: return
		ink_end = value
		_paint()

## How the number is displayed.
@export var readout := Readout.FRACTION:
	set(value):
		readout = value
		_refresh_text()

## Thickness of the bar (dp).
@export_range(2, 48) var thickness := 8:
	set(value):
		thickness = value
		if is_instance_valid(_bar): _bar.custom_minimum_size.y = value
		if is_instance_valid(_frame): _frame.custom_minimum_size.y = value

## Seconds to glide over when the value changes. 0 means instant.
@export_range(0.0, 1.0, 0.01) var ease_seconds := 0.18

## 🧱 Ticks that split the bar into this many chunks — the segmented gauge of an arcade HUD. Decoration only: the fill
## still moves smoothly. -1 leaves it to the look (`GoSkin.bar_ticks()` — one smooth bar by default, six chunks in the
## arcade looks); 0 is always one smooth bar.
@export_range(-1, 24) var segments := -1:
	set(value):
		segments = value
		if is_instance_valid(_ticks): _ticks.queue_redraw()
		if is_instance_valid(_frame_ticks): _frame_ticks.queue_redraw()

## 🖼 An icon before the name (a HUD's bolt). null hides it.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_instance_valid(_icon):
			_icon.texture = value
			_icon.visible = value != null

## The icon's square size (dp).
@export_range(4.0, 64.0, 1.0) var icon_size := 16.0:
	set(value):
		icon_size = value
		if is_instance_valid(_icon): _icon.custom_minimum_size = Vector2(value, value)

## The room between the icon and the name (dp).
@export_range(0, 32) var icon_gap := 3:
	set(value):
		icon_gap = value
		if is_instance_valid(_title): _title.add_theme_constant_override(&"separation", value)

## The name's and the readout's font size. -1: the compact text role's.
@export_range(-1, 64) var label_size := -1:
	set(value):
		label_size = value
		_apply_label_style()

## The name's and the readout's colour. Transparent: the theme's `secondary`.
@export var label_ink := Color.TRANSPARENT:
	set(value):
		label_ink = value
		_apply_label_style()

## The room between the name row and the bar (dp). -1: the theme's `gap_tiny`.
@export_range(-1, 32) var label_gap := -1:
	set(value):
		label_gap = value
		_apply_gap()

## Room left above the name (dp) — bars stacked under a banner keep apart with it. 0: none.
@export_range(0.0, 32.0, 1.0) var lead := 0.0:
	set(value):
		lead = value
		if is_instance_valid(_lead):
			_lead.custom_minimum_size.y = value
			_lead.visible = value > 0.0

var _column: VBoxContainer
var _lead: Control
var _title: HBoxContainer
var _icon: TextureRect
var _frame: Panel
var _gradient: TextureRect
var _paint_gradient: Gradient
var _frame_ticks: Control
var _name_label: Label
var _value_label: Label
var _bar: ProgressBar
var _ticks: Control
var _value := 0.0
var _maximum := 1.0
var _tween: Tween


func _init() -> void:
	name = "Bar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_column = column

	_lead = Control.new()
	_lead.name = "Lead"
	_lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lead.custom_minimum_size.y = lead
	_lead.visible = lead > 0.0
	column.add_child(_lead)

	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)

	_title = HBoxContainer.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_constant_override(&"separation", icon_gap)
	head.add_child(_title)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.texture = icon
	_icon.visible = icon != null
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(_icon)

	_name_label = GoStyle.label(label_text, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_name_label.name = "Name"
	GoStyle.one_line(_name_label)
	_name_label.visible = not label_text.is_empty()
	_title.add_child(_name_label)

	_value_label = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_value_label.name = "Value"
	GoStyle.one_line(_value_label)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 🛑 Numbers always read **left to right** — even in Arabic the order of `320 / 500` stays as it is.
	_value_label.text_direction = Control.TEXT_DIRECTION_LTR
	head.add_child(_value_label)

	_bar = GoStyle.progress()
	_bar.name = "Fill"
	_bar.custom_minimum_size.y = thickness
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0001
	column.add_child(_bar)
	_ticks = Control.new()
	_ticks.name = "Ticks"
	_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ticks.draw.connect(_draw_ticks)
	_bar.add_child(_ticks)

	# The painted frame: a rounded groove (the skin's `bar_frame_box`) clipping a gradient fill and the chunk lines.
	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.custom_minimum_size.y = thickness
	_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_frame.visible = false
	column.add_child(_frame)
	_gradient = TextureRect.new()
	_gradient.name = "Gradient"
	_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_gradient)
	_gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gradient.anchor_right = 0.0
	_frame_ticks = Control.new()
	_frame_ticks.name = "Ticks"
	_frame_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_ticks.draw.connect(_draw_frame_ticks)
	_frame.add_child(_frame_ticks)
	# 🛑 A `Control` does **not inherit** the minimum height of its child container — left alone, one bar is measured
	#    as taking only its own thickness (8dp), so in a vertical stack the name row and the bar below draw on top
	#    of each other (measured on a 2026-09-12 screenshot: the HP/MP/XP rows overlapped).
	GoStyle.fit_content_height(self, column)


func _ready() -> void:
	_restyle()
	_refresh_text()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 🎨 The whole look changed — `GoUi.use_preset()` and `GoUi.refresh()` call this.
## 🛑 Without it **the widgets already on screen are the only ones left on the old theme.** They sit next to freshly
##    built ones and one screen ends up wearing two looks (measured 2026-09-16: after switching presets the HP bar
##    kept the old accent color and the quick-slot panel its old color — the values had changed, but nobody re-read them).
func _on_ui_changed() -> void:
	_restyle()
	_refresh_text()


## Sets the value and the maximum. A maximum of 0 or less counts as an empty bar.
func set_values(value: float, maximum: float, animate := true) -> void:
	_value = maxf(0.0, value)
	_maximum = maximum
	var ratio := clampf(_value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_refresh_text()
	if is_instance_valid(_tween) and _tween.is_valid(): _tween.kill()
	if not animate or GoUi.config.reduce_motion or ease_seconds <= 0.0 or not is_inside_tree():
		_bar.value = ratio
		_gradient.anchor_right = ratio
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(_bar, "value", ratio, ease_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_gradient, "anchor_right", ratio, ease_seconds).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)


## For setting just the 0~1 ratio (when the maximum is unknown).
func set_ratio(ratio: float, animate := true) -> void:
	set_values(clampf(ratio, 0.0, 1.0), 1.0, animate)


func value() -> float:
	return _value


func maximum() -> float:
	return _maximum


## Whether the bar is drawn as the look's painted frame (`GoSkin.bar_frame_box()`) rather than a `ProgressBar`.
func frame_mode() -> bool:
	return GoUi.skin().bar_frame_box() != null


func _restyle() -> void:
	if not is_instance_valid(_bar): return
	var groove := GoUi.skin().bar_frame_box()
	_frame.visible = groove != null
	_bar.visible = groove == null
	if groove != null: _frame.add_theme_stylebox_override(&"panel", groove)
	_paint()
	_apply_label_style()
	_apply_gap()


## The fill's paint — the ink and `ink_end`. The gradient and its texture are built once and only get new colours, so a
## HUD tinting a bar every frame allocates nothing and leaves the labels and the gap alone.
func _paint() -> void:
	if not is_instance_valid(_bar): return
	var start := ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)
	var colors := PackedColorArray([start, ink_end if ink_end.a > 0.0 else start])
	if _paint_gradient == null:
		_paint_gradient = Gradient.new()
		_paint_gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var paint := GradientTexture2D.new()
		paint.gradient = _paint_gradient
		paint.fill_from = Vector2.ZERO
		paint.fill_to = Vector2(1.0, 0.0)
		paint.width = 128
		paint.height = 4
		_gradient.texture = paint
	if _paint_gradient.colors != colors: _paint_gradient.colors = colors
	if is_instance_valid(_frame_ticks): _frame_ticks.queue_redraw()
	GoStyle.tint_progress(_bar, ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT))
	if ink_end.a > 0.0:
		var tube := _bar.get_theme_stylebox(&"fill") as GoStyleBoxArcade
		if tube != null:
			var skin := GoUi.skin() as GoSkinArcade
			tube.end_color = Color(skin.vivid(ink_end) if skin != null else ink_end, 1.0)
	if is_instance_valid(_ticks): _ticks.queue_redraw()


## How many chunks the bar shows now — `segments`, or the look's choice when that is -1.
func segment_count() -> int:
	return segments if segments >= 0 else GoUi.skin().bar_ticks()


func _draw_ticks() -> void:
	var count := segment_count()
	if count >= 2: GoUi.skin().draw_bar_ticks(_ticks, Rect2(Vector2.ZERO, _ticks.size), count)


func _draw_frame_ticks() -> void:
	var count := segment_count()
	if count >= 2: GoUi.skin().draw_bar_ticks(_frame_ticks, Rect2(Vector2.ZERO, _frame_ticks.size), count)


func _apply_label_style() -> void:
	if not is_instance_valid(_name_label): return
	var colour := label_ink if label_ink.a > 0.0 else GoUi.color(GoTheme.SECONDARY)
	for label: Label in [_name_label, _value_label]:
		label.remove_theme_font_size_override(&"font_size")
		GoStyle.typography(label, GoTheme.ROLE_COMPACT, colour)
		label.add_theme_color_override(&"font_color", colour)
		if label_size > 0: label.add_theme_font_size_override(&"font_size", label_size)


func _apply_gap() -> void:
	if is_instance_valid(_column):
		_column.add_theme_constant_override(&"separation",
			label_gap if label_gap >= 0 else GoUi.metric(GoTheme.GAP_TINY))


## 🛑 The readout now goes through a **translation key** — the format has to change with the language
##    (Turkish %50 · French "50 %"). It is a string assembled in code, which the engine's automatic
##    translation never touches, so this notification is taken here to rebuild it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _refresh_text() -> void:
	if not is_instance_valid(_value_label): return
	match readout:
		Readout.NONE:
			_value_label.visible = false
		Readout.VALUE:
			_value_label.visible = true
			_value_label.text = format_amount(_value)
		Readout.FRACTION:
			_value_label.visible = true
			# 🛑 Don't hardcode the format — separator and order differ per language (GoConfig.text_keys).
			_value_label.text = GoUi.text(&"bar_fraction").format({
				"value": format_amount(_value), "max": format_amount(_maximum)})
		Readout.PERCENT:
			_value_label.visible = true
			var pct := (_value / _maximum * 100.0) if _maximum > 0.0 else 0.0
			# Turkish puts the percent sign in front (%50) — which is why this one is a translation key too.
			_value_label.text = GoUi.text(&"bar_percent").format({"percent": roundi(pct)})


## Writes big numbers short — if the host plugged in `GoConfig.number_formatter`, that is used instead.
## 🔑 Korean, Chinese and Japanese group by **man (10^4) and eok (10^8)**, not thousands and millions. Where the
##    grouping falls differs, so no format string can fix it — the arithmetic itself has to change. Hence the hook.
static func format_amount(amount: float) -> String:
	var hook: Callable = GoUi.config.number_formatter
	if hook.is_valid():
		return str(hook.call(amount))
	return abbreviate(amount)


## The built-in shortening rule — `12.3k`, `4.5m`. Keeps the bar width steady as digits pile up.
static func abbreviate(amount: float) -> String:
	var size := absf(amount)
	if size >= 1_000_000.0: return "%.1fm" % (amount / 1_000_000.0)
	if size >= 10_000.0: return "%.1fk" % (amount / 1000.0)
	return str(roundi(amount))


func _format(amount: float) -> String:
	return format_amount(amount)
