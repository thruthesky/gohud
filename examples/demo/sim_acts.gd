## 🎞️ **The scene script.** A scene builds the widgets, and the bot really works them.
##
## One scene = **two** functions.
##   `build_<key>(stage, bot) -> Dictionary`  builds the screen and returns, in a dictionary, the nodes the bot will aim at.
##   `play_<key>(stage, bot, refs)`           works those nodes with real input.
##
## Why they are split — pick one widget in the sidebar and only `build_` is called, for **you** to work by hand (explore);
## press "Play this" and `play_` moves the bot over the same screen (demonstrate). There is one screen.
##
## Every action is real input, so the widgets' callbacks really fire, and each callback leaves a line in the log on the
## right — the log is the proof that "it really was pressed". Work it yourself and the same log moves.
##
## 🛑 **Never wait for a person to press something.** A call that waits for an answer, such as
##    `await dialogs.confirm(…)`, never comes back once skip is on. Answers arrive by signal.
## 🛑 `build_` has to be a complete screen even with no bot — what only a bot can do (data arriving, starting a tour)
##    is left as a button, and in `play_` the bot presses that button.
class_name SimActs
extends RefCounted

## 🔬 The container-opacity lab — it uses **the same widget as the gallery**. Rebuild the slider for every demo and only
## one of them gets fixed, and then there is no telling which is the right way to use it.
const OpacityLab := preload("res://addons/gohud/examples/gallery/opacity_lab.gd")


## The scene order. The title, note and icon are shared by the stage heading and the sidebar. `hint` is the guidance shown in explore mode.
static func list() -> Array[Dictionary]:
	return [
		{"key": &"hud", "title": "HUD & quick slots", "icon": GoIconSet.POTION,
			"note": "Live status bars and ready-to-use actions.",
			"hint": "Press a slot to start its cooldown, take damage, then rest at camp."},
		{"key": &"buttons", "title": "Buttons", "icon": GoIconSet.TARGET,
			"note": "Five styles for different priorities.",
			"hint": "Click each style. The disabled button ignores you; the counter keeps score."},
		{"key": &"inputs", "title": "Inputs", "icon": GoIconSet.EDIT,
			"note": "Type, toggle, check and drag.",
			"hint": "Type a name, flip the switch, tick the boxes and drag the volume slider."},
		{"key": &"selection", "title": "Selection & menus", "icon": GoIconSet.LIST,
			"note": "Dropdowns, menus, segments, tabs and radio buttons.",
			"hint": "Open the dropdown and the menu, switch segments and tabs, pick a difficulty."},
		{"key": &"lists", "title": "Lists & navigation", "icon": GoIconSet.MENU,
			"note": "Navigate lists and expand grouped settings.",
			"hint": "Tap breadcrumbs and list rows. Only one accordion section stays open."},
		{"key": &"data", "title": "Data display", "icon": GoIconSet.CHART,
			"note": "Avatars, chips, tables and loading placeholders.",
			"hint": "Press Load inventory to replace the placeholders with a table."},
		{"key": &"states", "title": "Status & notices", "icon": GoIconSet.BELL,
			"note": "Persistent alerts and temporary notifications.",
			"hint": "Start the download, then trigger a success and an error notice."},
		{"key": &"surfaces", "title": "Dialogs & surfaces", "icon": GoIconSet.COLUMNS,
			"note": "Confirm a choice, open a sheet and dismiss a popup.",
			"hint": "Open the dialog, the bottom sheet and the popup. Try Escape and the scrim."},
		{"key": &"prompt", "title": "Prompt cards", "icon": GoIconSet.USER_PLUS,
			"note": "An invitation that leaves the action visible.",
			"hint": "Accept or decline the invitation, then close the card with its X."},
		{"key": &"touch", "title": "Touch controls", "icon": GoIconSet.MOBILE,
			"note": "A virtual joystick and thumb-friendly action buttons.",
			"hint": "Drag the stick, switch between the three modes, press the action discs."},
		{"key": &"coach", "title": "Coach marks", "icon": GoIconSet.FLAG,
			"note": "Guide a new player through the interface.",
			"hint": "Press Start tour. Highlighted controls stay interactive during the tour."},
		{"key": &"scrolling", "title": "Scrolling & grids", "icon": GoIconSet.GRID,
			"note": "Browse long lists and layouts that adapt to width.",
			"hint": "Scroll the region list. Resize the window to watch the grid reflow."},
		{"key": &"forms", "title": "Responsive forms", "icon": GoIconSet.BOOK,
			"note": "A complete form with validation and submission.",
			"hint": "Submit the empty form first, then fill it in. Back returns to the widget list."},
		{"key": &"anchors", "title": "HUD anchors", "icon": GoIconSet.LOCATION,
			"note": "Place a HUD safely at the edges of the viewport.",
			"hint": "Move the HUD chip between corners. Back returns to the widget list."},
		{"key": &"theming", "title": "Themes & icons", "icon": GoIconSet.SUN,
			"note": "Switch between light and dark appearances.",
			"hint": "Flip the preview between dark and light. Every icon below ships with the kit."},
		{"key": &"opacity", "title": "Container opacity", "icon": GoIconSet.DISPLAY,
			"note": "Let the game show through the panels.",
			"hint": "Drag the slider and watch the stripes appear behind the panels. Text stays sharp."},
		{"key": &"waiting", "title": "Waiting & counting", "icon": GoIconSet.HOURGLASS,
			"note": "A wait with no end in sight, a message you can undo, and the unread count.",
			"hint": "Press the slow button and watch it become a spinner. Undo the message before it goes."},
		{"key": &"fields", "title": "Fields & pickers", "icon": GoIconSet.CHECK,
			"note": "A form row that says which box is wrong, and pickers that search.",
			"hint": "Submit with an empty guild name to see the error land on that row."},
		{"key": &"shapes", "title": "Shapes games use", "icon": GoIconSet.CROWN,
			"note": "Attendance, the stat pentagon, damage share and a banner.",
			"hint": "Only today can be claimed. Press the banner dots; nothing moves on its own."},
		# 🛑 New chapters go **at the end** — `sim_test.gd` opens chapters by number, and the showreel pairs
		#    chapter N with theme N % (the theme count — five today), so the count must not become a multiple of it
		#    (every chapter would wear one look only). 31 now.
		{"key": &"inventory", "title": "Inventory & items", "icon": GoIconSet.BAG,
			"note": "A bag grid in each item's colour, a detail card, and the game icon set.",
			"hint": "Filter by kind, pick an item, use it, then Move it: press Move and pick an empty space."},
		{"key": &"overlays", "title": "Popovers, menus & drawers", "icon": GoIconSet.MORE,
			"note": "A card beside what you pressed, a right-click menu, a side drawer and a cheat console.",
			"hint": "Inspect the sword, right-click (or hold) the row, open the drawer and the console."},
		{"key": &"records", "title": "Tables & pages", "icon": GoIconSet.SORT,
			"note": "Sort a leaderboard, turn pages, and pick from a long list in a tall sheet.",
			"hint": "Press Score to sort, pick a row, go to page 2, then choose a server."},
		{"key": &"choices", "title": "Pick by picture", "icon": GoIconSet.STAR,
			"note": "Swatches, choice cards, a pill over the map, and HUD buttons that leave Space to the game.",
			"hint": "Pick a colour, a difficulty card and a map layer. The HUD buttons never keep keyboard focus."},
		{"key": &"app", "title": "An app screen", "icon": GoIconSet.HOME,
			"note": "An app bar, a search bar, bottom tabs, a floating button and a drawer, wired together.",
			"hint": "Search, flip a filter chip, add to cart, open Alerts, then the menu drawer."},
		{"key": &"actions", "title": "Actions in reach", "icon": GoIconSet.BOLT,
			"note": "A banner that waits, a split button, a floating toolbar and a bottom app bar.",
			"hint": "Answer the banner, open the arrow half of Send, like a post from the toolbar."},
		{"key": &"edges", "title": "Bars on the edges", "icon": GoIconSet.EXPAND,
			"note": "Top, bottom and side bars that hold a HUD's edges, a tap-once column and an equal grid.",
			"hint": "Press the buttons on each bar and call a pet from the side column. The sheep is resting."},
		{"key": &"steps", "title": "Tabs & steps", "icon": GoIconSet.FORWARD,
			"note": "Pages you swipe between, and a checkout taken one step at a time.",
			"hint": "Tap a tab or swipe the page sideways. Walk the steps with Next and Back."},
		{"key": &"dates", "title": "Dates & times", "icon": GoIconSet.CLOCK,
			"note": "A month to tap, a clock dial, and wheels that settle on one.",
			"hint": "Pick a day, tap the hour and then the minutes on the dial, spin a wheel."},
		{"key": &"feeds", "title": "Long lists", "icon": GoIconSet.REFRESH,
			"note": "A thousand rows built as you scroll, pull to refresh, rows you swipe and a queue you drag.",
			"hint": "Pull the list down at its top. Swipe a message aside. Drag a song by its grip."},
		{"key": &"progress", "title": "Progress & ranges", "icon": GoIconSet.DOWNLOAD,
			"note": "Progress you can measure, waits you cannot, and a range with two handles.",
			"hint": "Start the download, then drag either handle of the price range."},
		{"key": &"zoom", "title": "Pinch & zoom", "icon": GoIconSet.MAP,
			"note": "A map you zoom and pan, with buttons for anyone without a wheel.",
			"hint": "Roll the wheel over the map, drag to pan, then press Reset."},
	]


## Builds a scene. Returns, in a dictionary, the nodes the bot will aim at.
func build(key: StringName, stage: SimStage, bot: SimBot) -> Dictionary:
	return Callable(self, "build_" + key).call(stage, bot)


