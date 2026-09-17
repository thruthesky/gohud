## 🎥 **The showreel** — every widget in every look, one after another, cut for a short movie.
##
## The guided tour (`sim.gd`) takes minutes and shows one look at a time. This screen is the trailer:
## in **20 seconds** it walks the same chapters at **one widget every half second**, and every step wears
## a different theme — default, sci-fi, medieval — so the movie says "the same widgets, three looks"
## without a single word. The bot drives each widget for the half second it is up (fast), so nothing
## on screen is a still: bars fill, slots cool down, menus open, the cursor really presses.
##
## The chapters are the tour's own `SimActs` — nothing is built twice — and the theme is switched through
## the same `ThemePicker` the rest of the demo uses. Widgets keep the theme they were built with, so every
## step tears the stage down and builds it again under the next preset.
##
## ```
## bash run.sh --record-showreel /tmp/gohud-showreel.avi   # 1920×1080 · 60 fps · 20 s, then quits
## bash run.sh -- --open=showreel                          # watch it in a window (loops on Replay)
## bash run.sh -- --open=showreel --showreel-seconds=28.5 --showreel-order=random --exit
## ```
##
## Arguments (all optional):
##   `--showreel-seconds=20`  how long the whole reel runs
##   `--showreel-step=0.5`    how long each widget stays up
##   `--showreel-order=cycle` `cycle` walks the chapters in order and rotates the three themes — with 19
##                            chapters and 3 themes no pair repeats before 57 steps; `random` shuffles
##                            the chapters and picks a theme that differs from the one before
##   `--showreel-seed=0`      fixes the random order (0 = a fresh one each run)
##   `--exit`                 quit once the reel is over (recording); otherwise a Replay card is shown
extends Control

const ThemePicker := preload("theme_picker.gd")

const PRESETS: Array[StringName] = [GoThemePresets.DEFAULT_DARK, GoThemePresets.SCIFI_DARK, GoThemePresets.MEDIEVAL_DARK]
const PRESET_NAMES := {
	GoThemePresets.DEFAULT_DARK: "Default theme",
	GoThemePresets.SCIFI_DARK: "Sci-fi theme",
	GoThemePresets.MEDIEVAL_DARK: "Medieval theme",
}
## The logical canvas. A 1920×1080 movie is this at 1.5×, so the stage is 840 px wide on film.
const CANVAS := Vector2i(1280, 720)
const HUD_LAYER := 70   ## Above a chapter's full-screen layer (60), below dialogs (100) and the cursor (200)
const STAGE_INSET := 100.0   ## Space above and below the stage, for the top bar and the caption (dp)
## The same accent, success and text colours the tour gives the default preset.
const ACCENT := Color("#71d9e9")
const GREEN := Color("#81dcb0")
const BG := Color("#0b111e")
const VIOLET := Color("#8b7cf6")
const SUBTITLE_INK := Color("#afbbce")

## How long the whole reel runs, in seconds.
var seconds := 20.0
## How long each widget stays on screen, in seconds.
var step := 0.5
## `false` cycles chapters and themes in order; `true` shuffles the chapters and randomises the theme.
var random_order := false
## The seed for `random_order`. 0 draws a fresh one.
var seed_value := 0

## A step began: which chapter, under which preset.
signal step_started(number: int, key: StringName, preset: StringName)
## The whole reel has been shown (also before Replay is offered).
signal finished

var _acts := SimActs.new()
var _entries: Array[Dictionary] = []
var _plan: Array[Dictionary] = []
var _bot: SimBot
var _stage: SimStage
var _hud: CanvasLayer
var _hud_root: Control
var _progress: ProgressBar
var _caption: Label
var _callback: Label
var _end_card: Control

var _run := 0           ## Bumped on every start — a coroutine from an older run sees the mismatch and stops.
var _clock := 0.0       ## Seconds since the run began, from process deltas (exact under a fixed frame rate).
var _playing := false
var _driving := false
var _auto_exit := false
var _accent := ACCENT
var _green := GREEN
var _window_state: Dictionary = {}


func _ready() -> void:
	name = "Showreel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_read_args()
	_entries = SimActs.list()
	if _plan.is_empty(): _plan = _make_plan()
	_configure_window()
	_bot = SimBot.new()
	_bot.said.connect(_on_said)
	_bot.logged.connect(_on_logged)
	add_child(_bot)
	resized.connect(_sync_hud)
	_play.call_deferred()


func _exit_tree() -> void:
	_run += 1
	_playing = false
	if is_instance_valid(_bot): _bot.rest()
	_restore_window()


