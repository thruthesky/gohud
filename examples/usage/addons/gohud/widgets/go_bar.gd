## 📊 **Value bar** — one row that shows "how much is left": HP, MP, XP.
##
## ```gdscript
## var hp := GoBar.new()
## hp.label_text = "HP"
## hp.ink = GoUi.color(GoTheme.DANGER)
## hp.set_values(320, 500)      # "320 / 500"
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
		ink = value
		_restyle()

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

## Seconds to glide over when the value changes. 0 means instant.
@export_range(0.0, 1.0, 0.01) var ease_seconds := 0.18

var _name_label: Label
var _value_label: Label
var _bar: ProgressBar
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

	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)

	_name_label = GoStyle.label(label_text, GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_name_label.name = "Name"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label.visible = not label_text.is_empty()
	head.add_child(_name_label)

	_value_label = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	_value_label.name = "Value"
	_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
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
		return
	_tween = create_tween()
	_tween.tween_property(_bar, "value", ratio, ease_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## For setting just the 0~1 ratio (when the maximum is unknown).
func set_ratio(ratio: float, animate := true) -> void:
	set_values(clampf(ratio, 0.0, 1.0), 1.0, animate)


func value() -> float:
	return _value


func maximum() -> float:
	return _maximum


func _restyle() -> void:
	if not is_instance_valid(_bar): return
	GoStyle.tint_progress(_bar, ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT))


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
