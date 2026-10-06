## 🎬 **The YouTube reel** — every gohud theme, fifteen widgets each, cut for a 1920×1080 movie.
##
## Each theme gets five seconds: its name across the top, then five pages of three widgets, one second a page.
## Every preset in `themes/presets/` is shown — the built-in families first, then the rest in alphabetical order,
## dark before light — so a theme `tools/new_theme.py` adds joins the reel with no code change. Dark presets show one
## set of fifteen widgets and light presets another, so a family shows thirty.
##
## ```
## bash run.sh                          # watch it in a 1920×1080 window (loops)
## bash run.sh --record /tmp/reel.avi   # record it at 1920×1080 · 60 fps, then quit
## bash run.sh -- --themes=kids_light,arcade_dark   # only these presets (a quick look while tuning a theme)
## ```
##
## The canvas is 1280×720 logical, so a 1920×1080 window or movie is a clean 1.5×. Nothing here is input-driven:
## the widgets move on timers (bars take damage, slots cool down, a name is typed) so no page is a still.
extends Control

const INTRO_SECONDS := 2.0
const PAGE_SECONDS := 1.0
const PAGES := 5
## The widgets' own timings (a bar takes damage at 0.6 s, a name is typed letter by letter) are written for a
## three-second page; this scales them to the page, so a faster reel still shows each move before the cut.
const TEMPO := PAGE_SECONDS / 3.0
const OUTRO_SECONDS := 2.5
const MARGIN := 44
## Families whose name `capitalize()` would spell wrong.
const TITLES := {&"scifi": "Sci-fi"}

## Shown once the last theme's last page is over (and before a replay or a quit).
signal finished

var _presets: Array[StringName] = []
var _clock := 0.0
var _shown := -1
var _serial := 0        ## Bumped on every page — a timer from an older page sees the mismatch and does nothing.
var _auto_exit := false
var _done := false
var _progress: GoProgress
var _cards: HBoxContainer


func _ready() -> void:
	name = "YouTube"
	TranslationServer.set_locale("en")
	_auto_exit = OS.get_cmdline_user_args().has("--exit")
	_presets = presets()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--themes="):
			var wanted := arg.substr(9).split(",", false)
			_presets = _presets.filter(func(id: StringName) -> bool: return wanted.has(String(id)))
	var settings := GoConfig.new()
	settings.base_font_size = 18
	GoUi.config = settings
	print("YOUTUBE REEL: %d themes · %.1f s" % [_presets.size(), length()])


func _process(delta: float) -> void:
	if _done: return
	_clock += delta
	var step := _step_at(_clock)
	if step < 0:
		_finish()
		return
	if step != _shown:
		_shown = step
		_show(step)
	if is_instance_valid(_progress):
		var into := fposmod(_clock - INTRO_SECONDS, PAGE_SECONDS * PAGES)
		_progress.value = clampf(into / (PAGE_SECONDS * PAGES), 0.0, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GoUi.color(GoTheme.BACKGROUND))


## Every preset, grouped by family: the built-in ones in their own order, then the folder's, alphabetically, each
## family dark first. 🛑 Sorted as strings — `Array.sort()` on StringNames does not sort them alphabetically.
static func presets() -> Array[StringName]:
	var families: Array[String] = []
	var rest: Array[String] = []
	for id in GoThemePresets.names():
		var family := String(id).trim_suffix("_dark").trim_suffix("_light")
		if GoThemePresets.BUILTIN.has(id):
			if not families.has(family): families.append(family)
		elif not rest.has(family) : rest.append(family)
	rest.sort()
	for family in rest:
		if not families.has(family): families.append(family)
	var known := GoThemePresets.names()
	var out: Array[StringName] = []
	for family in families:
		for tone in ["_dark", "_light"]:
			var id := StringName(family + tone)
			if known.has(id): out.append(id)
	return out


## "Sci-fi" for `scifi_dark`, "Comic" for `comic_light`.
static func family_title(preset: StringName) -> String:
	var family := StringName(String(preset).trim_suffix("_dark").trim_suffix("_light"))
	return TITLES.get(family, String(family).capitalize())


## How long the whole reel runs, in seconds.
func length() -> float:
	return INTRO_SECONDS + _presets.size() * PAGES * PAGE_SECONDS + OUTRO_SECONDS