func _process(delta: float) -> void:
	if not _playing: return
	_clock += delta
	if is_instance_valid(_progress): _progress.value = clampf(_clock / maxf(0.01, seconds), 0.0, 1.0)


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	_auto_exit = args.has("--exit")
	for arg in args:
		if arg.begins_with("--showreel-seconds="): seconds = maxf(0.5, float(arg.substr(19)))
		elif arg.begins_with("--showreel-step="): step = maxf(0.1, float(arg.substr(16)))
		elif arg.begins_with("--showreel-order="): random_order = arg.substr(17) == "random"
		elif arg.begins_with("--showreel-seed="): seed_value = int(arg.substr(16))


# ── The plan ───────────────────────────────────────────────────────────

## Which chapter, under which preset, for every step. Built once so a random run can be replayed as it was.
func _make_plan() -> Array[Dictionary]:
	var count := maxi(1, int(round(seconds / step)))
	var plan: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	var order: Array[int] = []
	var last: StringName = &""
	for number in count:
		var index: int
		var preset: StringName
		if random_order:
			# Shuffle a fresh round only when the last one is used up — every chapter is seen before any repeats.
			if order.is_empty():
				for i in _entries.size(): order.append(i)
				for i in range(order.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var swap := order[i]
					order[i] = order[j]
					order[j] = swap
				# Do not open a round with the chapter that just closed the last one.
				if plan.size() > 0 and order.size() > 1 and order[0] == int(plan[-1].index):
					order.reverse()
			index = order.pop_front()
			preset = PRESETS[rng.randi_range(0, PRESETS.size() - 1)]
			while preset == last:
				preset = PRESETS[rng.randi_range(0, PRESETS.size() - 1)]
		else:
			index = number % _entries.size()
			preset = PRESETS[number % PRESETS.size()]
		plan.append({"index": index, "preset": preset})
		last = preset
	return plan


## The steps that will be shown — for checks and for anyone curious about the order. Works before the
## scene enters the tree, so a plan can be inspected without playing it.
func plan() -> Array[Dictionary]:
	if _plan.is_empty():
		if _entries.is_empty(): _entries = SimActs.list()
		_plan = _make_plan()
	return _plan.duplicate(true)


# ── Playing ────────────────────────────────────────────────────────────

func _play() -> void:
	_run += 1
	var run := _run
	_clock = 0.0
	_playing = true
	_drop_end_card()
	for number in _plan.size():
		if run != _run or not is_inside_tree(): return
		var slot := _plan[number]
		var entry := _entries[int(slot.index)]
		_apply_theme(slot.preset)
		_rebuild(number, entry, slot.preset)
		_stage.open("%02d" % (int(slot.index) + 1), entry.title, entry.note)
		_bot.rearm()
		# A short step needs a quick hand: at 0.5 s the bot runs at 6×, so the first press lands on film.
		_bot.speed = maxf(2.0, 3.0 / step)
		var refs: Dictionary = _acts.build(entry.key, _stage, _bot)
		step_started.emit(number, entry.key, slot.preset)
		_drive(entry.key, refs)
		var deadline := float(number + 1) * step
		while _clock < deadline and run == _run and is_inside_tree():
			await get_tree().process_frame
		if run != _run or not is_inside_tree(): return
		_bot.skip()
		# Let the bot's coroutine unwind before its widgets go — a click landing on a freed node is an error.
		var guard := 0
		while _driving and guard < 60 and run == _run:
			await get_tree().process_frame
			guard += 1
		if run != _run or not is_inside_tree(): return
		_bot.rest()
		_stage.clear()
	_playing = false
	if is_instance_valid(_progress): _progress.value = 1.0
	_bot.rearm()
	finished.emit()
	print("SHOWREEL: done — %d steps · %.1f s" % [_plan.size(), _clock])
	if _auto_exit:
		await get_tree().process_frame
		get_tree().quit(0)
		return
	_show_end_card()


## Runs the chapter's bot script in the background; `_driving` says when it has unwound.
func _drive(key: StringName, refs: Dictionary) -> void:
	_driving = true
	await _acts.play(key, _stage, _bot, refs)
	_driving = false


func _apply_theme(preset: StringName) -> void:
	ThemePicker.active_preset = preset
	var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: ACCENT, GoTheme.SUCCESS: GREEN,
		GoTheme.MUTED: Color("#91a1b8"), GoTheme.SECONDARY: SUBTITLE_INK}
	var settings := GoUi.config
	if not settings.has_meta(&"showreel"):
		# The tour's typography, so the two movies cut together: a body one step larger, taller buttons.
		settings = GoConfig.new()
		settings.base_font_size = 18
		settings.metric_overrides = {GoTheme.BUTTON_HEIGHT: 54, GoTheme.GAP: 14}
		settings.set_meta(&"showreel", true)
	ThemePicker.configure(settings, colors)
	_accent = GoUi.color(GoTheme.ACCENT)
	_green = GoUi.color(GoTheme.SUCCESS)
	_bot.set_ink(_accent)


