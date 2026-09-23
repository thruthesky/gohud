## 🔘 **Buttons from the icon library** — every way gohud puts an icon on a button, drawn from the 1,000 names of
## `GoIconLibrary`. Attach to the Control root in `icon_buttons.tscn`, or open that scene:
##
## ```
## godot res://addons/gohud/examples/icon_buttons/icon_buttons.tscn
## ```
##
## | Section | Call |
## |---|---|
## | Icon-only buttons in a toolbar | `GoStyle.icon_button(GoIconLibrary.CAMERA, action, -1, &"Screenshot")` |
## | Text and an icon | `GoStyle.button(…)` + `GoStyle.apply_icon(button, GoIconLibrary.DEVICE_GAMEPAD)` |
## | A toggle whose icon follows the state | `GoIconButton.icon_name = GoIconLibrary.MUSIC_OFF` |
## | List rows for a menu | `GoStyle.list_button(GoIconLibrary.BELL_RINGING, "Notifications", …)` |
## | A segmented choice | `GoStyle.segmented([{"icon": GoIconLibrary.CLOUD_RAIN, "tooltip": "Rain"}, …], 0, action, false, true)` |
## | A whole group as buttons | `GoUi.icons().names_in_group(&"weather")` |
## | Buttons found by words | `GoUi.icons().search("arrow")` |
##
## 🛑 **Add the library before the first button is built** — `GoStyle.apply_icon()` looks the texture up the moment
##    it is called, so a button made before `GoUi.add_icons()` keeps an empty icon. `GoIconButton` redraws itself when
##    the settings change, but a plain `Button` does not.
## 🔑 Only what is drawn is read from disk: this screen touches a few dozen of the 1,000 files, not all of them.
extends Control

## How many buttons a search may show — a word like "arrow" matches dozens.
const SEARCH_LIMIT := 24

var _log: Label
var _sound: GoIconButton
var _bell: GoIconButton
var _muted := false
var _quiet := false
var _found: HFlowContainer
var _found_count: Label


func _ready() -> void:
	name = "IconButtons"
	# Keep a look picked elsewhere (the preview launcher's `--preset`); otherwise use the default.
	if GoUi.config.preset.is_empty():
		GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	# 🔑 One line: 1,000 more names, and the game set's 187 the library falls back to. It sits in
	#    `GoConfig.extra_icons`, which `use_preset()` keeps — switch to medieval later and the engravings stay on top.
	GoUi.add_icons(GoIconLibrary.icon_set())

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 🛑 Assemble form → scroll → page before the form enters the tree — the form finds its scroll in `_ready`.
	var form := GoForm.new()
	form.name = "Form"
	var scroll := GoScroll.new()
	scroll.name = "Scroll"
	form.add_child(scroll)
	var page := GoStyle.column()
	page.name = "Page"
	scroll.add_child(page)
	page.add_child(GoStyle.label("Buttons from the icon library", GoTheme.ROLE_TITLE))
	page.add_child(GoStyle.label("%d names can be drawn now — press anything below."
		% GoUi.icons().icon_names().size(), GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	_log = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SUCCESS))
	_log.name = "Log"
	page.add_child(_log)

	_build_toolbar(page)
	_build_text_buttons(page)
	_build_toggles(page)
	_build_menu(page)
	_build_segmented(page)
	_build_group(page)
	_build_search(page)
	add_child(form)


# ── 1. Icon-only buttons ───────────────────────────────────────────────

func _build_toolbar(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("Icon-only buttons — a toolbar", false))
	var toolbar := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	toolbar.name = "Toolbar"
	var buttons: Array[Control] = []
	# ♿ The last argument is the tooltip — on an icon-only button it is also the name a screen reader says.
	for spec in [[GoIconLibrary.DEVICE_GAMEPAD, &"Controller"], [GoIconLibrary.CAMERA, &"Screenshot"],
			[GoIconLibrary.MUSIC, &"Music"], [GoIconLibrary.WIFI, &"Network"], [GoIconLibrary.CALENDAR, &"Events"],
			[GoIconLibrary.CLOUD_DOWNLOAD, &"Download"]]:
		var button := GoStyle.icon_button(spec[0], _say.bind(String(spec[1])), -1, spec[1])
		toolbar.add_child(button)
		buttons.append(button)
	# 🔑 Side by side, the widened touch areas overlap — the nearer centre takes the press.
	for button: GoIconButton in buttons:
		button.touch_peers = buttons
	page.add_child(toolbar)


# ── 2. Text and an icon ────────────────────────────────────────────────

func _build_text_buttons(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("Text and an icon", false))
	var line := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	line.name = "TextButtons"
	for spec in [["Play", GoIconLibrary.DEVICE_GAMEPAD, GoStyle.Tone.PRIMARY],
			["Messages", GoIconLibrary.MESSAGES, GoStyle.Tone.NORMAL],
			["Share", GoIconLibrary.SCREEN_SHARE, GoStyle.Tone.COMPACT],
			["Delete save", GoIconLibrary.TRASH_X, GoStyle.Tone.DANGER]]:
		var button := GoStyle.button(spec[0], _say.bind(String(spec[0]).to_lower()), spec[2])
		# The icon takes the button's own icon colour, so it follows the tone (white on primary, red on danger).
		GoStyle.apply_icon(button, spec[1])
		line.add_child(button)
	page.add_child(line)


# ── 3. A toggle whose icon follows the state ───────────────────────────

