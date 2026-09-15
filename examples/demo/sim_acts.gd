## 🎞️ **장면 대본.** 한 장면이 위젯을 짓고, 봇이 그것을 실제로 만진다.
##
## 장면 하나 = 함수 **둘**이다.
##   `build_<key>(stage, bot) -> Dictionary`  화면을 짓고, 봇이 겨눌 노드를 사전으로 돌려준다.
##   `play_<key>(stage, bot, refs)`           그 노드를 진짜 입력으로 조작한다.
##
## 둘로 나눈 이유 — 사이드바에서 위젯 하나를 고르면 `build_` 만 불러 **사람이 직접** 만지고(탐색),
## "Play this" 를 누르면 같은 화면 위에서 `play_` 가 봇을 움직인다(시연). 화면은 한 벌이다.
##
## 조작은 전부 진짜 입력이라 위젯의 콜백이 실제로 불리고, 그 콜백이 오른쪽 기록줄에 한 줄씩
## 남는다 — 기록줄이 곧 "정말 눌렸다"는 증거다. 사람이 만져도 같은 기록줄이 움직인다.
##
## 🛑 사람이 눌러 주기를 **기다리지 않는다.** `await dialogs.confirm(…)` 처럼 응답을 기다리는
##    호출은 건너뛰기가 걸렸을 때 영영 풀리지 않는다. 답은 시그널로 받는다.
## 🛑 `build_` 는 봇 없이도 완결된 화면이어야 한다 — 봇만 할 수 있는 일(자료 도착, 투어 시작)은
##    버튼으로 두고, `play_` 에서 봇이 그 버튼을 누른다.
class_name SimActs
extends RefCounted


## 장면 차례. 제목·설명·아이콘은 무대 머리글과 사이드바가 함께 쓴다. `hint` 는 탐색 모드의 안내.
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
	]


## 장면을 짓는다. 봇이 겨눌 노드를 사전으로 돌려준다.
func build(key: StringName, stage: SimStage, bot: SimBot) -> Dictionary:
	return Callable(self, "build_" + key).call(stage, bot)


## 지은 장면 위에서 봇을 움직인다.
func play(key: StringName, stage: SimStage, bot: SimBot, refs: Dictionary) -> void:
	await Callable(self, "play_" + key).call(stage, bot, refs)


# ── 01 HUD 막대와 퀵 슬롯 ──────────────────────────────────────────────

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


# ── 02 버튼 ────────────────────────────────────────────────────────────

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


# ── 03 입력 ────────────────────────────────────────────────────────────

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


# ── 04 선택과 메뉴 ─────────────────────────────────────────────────────

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


# ── 05 목록과 이동 ─────────────────────────────────────────────────────

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


# ── 06 데이터 표시 ─────────────────────────────────────────────────────

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
	# 자료가 "도착하는" 순간을 버튼으로 둔다 — 사람이 눌러도, 봇이 눌러도 같은 일이 일어난다.
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


# ── 07 상태와 알림 ─────────────────────────────────────────────────────

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
	# 시연에서는 알림이 하나씩 나타난다 — 탐색에서는 처음부터 다 보인다.
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
	# 🛑 진행은 트윈이라 배속을 안 탄다 — 4배속 검사에서는 아직 도중일 수 있다. 시작만 확인한다.
	bot.expect(bar.value > 0.0, "Download is running")
	await bot.click(refs.shout, "A temporary notice appears, then fades away.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(refs.fail, "An error uses a different color and feedback cue.")
	if bot.skipping(): return
	await bot.wait(1.6)
	if bot.skipping(): return


# ── 08 대화상자·시트·팝업 ──────────────────────────────────────────────

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

	# 시트 — 아래에서 올라와 목록을 담는다. 한 벌을 두고 열 때마다 다시 채운다.
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
		sheet.add_footer(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))   # 다음 open() 이 치운다
		bot.note("Sheet opened: 20 items"))
	stage.body.add_child(open_sheet)

	# 팝업 — 가운데 떠서 배경을 어둡게 한다. 누를 때마다 새로 만들고, 닫히면 제 레이어와 함께 사라진다.
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


# ── 09 권유 카드 ───────────────────────────────────────────────────────

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
	# 탐색 모드에서 닫은 카드를 다시 부를 수 있어야 한다.
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


# ── 10 터치 컨트롤 ─────────────────────────────────────────────────────

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


# ── 11 코치마크 투어 ───────────────────────────────────────────────────

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
	# 🛑 가리킨 것을 누르면 투어가 **스스로** 다음으로 넘어간다 — 여기서 '다음'을 또 누르면
	#    끝난 투어의 없는 버튼을 겨누게 된다.
	await bot.click(refs.slot, "Click the highlighted slot to advance the tour.")
	if bot.skipping(): return
	await bot.wait(1.4)
	if bot.skipping(): return
	await bot.click(tour.next_button, "Finish the guided tour.")
	if bot.skipping(): return
	await bot.wait(1.0)
	if bot.skipping(): return


# ── 12 스크롤과 반응형 격자 ────────────────────────────────────────────

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


# ── 13 반응형 폼 ───────────────────────────────────────────────────────
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


# ── 14 HUD 앵커 ────────────────────────────────────────────────────────

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


# ── 15 테마와 아이콘 ───────────────────────────────────────────────────

func build_theming(stage: SimStage, bot: SimBot) -> Dictionary:
	var preview := PanelContainer.new()
	var pair: Array[Theme] = preload("theme_picker.gd").pair()
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


# ── 거들기 ─────────────────────────────────────────────────────────────

## 화면 전체를 덮는 장면의 바탕 레이어. 무대가 비워질 때 함께 사라진다.
static func _full_layer(stage: SimStage) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	stage.add_child(layer)
	var background := ColorRect.new()
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	return layer


## 화면 전체를 덮는 장면에서 위젯 목록으로 돌아가는 버튼 — 사이드바가 가려져 있으므로 필요하다.
## 봇은 이것을 누르지 않는다.
static func _back_button(stage: SimStage) -> Button:
	var back := GoStyle.button("Back to widgets", stage.leave_requested.emit, GoStyle.Tone.BARE)
	back.name = "BackToWidgets"
	return back


## 글자로 버튼을 찾는다 — 위젯이 속을 감춰 두었을 때.
static func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == text: return child
		var found := _find_button(child, text)
		if found != null: return found
	return null
