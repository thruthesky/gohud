## ⏳ **A waiting indicator** — connecting to the server, downloading a map, waiting on a payment.
##
## ```gdscript
## var busy := GoSpinner.new()
## card.add_child(busy)
##
## # Press the button and it turns into a spinner right there — which also blocks a second press
## GoSpinner.busy(buy_button, true)
## var ok := await server.purchase(item)
## GoSpinner.busy(buy_button, false)
## ```
##
## ## 🛑 "Stuck" and "waiting" have to look different
## In a networked game a screen that sits still **reads as a dead game** to the player. While the server is being
## waited on, something has to be turning. The other way round, throwing a full-screen veil over something that
## finishes within three seconds looks sluggish in its own way — spinning **inside the button that was pressed** feels faster.
##
## ## ♿ For people who turned `reduce_motion` on, nothing spins
## Someone who turned rotation off because of vestibular issues must not be shown an endlessly spinning circle. For them
## it becomes **three dots brightening in turn** — still reading as "in progress", with no rotation.
##
## ## 🔑 When you know how long it takes, use a bar
## Anything whose **progress is known**, such as bytes received, belongs to `GoBar`. This one means "how long is unknown",
## and so it promises no end.
@tool
class_name GoSpinner
extends Control

## Seconds per turn.
@export var seconds_per_turn := 1.1:
	set(value):
		seconds_per_turn = maxf(0.05, value)

## Line thickness (dp). Negative means 1/9 of the diameter — the proportion holds even when it is made small.
@export var thickness := -1.0:
	set(value):
		thickness = value
		queue_redraw()

## The spinning color. Leave it empty for the theme accent — or, inside a busy button, that button's text color.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## Should the pale circle behind be drawn? 🔑 Over a busy game background, leaving it on keeps it readable.
@export var show_track := true:
	set(value):
		show_track = value
		queue_redraw()

var _phase := 0.0
## The button this spinner stands in for (`busy()`), or null for a free-standing spinner.
var _host: Button
## The face this spinner laid on as the button's `disabled` face — any other face found there was laid by the button.
var _held: StyleBox
## The accent pushed clear of every face (`_ink`), worked out once per look rather than every frame.
var _accent := Color.TRANSPARENT


func _init() -> void:
	name = "Spinner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 Spinning is **physical** — it does not run counter-clockwise just because the language is Arabic.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	var px := GoUi.metric(GoTheme.ICON_SIZE)
	custom_minimum_size = Vector2(px, px)


func _ready() -> void:
	# ♿ For a screen reader the single word "loading" is enough — the turning shape is information for the eyes only.
	accessibility_name = GoUi.text(&"loading")
	GoUi.watch(_on_ui_changed)
	set_process(is_visible_in_tree())
	if is_instance_valid(_host) and not _host.theme_changed.is_connected(_on_host_restyled):
		_host.theme_changed.connect(_on_host_restyled)
	_hold_face()


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	# Out of the tree it hears no look change — whatever it worked out may be stale when it comes back.
	_accent = Color.TRANSPARENT
	if is_instance_valid(_host) and _host.theme_changed.is_connected(_on_host_restyled):
		_host.theme_changed.disconnect(_on_host_restyled)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta / seconds_per_turn, 1.0)
	queue_redraw()


func _draw() -> void:
	var box := minf(size.x, size.y)
	if box <= 0.0: return
	var line := thickness if thickness > 0.0 else maxf(1.0, box / 9.0)
	var center := size * 0.5
	var radius := box * 0.5 - line * 0.5
	if radius <= 0.0: return
	var color := _ink()

	if GoUi.config.reduce_motion:
		_draw_dots(center, box, color)
		return

	if show_track:
		# 🔑 In a button the track is its own ink, faint — the theme track is made for the page, and on a filled
		#    face it is either a grey smudge or nothing.
		var track := Color(color, color.a * 0.3) if is_instance_valid(_host) else GoUi.color(GoTheme.TRACK)
		draw_arc(center, radius, 0.0, TAU, 40, track, line, true)
	# 🔑 The arc length is swung along with it — at a fixed length it does not read as spinning but as "a picture merely rotating".
	#    It is what Material's determinate spinner does, and it really does feel far more like "work is happening".
	var swing := (sin(_phase * TAU) * 0.5 + 0.5)
	var sweep := lerpf(PI * 0.25, PI * 1.35, swing)
	var start := _phase * TAU * 1.6
	draw_arc(center, radius, start, start + sweep, 48, color, line, true)