## 0 is the intro, 1… are the pages in order, the one after the last page is the outro, and -1 means it is over.
func _step_at(seconds: float) -> int:
	if seconds < INTRO_SECONDS: return 0
	var page := int(floor((seconds - INTRO_SECONDS) / PAGE_SECONDS))
	var pages := _presets.size() * PAGES
	if page < pages: return 1 + page
	if seconds < length(): return 1 + pages
	return -1


func _finish() -> void:
	_done = true
	finished.emit()
	print("YOUTUBE REEL: done — %.1f s" % _clock)
	if _auto_exit:
		get_tree().quit(0)
		return
	# Watching in a window: go round again.
	_clock = 0.0
	_shown = -1
	_done = false


# ── Screens ────────────────────────────────────────────────────────────

func _show(step: int) -> void:
	_serial += 1
	if step == 0:
		_wear(GoThemePresets.DEFAULT_DARK)
		_card_screen("gohud", "One UI kit · every theme", true)
		return
	if step > _presets.size() * PAGES:
		_wear(GoThemePresets.DEFAULT_DARK)
		_card_screen("gohud", "Game UI for Godot 4 · MIT · github.com/thruthesky/gohud", false)
		return
	var page := step - 1
	var index := page / PAGES
	var part := page % PAGES
	var preset := _presets[index]
	if part == 0 or not is_instance_valid(_cards):
		_wear(preset)
		_theme_screen(index, preset)
	_fill(preset, part)


## Puts the whole screen in [param preset]: everything built so far goes, since widgets keep the theme they were
## built with.
func _wear(preset: StringName) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_progress = null
	_cards = null
	GoUi.use_preset(preset)
	theme = GoUi.theme()
	queue_redraw()