# ── Screen ─────────────────────────────────────────────────────────────

## Tears everything but the bot down and builds it again under the current theme.
func _rebuild(number: int, entry: Dictionary, preset: StringName) -> void:
	for child in get_children():
		if child == _bot: continue
		remove_child(child)
		child.queue_free()
	theme = GoUi.theme()
	queue_redraw()

	# Top and bottom leave room for the two HUD bars (about 95 dp and 90 dp) so neither touches the stage.
	var frame := GoStyle.padding(24, STAGE_INSET)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(centre)
	_stage = SimStage.new()
	_stage.custom_minimum_size.y = maxf(320.0, size.y - STAGE_INSET * 2.0)
	centre.add_child(_stage)
	_enter(_stage)

	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	_hud.layer = HUD_LAYER
	add_child(_hud)
	_hud_root = Control.new()
	_hud_root.name = "HudRoot"
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.theme = GoUi.theme()
	_hud.add_child(_hud_root)
	_hud_root.add_child(_top_bar(number, entry, preset))
	_hud_root.add_child(_bottom_bar(entry))
	_sync_hud()


## The stage slides up a touch and fades in — a cut every half second reads as a flicker without it.
func _enter(node: Control) -> void:
	if GoUi.config.reduce_motion: return
	node.modulate.a = 0.0
	node.position.y += 18.0
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 1.0, 0.18)
	tween.tween_property(node, "position:y", node.position.y - 18.0, 0.22)


## The HUD layer draws in window space; this pins it to this control's own rectangle, so inside the
## demo's home the top bar and its `Home` button stay in reach.
func _sync_hud() -> void:
	if not is_instance_valid(_hud) or not is_inside_tree(): return
	_hud.offset = global_position
	_hud_root.position = Vector2.ZERO
	_hud_root.size = size
	if is_instance_valid(_stage): _stage.custom_minimum_size.y = maxf(320.0, size.y - STAGE_INSET * 2.0)


func _panel() -> StyleBox:
	if ThemePicker.active_preset != GoThemePresets.DEFAULT_DARK:
		var face := GoStyle.surface(GoTheme.BOX_CARD)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: face.set_content_margin(side, 12)
		return face
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("#121c2b")
	flat.border_color = Color("#22334a")
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(14)
	flat.set_content_margin_all(12)
	return flat