func _build_toggles(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("A toggle — the icon follows the state", false))
	var line := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	line.name = "Toggles"
	_sound = GoStyle.icon_button(GoIconLibrary.MUSIC, _toggle_sound, -1, &"Music is on")
	_sound.name = "SoundToggle"
	_bell = GoStyle.icon_button(GoIconLibrary.BELL_RINGING, _toggle_bell, -1, &"Notifications are on")
	_bell.name = "BellToggle"
	var pair: Array[Control] = [_sound, _bell]
	_sound.touch_peers = pair
	_bell.touch_peers = pair
	line.add_child(_sound)
	line.add_child(_bell)
	page.add_child(line)


func _toggle_sound() -> void:
	_muted = not _muted
	# 🔑 Changing the name is the whole job — the button reads the new drawing from the icon set itself.
	_sound.icon_name = GoIconLibrary.MUSIC_OFF if _muted else GoIconLibrary.MUSIC
	_sound.tooltip_text_name = &"Music is off" if _muted else &"Music is on"
	_say("music %s" % ("off" if _muted else "on"))


func _toggle_bell() -> void:
	_quiet = not _quiet
	_bell.icon_name = GoIconLibrary.BELL_OFF if _quiet else GoIconLibrary.BELL_RINGING
	_bell.tooltip_text_name = &"Notifications are off" if _quiet else &"Notifications are on"
	_say("notifications %s" % ("off" if _quiet else "on"))


# ── 4. List rows ───────────────────────────────────────────────────────

func _build_menu(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("List rows — a settings menu", false))
	# Rows sit `GAP_SMALL` apart — more than the space between a row's own two lines, so each row reads as one.
	var menu := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	menu.name = "Menu"
	for spec in [[GoIconLibrary.BELL_RINGING, "Notifications", "Sounds, badges and banners"],
			[GoIconLibrary.DEVICE_GAMEPAD, "Controls", "Buttons, stick and vibration"],
			[GoIconLibrary.SHIELD_LOCK, "Privacy", "Who can see your profile"],
			[GoIconLibrary.CLOUD_UPLOAD, "Cloud saves", ""]]:
		# `translate = false` — these are words, not translation keys. The trailing chevron says "a next screen follows".
		menu.add_child(GoStyle.list_button(spec[0], spec[1], _say.bind(String(spec[1]).to_lower()),
			Color.TRANSPARENT, spec[2], false, GoIconSet.CHEVRON_RIGHT))
	page.add_child(menu)


# ── 5. A segmented choice ──────────────────────────────────────────────

func _build_segmented(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("A segmented choice — icons alone need a tooltip", false))
	var weather := [GoIconLibrary.CLOUD_RAIN, GoIconLibrary.CLOUD_SNOW, GoIconLibrary.CLOUD_STORM, GoIconLibrary.SUNRISE]
	var titles := ["Rain", "Snow", "Storm", "Clear"]
	var options: Array = []
	for index in weather.size():
		options.append({"icon": weather[index], "tooltip": titles[index]})
	# 🔑 `compact` (last argument) — icon-only cells need no text room. The default cell is 1.5× the touch size, and four
	#    of them (288dp) pushed a 320dp phone's page off the screen.
	var choice := GoStyle.segmented(options, 0, func(index: int) -> void: _say("weather: %s" % titles[index].to_lower()),
		false, true)
	choice.name = "Weather"
	page.add_child(choice)


# ── 6. A whole group as buttons ────────────────────────────────────────

func _build_group(page: VBoxContainer) -> void:
	var icons := GoUi.icons()
	page.add_child(GoStyle.section("A whole group — %s" % icons.group_title(&"weather"), false))
	var line := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	line.name = "WeatherGroup"
	var buttons: Array[Control] = []
	# 🔑 Groups are data on the icon set, so the screen never lists names by hand — add a drawing to the group and it
	#    shows up here. The icon name doubles as the tooltip.
	for icon in icons.names_in_group(&"weather"):
		var button := GoStyle.icon_button(StringName(icon), _say.bind(icon), -1, StringName(icon))
		line.add_child(button)
		buttons.append(button)
	for button: GoIconButton in buttons:
		button.touch_peers = buttons
	page.add_child(line)


# ── 7. Buttons found by words ──────────────────────────────────────────

func _build_search(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("Buttons found by words", false))
	var field := GoStyle.line_edit("arrow, rain, sword …")
	field.name = "Search"
	field.text = "arrow"
	field.text_changed.connect(_show_found)
	page.add_child(GoInputGroup.make(field, {"prefix_icon": GoIconSet.SEARCH}))
	_found_count = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	_found_count.name = "FoundCount"
	page.add_child(_found_count)
	_found = GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	_found.name = "Found"
	page.add_child(_found)
	_show_found(field.text)


func _show_found(words: String) -> void:
	for child in _found.get_children():
		child.queue_free()
	# Best matches first — the whole name, then a name an alias leads to (`arrow left` finds `back`), then parts of names.
	var names := GoUi.icons().search(words, SEARCH_LIMIT)
	_found_count.text = "%d buttons for \"%s\"" % [names.size(), words] if not words.strip_edges().is_empty() else ""
	var buttons: Array[Control] = []
	for icon in names:
		var button := GoStyle.icon_button(StringName(icon), _say.bind(icon), -1, StringName(icon))
		_found.add_child(button)
		buttons.append(button)
	for button: GoIconButton in buttons:
		button.touch_peers = buttons


func _say(what: String) -> void:
	_log.text = "Pressed: %s" % what