## The color it draws in. 🔑 A busy button's text color is read **now**, not when `busy()` was called — called
## before the button is in the tree, the button only knows the engine's grey, and a theme switch changes it later.
func _ink() -> Color:
	if ink.a > 0: return ink
	if is_instance_valid(_host) and _host.is_inside_tree(): return _host.get_theme_color(&"font_color")
	# A thin line in the accent of a light look sat at 3.4:1 on a card — pushed a little, it stands clear of every face.
	if _accent.a <= 0.0: _accent = GoSkin.readable_on_faces(GoUi.color(GoTheme.ACCENT))
	return _accent


## 🛑 A busy button keeps **its own face**. `busy()` disables it, and a disabled face is pale on purpose — the
##    button's text color drawn on it disappeared in every theme (measured 2026-10-06: a white spinner on the
##    kids theme's pale-pink disabled Play button, 1.14:1; 1.06–1.69:1 for every filled button in all fourteen
##    looks). The text color is made to read on the normal face, so the spinner shows the normal face.
## 🛑 A button that lays **its own** disabled face (`GoFab` does, when it joins the tree and when it folds) would
##    cover the normal face again — so that face is taken as the button's, kept for `busy(false)` to put back, and the
##    normal face goes back on.
func _hold_face() -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree(): return
	var normal := _host.get_theme_stylebox(&"normal")
	if _host.has_theme_stylebox_override(&"disabled"):
		var found := _host.get_theme_stylebox(&"disabled")
		if found == _held and found == normal: return
		if found != _held and _host.has_meta(_BUSY_META):
			var carried: Dictionary = _host.get_meta(_BUSY_META)
			carried["had_face"] = true
			carried["face"] = found
	_host.remove_theme_stylebox_override(&"disabled")
	_held = _host.get_theme_stylebox(&"normal")
	_host.add_theme_stylebox_override(&"disabled", _held)


## The button changed one of its faces (or took a new look). Deferred, so a widget that lays several faces in a row
## is looked at once it is done.
func _on_host_restyled() -> void:
	_hold_face.call_deferred()


## ♿ For those who turned rotation off — three dots brighten in turn. The same "in progress", with nothing spinning.
## 🛑 If time stopped altogether it would be indistinguishable from "a dead screen". So **only the brightness** flows.
func _draw_dots(center: Vector2, box: float, color: Color) -> void:
	var dot := maxf(1.0, box / 8.0)
	var gap := dot * 2.6
	var beat := float(Time.get_ticks_msec()) / 1000.0 / maxf(0.05, seconds_per_turn)
	for i in 3:
		var lit := 0.35 + 0.65 * (sin((beat - i * 0.18) * TAU) * 0.5 + 0.5)
		draw_circle(center + Vector2((i - 1) * gap, 0.0), dot, Color(color, color.a * lit))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# 🛑 Nothing turns while it is out of sight — a hidden spinner redrawing every frame is thrown away for free.
		# 🛑 It **does not stop** under `reduce_motion` either — that is the indicator where three dots flow in brightness,
		#    and if time stopped altogether it would be indistinguishable from "a dead screen" (2026-09-16: turning it off left it frozen).
		set_process(is_visible_in_tree())
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		accessibility_name = GoUi.text(&"loading")
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		# 🔑 `_ready` runs once — a spinner taken out and put back would otherwise stop following the look.
		GoUi.watch(_on_ui_changed)


func _on_ui_changed() -> void:
	accessibility_name = GoUi.text(&"loading")
	set_process(is_visible_in_tree())
	_accent = Color.TRANSPARENT
	# Deferred: the button takes the new look in its own handler, which may run after this one.
	_hold_face.call_deferred()
	queue_redraw()


# ── Putting a button into the waiting state ─────────────────────────────

## The meta name that hangs the original label and the spinner on the button.
const _BUSY_META := &"gohud_busy"


