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

var hud: CanvasLayer
var pause: CanvasLayer
var inventory: Node

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
	var holder := Control.new()                        # owns the form and %BackButton (see surfaces.md §4)
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
	form.owner = holder
	back.owner = holder
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
	for old in sheet.footer().get_children():
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

## 7. Context menu and dropdowns

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