## Moves the bot over the scene that was built.
func play(key: StringName, stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await Callable(self, "play_" + key).call(stage, bot, refs)


# ── 01 HUD bars and quick slots ────────────────────────────────────────

func build_hud(stage: SimStage, bot: SimBot) -> Dictionary:
	var bars := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	bars.custom_minimum_size.x = 176
	var hp := GoBar.new()
	hp.label_text = "HP"
	hp.ink = GoUi.color(GoTheme.DANGER)
	bars.add_child(hp)
	var mp := GoBar.new()
	mp.label_text = "MP"
	mp.ink = GoUi.color(GoTheme.INFO)
	bars.add_child(mp)
	var xp := GoBar.new()
	xp.label_text = "XP"
	xp.readout = GoBar.Readout.PERCENT
	xp.ink = GoUi.color(GoTheme.WARNING)
	bars.add_child(xp)
	stage.body.add_child(bars)
	hp.set_values(500, 500, false)
	mp.set_values(120, 120, false)
	xp.set_values(35, 100, false)

	var slots: Array[GoSlot] = []
	var slot_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	for spec in [
		{"icon": GoIconSet.POTION, "color": GoTheme.DANGER, "count": 5, "key": "1"},
		{"icon": GoIconSet.BOLT, "color": GoTheme.WARNING, "count": 3, "key": "2"},
		{"icon": GoIconSet.SHIELD, "color": GoTheme.INFO, "count": GoSlot.NONE, "key": "3"},
	]:
		var slot := GoSlot.new()
		slot.icon_name = spec.icon
		slot.accent = GoUi.color(spec.color)
		slot.quantity = spec.count
		slot.shortcut_label = spec.key
		slot.pressed.connect(func() -> void:
			if slot.quantity > 0: slot.quantity -= 1
			slot.start_cooldown(6.0)
			hp.set_values(minf(hp.value() + 140.0, 500.0), 500.0)
			xp.set_values(minf(xp.value() + 12.0, 100.0), 100.0)
			bot.note("Used %s: 6-second cooldown" % slot.icon_name))
		slot_row.add_child(slot)
		slots.append(slot)
	var peers: Array[Control] = []
	for slot in slots: peers.append(slot)
	for slot in slots: slot.touch_peers = peers
	stage.float_at(slot_row, Control.PRESET_BOTTOM_RIGHT)

	stage.body.add_child(GoStyle.label(
		"Status bars ease toward their new values. Large numbers use compact labels such as 1.2k.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var hurt := GoStyle.button("Take damage", func() -> void:
		hp.set_values(maxf(0.0, hp.value() - 160.0), 500.0)
		mp.set_values(maxf(0.0, mp.value() - 25.0), 120.0)
		bot.note("160 damage: HP %d/500" % int(hp.value())), GoStyle.Tone.DANGER)
	stage.body.add_child(hurt)
	var rest_button := GoStyle.button("Rest at camp", func() -> void:
		hp.set_values(500, 500)
		mp.set_values(120, 120)
		bot.note("Fully restored"), GoStyle.Tone.PRIMARY)
	stage.body.add_child(rest_button)
	return {"hp": hp, "mp": mp, "slots": slots, "hurt": hurt, "rest": rest_button}


func play_hud(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var slots: Array[GoSlot] = refs.slots
	var hp: GoBar = refs.hp
	var mp: GoBar = refs.mp
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Health, mana and experience sit above the quick slots.")
	if bot.skipping(): return
	await bot.wait(1.2)
	if bot.skipping(): return
	await bot.click_times(refs.hurt, 2, 0.5, "Taking damage smoothly reduces the status bars.")
	if bot.skipping(): return
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(slots[0], "Use a potion: the count drops and a cooldown begins.")
	if bot.skipping(): return
	bot.expect(slots[0].quantity == 4, "Potion consumed")
	await bot.wait(1.0)
	if bot.skipping(): return
	await bot.click(slots[1], "A cooling-down slot displays its remaining time.")
	if bot.skipping(): return
	await bot.wait(1.2)
	if bot.skipping(): return
	await bot.click(refs.rest, "Rest at camp to restore health and mana.")
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return
	bot.expect(hp.value() == 500.0 and mp.value() == 120.0, "Camp restores bars")


# ── 02 Buttons ─────────────────────────────────────────────────────────

func build_buttons(stage: SimStage, bot: SimBot) -> Dictionary:
	var made: Array[Button] = []
	var row := GoStyle.wrap_row()
	for spec in [["Primary", GoStyle.Tone.PRIMARY], ["Normal", GoStyle.Tone.NORMAL],
			["Danger", GoStyle.Tone.DANGER], ["Compact", GoStyle.Tone.COMPACT], ["Bare", GoStyle.Tone.BARE]]:
		var button := GoStyle.button(spec[0], bot.note.bind("%s button pressed" % spec[0]), spec[1])
		row.add_child(button)
		made.append(button)
	var off := GoStyle.button("Disabled")
	off.disabled = true
	row.add_child(off)
	stage.body.add_child(row)

	stage.body.add_child(GoStyle.divider())
	var icons := GoStyle.wrap_row()
	var icon_buttons: Array[Button] = []
	for icon in [GoIconSet.SETTINGS, GoIconSet.SEARCH, GoIconSet.HEART, GoIconSet.BELL, GoIconSet.TRASH]:
		var button := GoStyle.icon_button(icon, bot.note.bind("%s icon pressed" % icon))
		icons.add_child(button)
		icon_buttons.append(button)
	stage.body.add_child(icons)

	stage.body.add_child(GoStyle.divider())
	var counter := GoStyle.label("Clicks: 0", GoTheme.ROLE_SUBTITLE)
	stage.body.add_child(counter)
	var hits := {"count": 0}
	var tally := GoStyle.button("Click repeatedly", func() -> void:
		hits.count += 1
		counter.text = "Clicks: %d" % hits.count
		bot.note("Repeated click: %d" % hits.count), GoStyle.Tone.PRIMARY)
	stage.body.add_child(tally)
	return {"made": made, "off": off, "icons": icon_buttons, "tally": tally, "hits": hits}


func play_buttons(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var made: Array[Button] = refs.made
	await bot.settle()
	if bot.skipping(): return
	for index in made.size():
		await bot.click(made[index], "%s: a distinct style for this action." % made[index].text)
		if bot.skipping(): return
	await bot.click(refs.off, "Disabled buttons ignore clicks.")
	if bot.skipping(): return
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.say("Icon buttons provide a generous touch target.")
	if bot.skipping(): return
	for button in refs.icons:
		await bot.click(button)
		if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	var before: int = refs.hits.count
	await bot.click_times(refs.tally, 6, 0.16, "Repeated clicks update the counter each time.")
	if bot.skipping(): return
	bot.expect(refs.hits.count == before + 6, "All six repeated clicks registered")
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 03 Inputs ──────────────────────────────────────────────────────────

func build_inputs(stage: SimStage, bot: SimBot) -> Dictionary:
	var name_edit := GoStyle.line_edit("Adventurer name")
	name_edit.text_changed.connect(func(value: String) -> void: bot.note("Name: %s" % value))
	stage.body.add_child(name_edit)

	var haptics := GoStyle.toggle("Haptic feedback", false)
	haptics.toggled.connect(func(on: bool) -> void: bot.note("Haptics %s" % ("on" if on else "off")))
	stage.body.add_child(haptics)

	var checks := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	var boxes: Array[CheckBox] = []
	for text in ["Auto loot", "Damage numbers", "Voice chat"]:
		var box := GoStyle.checkbox(text, false)
		box.toggled.connect(func(on: bool) -> void: bot.note("%s %s" % [text, "checked" if on else "unchecked"]))
		checks.add_child(box)
		boxes.append(box)
	stage.body.add_child(checks)

	stage.body.add_child(GoStyle.divider())
	var volume_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	volume_row.add_child(GoUi.icons().node(GoIconSet.VOLUME_HIGH, GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.SECONDARY)))
	var volume := GoStyle.slider(0.0, 100.0, 1.0)
	volume.value = 70.0
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_row.add_child(volume)
	var readout := GoStyle.label("70%")
	readout.custom_minimum_size.x = 52
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(readout)
	volume.value_changed.connect(func(value: float) -> void: readout.text = "%d%%" % int(value))
	volume.drag_ended.connect(func(changed: bool) -> void:
		if changed: bot.note("Volume: %d%%" % int(volume.value)))
	stage.body.add_child(volume_row)

	var note := GoStyle.textarea("Write a guild introduction...", 3)
	note.focus_exited.connect(func() -> void:
		if not note.text.is_empty(): bot.note("Introduction: %d characters" % note.text.length()))
	stage.body.add_child(note)
	return {"name": name_edit, "haptics": haptics, "boxes": boxes, "volume": volume, "note": note}


func play_inputs(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var name_edit: LineEdit = refs.name
	var haptics: CheckButton = refs.haptics
	var boxes: Array[CheckBox] = refs.boxes
	var volume: HSlider = refs.volume
	var note: TextEdit = refs.note
	await bot.settle()
	if bot.skipping(): return
	await bot.type_text(name_edit, "Aria", "Type a name one character at a time.")
	if bot.skipping(): return
	await bot.click(haptics, "Turn the switch on.")
	if bot.skipping(): return
	await bot.wait(0.3)
	if bot.skipping(): return
	await bot.click(boxes[0], "Click to enable a setting.")
	if bot.skipping(): return
	await bot.click(boxes[1])
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.drag_slider(volume, 24.0, "Drag the slider and watch the value follow.")
	if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.drag_slider(volume, 88.0)
	if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.type_text(note, "Welcome to the Dawn Guild.", "Type an introduction in the text area.")
	if bot.skipping(): return
	bot.expect(name_edit.text == "Aria", "Name entered through keyboard input")
	bot.expect(haptics.button_pressed and boxes[0].button_pressed and boxes[1].button_pressed, "Switch and checkboxes enabled")
	bot.expect(absf(volume.value - 88.0) <= 2.0, "Volume dragged to 88 percent")
	bot.expect(note.text == "Welcome to the Dawn Guild.", "Text area entered through keyboard input")
	await bot.click(boxes[0], "Click again to uncheck Auto loot.")
	if bot.skipping(): return
	bot.expect(not boxes[0].button_pressed, "Checkbox can be cleared")
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 04 Selection and menus ─────────────────────────────────────────────

func build_selection(stage: SimStage, bot: SimBot) -> Dictionary:
	var klass := GoStyle.select(["Warrior", "Mage", "Ranger", "Engineer"], "Choose a class")
	klass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	klass.item_selected.connect(func(index: int) -> void: bot.note("Class: %s" % klass.get_item_text(index)))
	stage.body.add_child(klass)

	var selected_menu := {"index": -1}
	var menu := GoStyle.dropdown("More actions", [
		{"text": "Rename", "icon": GoIconSet.EDIT},
		{"text": "Duplicate", "icon": GoIconSet.COPY},
		{"text": "Delete", "icon": GoIconSet.TRASH, "disabled": true},
	], func(index: int) -> void:
		selected_menu.index = index
		bot.note("Menu item: %d" % index))
	stage.body.add_child(menu)

	stage.body.add_child(GoStyle.divider())
	var span := GoStyle.segmented(["Day", "Week", "Month"], 1, func(index: int) -> void:
		bot.note("Selected segment: %d" % index))
	stage.body.add_child(span)

	var tabs := GoStyle.tabs(["Overview", "History", "Gear"], 0)
	var page := GoStyle.label("Overview: content follows the selected tab.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	tabs.tab_changed.connect(func(index: int) -> void:
		page.text = "%s: content follows the selected tab." % tabs.get_tab_title(index)
		bot.note("Tab: %s" % tabs.get_tab_title(index)))
	stage.body.add_child(tabs)
	stage.body.add_child(page)

	stage.body.add_child(GoStyle.divider())
	var radios := GoStyle.radio_group(["Easy", "Normal", "Hard"], 1)
	var radio_group: ButtonGroup = radios.get_meta(&"group")
	radio_group.pressed.connect(func(button: BaseButton) -> void:
		bot.note("Difficulty: %s" % (button as CheckBox).text))
	stage.body.add_child(radios)
	return {"klass": klass, "menu": menu, "menu_pick": selected_menu, "span": span,
		"tabs": tabs, "radios": radios, "radio_group": radio_group}


func play_selection(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var klass: OptionButton = refs.klass
	var menu: MenuButton = refs.menu
	var span: HBoxContainer = refs.span
	var tabs: TabBar = refs.tabs
	var radios: VBoxContainer = refs.radios
	var radio_group: ButtonGroup = refs.radio_group
	await bot.settle()
	if bot.skipping(): return
	await bot.open_select(klass, "Open the class dropdown.")
	if bot.skipping(): return
	await bot.pick_with_keys(klass.get_popup(), 2, "Move down the list and select Ranger.")
	if bot.skipping(): return
	bot.expect(klass.selected == 2, "Ranger selected (index 2)")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(menu, "Open a menu with icons and a disabled action.")
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.pick_in_menu(menu.get_popup(), 1, "Move the highlight and choose Duplicate.")
	if bot.skipping(): return
	bot.expect(refs.menu_pick.index == 1, "Duplicate selected through menu input")
	await bot.wait(0.6)
	if bot.skipping(): return
	if span.get_child_count() > 2:
		await bot.click(span.get_child(2) as Control, "Select a segment: only one stays active.")
		if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	for index in [1, 2]:
		await bot.reveal(tabs)
		if bot.skipping(): return
		var spot := tabs.get_global_rect().position + tabs.get_tab_rect(index).get_center()
		await bot.click_at(spot, "Click a tab to change the content.")
		if bot.skipping(): return
		await bot.wait(0.5)
		if bot.skipping(): return
	if radios.get_child_count() > 2:
		await bot.click(radios.get_child(2) as Control, "Radio buttons keep exactly one option selected.")
		if bot.skipping(): return
	bot.expect(tabs.current_tab == 2, "Gear tab selected")
	bot.expect((radio_group.get_pressed_button() as CheckBox).text == "Hard", "Hard radio option selected")
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 05 Lists and navigation ────────────────────────────────────────────

func build_lists(stage: SimStage, bot: SimBot) -> Dictionary:
	var trail := GoStyle.breadcrumb(["Home", "Inventory", "Weapons"], func(index: int) -> void:
		bot.note("Breadcrumb: step %d" % index))
	stage.body.add_child(trail)

	var list := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	var rows: Array[Button] = []
	for spec in [
		[GoIconSet.USER, "Profile", "Name, portrait and title"],
		[GoIconSet.VOLUME_HIGH, "Sound", ""],
		[GoIconSet.DISPLAY, "Display", ""],
	]:
		var row := GoStyle.list_button(spec[0], spec[1], bot.note.bind("List: %s" % spec[1]),
			Color.TRANSPARENT, spec[2], false, GoIconSet.CHEVRON_RIGHT)
		list.add_child(row)
		rows.append(row)
	list.add_child(GoStyle.divider())
	var out := GoStyle.list_button(GoIconSet.LOGOUT, "Log out", bot.note.bind("List: Log out"),
		GoUi.color(GoTheme.DANGER), "", false)
	list.add_child(out)
	rows.append(out)
	stage.body.add_child(list)

	stage.body.add_child(GoStyle.section("Accordion settings", false))
	var group := FoldableGroup.new()
	var folds: Array[FoldableContainer] = []
	for title in ["Graphics", "Audio", "Controls"]:
		var fold := GoStyle.foldable(title, title != "Graphics", group, false)
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
		inner.add_child(GoStyle.label("Adjust your %s settings here." % title, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
		inner.add_child(GoStyle.toggle("Advanced %s" % title, false))
		fold.add_child(inner)
		fold.folding_changed.connect(func(folded: bool) -> void:
			bot.note("%s %s" % [title, "collapsed" if folded else "expanded"]))
		stage.body.add_child(fold)
		folds.append(fold)
	return {"trail": trail, "rows": rows, "folds": folds}


func play_lists(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var trail: HBoxContainer = refs.trail
	var folds: Array[FoldableContainer] = refs.folds
	await bot.settle()
	if bot.skipping(): return
	if trail.get_child_count() > 0:
		await bot.click(trail.get_child(0) as Control, "Use breadcrumbs to return to a previous location.")
		if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.say("Tap anywhere on a list row to open it.")
	if bot.skipping(): return
	for row in refs.rows:
		await bot.click(row)
		if bot.skipping(): return
		await bot.wait(0.25)
		if bot.skipping(): return
	for index in [1, 2]:
		var fold := folds[index]
		await bot.reveal(fold)
		if bot.skipping(): return
		var head := fold.get_global_rect().position + Vector2(fold.size.x * 0.5, 18.0)
		await bot.click_at(head, "Expand %s: the previous section closes." % fold.title)
		if bot.skipping(): return
		await bot.wait(0.9)
		if bot.skipping(): return
	bot.expect(folds[0].folded and folds[1].folded and not folds[2].folded, "Accordion keeps only Controls open")
	await bot.wait(0.5)
	if bot.skipping(): return


# ── 06 Data display ────────────────────────────────────────────────────

func build_data(stage: SimStage, bot: SimBot) -> Dictionary:
	var people := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	for spec in [["Ada Lovelace", GoTheme.ACCENT], ["Grace Hopper", GoTheme.SUCCESS], ["Linus T", GoTheme.WARNING]]:
		people.add_child(GoStyle.avatar(spec[0], 44, GoUi.color(spec[1])))
	people.add_child(GoStyle.spacer())
	stage.body.add_child(people)

	var chips := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for spec in [["Online", GoTheme.SUCCESS], ["Level 42", GoTheme.ACCENT], ["Guild", GoTheme.INFO], ["Beta", GoTheme.WARNING]]:
		chips.add_child(GoStyle.chip(spec[0], GoUi.color(spec[1])))
	stage.body.add_child(chips)

	stage.body.add_child(GoStyle.section("Inventory", false))
	var holder := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	stage.body.add_child(holder)
	for index in 3:
		holder.add_child(GoStyle.skeleton(0.0, 16.0))
	# The moment the data "arrives" is left as a button — the same thing happens whether a person or the bot presses it.
	var loaded := {"done": false}
	var load := GoStyle.button("Load inventory", func() -> void:
		if loaded.done: return
		loaded.done = true
		for child in holder.get_children(): child.queue_free()
		holder.add_child(GoStyle.table(["Item", "Count", "Rarity"], [
			["Iron sword", "1", "Common"], ["Mana potion", "12", "Rare"], ["Dragon scale", "3", "Epic"]]))
		bot.note("Inventory loaded: 3 rows"), GoStyle.Tone.PRIMARY)
	stage.body.add_child(load)

	stage.body.add_child(GoStyle.section("Storage", false))
	var empty := GoStyle.empty_state(GoIconSet.BOX, "Nothing here yet", false)
	stage.body.add_child(empty)
	return {"holder": holder, "load": load, "loaded": loaded, "empty": empty}


func play_data(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Loading placeholders reserve space for upcoming content.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(refs.load, "The table replaces the placeholders when data arrives.")
	if bot.skipping(): return
	bot.expect(refs.loaded.done, "Inventory table loaded")
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.reveal(refs.empty)
	if bot.skipping(): return
	await bot.say("An empty state explains why no items are shown.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return


# ── 07 Status and notices ──────────────────────────────────────────────

func build_states(stage: SimStage, bot: SimBot) -> Dictionary:
	var holder := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	stage.body.add_child(holder)
	var alerts: Array[Control] = []
	for spec in [["Your progress is saved to the cloud.", GoTheme.INFO],
			["Quest complete. Rewards collected.", GoTheme.SUCCESS],
			["Low on potions. Restock before the boss.", GoTheme.WARNING],
			["Connection lost. Retrying...", GoTheme.DANGER]]:
		var alert := GoStyle.alert(spec[0], spec[1])
		holder.add_child(alert)
		alerts.append(alert)

	var bar := GoStyle.progress(GoUi.color(GoTheme.ACCENT))
	bar.max_value = 100.0
	bar.value = 0.0
	var caption := GoStyle.label("Waiting to download", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	stage.body.add_child(GoStyle.section("Progress", false))
	stage.body.add_child(bar)
	stage.body.add_child(caption)
	var download := GoStyle.button("Start download", func() -> void:
		if bar.value > 0.0 and bar.value < 100.0: return
		bar.value = 0.0
		bot.note("Download started")
		var tween := bar.create_tween()
		tween.tween_method(func(value: float) -> void:
			bar.value = value
			caption.text = "Downloading... %d%%" % int(value), 0.0, 100.0, 1.2)
		tween.tween_callback(func() -> void:
			caption.text = "Complete"
			bot.note("Download complete")))
	stage.body.add_child(download)

	var notice := GoNotice.new()
	notice.custom_minimum_size.x = 280
	stage.float_at(notice, Control.PRESET_CENTER_TOP)

	var shout := GoStyle.button("Show success notice", func() -> void:
		notice.show_text("Settings saved", GoTheme.SUCCESS)
		GoFeedback.confirmed()
		bot.note("Notice: success"), GoStyle.Tone.PRIMARY)
	stage.body.add_child(shout)
	var fail := GoStyle.button("Show error notice", func() -> void:
		notice.show_text("Unable to reach the server", GoTheme.DANGER)
		GoFeedback.failed()
		bot.note("Notice: error"), GoStyle.Tone.DANGER)
	stage.body.add_child(fail)
	return {"alerts": alerts, "bar": bar, "download": download, "shout": shout, "fail": fail}


func play_states(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var alerts: Array[Control] = refs.alerts
	var bar: ProgressBar = refs.bar
	# In the demonstration the alerts appear one at a time — in explore mode they are all there from the start.
	for alert in alerts: alert.visible = false
	await bot.settle()
	if bot.skipping():
		for alert in alerts: alert.visible = true
		return
	await bot.say("Persistent alerts come in four tones.")
	for alert in alerts:
		alert.visible = true
		if not GoUi.config.reduce_motion:
			alert.modulate.a = 0.0
			alert.create_tween().tween_property(alert, "modulate:a", 1.0, 0.25)
		await bot.wait(0.65)
		if bot.skipping():
			for rest in alerts:
				rest.visible = true
				rest.modulate.a = 1.0
			return
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.click(refs.download, "The progress bar follows the download.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return
	# 🛑 The progress is a tween and does not follow the speed — at 4× the check may still be mid-run. Only the start is confirmed.
	bot.expect(bar.value > 0.0, "Download is running")
	await bot.click(refs.shout, "A temporary notice appears, then fades away.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(refs.fail, "An error uses a different color and feedback cue.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return


# ── 08 Dialogs, sheets and popups ──────────────────────────────────────

func build_surfaces(stage: SimStage, bot: SimBot) -> Dictionary:
	var dialogs := GoDialogs.new()
	stage.add_child(dialogs)
	dialogs.answered.connect(func(yes: bool) -> void: bot.note("Dialog: %s" % ("confirmed" if yes else "Cancel")))

	stage.body.add_child(GoStyle.label(
		"Dialogs, bottom sheets and centered popups share the same surface design.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	stage.body.add_child(GoStyle.section("Dialogs", false))
	var ask := GoStyle.button("Ask to delete", func() -> void:
		dialogs.confirm("Delete character", "Delete \"{name}\"? This cannot be undone.", "Delete", "Cancel", "", {"name": "Aria"}),
		GoStyle.Tone.DANGER)
	stage.body.add_child(ask)
	var tell := GoStyle.button("Show alert", func() -> void:
		dialogs.alert("Connection lost", "Unable to reach the server. Please try again later.", "Got it"))
	stage.body.add_child(tell)

	# The sheet — it rises from the bottom and holds a list. One is kept and refilled each time it opens.
	stage.body.add_child(GoStyle.section("Bottom sheet", false))
	var sheet := GoSheet.new()
	stage.add_child(sheet)
	sheet.closed.connect(func() -> void: bot.note("Sheet closed"))
	var open_sheet := GoStyle.button("Open inventory sheet", func() -> void:
		sheet.clear()
		sheet.open("Inventory")
		for index in 20:
			sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Item %d" % (index + 1),
				bot.note.bind("Sheet: item %d" % (index + 1)), Color.TRANSPARENT, "A short description", false))
		sheet.add_footer(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))   # the next open() clears it
		bot.note("Sheet opened: 20 items"))
	stage.body.add_child(open_sheet)

	# The popup — it floats in the middle and dims the background. A new one is made per press, and on closing it goes with its own layer.
	stage.body.add_child(GoStyle.section("Centered popup", false))
	var popup := {"got": null}
	var open_popup := GoStyle.button("Open popup", func() -> void:
		if is_instance_valid(popup.got): return
		var layer := CanvasLayer.new()
		layer.layer = 50
		stage.add_child(layer)
		var surface := GoSurface.new()
		surface.dismiss_on_scrim = true
		surface.set_title("Centered popup")
		surface.close_requested.connect(func() -> void:
			layer.queue_free()
			bot.note("Popup closed"))
		layer.add_child(surface)
		surface.body.add_child(GoStyle.label(
			"This popup fits the available space. Close it with the button, X or a tap outside."))
		var got := GoStyle.button("Got it", surface.request_close, GoStyle.Tone.PRIMARY)
		surface.footer.add_child(got)
		surface.footer.visible = true
		popup.got = got
		bot.note("Popup opened"))
	stage.body.add_child(open_popup)
	return {"dialogs": dialogs, "ask": ask, "tell": tell, "sheet": sheet, "open_sheet": open_sheet,
		"open_popup": open_popup, "popup": popup}


func play_surfaces(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var dialogs: GoDialogs = refs.dialogs
	var sheet: GoSheet = refs.sheet
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.ask, "Open a confirmation dialog.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return
	var cancel := dialogs.find_child("Cancel", true, false) as Button
	await bot.click(cancel, "Cancel first to keep the character.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return
	await bot.click(refs.ask, "Open it again and confirm this time.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return
	var confirm := dialogs.find_child("Confirm", true, false) as Button
	await bot.click(confirm)
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return
	await bot.click(refs.tell, "An alert has one action: acknowledge and close.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return
	await bot.click(dialogs.find_child("Confirm", true, false) as Button)
	if bot.skipping(): return
	await bot.wait(0.8)
	if bot.skipping(): return

	await bot.click(refs.open_sheet, "A bottom sheet keeps choices within easy reach.")
	if bot.skipping(): return
	await bot.settle(0.8)
	if bot.skipping(): return
	await bot.scroll_by(sheet.surface.scroll, 4, "Scroll down inside the sheet.")
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	var picked := sheet.body.get_child(6) as Control
	await bot.click(picked, "Choose an item from the list.")
	if bot.skipping(): return
	await bot.wait(0.6)
	if bot.skipping(): return
	var close_button := sheet.footer().get_child(0) as Control
	await bot.click(close_button, "Close the sheet.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return

	await bot.click(refs.open_popup, "A centered popup dims everything behind it.")
	if bot.skipping(): return
	await bot.settle(0.8)
	if bot.skipping(): return
	await bot.click(refs.popup.got as Control, "A centered popup provides a clear way to close it.")
	if bot.skipping(): return
	await bot.wait(0.9)
	if bot.skipping(): return


# ── 09 Prompt cards ────────────────────────────────────────────────────

func build_prompt(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.label(
		"A prompt card keeps the action visible. "
		+ "Use it for party invitations and trade requests.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	var card := GoPromptCard.new()
	var reset := func() -> void:
		card.set_title("Aria invited you to a party")
		card.set_subtitle("Level 42 | Guardian")
	card.set_closable(true)
	card.set_accent(GoUi.color(GoTheme.ACCENT))
	card.set_icon(GoIconSet.USER_PLUS, GoUi.color(GoTheme.ACCENT), true)
	reset.call()
	card.closed.connect(func() -> void:
		card.hide()
		bot.note("Prompt card closed"))
	card.set_actions([
		{"text": "Accept", "action": func() -> void:
			bot.note("Party invitation accepted")
			card.set_title("You joined the party")
			card.set_subtitle("Members: 2 / 4"), "primary": true},
		{"text": "Decline", "action": func() -> void: bot.note("Party invitation declined")},
	])
	card.fit_width(300)
	stage.float_at(card, Control.PRESET_CENTER_RIGHT)
	card.show()
	# A card closed in explore mode has to be callable back.
	var again := GoStyle.button("Send the invitation again", func() -> void:
		reset.call()
		card.show()
		bot.note("Prompt card shown"))
	stage.body.add_child(again)
	return {"card": card, "again": again}


func play_prompt(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var card: GoPromptCard = refs.card
	await bot.settle(0.9)
	if bot.skipping(): return
	if not card.visible:
		await bot.click(refs.again, "Bring the invitation back.")
		if bot.skipping(): return
		await bot.wait(0.6)
		if bot.skipping(): return
	var accept := _find_button(card, "Accept")
	await bot.click(accept, "Accept the invitation to update the card in place.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(card.close_button, "Close the card with its X button.")
	if bot.skipping(): return
	bot.expect(not card.visible, "Prompt closed with X")
	await bot.wait(1.0)
	if bot.skipping(): return


# ── 10 Touch controls ──────────────────────────────────────────────────

func build_touch(stage: SimStage, bot: SimBot) -> Dictionary:
	var readout := GoStyle.label("Stick: 0.00, 0.00", GoTheme.ROLE_SUBTITLE)
	stage.body.add_child(readout)
	stage.body.add_child(GoStyle.label(
		"Move with a virtual joystick. "
		+ "Large touch targets make the action buttons easy to hit.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	var stage_box := Control.new()
	stage_box.custom_minimum_size = Vector2(0, 200)
	stage.body.add_child(stage_box)
	var stick := GoJoystick.new()
	stick.mode = GoJoystick.Mode.FIXED
	stick.radius = 86.0
	stick.knob_radius = 30.0
	stick.ink = GoUi.color(GoTheme.ACCENT)
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.moved.connect(func(vector: Vector2) -> void:
		readout.text = "Stick: %.2f, %.2f" % [vector.x, vector.y])
	stick.released.connect(func() -> void:
		readout.text = "Stick: released"
		bot.note("Joystick released"))
	stage_box.add_child(stick)
	var modes := GoStyle.segmented(["Fixed", "Follow", "Relative"], 0, func(index: int) -> void:
		stick.mode = index as GoJoystick.Mode
		bot.note("Joystick mode: %s" % ["Fixed", "Follow", "Relative"][index]))
	stage.body.add_child(modes)

	var actions := GoStyle.row(GoUi.metric(GoTheme.GAP))
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var discs: Array[Button] = []
	for spec in [[GoIconSet.SHIELD, "Defend"], [GoIconSet.SWORD, "Attack"], [GoIconSet.BOLT, "Special"]]:
		var diameter := 64.0
		var button := GoStyle.icon_button(spec[0], bot.note.bind("%s button" % spec[1]), int(diameter))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(diameter, diameter)
		for state in [[&"normal", 0.20], [&"hover", 0.30], [&"pressed", 0.42]]:
			button.add_theme_stylebox_override(state[0], GoStyle.disc(diameter, GoUi.color(GoTheme.ACCENT), state[1], 0.6))
		actions.add_child(button)
		discs.append(button)
	stage.body.add_child(actions)
	return {"stick": stick, "modes": modes, "discs": discs}


func play_touch(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var stick: GoJoystick = refs.stick
	var modes: HBoxContainer = refs.modes
	await bot.settle()
	if bot.skipping(): return
	if modes.get_child_count() > 0 and stick.mode != GoJoystick.Mode.FIXED:
		await bot.click(modes.get_child(0) as Control, "Start from the fixed joystick mode.")
		if bot.skipping(): return
	await bot.reveal(stick)
	if bot.skipping(): return
	var center := stick.get_global_rect().get_center()
	await bot.say("Drag the stick in a circle and watch the direction update.")
	if bot.skipping(): return
	var path: Array = []
	for step in 17:
		var angle := TAU * float(step) / 16.0
		path.append(center + Vector2(cos(angle), sin(angle)) * 70.0)
	await bot.drag(path, 0.0)
	if bot.skipping(): return
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.say("Push the stick in all four directions.")
	if bot.skipping(): return
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		await bot.drag([center, center + direction * 74.0], 0.35)
		if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	for mode_index in [1, 2]:
		await bot.click(modes.get_child(mode_index) as Control, "Try a different joystick mode.")
		if bot.skipping(): return
		await bot.reveal(stick)
		if bot.skipping(): return
		center = stick.get_global_rect().get_center()
		await bot.drag([center, center + Vector2(100, 0)], 0.25)
		if bot.skipping(): return
		bot.expect(not stick.is_active() and stick.vector() == Vector2.ZERO, "Joystick returns to idle")
	for button in refs.discs:
		await bot.click(button, "Press each action button.")
		if bot.skipping(): return
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 11 The coach mark tour ─────────────────────────────────────────────

func build_coach(stage: SimStage, bot: SimBot) -> Dictionary:
	var bar := GoBar.new()
	bar.label_text = "HP"
	bar.ink = GoUi.color(GoTheme.DANGER)
	bar.set_values(320, 500, false)
	stage.body.add_child(bar)

	var slot := GoSlot.new()
	slot.icon_name = GoIconSet.POTION
	slot.accent = GoUi.color(GoTheme.DANGER)
	slot.quantity = 4
	slot.shortcut_label = "1"
	slot.pressed.connect(func() -> void: bot.note("Quick slot pressed during the tour"))
	var slot_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	slot_row.add_child(slot)
	slot_row.add_child(GoStyle.spacer())
	stage.body.add_child(slot_row)

	var save := GoStyle.button("Save", bot.note.bind("Save pressed"), GoStyle.Tone.PRIMARY)
	stage.body.add_child(save)
	stage.body.add_child(GoStyle.label(
		"Coach marks guide new players through the interface. "
		+ "Highlighted controls remain interactive.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	var tour := GoCoachMark.new()
	tour.avoid_center_band = 0.0
	tour.finished.connect(func(done: bool) -> void: bot.note("Tour: %s" % ("Complete" if done else "skipped")))
	var tour_layer := CanvasLayer.new()
	tour_layer.layer = 80
	stage.add_child(tour_layer)
	tour_layer.add_child(tour)
	var begin := GoStyle.button("Start tour", func() -> void:
		tour.start([
			{"target": bar, "title": "Health bar", "body": "The bar eases toward its new value and abbreviates large numbers."},
			{"target": slot, "title": "Quick slot", "body": "This slot is still interactive. Click it to continue."},
			{"target": save, "title": "Save", "body": "You reached the last step. Press Done to complete the tour."},
		])
		bot.note("Tour started: 3 steps"))
	stage.body.add_child(begin)
	return {"bar": bar, "slot": slot, "save": save, "tour": tour, "begin": begin}


func play_coach(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var tour: GoCoachMark = refs.tour
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.begin, "Begin a three-step guided tour.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return
	await bot.click(tour.next_button, "Continue to the next step.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	# 🛑 Pressing what it points at moves the tour on **by itself** — press 'Next' again here and you aim at a button
	#    that is no longer there, on a tour that has finished.
	await bot.click(refs.slot, "Click the highlighted slot to advance the tour.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(tour.next_button, "Finish the guided tour.")
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return


# ── 12 Scrolling and responsive grids ──────────────────────────────────

func build_scrolling(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.label(
		"The grid adjusts its column count as the available width changes.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var grid := GoStyle.responsive_grid(150.0)
	for index in 6:
		var tile := GoStyle.card()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
		inner.add_child(GoStyle.label("Tile %d" % (index + 1)))
		inner.add_child(GoStyle.label("Subtitle", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
		tile.add_child(inner)
		grid.add_child(tile)
	stage.body.add_child(grid)

	stage.body.add_child(GoStyle.section("Explore regions", false))
	var first_row: Control = null
	for index in 18:
		var row := GoStyle.list_button(GoIconSet.MAP, "Region %d" % (index + 1),
			bot.note.bind("Region %d" % (index + 1)), Color.TRANSPARENT, "", false, GoIconSet.CHEVRON_RIGHT)
		stage.body.add_child(row)
		if index == 4: first_row = row
	return {"deep": first_row}


func play_scrolling(stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Scroll through the long list.")
	if bot.skipping(): return
	await bot.scroll_by(stage.scroll, 4)
	if bot.skipping(): return
	bot.expect(stage.scroll.scroll_vertical > 0, "List scrolled downward")
	await bot.wait(0.5)
	if bot.skipping(): return
	var deep: Control = refs.deep
	await bot.reveal(deep)
	if bot.skipping(): return
	await bot.click(deep, "Select a visible row after scrolling.")
	if bot.skipping(): return
	await bot.wait(0.7)
	if bot.skipping(): return
	bot.say("Return to the beginning of the list.")
	stage.get_viewport().gui_release_focus()
	await bot.reveal(stage.body.get_child(0) as Control)
	if bot.skipping(): return
	bot.expect(stage.scroll.scroll_vertical <= 2, "List returned to top")
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 13 Responsive forms ────────────────────────────────────────────────
# Full-viewport widgets are mounted on a chapter-owned layer so cleanup is automatic.

func build_forms(stage: SimStage, bot: SimBot) -> Dictionary:
	var layer := _full_layer(stage)
	var form := GoForm.new()
	form.route_back_button = false
	var scroll := GoScroll.new()
	form.add_child(scroll)
	var column := GoStyle.column(12)
	scroll.add_child(column)
	column.add_child(GoStyle.label("Create your adventurer", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.label("A responsive form keeps fields within reach. This is a local demo; no account is created."))
	var name_edit := GoStyle.line_edit("Adventurer name")
	column.add_child(name_edit)
	var agree := GoStyle.checkbox("Accept the guild rules", false)
	column.add_child(agree)
	var result := GoStyle.label("Enter a name and accept the rules.", GoTheme.ROLE_CAPTION)
	column.add_child(result)
	var submitted := {"count": 0}
	var submit := GoStyle.button("Create adventurer", func() -> void:
		if name_edit.text.strip_edges().is_empty() or not agree.button_pressed:
			result.text = "A name and agreement are required."
			bot.note("Form validation: complete the required fields")
			return
		submitted.count += 1
		result.text = "Welcome, %s!" % name_edit.text
		bot.note("Form submitted: %s" % name_edit.text), GoStyle.Tone.PRIMARY)
	column.add_child(submit)
	column.add_child(_back_button(stage))
	layer.add_child(form)
	return {"name": name_edit, "agree": agree, "result": result, "submit": submit, "submitted": submitted}


func play_forms(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var name_edit: LineEdit = refs.name
	var result: Label = refs.result
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.submit, "Try submitting an empty form.")
	if bot.skipping(): return
	bot.expect(refs.submitted.count == 0, "Empty form rejected")
	await bot.type_text(name_edit, "Aria", "Fill in the required name.")
	if bot.skipping(): return
	await bot.click(refs.agree, "Accept the guild rules.")
	if bot.skipping(): return
	await bot.click(refs.submit, "Submit the completed form.")
	if bot.skipping(): return
	bot.expect(refs.submitted.count == 1 and result.text == "Welcome, Aria!", "Valid form submitted once")
	await bot.wait(1.4)
	if bot.skipping(): return


# ── 14 HUD anchors ─────────────────────────────────────────────────────

func build_anchors(stage: SimStage, bot: SimBot) -> Dictionary:
	var layer := _full_layer(stage)
	var anchor := GoHudAnchor.new()
	anchor.spot = GoHudAnchor.Spot.TOP_LEFT
	layer.add_child(anchor)
	var status := GoStyle.chip("HUD anchored here", GoUi.color(GoTheme.ACCENT))
	anchor.add_child(status)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var column := GoStyle.column(12)
	column.custom_minimum_size.x = minf(300.0, stage.size.x - 24.0)
	center.add_child(column)
	column.add_child(GoStyle.label("HUD anchors", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.label("Keep a HUD at the viewport edge, with safe-area margins."))
	var buttons: Array[Button] = []
	for spec in [["Top left", GoHudAnchor.Spot.TOP_LEFT], ["Top right", GoHudAnchor.Spot.TOP_RIGHT],
			["Bottom right", GoHudAnchor.Spot.BOTTOM_RIGHT], ["Bottom left", GoHudAnchor.Spot.BOTTOM_LEFT]]:
		var button := GoStyle.button(spec[0], func() -> void:
			anchor.spot = spec[1]
			bot.note("HUD position: %s" % spec[0]))
		column.add_child(button)
		buttons.append(button)
	column.add_child(_back_button(stage))
	return {"anchor": anchor, "buttons": buttons}


func play_anchors(stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var anchor: GoHudAnchor = refs.anchor
	var buttons: Array[Button] = refs.buttons
	await bot.settle()
	if bot.skipping(): return
	for index in range(1, buttons.size()):
		await bot.click(buttons[index], "Move the HUD to another corner.")
		if bot.skipping(): return
		await bot.wait(0.5)
		if bot.skipping(): return
		bot.expect(stage.get_viewport_rect().encloses(anchor.get_global_rect()), "HUD remains inside the viewport")
	await bot.wait(1.0)
	if bot.skipping(): return


# ── 15 Themes and icons ────────────────────────────────────────────────

func build_theming(stage: SimStage, bot: SimBot) -> Dictionary:
	var preview := PanelContainer.new()
	# The family the screen is wearing — on a Fast tour that is this scene's theme, not the one picked at the top.
	var pair: Array[Theme] = preload("theme_picker.gd").pair(GoUi.config.preset)
	preview.theme = pair[0]
	preview.theme_type_variation = GoTheme.VAR_CARD
	var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	preview.add_child(inner)
	var title := GoStyle.label("One kit, two looks", GoTheme.ROLE_SUBTITLE)
	inner.add_child(title)
	var sample_button := GoStyle.button("Primary", bot.note.bind("Preview button pressed"), GoStyle.Tone.PRIMARY)
	inner.add_child(sample_button)
	var sample_toggle := GoStyle.toggle("Haptic feedback", false)
	sample_toggle.button_pressed = true
	inner.add_child(sample_toggle)
	var sample_slider := GoStyle.slider(0.0, 100.0, 1.0)
	sample_slider.value = 62.0
	sample_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sample_slider)

	var swap := func(light: bool) -> void:
		var picked := pair[1] if light else pair[0]
		for node in [preview, title, sample_button, sample_toggle, sample_slider]:
			(node as Control).theme = picked
		bot.note("Theme: %s" % ("Light" if light else "Dark"))

	var switcher := GoStyle.segmented(["Dark", "Light"], 0, func(index: int) -> void: swap.call(index == 1))
	stage.body.add_child(switcher)
	stage.body.add_child(preview)

	stage.body.add_child(GoStyle.section("Built-in icons", false))
	var icons := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	for icon in GoUi.icons().icon_names():
		icons.add_child(GoUi.icons().node(StringName(icon), 22, GoUi.color(GoTheme.SECONDARY)))
	stage.body.add_child(icons)
	return {"switcher": switcher, "sample": sample_button, "icons": icons}


func play_theming(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var switcher: HBoxContainer = refs.switcher
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Change the theme while keeping the same controls.")
	if bot.skipping(): return
	if switcher.get_child_count() > 1:
		await bot.click(switcher.get_child(1) as Control, "Switch to the light theme.")
		if bot.skipping(): return
		await bot.wait(1.4)
		if bot.skipping(): return
		await bot.click(switcher.get_child(0) as Control, "Switch back to the dark theme.")
		if bot.skipping(): return
		await bot.wait(1.0)
		if bot.skipping(): return
	await bot.click(refs.sample, "The button works the same way in either theme.")
	if bot.skipping(): return
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.reveal(refs.icons)
	if bot.skipping(): return
	await bot.say("Browse the built-in icon collection.")
	if bot.skipping(): return
	await bot.wait(2.0)
	if bot.skipping(): return


# ── 16 Container opacity ───────────────────────────────────────────────
#
# 🔑 This scene uses **the same lab widget as the gallery** (`examples/gallery/opacity_lab.gd`) — rebuild the slider for
#    every demo and only one of them gets fixed, and then there is no telling which is the right way to use it.
# 🛑 "Apply to every panel" is not shown here. That setting is global, so it outlives the scene and thins the panels of
#    the next one — a tour has to start each scene from the same state.

func build_opacity(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.label(
		"Panels can let the world show through. The fill thins out; text, icons and borders do not.",
		GoTheme.ROLE_BODY))
	var lab := OpacityLab.new()
	lab.allow_project_wide = false
	stage.body.add_child(lab)
	stage.body.add_child(GoStyle.label(
		"A theme ships the defaults, a project can override them, and one widget can always ask for "
		+ "its own value.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	# 🔑 The reset button is left where a hand can reach it — unlike the lab's apply-to-everything button, this one touches
	#    only this scene's preview.
	var restore := GoStyle.button("Back to the theme value",
		_restore_opacity.bind(lab, bot), GoStyle.Tone.COMPACT)
	stage.body.add_child(restore)
	return {"lab": lab, "dial": lab.dial(), "restore": restore}


## 🛑 **Never add an argument after a multi-line lambda** — the parser cannot tell where the lambda body ends.
##    That is why the reset is a named function.
func _restore_opacity(lab: OpacityLab, bot: SimBot) -> void:
	lab.dial().value = GoUi.surface_alpha(GoTheme.BOX_CARD)
	bot.note("Opacity: theme default")


func play_opacity(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var dial: HSlider = refs.dial
	var lab: OpacityLab = refs.lab
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Panels are 80% opaque by default — the game shows through.")
	if bot.skipping(): return
	await bot.drag_slider(dial, 0.30, "Thin the panel fill right down.")
	if bot.skipping(): return
	await bot.wait(0.8)
	if bot.skipping(): return
	# 🛑 The knob having moved is not enough — reading **the value baked into the panel** is what shows the value arrived.
	bot.expect(lab.fill_alpha() < 0.5, "Panel fill follows the slider")
	await bot.say("Too far: the stripes now fight the text. That is the floor, not a target.")
	if bot.skipping(): return
	await bot.drag_slider(dial, 1.0, "Back to a solid panel.")
	if bot.skipping(): return
	bot.expect(lab.fill_alpha() > 0.9, "A solid panel hides everything behind it")
	await bot.wait(0.8)
	if bot.skipping(): return
	await bot.click(refs.restore, "Return to the value the theme ships.")
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return


# ── Helpers ────────────────────────────────────────────────────────────

## The base layer of a scene that covers the whole screen. It goes when the stage is cleared.
static func _full_layer(stage: SimStage) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	stage.add_child(layer)
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	return layer


## The button back to the widget list from a scene that covers the whole screen — needed because the sidebar is hidden.
## The bot does not press it.
static func _back_button(stage: SimStage) -> Button:
	var back := GoStyle.button("Back to widgets", stage.leave_requested.emit, GoStyle.Tone.BARE)
	back.name = "BackToWidgets"
	return back


## Finds a button by its text — for when a widget keeps its insides to itself.
static func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == text: return child
		var found := _find_button(child, text)
		if found != null: return found
	return null


# ── 17 Waiting and counting ────────────────────────────────────────────

func build_waiting(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.section("A wait with no end in sight", false))
	# 🔑 The spinner turns **in the button's place**. Float it separately and the button is still pressable, and a slow request goes twice.
	var slow := GoStyle.button("Save to the cloud", Callable(), GoStyle.Tone.PRIMARY)
	var busy := {"runs": 0}
	slow.pressed.connect(func() -> void:
		if GoSpinner.is_busy(slow): return
		busy.runs += 1
		GoSpinner.busy(slow, true)
		bot.note("Save started — the button cannot fire again")
		await stage.get_tree().create_timer(1.6).timeout
		if is_instance_valid(slow): GoSpinner.busy(slow, false))
	stage.body.add_child(slow)

	stage.body.add_child(GoStyle.section("A message you can take back", false))
	var snackbar := GoSnackbar.new()
	stage.add_child(snackbar)
	var undone := {"count": 0}
	var drop := GoStyle.button("Drop the iron sword", func() -> void:
		# 🛑 Do not hold `post()` with `await` — waiting here stops the scene. The answer comes back through the callback.
		var answer: int = await snackbar.post({"text": "Iron sword dropped", "actions": ["Undo"],
			"tone": GoTheme.WARNING, "seconds": 6.0})
		if answer == 0:
			undone.count += 1
			bot.note("Undo pressed — the sword is back")
		else:
			bot.note("The message expired; the sword stays dropped"))
	stage.body.add_child(drop)

	stage.body.add_child(GoStyle.section("The unread count", false))
	var marks := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	stage.body.add_child(marks)
	var mail := GoStyle.button("Mail", Callable(), GoStyle.Tone.COMPACT)
	marks.add_child(mail)
	var shop := GoStyle.button("Shop", Callable(), GoStyle.Tone.COMPACT)
	marks.add_child(shop)
	# 🛑 A badge hangs on the corner by anchors — attach it **on the frame after** its place is settled.
	GoBadge.attach.call_deferred(mail, 3)
	GoBadge.attach.call_deferred(shop, 0, "NEW")

	var keys := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	keys.add_child(GoStyle.label("Save", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	keys.add_child(GoKbd.make("Ctrl", "S"))
	stage.body.add_child(keys)
	return {"slow": slow, "busy": busy, "drop": drop, "undone": undone, "snackbar": snackbar, "mail": mail}


func play_waiting(stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await bot.settle()
	if bot.skipping(): return
	await bot.say("A slow request turns its button into a spinner, in place and disabled.")
	if bot.skipping(): return
	await bot.click(refs.slow, "The label steps aside; the button keeps its size.")
	if bot.skipping(): return
	bot.expect(refs.busy.runs == 1, "Slow save started once")
	await bot.wait(1.0)
	if bot.skipping(): return
	bot.expect(GoSpinner.is_busy(refs.slow), "The button is still busy")
	await bot.wait(1.2)
	if bot.skipping(): return
	await bot.say("A cheap, reversible action asks with a button instead of stopping the game.")
	if bot.skipping(): return
	await bot.click(refs.drop, "The snackbar carries Undo, and passes input through elsewhere.")
	if bot.skipping(): return
	await bot.wait(1.2)
	if bot.skipping(): return
	var undo: Button = _snackbar_action(refs.snackbar)
	if undo != null:
		await bot.click(undo, "Undo puts the sword back.")
		if bot.skipping(): return
		bot.expect(refs.undone.count == 1, "Undo was pressed")
	await bot.reveal(refs.mail)
	if bot.skipping(): return
	await bot.say("A badge hangs off the corner and hides itself at zero.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return


## The first button of the floating snackbar. 🔑 For the bot to press it, **a real node** is needed — null if there is none.
func _snackbar_action(snackbar: GoSnackbar) -> Button:
	for node in _descendants(snackbar):
		if node is Button and (node as Button).text != "": return node as Button
	return null


func _descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


# ── 18 Fields and pickers ──────────────────────────────────────────────

func build_fields(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.section("The row that can be wrong", false))
	var guild := GoField.make("Guild name", GoStyle.line_edit("2-16 characters"), "Everyone sees this")
	stage.body.add_child(guild)

	var submit := GoStyle.button("Create guild", Callable(), GoStyle.Tone.PRIMARY)
	var tries := {"errors": 0}
	submit.pressed.connect(func() -> void:
		var typed: String = (guild.control as LineEdit).text.strip_edges()
		if typed.length() < 2:
			# 🛑 A sentence the server sent is not a translation key — it goes in as it is.
			guild.set_error("Enter at least two characters")
			tries.errors += 1
			bot.note("The error landed on the guild name row")
			return
		guild.clear_error()
		bot.note("Guild created: %s" % typed))
	stage.body.add_child(submit)

	stage.body.add_child(GoStyle.section("An input welded to its button", false))
	stage.body.add_child(GoInputGroup.make(GoStyle.line_edit("Message"),
		{"suffix": GoStyle.button("Send", Callable(), GoStyle.Tone.PRIMARY)}))
	stage.body.add_child(GoInputGroup.make(GoStyle.line_edit("Search by name"),
		{"prefix_icon": GoIconSet.SEARCH}))

	stage.body.add_child(GoStyle.section("A picker that searches inside names", false))
	var friends: Array = []
	for name in ["Ada Lovelace", "Grace Hopper", "Rusty sword", "Iron sword", "Mana potion",
			"Dragon scale", "Tower key", "Northern marches"]:
		friends.append(name)
	var combo := GoCombobox.make(friends, -1, "Find an item")
	stage.body.add_child(combo)

	stage.body.add_child(GoStyle.section("Coupon codes", false))
	var coupon := GoCodeInput.make(8, 4)
	stage.body.add_child(coupon)
	return {"guild": guild, "submit": submit, "tries": tries, "combo": combo, "coupon": coupon}


func play_fields(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await bot.settle()
	if bot.skipping(): return
	await bot.say("One line saying \"check your input\" makes you hunt. This marks the box itself.")
	if bot.skipping(): return
	await bot.click(refs.submit, "Submitting empty puts the reason under that row.")
	if bot.skipping(): return
	bot.expect(refs.guild.has_error(), "The field is holding an error")
	await bot.wait(1.6)
	if bot.skipping(): return
	await bot.reveal(refs.combo)
	if bot.skipping(): return
	await bot.say("The picker searches inside names, so \"sword\" finds \"Rusty sword\".")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.reveal(refs.coupon)
	if bot.skipping(): return
	await bot.say("Coupon cells are drawn; one hidden field holds the text, so pasting works.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return


# ── 19 Shapes games use ────────────────────────────────────────────────

func build_shapes(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.section("Daily attendance", false))
	var days: Array = []
	for index in 7:
		days.append({"icon": GoIconSet.COIN if index < 6 else GoIconSet.CROWN,
			"amount": 50 * (index + 1), "special": index == 6})
	var calendar := GoRewardCalendar.make(days, 2)
	var claims := {"count": 0}
	calendar.claimed.connect(func(day: int) -> void:
		claims.count += 1
		calendar.set_claimed_until(day)
		bot.note("Day %d claimed" % (day + 1)))
	stage.body.add_child(calendar)

	stage.body.add_child(GoStyle.section("Stats at a glance", false))
	var shapes := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	# 🛑 Normalise the values to 0–1 — drawing STR 120 and INT 45 as they are makes the shape lie.
	var radar := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45},
		{"STR": 0.92, "AGI": 0.44, "INT": 0.3, "VIT": 0.7, "LUK": 0.45})
	radar.custom_minimum_size = Vector2(150, 150)
	shapes.add_child(radar)
	var donut := GoDonut.make([{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340},
		{"label": "Pierce", "value": 90}])
	donut.center_text = "1050"
	donut.custom_minimum_size = Vector2(130, 130)
	shapes.add_child(donut)
	stage.body.add_child(shapes)
	stage.body.add_child(donut.legend())

	stage.body.add_child(GoStyle.section("Banners that never move on their own", false))
	var carousel := GoCarousel.new()
	var banners: Array[Control] = []
	for spec in [["Midsummer festival", GoTheme.WARNING], ["Double crowns", GoTheme.ACCENT],
			["New region: the north", GoTheme.INFO]]:
		var card := GoStyle.card()
		var inset := GoStyle.padding(GoUi.metric(GoTheme.GAP))
		card.add_child(inset)
		inset.add_child(GoStyle.label(str(spec[0]), GoTheme.ROLE_SUBTITLE, GoUi.color(spec[1])))
		banners.append(card)
	# 🛑 Leave `autoplay_seconds` at 0 — a banner that moves on by itself steals what someone was about to press.
	carousel.set_pages(banners)
	stage.body.add_child(carousel)
	return {"calendar": calendar, "claims": claims, "radar": radar, "donut": donut, "carousel": carousel}


func play_shapes(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Attendance: claimed days, today, and days still to come. Only today can be pressed.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return
	await bot.reveal(refs.radar)
	if bot.skipping(): return
	await bot.say("The pentagon shows the build; the dashed line is the gear you would equip.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return
	await bot.reveal(refs.donut)
	if bot.skipping(): return
	await bot.say("The legend says each slice in words too — colour alone is not a label.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return
	await bot.reveal(refs.carousel)
	if bot.skipping(): return
	await bot.say("A banner that advances by itself steals the tap you were aiming at. This one waits.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return


# ── 20 Inventory and items ─────────────────────────────────────────────
#
# 🛑 `GoSlotGrid` draws with the **global** icon set, and a chapter never changes global settings — the next chapter
#    and the theme picker would inherit them. So the grid uses default-set names, and the game icon set gets a row of
#    its own, drawn straight from `GoGameIcons.icon_set()`.

const BAG_ITEMS: Array[Dictionary] = [
	{"icon": GoIconSet.SWORD, "name": "Iron sword", "kind": 1, "ink": Color("c9d1d9"), "rarity": "Common",
		"about": "A plain blade that holds its edge.", "stats": [["Attack", "+12"], ["Weight", "3.5"]]},
	{"icon": GoIconSet.POTION, "name": "Health potion", "kind": 2, "quantity": 12, "ink": Color("e5484d"),
		"rarity": "Common", "about": "Restores 150 health over two seconds.", "stats": [["Heals", "150"], ["Cooldown", "8s"]]},
	{"icon": GoIconSet.POTION, "name": "Mana potion", "kind": 2, "quantity": 7, "ink": Color("3e63dd"),
		"rarity": "Rare", "about": "Restores 80 mana at once.", "stats": [["Mana", "80"], ["Cooldown", "12s"]]},
	{"icon": GoIconSet.SHIELD, "name": "Oak shield", "kind": 1, "ink": Color("ad7f58"), "rarity": "Common",
		"about": "Blocks the first hit of every fight.", "stats": [["Defence", "+8"], ["Weight", "5.0"]]},
	{"icon": GoIconSet.KEY, "name": "Tower key", "kind": 0, "quantity": 1, "ink": Color("ffc53d"), "rarity": "Quest",
		"about": "Opens the north tower. It cannot be dropped.", "stats": []},
	{"icon": GoIconSet.COIN, "name": "Gold", "kind": 0, "quantity": 1250, "ink": Color("ffc53d"), "rarity": "Currency",
		"about": "Spent at any shop.", "stats": []},
	{"icon": GoIconSet.GIFT, "name": "Sealed gift", "kind": 0, "quantity": 1, "ink": Color("8e4ec6"), "rarity": "Event",
		"about": "Opens at the festival. Until then it stays locked.", "stats": [], "locked": true},
]

func build_inventory(stage: SimStage, bot: SimBot) -> Dictionary:
	var bag: Array = []
	for index in 12: bag.append(BAG_ITEMS[index].duplicate(true) if index < BAG_ITEMS.size() else {})
	var state := {"filter": 0, "moving": -1}
	# 🛑 A lambda cannot reach itself through the variable it is being assigned to — the redraws live in a dictionary.
	var redraw := {}

	# 🔑 Icons in segments — the kinds read at a glance, and an icon-only cell is named by its tooltip.
	var filter := GoStyle.segmented([{"text": "All", "icon": GoIconSet.GRID}, {"icon": GoIconSet.SWORD, "tooltip": "Gear"},
		{"icon": GoIconSet.POTION, "tooltip": "Potions"}], 0, Callable(), false, true)
	stage.body.add_child(filter)

	var grid := GoSlotGrid.new()
	grid.slot_count = bag.size()
	grid.cell_size = 60
	# A bag inside a tour: Space belongs to the tour (pause), not to the last cell pressed — the hotbar rule.
	grid.keyboard_focus = false
	stage.body.add_child(grid)
	var hint := GoStyle.label("Pick an item to see what it is.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	stage.body.add_child(hint)
	var detail := GoStyle.column(0)
	stage.body.add_child(detail)

	redraw.paint = func() -> void:
		for index in bag.size():
			var item: Dictionary = bag[index]
			if item.is_empty():
				grid.set_cell(index, {})
				continue
			var cell := {"icon": item.icon, "ink": item.ink, "tooltip": item.name,
				# Filtered out and locked read the same way: still there, not for now.
				"disabled": bool(item.get("locked", false)) or (state.filter != 0 and int(item.kind) != state.filter)}
			if item.has("quantity"): cell["quantity"] = int(item.quantity)
			grid.set_cell(index, cell)

	redraw.show = func(index: int) -> void:
		for child in detail.get_children():
			detail.remove_child(child)
			child.queue_free()
		var item: Dictionary = bag[index]
		var spec := {"icon": item.icon, "ink": item.ink, "title": item.name, "subtitle": item.rarity,
			"body": item.about, "stats": item.stats, "chips": []}
		if item.has("quantity"): spec.chips.append({"text": "×%d" % int(item.quantity), "ink": GoUi.color(GoTheme.INFO)})
		if bool(item.get("locked", false)): spec.chips.append({"text": "Locked", "ink": GoUi.color(GoTheme.WARNING), "icon": GoIconSet.LOCK})
		var actions: Array = []
		if int(item.get("quantity", 0)) > 0 and int(item.kind) == 2:
			actions.append({"text": "Use", "tone": GoStyle.Tone.PRIMARY, "action": func() -> void:
				item.quantity = int(item.quantity) - 1
				bot.note("Used: %s (%d left)" % [item.name, int(item.quantity)])
				redraw.paint.call()
				redraw.show.call(index)})
		actions.append({"text": "Move", "action": func() -> void:
			state.moving = index
			hint.text = "Now pick the space the %s goes to." % item.name
			bot.note("Moving: %s" % item.name)})
		spec["actions"] = actions
		detail.add_child(GoStyle.item_card(spec))

	filter.get_meta(&"group").pressed.connect(func(button: BaseButton) -> void:
		state.filter = button.get_index()
		redraw.paint.call()
		bot.note("Filter: %s" % ["All", "Gear", "Potions"][state.filter]))

	grid.slot_pressed.connect(func(index: int) -> void:
		# The tap route to rearrange — a finger drag belongs to the scroll, so Move, then the target.
		if state.moving >= 0:
			var from: int = state.moving
			state.moving = -1
			if from != index:
				var carried: Dictionary = bag[from]
				bag[from] = bag[index]
				bag[index] = carried
				bot.note("Item moved: %d → %d" % [from + 1, index + 1])
			hint.text = "Pick an item to see what it is."
			redraw.paint.call()
			grid.selected = index
			redraw.show.call(index)
			return
		var item: Dictionary = bag[index]
		if item.is_empty():
			grid.selected = -1
			hint.text = "An empty space — room for one more."
			for child in detail.get_children(): child.queue_free()
			return
		grid.selected = index
		redraw.show.call(index)
		bot.note("Inventory: %s" % item.name))
	redraw.paint.call()
	# 🛑 The two lambdas and the dictionary hold each other — clear it when the chapter goes, or neither is ever freed
	#    (the check caught it as `res://sim_acts.gd` still in use at exit).
	grid.tree_exiting.connect(func() -> void: redraw.clear())

	stage.body.add_child(GoStyle.section("The game icon set — %d more icons" % GoGameIcons.names().size(), false))
	var game_icons := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	var game_set := GoGameIcons.icon_set()
	for icon_name in [GoGameIcons.BACKPACK, GoGameIcons.CHEST, GoGameIcons.GEM, GoGameIcons.RING, GoGameIcons.NECKLACE,
			GoGameIcons.HELMET, GoGameIcons.ARMOR, GoGameIcons.AXE, GoGameIcons.BOW, GoGameIcons.WAND, GoGameIcons.PICKAXE,
			GoGameIcons.APPLE, GoGameIcons.MEAT, GoGameIcons.FLASK, GoGameIcons.SHOP, GoGameIcons.COINS]:
		game_icons.add_child(game_set.node(icon_name, 26, GoUi.color(GoTheme.SECONDARY)))
	stage.body.add_child(game_icons)
	stage.body.add_child(GoStyle.label("GoUi.config.icons = GoGameIcons.icon_set() — the default names keep working.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return {"filter": filter, "grid": grid, "bag": bag, "state": state, "detail": detail, "icons": game_icons}


func play_inventory(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var filter: HBoxContainer = refs.filter
	var grid: GoSlotGrid = refs.grid
	var bag: Array = refs.bag
	await bot.settle()
	if bot.skipping(): return
	await bot.say("Each item keeps its own colour, lifted until it reads on the slot.")
	if bot.skipping(): return
	await bot.click(filter.get_child(2) as Control, "Filter to potions: the rest fade but keep their place.")
	if bot.skipping(): return
	bot.expect(refs.state.filter == 2, "Potion filter chosen")
	await bot.wait(0.8)
	if bot.skipping(): return
	await bot.click(filter.get_child(0) as Control, "Back to everything.")
	if bot.skipping(): return
	await bot.click(grid.slot(1), "Pick the health potion: its card shows what it is and what it does.")
	if bot.skipping(): return
	bot.expect(grid.selected == 1, "Health potion picked")
	await bot.wait(0.8)
	if bot.skipping(): return
	await bot.click(_find_button(refs.detail, "Use"), "Use one.")
	if bot.skipping(): return
	bot.expect(int(bag[1].quantity) == 11, "One potion used")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(_find_button(refs.detail, "Move"), "Rearrange by tapping: Move, then the space.")
	if bot.skipping(): return
	await bot.click(grid.slot(9), "Drop it into an empty space.")
	if bot.skipping(): return
	bot.expect(not (bag[9] as Dictionary).is_empty() and bag[9].name == "Health potion", "Potion moved to space 10")
	await bot.wait(0.8)
	if bot.skipping(): return
	await bot.reveal(refs.icons)
	if bot.skipping(): return
	await bot.say("A second icon set for bags and shops, falling back to the default one.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return


# ── 21 Popovers, menus and drawers ─────────────────────────────────────

func build_overlays(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.label(
		"Panels that open beside the game and close again — no trip to another screen.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	stage.body.add_child(GoStyle.section("A card beside what you pressed", false))
	var equipped := {"count": 0}
	var popover := {"surface": null}
	var inspect := GoStyle.button("Inspect the sword", Callable(), GoStyle.Tone.COMPACT)
	# 🛑 Natural width — a compact button squeezed to the row start folded "Inspect the sword" into three lines.
	GoStyle.natural_width(inspect)
	inspect.pressed.connect(func() -> void:
		# 🔑 The same detail card as the bag, unframed — the popover is the frame.
		var card := GoStyle.item_card({"icon": GoIconSet.SWORD, "title": "Iron sword", "subtitle": "Common",
			"body": "A plain blade that holds its edge.", "stats": [["Attack", "+12"]],
			"actions": [{"text": "Equip", "tone": GoStyle.Tone.PRIMARY, "action": func() -> void:
				equipped.count += 1
				bot.note("Popover: equipped")
				GoPopover.close()}]}, false)
		popover.surface = GoPopover.open(inspect, card, {"title": "Item", "width": 300})
		bot.note("Popover opened"))
	stage.body.add_child(inspect)

	stage.body.add_child(GoStyle.section("Right-click or hold for more", false))
	var menu_picks := {"text": ""}
	var pick := func(word: String) -> void:
		menu_picks.text = word
		bot.note("Menu: %s" % word)
	var row := GoStyle.list_button(GoIconSet.SWORD, "Iron sword", bot.note.bind("Row pressed"), Color.TRANSPARENT,
		"Right-click, or hold a finger on it", false, GoIconSet.MORE)
	GoContextMenu.attach(row, [
		{"text": "Use", "action": pick.bind("Use")},
		{"text": "Equip", "action": pick.bind("Equip")},
		{"separator": true},
		{"text": "Drop", "danger": true, "action": pick.bind("Drop")},
	])
	stage.body.add_child(row)

	stage.body.add_child(GoStyle.section("A drawer from the side", false))
	var drawer := GoDrawer.new()
	stage.add_child(drawer)
	for index in 6:
		drawer.body.add_child(GoStyle.list_button(GoIconSet.POTION, "Potion %d" % (index + 1), func() -> void:
			bot.note("Drawer: Potion %d" % (index + 1))
			drawer.close(), Color.TRANSPARENT, "Restores health", false))
	drawer.closed.connect(func() -> void: bot.note("Drawer closed"))
	var open_drawer := GoStyle.button("Open the bag drawer", func() -> void:
		drawer.open("Bag")
		bot.note("Drawer opened"), GoStyle.Tone.COMPACT)
	GoStyle.natural_width(open_drawer)
	stage.body.add_child(open_drawer)

	stage.body.add_child(GoStyle.section("A cheat console for testing", false))
	var console := GoConsole.new()
	# 🛑 Below the tour's cursor (layer 200), or the cursor vanishes behind it. The default 200 is right in a game.
	console.layer_index = 150
	stage.add_child(console)
	console.register("give", "Grant an item: give <item> <count>", func(args: PackedStringArray) -> String:
		bot.note("Console: give %s" % " ".join(args))
		return "Granted %s" % " ".join(args))
	console.register("exit", "Close the console", func(_args: PackedStringArray) -> String:
		console.close.call_deferred()
		return "")
	var open_console := GoStyle.button("Open the console", func() -> void:
		console.open()
		bot.note("Console opened" if console.is_open() else "Console refused: release build"), GoStyle.Tone.COMPACT)
	GoStyle.natural_width(open_console)
	stage.body.add_child(open_console)
	stage.body.add_child(GoStyle.label("It refuses to open in a release build — cheats never reach players.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return {"inspect": inspect, "popover": popover, "equipped": equipped, "row": row, "menu": menu_picks,
		"drawer": drawer, "open_drawer": open_drawer, "console": console, "open_console": open_console}


func play_overlays(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var drawer: GoDrawer = refs.drawer
	var console: GoConsole = refs.console
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.inspect, "A popover opens beside what you pressed and keeps the screen in view.")
	if bot.skipping(): return
	await bot.wait(0.7)
	if bot.skipping(): return
	var surface := refs.popover.surface as GoSurface
	if is_instance_valid(surface):
		await bot.click(_find_button(surface, "Equip"), "Act on it right there.")
		if bot.skipping(): return
	bot.expect(refs.equipped.count == 1, "Equipped from the popover")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.right_click(refs.row, "Right-click for the actions; a finger holds instead.")
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	var popup := (refs.row as Node).find_child("ContextMenu", false, false) as PopupMenu
	if popup != null:
		await bot.pick_in_menu(popup, 1, "Choose Equip. Drop is marked as the dangerous one.")
		if bot.skipping(): return
	bot.expect(refs.menu.text == "Equip", "Equip picked from the context menu")
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.click(refs.open_drawer, "A drawer slides in from the side on wider screens.")
	if bot.skipping(): return
	await bot.settle(0.6)
	if bot.skipping(): return
	await bot.click(drawer.body.get_child(2) as Control, "Pick from it and it closes.")
	if bot.skipping(): return
	bot.expect(not drawer.is_open(), "Drawer closed after the pick")
	await bot.wait(0.6)
	if bot.skipping(): return
	if not OS.is_debug_build(): return
	await bot.click(refs.open_console, "The console lists matching commands as you type.")
	if bot.skipping(): return
	await bot.wait(0.3)
	if bot.skipping(): return
	await bot.type_text(console.input, "give potion 3")
	if bot.skipping(): return
	await bot.press_key(KEY_ENTER, "Enter runs it.")
	if bot.skipping(): return
	await bot.wait(0.8)
	if bot.skipping(): return
	await bot.type_text(console.input, "exit")
	if bot.skipping(): return
	await bot.press_key(KEY_ENTER)
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	bot.expect(not console.is_open(), "Console closed with exit")


# ── 22 Tables and pages ────────────────────────────────────────────────

const SERVERS: Array[String] = ["Northern marches", "Sunken coast", "Ember wastes", "Glass forest", "High pass",
	"Old capital", "Salt flats", "Moon harbour", "Iron hills", "Silent bay", "Red canyon", "Frost reach",
	"Bramble vale", "Cinder isle", "Duskwood", "Last light", "Stone gate", "Willow ford", "Amber steppe",
	"Hollow peak", "Rain court", "Dune sea", "Pale shore", "Kings road"]

func build_records(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.section("A leaderboard you can sort", false))
	var board := GoTable.make(
		[{"text": "Rank", "width": 56}, {"text": "Name"}, {"text": "Score", "numeric": true}],
		[[1, "Aria", 9124], [2, "Brin", 91240], [3, "Cade", 48210], [4, "Dane", 500], [5, "Esme", 12800]])
	board.sorted.connect(func(column: int, ascending: bool) -> void:
		bot.note("Table sorted by %s %s" % [["Rank", "Name", "Score"][column], "up" if ascending else "down"]))
	board.row_selected.connect(func(index: int) -> void:
		bot.note("Row picked: %s" % str(board.rows()[index][1])))
	stage.body.add_child(board)
	stage.body.add_child(GoStyle.label("Numbers sort as numbers: 91240 is above 9124.", GoTheme.ROLE_MICRO,
		GoUi.color(GoTheme.MUTED)))

	stage.body.add_child(GoStyle.section("Pages, the current one lit", false))
	# 🛑 Every page button is a full touch target (48dp), and the row does not wrap — on a 390dp phone twelve pages ran
	#    past the stage and the next button was off screen. A phone-width row holds about five buttons.
	var pager := GoPagination.make(1, 3, func(page: int) -> void: bot.note("Page %d" % page))
	stage.body.add_child(pager)

	stage.body.add_child(GoStyle.section("One pick from a long list", false))
	var chosen := {"name": ""}
	var picked_label := GoStyle.label("No server chosen yet.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	var sheet := GoSheet.new()
	# 🔑 A long list earns a tall sheet — `height_ratio` above the global 0.72 ceiling needs this sheet's own ceiling.
	sheet.max_height_ratio = 0.9
	sheet.height_ratio = 0.86
	stage.add_child(sheet)
	sheet.closed.connect(func() -> void: bot.note("Server sheet closed"))
	var rows: Array[Button] = []
	var open_sheet := GoStyle.button("Choose a server", func() -> void:
		sheet.open("Servers")
		rows.clear()
		for server in SERVERS:
			var line := GoStyle.list_button(GoIconSet.GLOBE, server, Callable(), Color.TRANSPARENT, "", false)
			line.pressed.connect(func() -> void:
				chosen.name = server
				# Only the faces change — the rows are not rebuilt on every pick.
				for other in rows: GoStyle.restyle_list_row(other, other == line)
				picked_label.text = "Server: %s" % server
				bot.note("Server: %s" % server))
			GoStyle.restyle_list_row(line, server == chosen.name)
			sheet.body.add_child(line)
			rows.append(line)
		sheet.add_footer(GoStyle.button("Done", sheet.close, GoStyle.Tone.PRIMARY))
		bot.note("Server sheet opened"), GoStyle.Tone.COMPACT)
	GoStyle.natural_width(open_sheet)
	stage.body.add_child(open_sheet)
	stage.body.add_child(picked_label)
	return {"board": board, "pager": pager, "sheet": sheet, "open_sheet": open_sheet, "rows": rows, "chosen": chosen}


func play_records(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var board: GoTable = refs.board
	var pager: GoPagination = refs.pager
	var sheet: GoSheet = refs.sheet
	await bot.settle()
	if bot.skipping(): return
	for press in 2:
		await bot.reveal(board)
		if bot.skipping(): return
		await bot.click(board.head.get_child(2) as Control,
			"Press a header to sort." if press == 0 else "Press it again for the other direction.")
		if bot.skipping(): return
		await bot.wait(0.6)
		if bot.skipping(): return
	var top := board.rows_box.get_child(0) as Control
	bot.expect(top != null and top.name == "Pick1", "Highest score first after sorting down")
	await bot.click(top, "Pick a row.")
	if bot.skipping(): return
	bot.expect(board.selected() == 1, "Brin's row picked")
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.click(pager.get_child(pager.get_child_count() - 1) as Control, "Next page.")
	if bot.skipping(): return
	bot.expect(pager.page() == 2, "Page 2")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(refs.open_sheet, "A long list gets a tall sheet of its own.")
	if bot.skipping(): return
	await bot.settle(0.8)
	if bot.skipping(): return
	var rows: Array[Button] = refs.rows
	if rows.size() > 2:
		await bot.click(rows[2], "The pick gets a border, not just a colour.")
		if bot.skipping(): return
		bot.expect(rows[2].get_meta(&"go_selected", false) and not rows[0].get_meta(&"go_selected", false),
			"Only the picked server is marked")
		await bot.wait(0.8)
		if bot.skipping(): return
		await bot.click(rows[0], "Pick another: the mark moves.")
		if bot.skipping(): return
		await bot.wait(0.6)
		if bot.skipping(): return
	var done := sheet.footer().get_child(sheet.footer().get_child_count() - 1) as Control
	await bot.click(done, "Done.")
	if bot.skipping(): return
	bot.expect(refs.chosen.name == SERVERS[0], "Northern marches chosen")
	await bot.wait(0.6)
	if bot.skipping(): return


# ── 23 Pick by picture ─────────────────────────────────────────────────

func build_choices(stage: SimStage, bot: SimBot) -> Dictionary:
	stage.body.add_child(GoStyle.section("Swatches", false))
	var skins := [["Porcelain", Color("f3d9c6")], ["Honey", Color("d9a066")], ["Cocoa", Color("8d5524")],
		["Umber", Color("5c3a21")], ["Moss", Color("7a9a5a")]]
	var swatch_items: Array = []
	for pair in skins: swatch_items.append({"color": pair[1], "tooltip": pair[0]})
	var swatches := GoStyle.choice_grid(swatch_items, 0, func(index: int) -> void:
		bot.note("Skin: %s" % skins[index][0]))
	stage.body.add_child(swatches)

	stage.body.add_child(GoStyle.section("Cards you choose from", false))
	var cards := GoStyle.responsive_grid(150, GoUi.metric(GoTheme.GAP_SMALL))
	var group := ButtonGroup.new()
	var picked := {"text": "Normal"}
	for spec in [["Story", GoTheme.SUCCESS, GoIconSet.BOOK, "Enemies go easy on you."],
			["Normal", GoTheme.INFO, GoIconSet.SWORD, "The fight as designed."],
			["Hard", GoTheme.DANGER, GoIconSet.SKULL, "Every mistake costs."]]:
		var accent := GoUi.color(spec[1])
		var card := Button.new()
		card.name = "Card%s" % spec[0]
		card.button_group = group
		# 🛑 PASS — the card sits in a scroll, and a drag that starts on it must still scroll the page.
		GoStyle.style_choice_card(card, accent, false, true, true, Control.MOUSE_FILTER_PASS)
		card.button_pressed = spec[0] == picked.text
		card.accessibility_name = spec[0]
		var body := GoStyle.card_body(card)
		body.add_child(GoUi.icons().node(spec[2], GoUi.metric(GoTheme.ICON_SIZE), accent))
		body.add_child(GoStyle.label(spec[0], GoTheme.ROLE_SUBTITLE))
		body.add_child(GoStyle.label(spec[3], GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
		# 🛑 The card is the button — text and icons on it must not swallow the press or the hover.
		GoStyle.let_input_through(body)
		card.pressed.connect(func() -> void:
			picked.text = spec[0]
			bot.note("Difficulty: %s" % spec[0]))
		cards.add_child(card)
	stage.body.add_child(cards)

	stage.body.add_child(GoStyle.section("A pill over the map", false))
	var map := PanelContainer.new()
	map.custom_minimum_size.y = 96
	map.add_theme_stylebox_override(&"panel", GoStyle.surface(GoTheme.BOX_CARD, GoUi.color(GoTheme.SUCCESS)))
	var pill := GoStyle.overlay_panel()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var layer := {"index": 0}
	var layers := GoStyle.segmented([{"icon": GoIconSet.MAP, "tooltip": "Terrain"}, {"icon": GoIconSet.FLAG, "tooltip": "Quests"},
		{"icon": GoIconSet.USERS, "tooltip": "Party"}], 0, func(index: int) -> void:
			layer.index = index
			bot.note("Map layer: %s" % ["Terrain", "Quests", "Party"][index]), false, true)
	pill.add_child(layers)
	map.add_child(pill)
	stage.body.add_child(map)

	stage.body.add_child(GoStyle.section("HUD buttons that leave Space to the game", false))
	var hud := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var hud_buttons: Array[Control] = []
	for spec in [[GoIconSet.BAG, "Open the bag"], [GoIconSet.MAP, "Open the map"], [GoIconSet.SETTINGS, "Settings"]]:
		# Plain words or your own translation key — the tooltip goes through the translation server either way.
		var mark := GoStyle.icon_button(spec[0], bot.note.bind("HUD: %s" % spec[1]), -1, StringName(spec[1]))
		# 🔑 Off over gameplay: a clicked button would keep focus, and Space would press it again instead of jumping.
		mark.keyboard_focus = false
		hud.add_child(mark)
		hud_buttons.append(mark)
	for mark in hud_buttons: (mark as GoIconButton).touch_peers = hud_buttons
	stage.body.add_child(hud)
	stage.body.add_child(GoStyle.label("keyboard_focus = false — or GoHudAnchor.keyboard_focus = false for a whole corner.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return {"swatches": swatches, "cards": cards, "picked": picked, "layers": layers, "layer": layer, "hud": hud_buttons}


func play_choices(stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var swatches: HFlowContainer = refs.swatches
	var cards: Control = refs.cards
	var layers: HBoxContainer = refs.layers
	await bot.settle()
	if bot.skipping(): return
	if swatches.get_child_count() > 2:
		await bot.click(swatches.get_child(2) as Control, "Pick a colour: the chosen swatch gets a thick border, never a tint.")
		if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.click(cards.get_child(2) as Control, "Cards carry more than a name. One stays chosen.")
	if bot.skipping(): return
	bot.expect(refs.picked.text == "Hard", "Hard difficulty chosen")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(layers.get_child(1) as Control, "Small icon segments in a pill over the map.")
	if bot.skipping(): return
	bot.expect(refs.layer.index == 1, "Quest layer shown")
	await bot.wait(0.6)
	if bot.skipping(): return
	var bag: Control = refs.hud[0]
	await bot.click(bag, "A HUD button over gameplay does not keep keyboard focus.")
	if bot.skipping(): return
	bot.expect(stage.get_viewport().gui_get_focus_owner() != bag, "The HUD button left keyboard focus alone")
	await bot.wait(1.0)
	if bot.skipping(): return


## Waits until [param done] says yes, for at most [param seconds] of real time — for a widget that settles on its own
## clock (a wheel spinning down, a page sliding, a timer finishing the work), which the bot's speed does not hurry.
static func _until(bot: SimBot, done: Callable, seconds := 1.5) -> void:
	var left := seconds
	while left > 0.0 and not bot.skipping() and not done.call():
		await bot.get_tree().process_frame
		left -= bot.get_process_delta_time()


## Waits until [param node] stops moving on screen — a row above it folding away, a page still settling — so a spot
## taken from it is still right when the cursor gets there. At most [param seconds] of real time.
static func _still(bot: SimBot, node: Control, seconds := 1.5) -> void:
	var last := Vector2.INF
	var calm := 0
	var left := seconds
	while left > 0.0 and calm < 3 and not bot.skipping() and is_instance_valid(node):
		var now := node.get_global_rect().position
		calm = calm + 1 if now.is_equal_approx(last) else 0
		last = now
		await bot.get_tree().process_frame
		left -= bot.get_process_delta_time()


# ── 24 An app screen ───────────────────────────────────────────────────
#
# 🔑 `GoScaffold` usually fills the window. Here it fills a phone-sized frame on the stage, so the app bar and the
#    navigation bar turn `safe_area` off — the frame is not at a screen edge, and there is no notch to keep clear of.

func build_app(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"query": "", "added": 0, "place": -1}
	var page := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	var search := GoSearchBar.make("Search the shop", func(query: String) -> void:
		state.query = query
		bot.note("Search: %s" % query))
	search.add_action(GoIconSet.FILTER, &"Filter", bot.note.bind("Search bar: Filter"))
	page.add_child(search)
	var chips := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	var stock := GoStyle.filter_chip("In stock", false, func(on: bool) -> void:
		bot.note("In stock: %s" % ("on" if on else "off")))
	chips.add_child(stock)
	chips.add_child(GoStyle.filter_chip("On sale", false, func(on: bool) -> void:
		bot.note("On sale: %s" % ("on" if on else "off"))))
	var tag := GoStyle.input_chip("Swords", bot.note.bind("Tag removed: Swords"), GoIconSet.SWORD)
	chips.add_child(tag)
	page.add_child(chips)
	for spec in [[GoIconSet.SWORD, "Iron sword", "120 gold"], [GoIconSet.SHIELD, "Oak shield", "80 gold"],
			[GoIconSet.POTION, "Health potion", "15 gold"], [GoIconSet.KEY, "Tower key", "Sold out"]]:
		page.add_child(GoStyle.list_button(spec[0], spec[1], bot.note.bind("Opened: %s" % spec[1]), Color.TRANSPARENT,
			spec[2], false))

	var screen := GoScaffold.new()
	screen.custom_minimum_size.y = 420
	# 🔑 The frame is as tall as the stage shows, so its bottom tabs are on screen without scrolling the stage — a wheel
	#    over the frame scrolls the shop page inside it, as on a phone, and never reaches the stage behind.
	var fit := func() -> void:
		if is_instance_valid(screen) and stage.scroll.size.y > 0.0:
			screen.custom_minimum_size.y = clampf(stage.scroll.size.y - 2.0, 320.0, 560.0)
	stage.scroll.resized.connect(fit)
	screen.tree_exiting.connect(func() -> void:
		if stage.scroll.resized.is_connected(fit): stage.scroll.resized.disconnect(fit))
	fit.call_deferred()
	var bar := GoAppBar.make("Shop", GoIconSet.MENU)
	bar.safe_area = false
	bar.add_action(GoIconSet.BAG, &"Bag", bot.note.bind("App bar: Bag"))
	screen.set_app_bar(bar)
	screen.set_body(page)
	var nav := GoNavBar.make([{"icon": GoIconSet.HOME, "text": "Home"}, {"icon": GoIconSet.SEARCH, "text": "Search"},
		{"icon": GoIconSet.BELL, "text": "Alerts", "badge": 3}, {"icon": GoIconSet.USER, "text": "Profile"}])
	nav.safe_area = false
	nav.selected.connect(func(index: int) -> void:
		if index == 2: nav.set_badge(2, 0)   # read — the count goes, and the badge with it
		bot.note("Tab: %s" % ["Home", "Search", "Alerts", "Profile"][index]))
	screen.set_bottom_bar(nav)
	var fab := GoFab.make(GoIconSet.PLUS, "Add to cart", func() -> void:
		state.added += 1
		bot.note("Added to cart"))
	screen.set_fab(fab)
	# The app bar's menu button opens the drawer by itself — the scaffold wires it.
	var drawer := GoDrawer.new()
	var places := ["Shop", "Wish list", "Orders"]
	drawer.body.add_child(GoNavBar.drawer_list([{"icon": GoIconSet.HOME, "text": places[0]},
		{"icon": GoIconSet.HEART, "text": places[1]}, {"icon": GoIconSet.BOX, "text": places[2]}], 0,
		func(index: int) -> void:
			state.place = index
			bot.note("Drawer: %s" % places[index])
			drawer.close()))
	screen.set_drawer(drawer)
	stage.body.add_child(screen)
	return {"search": search, "stock": stock, "tag": tag, "bar": bar, "nav": nav, "fab": fab, "drawer": drawer,
		"state": state}


func play_app(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var search: GoSearchBar = refs.search
	var nav: GoNavBar = refs.nav
	var drawer: GoDrawer = refs.drawer
	await bot.settle()
	if bot.skipping(): return
	await bot.say("GoScaffold wires an app bar, the page, bottom tabs, a floating button and a drawer together.")
	if bot.skipping(): return
	await bot.type_text(search.field, "sword", "The search bar: type, then Enter.")
	if bot.skipping(): return
	await bot.press_key(KEY_ENTER)
	if bot.skipping(): return
	bot.expect(refs.state.query == "sword", "Search submitted")
	await bot.click(refs.stock, "Filter chips switch on and off, and a tick says which.")
	if bot.skipping(): return
	bot.expect((refs.stock as Button).button_pressed, "In stock filter on")
	await bot.click((refs.tag as Node).find_child("Remove", true, false) as Control, "An input chip carries its own ✕.")
	if bot.skipping(): return
	await bot.wait(0.3)
	if bot.skipping(): return
	bot.expect(not is_instance_valid(refs.tag), "Tag chip removed")
	await bot.click(refs.fab, "The one main action floats above the tabs.")
	if bot.skipping(): return
	bot.expect(refs.state.added == 1, "Added to cart")
	await bot.click(nav.cell(2), "A bottom tab switches the whole page; its badge clears once read.")
	if bot.skipping(): return
	bot.expect(nav.selected_index() == 2, "Alerts tab chosen")
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.click((refs.bar as GoAppBar).leading_button, "The menu button opens the drawer.")
	if bot.skipping(): return
	await bot.settle(0.4)
	if bot.skipping(): return
	var places := drawer.body.get_child(0) as GoNavBar
	if places != null:
		await bot.click(places.cell(1), "Pick a place and the drawer closes.")
		if bot.skipping(): return
	bot.expect(refs.state.place == 1 and not drawer.is_open(), "Drawer pick closed it")
	await bot.wait(0.6)
	if bot.skipping(): return


# ── 25 Actions in reach ────────────────────────────────────────────────

func build_actions(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"banner": "", "sent": "", "liked": 0, "posts": 0}
	stage.body.add_child(GoStyle.section("A banner that waits for an answer", false))
	var banner := GoBanner.make("You're offline. Showing saved posts.", [{"text": "Dismiss"},
		{"text": "Retry", "action": func() -> void:
			state.banner = "Retry"
			bot.note("Banner: Retry")}], GoIconSet.WARNING)
	banner.closed.connect(bot.note.bind("Banner folded away"))
	stage.body.add_child(banner)

	stage.body.add_child(GoStyle.section("One action, its variants a press away", false))
	var send := GoSplitButton.make("Send", func() -> void:
		state.sent = "now"
		bot.note("Sent now"), ["Send later", "Save as draft"])
	send.chosen.connect(func(index: int) -> void:
		state.sent = ["later", "draft"][index]
		bot.note(["Send later", "Saved as draft"][index]))
	send.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stage.body.add_child(send)

	stage.body.add_child(GoStyle.section("A floating toolbar", false))
	var tools := GoStyle.toolbar([
		{"icon": GoIconSet.EDIT, "tooltip": &"Edit", "action": bot.note.bind("Toolbar: Edit")},
		{"icon": GoIconSet.HEART, "tooltip": &"Like", "action": func() -> void:
			state.liked += 1
			bot.note("Toolbar: Like")},
		{"icon": GoIconSet.TRASH, "tooltip": &"Delete", "action": bot.note.bind("Toolbar: Delete")},
	])
	stage.body.add_child(tools)

	stage.body.add_child(GoStyle.section("A bottom app bar with the main action at its end", false))
	var new_post := GoFab.make(GoIconSet.PLUS, "", func() -> void:
		state.posts += 1
		bot.note("New post"))
	new_post.tooltip_text_name = &"New post"
	stage.body.add_child(GoStyle.bottom_app_bar([
		{"icon": GoIconSet.SEARCH, "tooltip": &"search", "action": bot.note.bind("Bottom bar: Search")},
		{"icon": GoIconSet.HEART, "tooltip": &"Like", "action": bot.note.bind("Bottom bar: Saved")}], new_post))
	return {"banner": banner, "send": send, "tools": tools, "new_post": new_post, "state": state}


func play_actions(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var send: GoSplitButton = refs.send
	await bot.settle()
	if bot.skipping(): return
	await bot.click(_find_button(refs.banner, "Retry"), "A banner stays until it is answered. Retry acts and folds it away.")
	if bot.skipping(): return
	bot.expect(refs.state.banner == "Retry", "Banner answered with Retry")
	await bot.wait(0.6)
	if bot.skipping(): return
	await bot.click(send.main_button, "The wide half of a split button runs the usual action.")
	if bot.skipping(): return
	bot.expect(refs.state.sent == "now", "Sent now")
	await bot.click(send.menu_button, "The arrow half opens the variants.")
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.pick_in_menu(send.menu_button.get_popup(), 0, "Send it later instead.")
	if bot.skipping(): return
	bot.expect(refs.state.sent == "later", "Send later chosen from the menu")
	var buttons: Array = (refs.tools as Node).find_children("*", "GoIconButton", true, false)
	if buttons.size() > 1:
		await bot.click(buttons[1] as Control, "A floating toolbar keeps a few actions over the content.")
		if bot.skipping(): return
	bot.expect(refs.state.liked == 1, "Liked from the toolbar")
	await bot.click(refs.new_post, "A bottom app bar holds actions, and the main one at its end.")
	if bot.skipping(): return
	bot.expect(refs.state.posts == 1, "New post from the bottom app bar")
	await bot.wait(0.8)
	if bot.skipping(): return


# ── 26 Bars on the edges ───────────────────────────────────────────────
#
# 🔑 The frame is a plain `Control`, not a container — so each bar pins itself to one of its edges, the way it pins to
#    the screen's in a game. The side bars stay between the top and bottom bars (`clear_of`).

func build_edges(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"pressed": ""}
	var press := func(what: String) -> void:
		state.pressed = what
		bot.note("Pressed: %s" % what)
	stage.body.add_child(GoStyle.label("A HUD frame: bars that hold the edges of whatever they sit in. They draw nothing.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var frame := Control.new()
	frame.name = "HudFrame"
	frame.custom_minimum_size.y = 400
	var face := GoStyle.card()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(face)
	var world := CenterContainer.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.add_child(GoStyle.label("The game shows here", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	frame.add_child(world)

	var top := GoTopBar.make(3)
	top.edge_margin = 8
	var back := GoStyle.icon_button(GoIconSet.BACK, press.bind("Back"), -1, &"back")
	top.add_start(back)
	top.add_center(GoStyle.label("Stage 3"))
	top.add_end(GoStyle.chip("1,250", GoUi.color(GoTheme.WARNING), false, GoIconSet.COIN))
	frame.add_child(top)
	var actions := GoBottomBar.make(1, GoBottomBar.Justify.SPACE_BETWEEN)
	actions.edge_margin = 8
	var moves: Array[Button] = []
	for word in ["Attack", "Guard", "Item", "Run"]:
		var move := GoStyle.button(word, press.bind(word), GoStyle.Tone.COMPACT)
		GoStyle.natural_width(move)
		actions.add_start(move)
		moves.append(move)
	frame.add_child(actions)
	var tools := GoLeftSideBar.make(3)
	tools.edge_margin = 8
	var filter := GoStyle.icon_button(GoIconSet.FILTER, press.bind("Filter"), -1, &"Filter")
	tools.add_start(GoStyle.icon_button(GoIconSet.MENU, press.bind("Menu"), -1, &"menu"))
	tools.add_center(filter)
	tools.add_end(GoStyle.icon_button(GoIconSet.SETTINGS, press.bind("Settings"), -1, &"settings"))
	frame.add_child(tools)
	# A tap-once column on the right: the pets a player can call. The game marks who is out and greys who cannot come.
	var side := GoRightSideBar.make(1, GoRightSideBar.Justify.CENTER)
	side.edge_margin = 8
	var pets := ["Hen", "Cat", "Dog", "Pig", "Sheep", "Cow"]
	var summons := GoChoiceColumn.make(pets, 4)
	summons.set_dimmed(4, true)
	summons.item_pressed.connect(func(index: int) -> void:
		if summons.is_dimmed(index): return
		var out := not summons.is_selected(index)
		summons.set_selected(index, out)
		bot.note("%s %s" % [pets[index], "called" if out else "sent home"]))
	side.add_start(summons)
	frame.add_child(side)
	for bar: GoSideBar in [tools, side]: bar.clear_of([top, actions] as Array[GoEdgeBar])
	stage.body.add_child(frame)

	stage.body.add_child(GoStyle.section("Equal columns, as many as fit", false))
	var tiles := GoGrid.make(1, 120.0)
	for index in 5:
		var tile := GoStyle.card()
		tile.add_child(GoStyle.label("Tile %d" % (index + 1)))
		tiles.add_child(tile)
	stage.body.add_child(tiles)
	return {"back": back, "moves": moves, "filter": filter, "summons": summons, "tiles": tiles, "state": state}


func play_edges(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var summons: GoChoiceColumn = refs.summons
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.back, "The top bar: back at the start, the title centred, the coins at the end.")
	if bot.skipping(): return
	bot.expect(refs.state.pressed == "Back", "Top bar button pressed")
	await bot.click(refs.moves[1], "The bottom bar spreads its buttons with one gap between every pair.")
	if bot.skipping(): return
	bot.expect(refs.state.pressed == "Guard", "Bottom bar button pressed")
	await bot.click(refs.filter, "The side bars keep between the top and the bottom bar.")
	if bot.skipping(): return
	bot.expect(refs.state.pressed == "Filter", "Side bar button pressed")
	await bot.reveal(summons)
	if bot.skipping(): return
	await bot.click_at(summons.get_global_rect().position + summons.row_rect(2).get_center(),
		"A tap on a row acts at once: call the dog.")
	if bot.skipping(): return
	bot.expect(summons.is_selected(2), "The dog is out")
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.click_at(summons.get_global_rect().position + summons.row_rect(4).get_center(),
		"A greyed row cannot act now — the sheep is resting.")
	if bot.skipping(): return
	bot.expect(not summons.is_selected(4), "The resting sheep stays home")
	await bot.reveal(refs.tiles)
	if bot.skipping(): return
	await bot.say("A grid of equal columns, counted again whenever the width changes.")
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return


# ── 27 Tabs and steps ──────────────────────────────────────────────────

func build_steps(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"placed": 0}
	var tab_names := ["Posts", "Photos", "Saved"]
	stage.body.add_child(GoStyle.section("Tabs with pages you swipe", false))
	var pages: Array = []
	for spec in [[GoIconSet.CHAT, "Swipe the page sideways, or tap a tab."], [GoIconSet.STAR, "Photos go here."],
			[GoIconSet.HEART, "Nothing saved yet."]]:
		var paper := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
		# 🔑 PASS — a swipe that starts on the page must reach the tab view.
		paper.mouse_filter = Control.MOUSE_FILTER_PASS
		paper.add_child(GoUi.icons().node(spec[0], 24, GoUi.color(GoTheme.SECONDARY)))
		paper.add_child(GoStyle.label(spec[1], GoTheme.ROLE_BODY))
		pages.append(paper)
	var tabs := GoTabView.make(tab_names, pages)
	tabs.custom_minimum_size.y = 150
	tabs.tab_changed.connect(func(index: int) -> void: bot.note("Tab view: %s" % tab_names[index]))
	stage.body.add_child(tabs)

	stage.body.add_child(GoStyle.section("Steps, one open at a time", false))
	var step_names := ["Cart", "Address", "Payment"]
	var steps := GoStepper.make([
		{"title": step_names[0], "subtitle": "3 items", "content": GoStyle.label("Check the items in your cart.")},
		{"title": step_names[1], "content": GoStyle.label("Where should it go?")},
		{"title": step_names[2], "content": GoStyle.label("Pay by card or wallet.")},
	])
	steps.step_changed.connect(func(index: int) -> void: bot.note("Step: %s" % step_names[index]))
	steps.finished.connect(func() -> void:
		state.placed += 1
		bot.note("Order placed"))
	stage.body.add_child(steps)
	return {"tabs": tabs, "steps": steps, "state": state}


func play_steps(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var tabs: GoTabView = refs.tabs
	var steps: GoStepper = refs.steps
	await bot.settle()
	if bot.skipping(): return
	await bot.reveal(tabs)
	if bot.skipping(): return
	var bar := tabs.tab_bar
	await bot.click_at(bar.get_global_rect().position + bar.get_tab_rect(1).get_center(), "Tap a tab: its page slides in.")
	if bot.skipping(): return
	await _until(bot, func() -> bool: return tabs.current() == 1)
	bot.expect(tabs.current() == 1, "Photos tab chosen")
	await bot.wait(0.4)
	if bot.skipping(): return
	var area := tabs.get_global_rect()
	var middle := Vector2(area.get_center().x + area.size.x * 0.25, (bar.get_global_rect().end.y + area.end.y) * 0.5)
	await bot.say("Or swipe the page itself toward the start.")
	if bot.skipping(): return
	await bot.drag([middle, middle - Vector2(area.size.x * 0.55, 0.0)])
	if bot.skipping(): return
	await _until(bot, func() -> bool: return tabs.current() == 2)
	bot.expect(tabs.current() == 2, "A sideways swipe turned to Saved")
	await bot.reveal(steps)
	if bot.skipping(): return
	for press in [["Next", "Next opens the following step and ticks this one."], ["Next", ""],
			["Back", "Back is always free."], ["Next", ""], ["Next", "The last step's button says Done."]]:
		await bot.click(steps.find_child(press[0], true, false) as Control, press[1])
		if bot.skipping(): return
		await bot.wait(0.35)
		if bot.skipping(): return
	bot.expect(refs.state.placed == 1, "The checkout finished")
	await bot.wait(0.6)
	if bot.skipping(): return


# ── 28 Dates and times ─────────────────────────────────────────────────

func build_dates(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"date": {}, "time": [9, 30], "amount": 1}
	stage.body.add_child(GoStyle.section("A day from a month", false))
	var dates := GoDatePicker.make({"year": 2026, "month": 10, "day": 2}, func(date: Dictionary) -> void:
		state.date = date
		bot.note("Date: %d-%02d-%02d" % [date.year, date.month, date.day]))
	stage.body.add_child(dates)

	stage.body.add_child(GoStyle.section("A time on a dial", false))
	var clock := GoTimePicker.make(9, 30, func(hour: int, minute: int) -> void:
		state.time = [hour, minute]
		bot.note("Time: %d:%02d" % [hour, minute]))
	stage.body.add_child(clock)

	stage.body.add_child(GoStyle.section("Wheels that settle on one", false))
	var wheels := GoStyle.row(GoUi.metric(GoTheme.GAP))
	var hours: Array = []
	for hour in 24: hours.append(str(hour).pad_zeros(2))
	var minutes: Array = []
	for step in 12: minutes.append(str(step * 5).pad_zeros(2))
	wheels.add_child(GoWheelPicker.make(hours, 9))
	wheels.add_child(GoWheelPicker.make(minutes, 6))
	var amounts := ["x1", "x5", "x10", "x50"]
	var amount := GoWheelPicker.make(amounts, 1, func(index: int) -> void:
		state.amount = index
		bot.note("Amount: %s" % amounts[index]))
	wheels.add_child(amount)
	stage.body.add_child(wheels)
	return {"dates": dates, "clock": clock, "amount": amount, "state": state}


func play_dates(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var dates: GoDatePicker = refs.dates
	var clock: GoTimePicker = refs.clock
	var amount: GoWheelPicker = refs.amount
	await bot.settle()
	if bot.skipping(): return
	await bot.click(dates.find_child("Day15", true, false) as Control, "Today is ringed; the picked day is filled.")
	if bot.skipping(): return
	bot.expect(int(refs.state.date.get("day", 0)) == 15, "15 October picked")
	await bot.wait(0.5)
	if bot.skipping(): return
	# 🛑 The dial is the picker's own child — the bot aims at it the way a finger would, by where the numbers are.
	var dial: Control = clock._dial
	await bot.reveal(dial)
	if bot.skipping(): return
	var face := dial.get_global_rect()
	var reach := minf(face.size.x, face.size.y) * 0.5 * 0.75
	await bot.click_at(face.get_center() + Vector2(reach, 0.0), "Tap the hour on the dial; it turns to the minutes.")
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	await bot.click_at(face.get_center() - Vector2(reach, 0.0), "Then the minutes: nine o'clock is a quarter to.")
	if bot.skipping(): return
	bot.expect(refs.state.time == [3, 45], "Time set to 3:45")
	await bot.reveal(amount)
	if bot.skipping(): return
	await bot.click_at(amount.get_global_rect().get_center() + Vector2(0.0, amount.item_height),
		"A tap below the band brings that item up; it settles, then says so.")
	if bot.skipping(): return
	await _until(bot, func() -> bool: return refs.state.amount == 2)
	bot.expect(amount.get_selected() == 2 and refs.state.amount == 2, "Amount wheel settled on x10")
	await bot.wait(0.6)
	if bot.skipping(): return


# ── 29 Long lists ──────────────────────────────────────────────────────

func build_feeds(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"refreshed": 0, "deleted": "", "read": "", "moves": []}
	stage.body.add_child(GoStyle.section("A thousand rows, only the ones in view built", false))
	var feed := GoListView.make(1000, 48.0, func(index: int) -> Control:
		return GoStyle.list_row(Button.new(), GoIconSet.USER, "Player %d" % (index + 1), Callable(), Color.TRANSPARENT,
			"", false))
	feed.custom_minimum_size.y = 230
	feed.spacing = GoUi.metric(GoTheme.GAP_TINY)
	stage.body.add_child(feed)
	# 🛑 Connect after `attach()` returns — a lambda handed to `attach()` would capture `refresh` before it is assigned.
	var refresh := GoRefresh.attach(feed)
	refresh.refresh_requested.connect(func() -> void:
		bot.note("Feed refreshing")
		await feed.get_tree().create_timer(0.8).timeout
		if not is_instance_valid(refresh): return
		refresh.finish()
		state.refreshed += 1
		bot.note("Feed refreshed"))
	stage.body.add_child(GoStyle.label("At the top, pull the list down and let go to refresh it.", GoTheme.ROLE_MICRO,
		GoUi.color(GoTheme.MUTED)))

	stage.body.add_child(GoStyle.section("Rows you swipe aside", false))
	var mails: Array[GoSwipeRow] = []
	for who in ["Ann", "Ben"]:
		var line := GoSwipeRow.wrap(GoStyle.list_row(Button.new(), GoIconSet.CHAT, "Message from %s" % who, Callable(),
			Color.TRANSPARENT, "", false),
			{"icon": GoIconSet.TRASH, "text": "Delete", "tone": GoTheme.DANGER, "action": func() -> void:
				state.deleted = who
				bot.note("Deleted: %s" % who)},
			{"icon": GoIconSet.CHECK, "text": "Read", "tone": GoTheme.SUCCESS, "dismiss": false, "action": func() -> void:
				state.read = who
				bot.note("Read: %s" % who)})
		stage.body.add_child(line)
		mails.append(line)

	stage.body.add_child(GoStyle.section("A queue you put in order", false))
	var songs := ["Intro", "Village theme", "Boss battle", "Credits"]
	var rows: Array = []
	for title in songs:
		rows.append(GoStyle.list_row(Button.new(), GoIconSet.PLAY, title, Callable(), Color.TRANSPARENT, "", false))
	var queue := GoReorderList.make(rows)
	queue.reordered.connect(func(from: int, to: int) -> void:
		songs.insert(to, songs.pop_at(from))
		state.moves.append([from, to])
		bot.note("Moved: %s → %d" % [songs[to], to + 1]))
	stage.body.add_child(queue)
	return {"feed": feed, "refresh": refresh, "mails": mails, "queue": queue, "state": state}


func play_feeds(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var feed: GoListView = refs.feed
	var queue: GoReorderList = refs.queue
	await bot.settle()
	if bot.skipping(): return
	await bot.reveal(feed)
	if bot.skipping(): return
	var top := feed.get_global_rect()
	var grab := Vector2(top.get_center().x, top.position.y + 24.0)
	await bot.say("At the top of a list, pull it down and let go.")
	if bot.skipping(): return
	await bot.drag([grab, grab + Vector2(0.0, 90.0), grab + Vector2(0.0, 170.0)])
	if bot.skipping(): return
	await _until(bot, func() -> bool: return refs.state.refreshed >= 1, 3.0)
	bot.expect(refs.state.refreshed == 1, "Pull to refresh ran once")
	await bot.scroll_by(feed, 8, "Roll through a thousand rows: only the ones near the view exist.")
	if bot.skipping(): return
	bot.expect(feed.scroll_vertical > 0 and feed.built_indexes().size() < 40,
		"Only the rows near the view are built (%d)" % feed.built_indexes().size())
	var mails: Array[GoSwipeRow] = refs.mails
	for at in mails.size():
		var line := mails[at]
		if not is_instance_valid(line): continue
		await bot.reveal(line)
		if bot.skipping(): return
		await _still(bot, line)
		var rect := line.get_global_rect()
		var lean := rect.size.x * 0.32 * (1.0 if at == 0 else -1.0)
		await bot.say("Swipe toward the start to delete." if at == 0 else "Toward the end marks it read and springs back.")
		if bot.skipping(): return
		await bot.drag([rect.get_center() + Vector2(lean, 0.0), rect.get_center() - Vector2(lean, 0.0) * 1.1])
		if bot.skipping(): return
		await bot.wait(0.6)
		if bot.skipping(): return
	bot.expect(refs.state.deleted == "Ann" and refs.state.read == "Ben", "Ann deleted, Ben read")
	# 🛑 Ann's row is still folding away, and the queue rises with it — aim only once it has stopped.
	await _still(bot, queue)
	await bot.reveal(queue)
	if bot.skipping(): return
	await _still(bot, queue)
	var rows := queue.rows()
	var grip := rows[3].get_parent().get_node(^"Grip") as Control
	var step := rows[3].get_global_rect().position.y - rows[2].get_global_rect().position.y
	var hold := grip.get_global_rect().get_center()
	await bot.say("Drag a row by its grip; the others step aside.")
	if bot.skipping(): return
	# 🛑 Upward — the queue sits at the foot of the stage, and a drag down there runs into the edge that scrolls.
	await bot.drag([hold, hold - Vector2(0.0, step * 2.2)])
	if bot.skipping(): return
	await bot.wait(0.4)
	if bot.skipping(): return
	bot.expect(refs.state.moves == [[3, 1]], "Credits moved to second (%s)" % str(refs.state.moves))


# ── 30 Progress and ranges ─────────────────────────────────────────────

func build_progress(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"done": 0, "price": []}
	stage.body.add_child(GoStyle.section("Progress you can measure", false))
	var line := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var download := GoProgress.linear()
	download.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	download.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(download)
	var percent := GoStyle.label("0%", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	GoStyle.natural_width(percent)
	percent.custom_minimum_size.x = 48
	line.add_child(percent)
	stage.body.add_child(line)
	var start := GoStyle.button("Download the map pack", Callable(), GoStyle.Tone.PRIMARY)
	start.pressed.connect(func() -> void:
		if download.value > 0.0 and download.value < 1.0: return
		bot.note("Download started")
		var run := download.create_tween()
		run.tween_method(func(at: float) -> void:
			download.value = at
			percent.text = "%d%%" % roundi(at * 100.0), 0.0, 1.0, 1.2)
		run.finished.connect(func() -> void:
			state.done += 1
			bot.note("Download done")))
	stage.body.add_child(start)

	stage.body.add_child(GoStyle.section("Waits with no measure", false))
	var waits := GoStyle.row(GoUi.metric(GoTheme.GAP))
	waits.add_child(GoProgress.circular(true))
	waits.add_child(GoLoadingIndicator.new())
	var held := GoLoadingIndicator.new()
	held.contained = true
	waits.add_child(held)
	stage.body.add_child(waits)
	stage.body.add_child(GoStyle.label("A ring that turns, and a shape that keeps morphing — bare and on a disc.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))

	stage.body.add_child(GoStyle.section("A range with two handles", false))
	var reading := GoStyle.label("40 – 220 gold", GoTheme.ROLE_BODY)
	stage.body.add_child(reading)
	var price := GoRangeSlider.make(0.0, 500.0, 40.0, 220.0, 10.0)
	price.changed.connect(func(low: float, high: float) -> void: reading.text = "%d – %d gold" % [low, high])
	price.change_ended.connect(func(low: float, high: float) -> void:
		state.price = [low, high]
		bot.note("Price: %d – %d" % [low, high]))
	stage.body.add_child(price)
	return {"download": download, "start": start, "waits": waits, "price": price, "state": state}


func play_progress(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var download: GoProgress = refs.download
	var price: GoRangeSlider = refs.price
	await bot.settle()
	if bot.skipping(): return
	await bot.click(refs.start, "A download knows how far it has come, so it shows it.")
	if bot.skipping(): return
	await _until(bot, func() -> bool: return refs.state.done >= 1, 3.0)
	bot.expect(download.value >= 0.999 and refs.state.done == 1, "Download finished")
	await bot.reveal(refs.waits)
	if bot.skipping(): return
	await bot.say("No measure yet? A ring that turns, or a shape that keeps morphing.")
	if bot.skipping(): return
	await bot.wait(1.2)
	if bot.skipping(): return
	await bot.reveal(price)
	if bot.skipping(): return
	# The handles' spots on the track — the same sum the slider makes when it draws them.
	var y := price.get_global_rect().get_center().y
	var from := Vector2(price.global_position.x + price._x_of(220.0), y)
	var to := Vector2(price.global_position.x + price._x_of(300.0), y)
	await bot.say("A press takes the nearer handle; the two never cross.")
	if bot.skipping(): return
	await bot.drag([from, to])
	if bot.skipping(): return
	bot.expect(absf(price.high - 300.0) <= 10.0 and is_equal_approx(price.low, 40.0),
		"High handle moved to about 300 (%d – %d)" % [price.low, price.high])
	await bot.wait(0.6)
	if bot.skipping(): return


# ── 31 Pinch and zoom ──────────────────────────────────────────────────

func build_zoom(stage: SimStage, bot: SimBot) -> Dictionary:
	var state := {"noted": 1.0}
	stage.body.add_child(GoStyle.label("A map you zoom with the wheel or two fingers, and pan once zoomed.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var map := GridContainer.new()
	map.columns = 8
	for index in 48:
		var cell := ColorRect.new()
		var town := index in [9, 21, 30, 44]
		var land := (index % 8 + floori(index / 8.0)) % 3 != 0
		cell.color = GoUi.color(GoTheme.WARNING if town else (GoTheme.SUCCESS if land else GoTheme.INFO))
		cell.color.a = 1.0 if town else 0.55
		cell.custom_minimum_size = Vector2(20, 20)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# 🔑 PASS — a drag that starts on the map must reach the zoom view to pan it.
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		map.add_child(cell)
	var view := GoZoomView.wrap(map, 4.0)
	view.custom_minimum_size.y = 250
	stage.body.add_child(view)
	var controls := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var zoom_in := GoStyle.icon_button(GoIconSet.PLUS, func() -> void: view.zoom_to(view.get_zoom() * 1.5), -1, &"Zoom in")
	controls.add_child(zoom_in)
	controls.add_child(GoStyle.icon_button(GoIconSet.MINUS, func() -> void: view.zoom_to(view.get_zoom() / 1.5), -1,
		&"Zoom out"))
	var reset := GoStyle.button("Reset", func() -> void:
		view.reset()
		bot.note("Zoom reset"), GoStyle.Tone.COMPACT)
	GoStyle.natural_width(reset)
	controls.add_child(reset)
	var reading := GoStyle.label("1.0×", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SECONDARY))
	reading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(reading)
	stage.body.add_child(controls)
	view.zoom_changed.connect(func(zoom: float) -> void:
		reading.text = "%.1f×" % zoom
		# Every frame of a zoom reports — the log gets a line only for a real step.
		if absf(zoom - state.noted) >= 0.2:
			state.noted = zoom
			bot.note("Zoom: %.1f×" % zoom))
	return {"view": view, "zoom_in": zoom_in, "reset": reset, "state": state}


func play_zoom(_stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	var view: GoZoomView = refs.view
	await bot.settle()
	if bot.skipping(): return
	await bot.reveal(view)
	if bot.skipping(): return
	await bot.scroll_by(view, -3, "The wheel zooms in around the pointer.")
	if bot.skipping(): return
	await bot.wait(0.3)
	if bot.skipping(): return
	bot.expect(view.get_zoom() > 1.4, "The wheel zoomed in (%.2f)" % view.get_zoom())
	var centre := view.get_global_rect().get_center()
	await bot.say("Zoomed in, a drag pans. The map never slides out of the view.")
	if bot.skipping(): return
	await bot.drag([centre, centre + Vector2(-110.0, -50.0)])
	if bot.skipping(): return
	bot.expect(view.content.position != Vector2.ZERO, "The map panned")
	await bot.click(refs.zoom_in, "Buttons zoom too — for anyone without a wheel or two fingers.")
	if bot.skipping(): return
	await bot.wait(0.5)
	if bot.skipping(): return
	await bot.click(refs.reset, "Reset goes back to the whole map.")
	if bot.skipping(): return
	await _until(bot, func() -> bool: return is_equal_approx(view.get_zoom(), 1.0))
	bot.expect(is_equal_approx(view.get_zoom(), 1.0), "Back to 1×")
	await bot.wait(0.5)
	if bot.skipping(): return
