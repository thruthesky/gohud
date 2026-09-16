# Recipes — full screens and wiring

Every snippet uses only APIs from the other references. The five templates in `assets/templates/` are complete,
headless-tested versions of the first screens; copy them rather than retyping.

## Contents

1. [App flow: main menu → game → settings](#1-app-flow)
2. [Game scene: HUD + pause + inventory](#2-game-scene)
3. [Login / sign-up form](#3-login--sign-up-form)
4. [Shop with purchase confirmation](#4-shop)
5. [Quest log with tabs](#5-quest-log)
6. [Character sheet on a responsive grid](#6-character-sheet)
7. [Context menu and dropdowns](#7-context-menu-and-dropdowns)
8. [First-run tutorial](#8-first-run-tutorial)
9. [Loading, empty and error states](#9-loading-empty-and-error-states)
10. [Controls floating over a map](#10-controls-floating-over-a-map)
11. [Runtime theme switcher](#11-runtime-theme-switcher)
12. [Daily attendance rewards](#12-daily-attendance-rewards)
13. [A developer console you cannot ship](#13-a-developer-console-you-cannot-ship)
14. [A form that says which box is wrong](#14-a-form-that-says-which-box-is-wrong)
15. [A side panel on a wide screen](#15-a-side-panel-on-a-wide-screen)

## 1. App flow

```gdscript
# res://main.gd on the main scene's root Node
extends Node

const MainMenu := preload("res://ui/main_menu.gd")
const Settings := preload("res://ui/settings_menu.gd")

func _ready() -> void:
	GoUi.use_preset(GoThemePresets.MEDIEVAL_DARK)      # once, before any UI exists
	show_menu()

func show_menu() -> void:
	var menu := MainMenu.new()
	menu.game_title = "Ashen Crown"
	add_child(menu)
	menu.continue_requested.connect(func() -> void: _start_game(menu))
	menu.new_game_requested.connect(func() -> void: _start_game(menu))
	menu.settings_requested.connect(open_settings)

func open_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS       # works over a paused game too
	add_child(layer)
	var settings := Settings.new()
	layer.add_child(settings)
	settings.closed.connect(func(_saved: bool) -> void: layer.queue_free())

func _start_game(menu: Node) -> void:
	menu.queue_free()
	get_tree().change_scene_to_file("res://game/game.tscn")
```

## 2. Game scene

```gdscript
extends Node2D

const Hud := preload("res://ui/game_hud.gd")
const Pause := preload("res://ui/pause_menu.gd")
const Inventory := preload("res://ui/inventory_sheet.gd")

# 🛑 Do **not** write `var hud: CanvasLayer` here. GDScript checks member access against the declared
#    type, and `menu_requested`, `toast()` and `set_health()` belong to the template, not to CanvasLayer —
#    the script then fails to **parse**, with no output at all (verified 2026-09-16).
#    Leave these untyped, or type them with a `class_name` your own project gives the template.
var hud                                                # game_hud.gd
var pause                                              # pause_menu.gd
var inventory                                          # inventory_sheet.gd

func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	pause = Pause.new()
	add_child(pause)
	inventory = Inventory.new()
	add_child(inventory)

	hud.menu_requested.connect(pause.open)
	hud.move_input.connect(func(v: Vector2) -> void: $Player.direction = v)
	hud.slot_used.connect(_on_slot_used)
	inventory.item_used.connect(func(item: Dictionary) -> void:
		hud.toast("Used %s" % item.name, GoTheme.SUCCESS))
	hud.set_health($Player.health, $Player.max_health)

func _unhandled_input(event: InputEvent) -> void:
	if GoSurface.is_any_open():                        # a sheet, dialog or pause menu is up
		return
	if event.is_action_pressed(&"inventory"):
		inventory.open()

func _on_slot_used(index: int) -> void:
	if index == 0:
		$Player.heal(120)
		hud.set_health($Player.health, $Player.max_health)

func _on_party_invite(from: String) -> void:
	hud.ask("%s invited you" % from, "Join their party?", "Join", func() -> void: _join(from))
```

## 3. Login / sign-up form

```gdscript
extends Control

signal signed_in(email: String)

var _email: LineEdit
var _password: LineEdit
var _error: Control
var _submit: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	var holder := Control.new()                        # owns the whole branch so GoForm finds %BackButton
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var form := GoForm.new()
	var scroll := GoScroll.new()
	var column := GoStyle.column()
	holder.add_child(form)
	form.add_child(scroll)
	scroll.add_child(column)

	column.add_child(GoStyle.label("Welcome back", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.label("Sign in to sync your progress.", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	_error = GoStyle.alert("", GoTheme.DANGER)
	_error.visible = false
	column.add_child(_error)
	_email = GoStyle.line_edit("Email")
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	column.add_child(_email)
	_password = GoStyle.line_edit("Password")
	_password.secret = true
	_password.text_submitted.connect(func(_t: String) -> void: _on_submit())
	column.add_child(_password)
	_submit = GoStyle.button("Sign in", _on_submit, GoStyle.Tone.PRIMARY)
	column.add_child(_submit)
	var back := GoStyle.button("Back", func() -> void: queue_free(), GoStyle.Tone.BARE)
	back.name = "BackButton"
	column.add_child(back)
	for node in holder.find_children("*", "", true, false):
		node.owner = holder                        # the whole branch (surfaces.md §4)
	back.unique_name_in_owner = true
	add_child(holder)

func _on_submit() -> void:
	if not _email.text.contains("@") or _password.text.length() < 8:
		_show_error("Enter a valid email and a password of at least 8 characters.")
		GoFeedback.failed()
		return
	_submit.disabled = true
	_submit.text = GoUi.text(&"loading")
	var ok: bool = await Auth.sign_in(_email.text, _password.text)   # your backend
	_submit.disabled = false
	_submit.text = "Sign in"
	GoStyle.fit_words(_submit)
	if ok:
		signed_in.emit(_email.text)
	else:
		_show_error("Email or password is wrong.")

func _show_error(message: String) -> void:
	(_error.find_children("*", "Label", true, false)[0] as Label).text = message
	_error.visible = true
```

## 4. Shop

```gdscript
func build_shop(sheet: GoSheet, dialogs: GoDialogs, notice: GoNotice, gold: int, offers: Array) -> void:
	sheet.open("Merchant")
	for old in sheet.footer().get_children():          # 1.0.3 and older; newer gohud: add buttons with add_footer()
		sheet.footer().remove_child(old)
		old.queue_free()
	sheet.toolbar().add_child(GoStyle.chip("%d gold" % gold, GoUi.color(GoTheme.WARNING)))
	sheet.toolbar().visible = true
	for offer in offers:                                # {name, price, icon, description}
		var row := GoStyle.list_button(offer.icon, "%s — %d g" % [offer.name, offer.price],
			Callable(), Color.TRANSPARENT, offer.description, false)
		row.disabled = offer.price > gold
		row.pressed.connect(func() -> void:
			var yes := await dialogs.confirm("Buy %s?" % offer.name, "It costs {price} gold.", "Buy", "",
				"", {"price": offer.price})
			if yes:
				notice.show_text("Bought %s" % offer.name, GoTheme.SUCCESS))
		sheet.body.add_child(row)
```

**A coupon field** on the same sheet. `GoCodeInput` keeps one hidden `LineEdit` behind the drawn cells, so
pasting a code from a chat app works and an IME cannot swallow a letter:

```gdscript
var coupon := GoCodeInput.make(12, 4)                  # 12 characters, grouped in fours
sheet.body.add_child(GoField.make("Coupon code", coupon, "Letters and digits"))
coupon.completed.connect(func(code: String) -> void:
	var reply := await redeem(code)                    # your server call
	if reply.ok:
		notice.show_text("Redeemed", GoTheme.SUCCESS)
	else:
		coupon.set_error(reply.message)                 # marks the cells, keeps the code for editing
)
```

**A purchase the player can take back.** A snackbar with a button is better than a confirm dialog for a
cheap, reversible action — it does not stop the game to ask:

```gdscript
var snackbar := GoSnackbar.new()                       # once, on the scene root
add_child(snackbar)

# `post()` returns the index of the button that was pressed, or -1 when it expired.
if await snackbar.post({"text": "Bought %s" % offer.name, "actions": ["Undo"]}) == 0:
	refund(offer)
```

## 5. Quest log

```gdscript
func build_quest_log(parent: Control, quests: Array) -> void:
	var column := GoStyle.column()
	parent.add_child(column)
	var tabs := GoStyle.tabs(["Active", "Completed"])
	column.add_child(tabs)
	var list := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	column.add_child(list)
	var fill := func(tab: int) -> void:
		for old in list.get_children():
			list.remove_child(old)
			old.queue_free()
		var shown := quests.filter(func(q: Dictionary) -> bool: return q.done == (tab == 1))
		if shown.is_empty():
			list.add_child(GoStyle.empty_state(GoIconSet.BOOK, "No quests here", false))
		for quest in shown:
			var card := GoStyle.card()
			var inner := GoStyle.padding()
			card.add_child(inner)
			var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
			inner.add_child(body)
			body.add_child(GoStyle.label(quest.title, GoTheme.ROLE_SUBTITLE))
			for step in quest.steps:                    # {text, done}
				var box := GoStyle.checkbox(step.text, false)
				box.button_pressed = step.done
				box.disabled = true
				body.add_child(box)
			list.add_child(card)
	tabs.tab_changed.connect(fill)
	fill.call(0)
```

**A leaderboard instead of cards.** When the rows are comparable numbers, a table beats a list — and
`GoTable` sorts a numeric column **as numbers**, so `2` does not come after `10`:

```gdscript
var board := GoTable.make(
	[{"text": "Name"}, {"text": "Score", "numeric": true}, {"text": "Clear", "numeric": true}],
	[["Aldric", "1420", "38"], ["Mira", "980", "51"], ["Toren", "1120", "44"]])
board.sort_by(1, false)                                # highest score first
board.row_selected.connect(func(row: int) -> void: show_player(board.rows()[row]))
column.add_child(board)

# Long lists: numbered pages where there is room, one More row where there is not.
var pager := (GoPagination.more(load_more) if GoUi.is_handheld_platform()
	else GoPagination.make(1, 12, load_page))
column.add_child(pager)
```

## 6. Character sheet

`examples/medieval/medieval.gd` in gohud is the full version (character card with bars and equipment rows,
satchel of slots, quest card). The pattern:

```gdscript
var grid := GoStyle.responsive_grid(320.0)             # 1 column on phones, 2–3 on desktop
page.add_child(grid)
var panel := PanelContainer.new()
panel.add_theme_stylebox_override(&"panel", GoStyle.surface(GoTheme.BOX_PANEL))   # keeps the preset's frame
grid.add_child(panel)
var inset := GoStyle.padding(20)
panel.add_child(inset)
var body := GoStyle.column(16)
inset.add_child(body)
body.add_child(GoStyle.label("Character", GoTheme.ROLE_SUBTITLE))
body.add_child(GoStyle.avatar("Ser Aldric", 64))
body.add_child(GoStyle.table(["Stat", "Value"], [["Attack", "42"], ["Defence", "28"]]))
var slots := GoStyle.responsive_grid(56.0, 12)
body.add_child(slots)
for icon in [GoIconSet.SWORD, GoIconSet.SHIELD, GoIconSet.POTION, GoIconSet.KEY]:
	var slot := GoSlot.new()
	slot.icon_name = icon
	slot.quantity = GoSlot.NONE
	slots.add_child(slot)
```

**The stats as a shape.** A table of five numbers tells you the values; the pentagon tells you the *build* at
a glance — and the dashed overlay answers "what happens if I equip this?" without leaving the screen:

```gdscript
# 🛑 Values are 0–1. Your game decides what counts as 1 (the class cap? the server's best?) —
#    drawing 120 strength next to 45 intellect raw makes the shape lie.
var radar := GoRadar.make(
	{"STR": 0.85, "AGI": 0.50, "INT": 0.30, "VIT": 0.70, "LUK": 0.45},
	{"STR": 0.92, "AGI": 0.44, "INT": 0.30, "VIT": 0.70, "LUK": 0.45})   # the sword you are hovering
body.add_child(radar)

# Where the damage actually goes. legend() says every slice in words as well as in colour.
var donut := GoDonut.make([
	{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340}, {"label": "Pierce", "value": 90}])
donut.center_text = "1050"
body.add_child(donut)
body.add_child(donut.legend())
```

## 7. Context menu and dropdowns

**Long-press or right-click on any control** — the inventory slot, the table row, the friend in the list:

```gdscript
GoContextMenu.attach(slot, [
	{"text": "Equip", "icon": GoIconSet.SWORD, "action": _equip},
	{"text": "Split stack", "icon": GoIconSet.COPY, "action": _split},
	{"separator": true},
	{"text": "Drop", "icon": GoIconSet.TRASH, "action": _drop, "danger": true},
])

`items` may also be a `Callable` that builds the array **each time the menu opens** — use that whenever the
actions depend on state (is this player the party leader? is the stack splittable?).
```

🔑 A finger that moves more than 12 dp cancels the press, so a long list still scrolls normally. Attaching
twice replaces the first menu — call it again when the items change, don't stack them.

🛑 Touch has no right-click and no hover, so a long-press menu is **invisible** until someone finds it. Put
every action it holds somewhere else too (a footer button, a detail page), or first-time players never meet it.

- Simple menu button: `GoStyle.dropdown("More", [{"text": "Rename", "icon": GoIconSet.EDIT}, "Delete"], _on_more)`.
- Choice field: `GoStyle.select(["Low", "Mid", "High"], "Quality")` + `item_selected`.
- Rich menu anchored to any control (rows with descriptions, icons, dividers): `GoSurface` with
  `placement = ANCHOR`, `anchor_control`, `show_header = false`, `scrim_transparent = true`,
  `dismiss_on_scrim = true` inside a `CanvasLayer` — full code in surfaces.md §1.

## 8. First-run tutorial

```gdscript
func maybe_start_tutorial(hud: CanvasLayer, save: Dictionary) -> void:
	if save.get("tutorial_done", false):
		return
	var tour := GoCoachMark.new()
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	layer.add_child(tour)
	tour.finished.connect(func(completed: bool) -> void:
		save.tutorial_done = true
		layer.queue_free())
	tour.start([
		{"target": hud.hp, "title": "Health", "body": "Drink a potion before it runs out."},
		{"target": hud.slots[0], "title": "Quick slot", "body": "Tap it to use the potion."},
	])
```

## 9. Loading, empty and error states

```gdscript
func show_loading(list: VBoxContainer) -> void:
	for i in 4:
		list.add_child(GoStyle.skeleton(0.0, 48.0))       # pulses unless reduce_motion

func show_result(list: VBoxContainer, rows: Array, error := "") -> void:
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	if not error.is_empty():
		list.add_child(GoStyle.alert(error, GoTheme.DANGER))
		list.add_child(GoStyle.button(GoUi.text(&"retry"), reload, GoStyle.Tone.COMPACT))
	elif rows.is_empty():
		list.add_child(GoStyle.empty_state(GoIconSet.SEARCH, "No results", false))
	for row in rows:
		list.add_child(GoStyle.list_button(GoIconSet.USER, row.name, Callable(), Color.TRANSPARENT, row.status, false))
```

**A button that must not fire twice.** A skeleton is for a list whose shape you know; a button waiting on a
server is a different wait, and the danger is a second press, not a blank area:

```gdscript
func _on_buy_pressed(button: Button) -> void:
	GoSpinner.busy(button, true)                        # same size, disabled, label put aside
	var reply := await purchase()
	# 🛑 The player may have closed the screen while the request was in flight.
	if is_instance_valid(button):
		GoSpinner.busy(button, false)                   # the label comes back
	handle(reply)
```

`GoSpinner.new()` on its own is the standalone version, for a panel that is filling in.

## 10. Controls floating over a map

```gdscript
var anchor := GoHudAnchor.new()
anchor.spot = GoHudAnchor.Spot.TOP_CENTER
hud_root.add_child(anchor)
var pill := PanelContainer.new()
pill.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box())   # readable over any backdrop
anchor.add_child(pill)
var row := GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
pill.add_child(row)
row.add_child(GoStyle.segmented(["Map", "Quests", "Party"], 0, _switch_layer, false, true))
var zoom := GoStyle.icon_button(GoIconSet.PLUS, _zoom_in, -1, &"Zoom in")
var unzoom := GoStyle.icon_button(GoIconSet.MINUS, _zoom_out, -1, &"Zoom out")
zoom.touch_peers = [zoom, unzoom]
unzoom.touch_peers = [zoom, unzoom]
row.add_child(unzoom)
row.add_child(zoom)
```

## 11. Runtime theme switcher

```gdscript
func switch_look(id: StringName) -> void:
	GoUi.use_preset(id)                                 # clears explicit theme/skin/icons, notifies widgets
	RenderingServer.set_default_clear_color(GoUi.color(GoTheme.BACKGROUND))
	for screen in get_tree().get_nodes_in_group(&"ui_screens"):
		screen.build()                                  # every template exposes build(); rebuild keeps state you pass in
```

Add each screen with `add_to_group(&"ui_screens")`. Settings persistence: store the preset id and re-apply it with
`GoUi.use_preset()` at boot before building the first screen.

## 12. Daily attendance rewards

```gdscript
func build_attendance(page: VBoxContainer, save: Dictionary) -> void:
	# days: [{"reward": "100 gold", "icon": GoIconSet.COIN}, …] — one entry per day of the run
	# The second argument is the **last day already claimed** (-1 = nothing claimed yet).
	var calendar := GoRewardCalendar.make(days, save.claimed_until)
	calendar.claimed.connect(func(day: int) -> void:
		grant(days[day])
		save.claimed_until = day
		calendar.set_claimed_until(day))                # today turns into a claimed day
	page.add_child(calendar)
```

🔑 **Only today can be pressed.** Yesterday is gone and tomorrow has not happened — a calendar that lets you
press either one is a bug report waiting to happen. The widget enforces this; your handler does not have to.

🛑 The day number comes from **your** save data, not from the device clock alone — a player who moves the
phone's clock forward must not collect a week in a minute. Check the day against the server.

## 13. A developer console you cannot ship

```gdscript
func _ready() -> void:
	console = GoConsole.new()
	add_child(console)
	# register(command, help, action) — the action is func(args: PackedStringArray) -> String,
	# and whatever it returns is printed to the log.
	console.register("give", "give <item> <count>", func(args: PackedStringArray) -> String:
		if args.size() < 2: return "give <item> <count>"
		inventory.add(args[0], int(args[1]))
		return "gave %s x%s" % [args[0], args[1]])
	console.register("tp", "tp <x> <z>", _teleport)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_console"):
		console.toggle()
```

🛑 `debug_only` is `true` by default and should stay that way — `OS.has_feature("release")` decides, so the
console simply refuses to open in a shipped build. Do not replace it with your own debug flag; flags get
flipped for a test build and then forgotten.

## 14. A form that says which box is wrong

```gdscript
var name_field := GoField.make("Guild name", GoStyle.line_edit("2–16 characters"), "Everyone sees this")
var tag_field := GoField.make("Tag", GoStyle.line_edit("3 letters"))
column.add_child(name_field)
column.add_child(tag_field)

func _on_submit() -> void:
	name_field.clear_error()
	tag_field.clear_error()
	# `control` is a property holding the node you passed to make().
	var reply := await create_guild(name_field.control.text, tag_field.control.text)
	if reply.ok:
		return
	# The server says which field it rejected — put the message **on that field**.
	if reply.field == "tag":
		tag_field.set_error(reply.message)
	else:
		name_field.set_error(reply.message)
```

🔑 One line at the top saying "check your input" makes the player hunt through five boxes. `set_error()` marks
the box, writes the reason under it, and makes that reason the control's accessible description — so a screen
reader says it when focus lands there.

🛑 **Do not translate a server message.** `set_error(text)` takes the words as they are; pass
`translate = true` only for a key your own project owns.

## 15. A side panel on a wide screen

```gdscript
func _ready() -> void:
	drawer = GoDrawer.new()
	add_child(drawer)
	drawer.side = GoDrawer.Side.LEFT
	drawer.follow_text_direction = true         # a menu drawer means "the start side" — mirror it in RTL
	drawer.body.add_child(build_party_list())

func _on_party_pressed() -> void:
	# On a phone the same content belongs in a GoSheet — a drawer eats most of the screen.
	if GoUi.is_handheld_platform():
		party_sheet.open("Party")
	else:
		drawer.open("Party")                    # open(title) — pass "" for no header
```

🔑 It closes on Back and on the scrim, and keeps clear of the safe area. Like every surface it lives on its
own layer, so it does not fight the HUD.