func _top_bar(number: int, entry: Dictionary, preset: StringName) -> Control:
	var holder := GoStyle.padding(18, 14)
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := GoStyle.column(6)
	holder.add_child(column)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", _panel())
	column.add_child(card)
	var row := GoStyle.row(12)
	card.add_child(row)

	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(32, 32)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_theme_stylebox_override(&"panel", GoStyle.disc(32, _accent, 0.18, 0.55))
	var disc_centre := CenterContainer.new()
	disc.add_child(disc_centre)
	disc_centre.add_child(GoUi.icons().node(GoIconSet.GRID, 16, _accent))
	row.add_child(disc)
	var logo := GoStyle.label("gohud", GoTheme.ROLE_TITLE, Color.WHITE)
	GoStyle.natural_width(logo)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var version := GoStyle.chip("v" + GoUi.VERSION, _accent)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(version)

	var counter := GoStyle.label("%02d / %02d" % [number + 1, _plan.size()], GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED))
	GoStyle.natural_width(counter)
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(counter)
	var icon := GoUi.icons().node(entry.icon, 22, _accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var title := GoStyle.label(entry.title, GoTheme.ROLE_SUBTITLE, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)

	var look := GoStyle.chip(PRESET_NAMES[preset], _accent, false, GoIconSet.SUN)
	look.name = "Look"
	look.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(look)

	_progress = GoStyle.progress(_accent)
	_progress.custom_minimum_size.y = 4
	_progress.max_value = 1.0
	_progress.value = clampf(_clock / maxf(0.01, seconds), 0.0, 1.0)
	for style in [&"background", &"fill"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(_accent, 0.18) if style == &"background" else _accent
		rail.set_corner_radius_all(2)
		_progress.add_theme_stylebox_override(style, rail)
	column.add_child(_progress)
	return holder


func _bottom_bar(entry: Dictionary) -> Control:
	var holder := GoStyle.padding(18, 14)
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# 🛑 A bottom-anchored box starts 0 dp tall and grows downward by default — off the screen. Grow upward.
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre := CenterContainer.new()
	holder.add_child(centre)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = minf(920.0, size.x - 36.0)
	card.add_theme_stylebox_override(&"panel", _panel())
	centre.add_child(card)
	var row := GoStyle.row(14)
	card.add_child(row)
	var mark := GoUi.icons().node(GoIconSet.PLAY, 20, _accent)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var column := GoStyle.column(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_caption = GoStyle.label(entry.note, GoTheme.ROLE_BODY)
	_caption.add_theme_font_size_override(&"font_size", 19)
	column.add_child(_caption)
	_callback = GoStyle.label(" ", GoTheme.ROLE_CAPTION, _green)
	column.add_child(_callback)
	return holder


func _on_said(text: String) -> void:
	if text.is_empty() or not is_instance_valid(_caption): return
	_caption.text = text


## A widget's own callback fired — the proof it was really pressed, kept under the caption.
func _on_logged(text: String) -> void:
	if not is_instance_valid(_callback): return
	_callback.text = "→ " + text
	if GoUi.config.reduce_motion: return
	_callback.modulate.a = 0.3
	create_tween().tween_property(_callback, "modulate:a", 1.0, 0.15)


# ── The end card ───────────────────────────────────────────────────────

func _show_end_card() -> void:
	_drop_end_card()
	_end_card = Control.new()
	_end_card.name = "EndCard"
	_end_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_end_card)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_card.add_child(centre)
	var card := GoStyle.card(_accent)
	card.custom_minimum_size.x = minf(520.0, size.x - 36.0)
	centre.add_child(card)
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP))
	card.add_child(column)
	column.add_child(GoUi.icons().node(GoIconSet.SUCCESS, 44, _green))
	column.add_child(GoStyle.label("Showreel complete", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.label("%d widgets in %d looks, %.0f seconds." % [_plan.size(), PRESETS.size(), seconds],
		GoTheme.ROLE_BODY, GoUi.color(GoTheme.SECONDARY)))
	column.add_child(GoStyle.divider())
	var again := GoStyle.button("Replay", _play, GoStyle.Tone.PRIMARY)
	again.name = "Replay"
	again.custom_minimum_size.y = 48
	column.add_child(again)
	again.grab_focus()


func _drop_end_card() -> void:
	if is_instance_valid(_end_card):
		_end_card.hide()
		_end_card.queue_free()
	_end_card = null


# ── Window ─────────────────────────────────────────────────────────────

## One 16:9 canvas whatever the window: 1280×720 logical, so a 1920×1080 movie is a clean 1.5×.
func _configure_window() -> void:
	TranslationServer.set_locale("en")
	Input.use_accumulated_input = false
	var window := get_window()
	_window_state = {"mode": window.content_scale_mode, "aspect": window.content_scale_aspect,
		"size": window.content_scale_size, "factor": window.content_scale_factor}
	if DisplayServer.get_name() == "headless" and window.size == Vector2i(64, 64):
		window.size = Vector2i(1920, 1080)
	if OS.has_feature("movie"):
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = Vector2i(1920, 1080)
		window.content_scale_factor = 1.5
	else:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_size = CANVAS
		window.content_scale_factor = 1.0


func _restore_window() -> void:
	if _window_state.is_empty() or not is_inside_tree(): return
	var window := get_window()
	if window == null: return
	window.content_scale_mode = _window_state.mode
	window.content_scale_aspect = _window_state.aspect
	window.content_scale_size = _window_state.size
	window.content_scale_factor = _window_state.factor


# ── Backdrop ───────────────────────────────────────────────────────────

func _draw() -> void:
	var view := size
	var bg := BG if ThemePicker.active_preset == GoThemePresets.DEFAULT_DARK else GoUi.color(GoTheme.BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, view), bg)
	var dot := Color(_accent, 0.05)
	var x := 18.0
	while x < view.x:
		var y := 18.0
		while y < view.y:
			draw_circle(Vector2(x, y), 1.1, dot)
			y += 36.0
		x += 36.0
	_glow(Vector2(view.x * 0.16, view.y * 0.10), 380.0, _accent)
	_glow(Vector2(view.x * 0.88, view.y * 0.94), 340.0, VIOLET if ThemePicker.active_preset == GoThemePresets.DEFAULT_DARK else _green)


func _glow(centre: Vector2, radius: float, color: Color) -> void:
	for ring in range(16, 0, -1):
		draw_circle(centre, radius * float(ring) / 16.0, Color(color, 0.0028))