func _card_screen(title: String, subtitle: String, intro: bool) -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := GoStyle.column(18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	var big := GoStyle.label(title, GoTheme.ROLE_TITLE, GoUi.color(GoTheme.ACCENT))
	big.add_theme_font_size_override(&"font_size", 96)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GoStyle.natural_width(big)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(big)
	var line := GoStyle.label(subtitle, GoTheme.ROLE_SUBTITLE)
	line.add_theme_font_size_override(&"font_size", 28)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GoStyle.natural_width(line)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(line)
	if intro:
		var names := GoStyle.row(10)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		var seen: Array[String] = []
		for preset in _presets:
			var family := family_title(preset)
			if seen.has(family): continue
			seen.append(family)
			names.add_child(GoStyle.chip(family, GoUi.color(GoTheme.ACCENT)))
		column.add_child(names)
	_enter(column, 0.0)


## The frame a theme keeps for its nine seconds: its name, dark or light, where in the reel, and a bar that fills.
func _theme_screen(index: int, preset: StringName) -> void:
	var frame := GoStyle.padding(MARGIN, 26)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var column := GoStyle.column(16)
	frame.add_child(column)

	var head := GoStyle.row(16)
	column.add_child(head)
	var names := GoStyle.column(2)
	head.add_child(names)
	names.add_child(GoStyle.label("THEME %d OF %d" % [index + 1, _presets.size()], GoTheme.ROLE_CAPTION,
		GoUi.color(GoTheme.MUTED)))
	var title_row := GoStyle.row(16)
	names.add_child(title_row)
	var title := GoStyle.label(family_title(preset) + " theme", GoTheme.ROLE_TITLE)
	title.add_theme_font_size_override(&"font_size", 44)
	GoStyle.natural_width(title)
	title_row.add_child(title)
	var light := String(preset).ends_with("_light")
	var tone := GoStyle.chip("Light" if light else "Dark", GoUi.color(GoTheme.ACCENT), false,
		GoIconSet.SUN if light else GoIconSet.MOON)
	tone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(tone)
	head.add_child(GoStyle.spacer())
	var right := GoStyle.column(2)
	right.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(right)
	var id := GoStyle.label(String(preset), GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	id.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GoStyle.natural_width(id)
	id.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(id)

	_progress = GoProgress.linear()
	_progress.wavy = false
	column.add_child(_progress)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 20)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_cards)

	var foot := GoStyle.row(8)
	for text in ["gohud — game UI for Godot 4", "github.com/thruthesky/gohud"]:
		var words := GoStyle.label(text, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
		GoStyle.natural_width(words)
		foot.add_child(words)
		if foot.get_child_count() == 1: foot.add_child(GoStyle.spacer())
	column.add_child(foot)
	_enter(head, 0.0)


## One page: three cards side by side, each a widget with its name and the class or function behind it.
func _fill(preset: StringName, part: int) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var light := String(preset).ends_with("_light")
	var specs := _set_b() if light else _set_a()
	for slot in 3:
		var spec: Array = specs[part * 3 + slot]
		var card := GoStyle.card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		card.custom_minimum_size.x = 0.0
		_cards.add_child(card)
		var body := GoStyle.column(12)
		card.add_child(body)
		body.add_child(GoStyle.label(spec[0], GoTheme.ROLE_SUBTITLE))
		body.add_child(GoStyle.label(spec[1], GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
		body.add_child(GoStyle.divider())
		var widget: Control = (spec[2] as Callable).call()
		body.add_child(widget)
		_enter(card, slot * 0.08)


## Fades in and settles from a touch smaller — a cut every three seconds reads as a flicker without it.
func _enter(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.96, 0.96)
	node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)
	var tween := node.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 1.0, 0.25 * TEMPO).set_delay(delay * TEMPO)
	tween.tween_property(node, "scale", Vector2.ONE, 0.3 * TEMPO).set_delay(delay * TEMPO)


## Runs [param action] [param seconds] into this page (on the three-second clock — see `TEMPO`), unless the page has
## gone by then.
func _later(seconds: float, action: Callable) -> void:
	var serial := _serial
	get_tree().create_timer(seconds * TEMPO, false).timeout.connect(func() -> void:
		if serial == _serial and not _done: action.call())


# ── The widgets ────────────────────────────────────────────────────────
# Each entry is [name, what it is made with, builder]. Set A goes with dark presets, set B with light ones.

func _set_a() -> Array:
	return [
		["Status bars", "GoBar", _bars],
		["Buttons", "GoStyle.button · icon_button", _buttons],
		["Quick slots", "GoSlot", _slots],
		["Settings", "toggle · checkbox · slider · select", _settings],
		["Choices", "segmented · tabs · radio_group", _choices],
		["Alerts", "GoStyle.alert", _alerts],
		["Stat radar", "GoRadar", _radar],
		["Text fields", "GoField · GoSearchBar", _fields],
		["Chips & avatars", "chip · filter_chip · GoBadge", _chips],
		["Joystick", "GoJoystick", _joystick],
		["Wheel picker", "GoWheelPicker", _wheel],
		["Split, combo & group", "GoSplitButton · GoCombobox · GoInputGroup", _split],
		["Waiting & empty", "GoSpinner · GoNotice · empty_state", _waiting],
		["Folding sections", "GoStyle.foldable · section", _folding],
		["Key hints", "GoKbd", _keys],
	]


func _set_b() -> Array:
	return [
		["Donut chart", "GoDonut", _donut],
		["List rows", "GoStyle.list_button", _list_rows],
		["Progress", "GoProgress · GoLoadingIndicator", _progress_page],
		["Inventory", "GoSlotGrid · item_card", _inventory],
		["Prompts", "GoPromptCard · GoBanner", _prompts],
		["Navigation", "GoNavBar · GoFab · toolbar", _navigation],
		["Leaderboard", "GoTable", _table],
		["Ranges & codes", "GoRangeSlider · GoCodeInput", _ranges],
		["Daily rewards", "GoRewardCalendar", _calendar],
		["App bar", "GoAppBar", _app_bar],
		["Stepper", "GoStepper", _stepper],
		["Tab view", "GoTabView", _tab_view],
		["Rows you drag", "GoReorderList · GoSwipeRow", _drag_rows],
		["Swatches & choices", "choice_grid · GoChoiceColumn", _swatches],
		["Date picker", "GoDatePicker", _date],
	]


func _bars() -> Control:
	var box := GoStyle.column(18)
	var bars: Array[GoBar] = []
	for spec in [["HP", 420, 500, GoTheme.DANGER], ["MP", 90, 120, GoTheme.INFO], ["XP", 35, 100, GoTheme.WARNING],
			["Stamina", 70, 100, GoTheme.SUCCESS]]:
		var bar := GoBar.new()
		bar.label_text = spec[0]
		bar.ink = GoUi.color(spec[3])
		if spec[0] == "XP": bar.readout = GoBar.Readout.PERCENT
		bar.set_values(spec[1], spec[2], false)
		box.add_child(bar)
		bars.append(bar)
	_later(0.6, func() -> void:
		bars[0].set_values(160, 500)
		bars[3].set_values(25, 100))
	_later(1.5, func() -> void:
		bars[2].set_values(85, 100)
		bars[1].set_values(30, 120))
	_later(2.2, func() -> void: bars[0].set_values(470, 500))
	return box


func _buttons() -> Control:
	var box := GoStyle.column(12)
	box.add_child(GoStyle.glow(GoStyle.button("Start game", Callable(), GoStyle.Tone.PRIMARY)))
	box.add_child(GoStyle.button("Continue"))
	box.add_child(GoStyle.button("Options", Callable(), GoStyle.Tone.OUTLINED))
	box.add_child(GoStyle.button("Quit", Callable(), GoStyle.Tone.DANGER_SOLID))
	var icons := GoStyle.row(4)
	for icon in [GoIconSet.SETTINGS, GoIconSet.SEARCH, GoIconSet.HEART, GoIconSet.BELL, GoIconSet.TRASH]:
		icons.add_child(GoStyle.icon_button(icon, Callable(), -1, icon))
	box.add_child(icons)
	return box


func _slots() -> Control:
	var box := GoStyle.column(14)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	var made: Array[GoSlot] = []
	var specs := [[GoIconSet.POTION, 12, "1"], [GoIconSet.SWORD, -1, "2"], [GoIconSet.SHIELD, -1, "3"],
		[GoIconSet.BOLT, 3, "4"], [GoIconSet.BAG, -1, "Q"], [GoIconSet.COIN, 999, "E"], [GoIconSet.KEY, 2, "R"],
		[GoIconSet.MAP, -1, "M"]]
	for spec in specs:
		var slot := GoSlot.new()
		slot.icon_name = spec[0]
		slot.quantity = spec[1] if spec[1] >= 0 else GoSlot.NONE
		slot.shortcut_label = spec[2]
		grid.add_child(slot)
		made.append(slot)
	made[1].selected = true
	box.add_child(grid)
	box.add_child(GoStyle.label("Counts, key hints and cooldowns on one face.", GoTheme.ROLE_CAPTION,
		GoUi.color(GoTheme.MUTED)))
	_later(0.4, func() -> void:
		made[3].start_cooldown(2.2)
		made[0].quantity = 11)
	_later(0.9, func() -> void:
		made[0].start_cooldown(1.6)
		made[1].selected = false
		made[2].selected = true)
	return box


func _settings() -> Control:
	var box := GoStyle.column(12)
	var music := GoStyle.toggle("Music", false)
	music.button_pressed = true
	box.add_child(music)
	var vibration := GoStyle.toggle("Vibration", false)
	box.add_child(vibration)
	var numbers := GoStyle.checkbox("Show damage numbers", false)
	numbers.button_pressed = true
	box.add_child(numbers)
	box.add_child(GoStyle.label("Volume", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	var volume := GoStyle.slider(0.0, 1.0, 0.01)
	volume.value = 0.35
	box.add_child(volume)
	box.add_child(GoStyle.select(["Low quality", "Medium quality", "High quality"]))
	(box.get_child(box.get_child_count() - 1) as OptionButton).select(2)
	_later(0.7, func() -> void: vibration.button_pressed = true)
	_later(1.0, func() -> void:
		volume.create_tween().tween_property(volume, "value", 0.85, 1.2 * TEMPO).set_trans(Tween.TRANS_SINE))
	return box


func _choices() -> Control:
	var box := GoStyle.column(16)
	var range_row := GoStyle.segmented(["Day", "Week", "Month"], 0)
	box.add_child(range_row)
	var tabs := GoStyle.tabs(["Overview", "Stats", "Gear"], 0, false, true)
	box.add_child(tabs)
	var radios := GoStyle.radio_group(["Easy", "Normal", "Hard"], 1)
	box.add_child(radios)
	_later(0.8, func() -> void:
		var week := range_row.get_child(1) as Button
		if week != null: week.button_pressed = true)
	_later(1.4, func() -> void: tabs.current_tab = 2)
	_later(2.0, func() -> void:
		var hard := radios.get_child(2) as Button
		if hard != null: hard.button_pressed = true)
	return box


func _alerts() -> Control:
	var box := GoStyle.column(10)
	box.add_child(GoStyle.alert("Progress saved to the cloud.", GoTheme.SUCCESS))
	box.add_child(GoStyle.alert("A new season starts on Friday.", GoTheme.INFO))
	box.add_child(GoStyle.alert("Low on potions.", GoTheme.WARNING))
	box.add_child(GoStyle.alert("Connection lost. Retrying…", GoTheme.DANGER))
	return box


func _radar() -> Control:
	var stats := {"STR": 0.85, "AGI": 0.5, "INT": 0.35, "VIT": 0.7, "LUK": 0.45}
	var radar := GoRadar.make(stats, {"STR": 0.6, "AGI": 0.72, "INT": 0.55, "VIT": 0.5, "LUK": 0.62})
	radar.custom_minimum_size = Vector2(0, 290)
	_later(1.2, func() -> void: radar.set_values({"STR": 0.7, "AGI": 0.8, "INT": 0.6, "VIT": 0.65, "LUK": 0.7}))
	return radar


func _fields() -> Control:
	var box := GoStyle.column(12)
	var name_edit := GoStyle.line_edit("Your name")
	box.add_child(GoField.make("Nickname", name_edit, "3–12 letters"))
	var email := GoStyle.line_edit("you@example.com")
	email.text = "ann@example"
	var email_field := GoField.make("Email", email)
	box.add_child(email_field)
	box.add_child(GoSearchBar.make("Search items"))
	var typed := "Laryen"
	for count in typed.length():
		_later(0.3 + count * 0.12, func() -> void: name_edit.text = typed.substr(0, count + 1))
	_later(1.4, func() -> void: email_field.set_error("Add the rest of the address"))
	return box


func _chips() -> Control:
	var box := GoStyle.column(14)
	var people := GoStyle.row(10)
	for initials in ["AK", "JS", "MR"]:
		people.add_child(GoStyle.avatar(initials, 44))
	var bell := GoStyle.icon_button(GoIconSet.BELL, Callable(), -1, &"Alerts")
	people.add_child(bell)
	box.add_child(people)
	GoBadge.attach(bell, 3)
	var tags := GoStyle.wrap_row(8)
	tags.add_child(GoStyle.chip("Rare", GoUi.color(GoTheme.INFO)))
	tags.add_child(GoStyle.chip("Epic", GoUi.color(GoTheme.ACCENT)))
	tags.add_child(GoStyle.chip("Sold out", GoUi.color(GoTheme.DANGER)))
	box.add_child(tags)
	var filters := GoStyle.wrap_row(8)
	var stock := GoStyle.filter_chip("In stock", true)
	filters.add_child(stock)
	var sale := GoStyle.filter_chip("On sale", false)
	filters.add_child(sale)
	box.add_child(filters)
	var to := GoStyle.wrap_row(8)
	to.add_child(GoStyle.input_chip("Ann", Callable(), GoIconSet.USER))
	to.add_child(GoStyle.input_chip("Ben", Callable(), GoIconSet.USER))
	box.add_child(to)
	_later(1.0, func() -> void:
		if sale is BaseButton: (sale as BaseButton).button_pressed = true
		GoBadge.attach(bell, 4))
	return box


func _donut() -> Control:
	var box := GoStyle.column(12)
	var donut := GoDonut.make([{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340},
		{"label": "Fire", "value": 180}, {"label": "Poison", "value": 90}])
	donut.center_text = "1,230"
	donut.center_hint = "damage"
	donut.custom_minimum_size = Vector2(0, 220)
	box.add_child(donut)
	box.add_child(donut.legend())
	return box


func _list_rows() -> Control:
	var box := GoStyle.column(6)
	box.add_child(GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "Level 42 · Ranger", false))
	box.add_child(GoStyle.list_button(GoIconSet.SETTINGS, "Settings", Callable(), Color.TRANSPARENT,
		"Sound, display, controls", false))
	box.add_child(GoStyle.list_button(GoIconSet.BELL, "Notifications", Callable(), Color.TRANSPARENT, "3 new", false))
	box.add_child(GoStyle.list_button(GoIconSet.SHIELD, "Privacy", Callable(), Color.TRANSPARENT, "", false))
	box.add_child(GoStyle.list_button(GoIconSet.LOGOUT, "Sign out", Callable(), GoUi.color(GoTheme.DANGER), "", false))
	return box


func _progress_page() -> Control:
	var box := GoStyle.column(16)
	var caption := GoStyle.label("Downloading 10%", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	box.add_child(caption)
	var line := GoProgress.linear()
	line.value = 0.1
	box.add_child(line)
	var rings := GoStyle.row(24)
	var ring := GoProgress.circular()
	ring.value = 0.65
	rings.add_child(ring)
	rings.add_child(GoProgress.circular(true))
	var morph := GoLoadingIndicator.new()
	morph.contained = true
	rings.add_child(morph)
	box.add_child(rings)
	box.add_child(GoStyle.label("Waiting", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	box.add_child(GoProgress.linear(true))
	box.add_child(GoStyle.skeleton(0, 14))
	box.add_child(GoStyle.skeleton(180, 14))
	var tween := line.create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(line, "value", 0.95, 2.6 * TEMPO)
	tween.parallel().tween_method(func(value: float) -> void:
		caption.text = "Downloading %d%%" % int(round(value * 100.0)), 0.1, 0.95, 2.6 * TEMPO)
	ring.create_tween().tween_property(ring, "value", 1.0, 2.4 * TEMPO)
	return box


func _inventory() -> Control:
	var box := GoStyle.column(12)
	var grid := GoSlotGrid.new()
	grid.slot_count = 10
	grid.cell_size = 56
	var cells := [{"icon": GoIconSet.POTION, "quantity": 12}, {"icon": GoIconSet.SWORD},
		{"icon": GoIconSet.SHIELD}, {"icon": GoIconSet.COIN, "quantity": 250}, {"icon": GoIconSet.KEY, "quantity": 2},
		{"icon": GoIconSet.BOOK}, {"icon": GoIconSet.GIFT}]
	for index in cells.size(): grid.set_cell(index, cells[index])
	grid.selected = 1
	box.add_child(grid)
	box.add_child(GoStyle.item_card({"icon": GoIconSet.SWORD, "title": "Iron sword", "subtitle": "One-handed · level 12",
		"chips": [{"text": "Rare", "ink": GoUi.color(GoTheme.INFO)}, "Tradable"],
		"stats": [["Attack", "+12"], ["Weight", "3.5"]]}, false))
	_later(1.3, func() -> void: grid.selected = 2)
	return box


func _prompts() -> Control:
	var box := GoStyle.column(14)
	var invite := GoPromptCard.new()
	invite.set_title("Party invite from Ann")
	invite.set_subtitle("Ruins of Erel · 3 of 4 players")
	invite.set_icon(GoIconSet.USERS, Color.TRANSPARENT, true)
	invite.set_actions([{"text": "Join", "action": Callable(), "primary": true}, {"text": "Later", "action": Callable()}])
	invite.set_closable(true)
	box.add_child(invite)
	invite.show()   # A prompt card starts hidden and fades in when shown.
	box.add_child(GoBanner.make("You're offline. Progress will sync later.", [{"text": "Retry", "action": Callable()}],
		GoIconSet.WARNING))
	return box


func _navigation() -> Control:
	var box := GoStyle.column(16)
	var nav := GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"}, {"icon": GoIconSet.MAP, "text": "Quests"},
		{"icon": GoIconSet.BAG, "text": "Bag", "badge": 3}, {"icon": GoIconSet.USER, "text": "Me"}], 0)
	nav.safe_area = false
	box.add_child(nav)
	var actions := GoStyle.row(12)
	actions.add_child(GoStyle.toolbar([{"icon": GoIconSet.EDIT, "tooltip": &"Edit"},
		{"icon": GoIconSet.COPY, "tooltip": &"Copy"}, {"icon": GoIconSet.TRASH, "tooltip": &"Delete"}]))
	box.add_child(actions)
	var fab := GoFab.make(GoIconSet.PLUS, "New quest")
	fab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(fab)
	box.add_child(GoStyle.breadcrumb(["Home", "Shop", "Swords"]))
	_later(1.2, func() -> void: nav.set_selected(2))
	return box


func _table() -> Control:
	return GoTable.make(["Player", {"text": "Level", "numeric": true}, {"text": "Score", "numeric": true}],
		[["Cleo", 51, 12040], ["Eve", 47, 10233], ["Ann", 42, 9124], ["Ben", 38, 8710], ["Dan", 29, 4302]], false)


func _ranges() -> Control:
	var box := GoStyle.column(14)
	var price_label := GoStyle.label("Price 40 – 220", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	box.add_child(price_label)
	var price := GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)
	box.add_child(price)
	box.add_child(GoStyle.label("Gift code", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	var code := GoCodeInput.make(8, 4)
	box.add_child(code)
	var typed := "GOHUD026"
	for count in typed.length():
		_later(0.4 + count * 0.12, func() -> void: code.set_code(typed.substr(0, count + 1)))
	_later(1.0, func() -> void:
		price.set_range(120.0, 380.0)
		price_label.text = "Price 120 – 380")
	return box


func _calendar() -> Control:
	var days := [{"icon": GoIconSet.COIN, "amount": 100}, {"icon": GoIconSet.POTION, "amount": 3},
		{"icon": GoIconSet.KEY, "amount": 1}, {"icon": GoIconSet.COIN, "amount": 300},
		{"icon": GoIconSet.GIFT, "amount": 1}, {"icon": GoIconSet.POTION, "amount": 5},
		{"icon": GoIconSet.CROWN, "amount": 1, "special": true}]
	var calendar := GoRewardCalendar.make(days, 1)
	calendar.columns = 4
	_later(1.3, func() -> void: calendar.set_claimed_until(2))
	return calendar


func _joystick() -> Control:
	var box := GoStyle.column(12)
	var pad := GoJoystick.new()
	pad.mode = GoJoystick.Mode.FIXED
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(pad)
	var readout := GoStyle.label("Direction 0.0, 0.0", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(readout)
	pad.moved.connect(func(direction: Vector2) -> void:
		readout.text = "Direction %.1f, %.1f" % [direction.x, direction.y])
	# The stick takes the mouse as well as a finger — press it and walk the knob round its ring.
	_later(0.3, func() -> void:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = pad.size * 0.5
		pad._gui_input(press)
		pad.create_tween().tween_method(func(angle: float) -> void:
			var motion := InputEventMouseMotion.new()
			motion.position = pad.size * 0.5 + Vector2.from_angle(angle) * pad.radius * 0.85
			pad._gui_input(motion), -PI / 2.0, PI * 1.5, 2.4 * TEMPO))
	return box


func _wheel() -> Control:
	var box := GoStyle.column(12)
	box.add_child(GoStyle.label("Buy how many?", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	var wheel := GoWheelPicker.make(["×1", "×5", "×10", "×50", "×100", "×500"], 1)
	wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(wheel)
	_later(0.6, func() -> void: wheel.select(3))
	_later(1.8, func() -> void: wheel.select(4))
	return box


func _split() -> Control:
	var box := GoStyle.column(16)
	var send := GoSplitButton.make("Send", Callable(), ["Send later", "Save as draft"])
	send.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(send)
	box.add_child(GoCombobox.make(["Ann", "Ben", "Cleo", "Dan", "Eve"], 2, "Find a friend"))
	box.add_child(GoInputGroup.make(GoStyle.line_edit("Message"),
		{"suffix": GoStyle.button("Send", Callable(), GoStyle.Tone.PRIMARY)}))
	return box


func _waiting() -> Control:
	var box := GoStyle.column(14)
	var buy := GoStyle.button("Buy 500 gems", Callable(), GoStyle.Tone.PRIMARY)
	box.add_child(buy)
	var notice := GoNotice.new()
	box.add_child(notice)
	box.add_child(GoStyle.empty_state(GoIconSet.BOX, "Your mailbox is empty", false))
	_later(0.3, func() -> void: GoSpinner.busy(buy, true))
	_later(0.6, func() -> void: notice.show_text("Purchase complete", GoTheme.SUCCESS, 30.0))
	_later(2.0, func() -> void: GoSpinner.busy(buy, false))
	return box


func _folding() -> Control:
	var box := GoStyle.column(10)
	box.add_child(GoStyle.section("Settings", false))
	var graphics := GoStyle.foldable("Graphics", true, null, false)
	var inside := GoStyle.column(8)
	inside.add_child(GoStyle.toggle("Shadows", false))
	inside.add_child(GoStyle.toggle("Bloom", false))
	graphics.add_child(inside)
	box.add_child(graphics)
	var audio := GoStyle.foldable("Audio", true, null, false)
	audio.add_child(GoStyle.slider())
	box.add_child(audio)
	var controls := GoStyle.foldable("Controls", true, null, false)
	controls.add_child(GoStyle.checkbox("Invert the camera", false))
	box.add_child(controls)
	_later(0.5, func() -> void: graphics.folded = false)
	_later(1.6, func() -> void:
		graphics.folded = true
		audio.folded = false)
	return box


func _keys() -> Control:
	var box := GoStyle.column(10)
	for spec in [["Save", "Ctrl", "S"], ["Interact", "E", ""], ["Previous tab", "Shift", "Tab"], ["Jump", "Space", ""],
			["Menu", "Esc", ""]]:
		var line := GoStyle.row(8)
		var words := GoStyle.label(spec[0])
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		line.add_child(GoKbd.make(spec[1], spec[2]))
		box.add_child(line)
	return box


func _app_bar() -> Control:
	var box := GoStyle.column(6)
	var bar := GoAppBar.make("Inbox", GoIconSet.MENU)
	bar.add_action(GoIconSet.SEARCH, &"Search")
	bar.add_action(GoIconSet.MORE, &"More")
	box.add_child(bar)
	box.add_child(GoStyle.list_button(GoIconSet.USER, "Ann", Callable(), Color.TRANSPARENT, "Raid at eight?", false))
	box.add_child(GoStyle.list_button(GoIconSet.GIFT, "Daily gift", Callable(), Color.TRANSPARENT, "Claim 100 coins", false))
	box.add_child(GoStyle.list_button(GoIconSet.CROWN, "Season 3", Callable(), Color.TRANSPARENT, "New ranks are in", false))
	return box


func _stepper() -> Control:
	var steps: Array = []
	for spec in [["Cart", "Two items · 1,200 coins"], ["Address", "Ruins of Erel, gate 3"], ["Pay", "Coins or gems"]]:
		steps.append({"title": spec[0], "content": GoStyle.label(spec[1], GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))})
	var stepper := GoStepper.make(steps)
	_later(0.8, func() -> void: stepper.set_step(1))
	_later(1.8, func() -> void: stepper.set_step(2))
	return stepper


func _tab_view() -> Control:
	var pages: Array = []
	for spec in [["Ann reached level 42.", GoTheme.INFO], ["3 new screenshots.", GoTheme.SUCCESS],
			["Nothing saved yet.", GoTheme.WARNING]]:
		var page := GoStyle.column(10)
		page.add_child(GoStyle.alert(spec[0], spec[1]))
		page.add_child(GoStyle.skeleton(0, 14))
		page.add_child(GoStyle.skeleton(160, 14))
		pages.append(page)
	var tabs := GoTabView.make(["Posts", "Photos", "Saved"], pages)
	tabs.custom_minimum_size.y = 240
	_later(0.7, func() -> void: tabs.set_tab(1))
	_later(1.7, func() -> void: tabs.set_tab(2))
	return tabs


func _drag_rows() -> Control:
	var box := GoStyle.column(10)
	var rows: Array = []
	for title in ["Intro theme", "Forest", "Boss battle"]:
		rows.append(GoStyle.list_button(GoIconSet.PLAY, title, Callable(), Color.TRANSPARENT, "", false))
	box.add_child(GoReorderList.make(rows))
	box.add_child(GoStyle.divider())
	box.add_child(GoSwipeRow.wrap(GoStyle.list_button(GoIconSet.CHAT, "Swipe me aside", Callable(), Color.TRANSPARENT,
		"Delete or archive", false), {"icon": GoIconSet.TRASH, "text": "Delete", "tone": GoTheme.DANGER, "action": Callable()}))
	return box


func _swatches() -> Control:
	var box := GoStyle.column(14)
	box.add_child(GoStyle.label("Skin tone", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	box.add_child(GoStyle.choice_grid([{"color": "f6cfae", "tooltip": "Peach"}, {"color": "e0ac7e", "tooltip": "Sand"},
		{"color": "c68642", "tooltip": "Honey"}, {"color": "8d5a36", "tooltip": "Cocoa"},
		{"color": "5a3825", "tooltip": "Coffee"}], 1))
	box.add_child(GoStyle.label("Summon", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	var animals := GoChoiceColumn.make(["Hen", "Cat", "Dog", "Pig", "Cow"], 5)
	animals.set_selected(1, true)
	box.add_child(animals)
	_later(0.8, func() -> void: animals.set_selected(3, true))
	return box


func _date() -> Control:
	var picker := GoDatePicker.make({"year": 2026, "month": 10, "day": 6})
	_later(0.9, func() -> void: picker.set_date({"year": 2026, "month": 10, "day": 17}))
	return picker