## Turns the button into **waiting** — the label is hidden and a spinner turns in its place. It cannot be pressed.
##
## ```gdscript
## GoSpinner.busy(buy, true)
## var ok := await server.purchase(item)
## GoSpinner.busy(buy, false)
## ```
##
## 🛑 **The size does not change.** Erasing the label and replacing it with a spinner makes the button skinny and the whole row lurch.
##    So the label goes transparent at `modulate.a = 0` **while keeping its place**, and the spinner overlays it
##    (design 2026-09-16: erasing the label shrank a two-character "Buy" button into a square).
## 🛑 **Half of what this function does is preventing a double press.** For requests that must not go out twice, such as
##    a payment or a trade, `disabled` alone is not enough — a second press slips in between the first one and the `await`.
static func busy(button: Button, waiting: bool) -> void:
	if not is_instance_valid(button): return
	# 🛑 `get_meta(key, default)` prints an error when the key is missing — ask `has_meta` first.
	var carried: Dictionary = button.get_meta(_BUSY_META) if button.has_meta(_BUSY_META) else {}

	if not waiting:
		if carried.is_empty(): return
		var spinner: GoSpinner = carried.get("spinner")
		if is_instance_valid(spinner):
			# Let go first — a theme change in this frame would otherwise lay the normal face back on after the restore below.
			if button.theme_changed.is_connected(spinner._on_host_restyled):
				button.theme_changed.disconnect(spinner._on_host_restyled)
			spinner._host = null
			spinner.queue_free()
		button.disabled = bool(carried.get("disabled", false))
		# 🛑 The hidden label color is **put back** — leave it and that button shows as an empty panel, its label
		#    transparent, even later on when it really is disabled.
		if bool(carried.get("had_font", false)):
			button.add_theme_color_override(&"font_disabled_color", carried["font"])
		else:
			button.remove_theme_color_override(&"font_disabled_color")
		if bool(carried.get("had_icon", false)):
			button.add_theme_color_override(&"icon_disabled_color", carried["icon"])
		else:
			button.remove_theme_color_override(&"icon_disabled_color")
		if bool(carried.get("had_face", false)):
			button.add_theme_stylebox_override(&"disabled", carried["face"])
		else:
			button.remove_theme_stylebox_override(&"disabled")
		button.remove_meta(_BUSY_META)
		return

	if not carried.is_empty(): return   # already waiting — no second spinner is stacked on
	var spinner := GoSpinner.new()
	spinner.name = "BusySpinner"
	# Matched to the height of the button label — bigger sticks out of the button, smaller cannot be seen.
	var px := maxi(12, roundi(float(GoUi.metric(GoTheme.ICON_SIZE)) * 0.8))
	spinner.custom_minimum_size = Vector2(px, px)
	spinner.size = Vector2(px, px)
	# 🛑 The anchor is **centered**, so `position` is the offset from that point. Adding the parent size on top again
	#    puts it outside the button, out of sight (captured 2026-09-16: an empty button with the label gone and nothing turning).
	#    With the anchor it keeps the center even when the button size is settled later.
	spinner.set_anchors_preset(Control.PRESET_CENTER)
	spinner.position = -Vector2(px, px) * 0.5
	# 🔑 The color is **that button's text color** — on an accent button (a filled panel) an accent-colored spinner sinks in.
	#    It is read while drawing (`_ink`), and the button keeps its normal face to draw it on (`_hold_face`).
	spinner._host = button
	# For restoring later, **the overrides that were already there** are recorded too — removing something that was
	# never there is not the same as putting back something that was.
	button.set_meta(_BUSY_META, {
		"spinner": spinner, "disabled": button.disabled,
		# 🔑 When there **was no** override, the value is never used (restoring goes through `remove_…`). It is only filler,
		#    so a token is used — hard-coding white would be invisible in a light theme should it ever leak out.
		"had_font": button.has_theme_color_override(&"font_disabled_color"),
		"font": button.get_theme_color(&"font_disabled_color") if button.has_theme_color_override(&"font_disabled_color") else GoUi.color(GoTheme.MUTED),
		"had_icon": button.has_theme_color_override(&"icon_disabled_color"),
		"icon": button.get_theme_color(&"icon_disabled_color") if button.has_theme_color_override(&"icon_disabled_color") else GoUi.color(GoTheme.MUTED),
		"had_face": button.has_theme_stylebox_override(&"disabled"),
		"face": button.get_theme_stylebox(&"disabled") if button.has_theme_stylebox_override(&"disabled") else null,
	})
	# 🛑 Added **after** the record: in the tree, the spinner lays the normal face on as it joins — recorded after
	#    that, the button's own disabled face would be lost and the spinner's put back in its place.
	button.add_child(spinner)
	button.disabled = true
	# Only the label goes transparent — the button panel and its size stay as they are.
	button.add_theme_color_override(&"font_disabled_color", Color(0, 0, 0, 0))
	button.add_theme_color_override(&"icon_disabled_color", Color(0, 0, 0, 0))


## Is this button waiting right now?
static func is_busy(button: Button) -> bool:
	return is_instance_valid(button) and button.has_meta(_BUSY_META)
