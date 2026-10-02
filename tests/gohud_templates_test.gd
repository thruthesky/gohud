## 🧪 **The seven templates the skill hands out** — check that they really stand up.
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_templates_test.gd
##
## ## 🛑 Why this is needed (2026-09-16)
## The files under `skills/gohud/assets/templates/` are **code people copy into their own project and use as-is**.
## Yet until now there was **not one check** that opened them — the docs (`SKILL.md`) merely said "headless-tested".
## Ship a single parse error and whoever receives it sees an empty screen and one error line.
##
## ## What is checked
## ① Do the seven **load** (no parse errors) ② do they enter the tree and **stand up**
## ③ does the public API run when called ④ are the newly wired widgets (snackbar, badge, spinner, key hint, GoField) really there
##
## 🛑 APIs that `await` an answer (`say()`, the inventory's Drop) are **not called** — nobody is there to press,
##    so they never come back. For those we only check that the widget was built.
extends SceneTree

const TEMPLATES := "res://addons/gohud/skills/gohud/assets/templates"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true

	await _loads()
	await _main_menu()
	await _game_hud()
	await _pause_menu()
	await _inventory_sheet()
	await _settings_menu()
	await _app_screen()
	await _edge_bar_hud()

	print("gohud template tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for _i in count: await process_frame


func _make(file: String) -> Node:
	var script: Script = load("%s/%s" % [TEMPLATES, file])
	if script == null: return null
	return script.new()


## Every descendant in the tree.
func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out


## Is there a descendant of that type? 🔑 It tests with `is`, so subclasses count too.
func _has(node: Node, kind: Variant) -> bool:
	for child in _all(node):
		if is_instance_of(child, kind): return true
	return false


# ── ① Do the seven open ───────────────────────────────────────────────

func _loads() -> void:
	for file in ["main_menu.gd", "game_hud.gd", "pause_menu.gd", "inventory_sheet.gd", "settings_menu.gd",
			"app_screen.gd", "edge_bar_hud.gd"]:
		check(load("%s/%s" % [TEMPLATES, file]) != null, "template loads — %s" % file)


# ── ② First screen ────────────────────────────────────────────────────

func _main_menu() -> void:
	var menu: Control = _make("main_menu.gd")
	check(menu != null, "main_menu is built")
	if menu == null: return
	root.add_child(menu)
	await frames(2)
	check(_has(menu, GoForm), "main_menu stands up a GoForm")
	check(menu.continue_button != null, "main_menu holds a Continue button")

	# Slow loading — the button turns into a spinner in place, and cannot be pressed meanwhile.
	if menu.continue_button != null:
		# 🛑 The templates carry no `class_name`, so their members are Variant — without a written type there is no inference.
		var size_before: Vector2 = menu.continue_button.size
		menu.set_loading(true)
		await frames(2)
		check(GoSpinner.is_busy(menu.continue_button), "set_loading(true) turns the button into a spinner")
		check(menu.continue_button.disabled, "the button cannot be pressed while waiting")
		check(menu.continue_button.size.is_equal_approx(size_before),
			"the spinner does not change the button size — %s → %s" % [size_before, menu.continue_button.size])
		menu.set_loading(false)
		await frames(2)
		check(not GoSpinner.is_busy(menu.continue_button), "set_loading(false) restores the label")
	menu.queue_free()
	await frames(1)


# ── ③ HUD ──────────────────────────────────────────────────────────────

func _game_hud() -> void:
	var hud: CanvasLayer = _make("game_hud.gd")
	check(hud != null, "game_hud is built")
	if hud == null: return
	root.add_child(hud)
	await frames(2)
	check(hud.layer == 5, "the HUD stands on layer 5 — %d" % hud.layer)
	check(hud.hp != null and hud.slots.size() == 4, "the bar and four quick slots stand up")

	hud.set_health(60.0, 100.0)
	hud.toast("저장했습니다", GoTheme.SUCCESS)
	await frames(2)

	# 🔑 The snackbar has **a layer of its own** — inside the HUD's Control tree a sheet would cover it.
	check(hud.snackbar != null, "the HUD holds a snackbar")
	if hud.snackbar != null:
		check(hud.snackbar.get_parent() == hud, "the snackbar attaches to the HUD node, not to the HUD root")

	# Badge — hidden at 0, visible once it counts.
	hud.set_unread(0)
	await frames(2)
	var badge: GoBadge = _find_badge(hud)
	check(badge != null, "a badge attaches to the menu button")
	if badge != null:
		check(not badge.visible, "with nothing unread the badge hides")
		hud.set_unread(7)
		await frames(2)
		check(badge.visible, "with something unread the badge shows")
		# 🛑 The badge hangs on a **corner** through anchors — sitting at the parent's top-left (0,0) means the anchors did not take.
		check(badge.position.x > 0.0 or badge.position.y != 0.0,
			"the badge hangs on a corner — %s" % badge.position)
	hud.queue_free()
	await frames(1)


func _find_badge(node: Node) -> GoBadge:
	for child in _all(node):
		if child is GoBadge: return child as GoBadge
	return null


# ── ④ Pause ───────────────────────────────────────────────────────────

func _pause_menu() -> void:
	var pause: CanvasLayer = _make("pause_menu.gd")
	check(pause != null, "pause_menu is built")
	if pause == null: return
	root.add_child(pause)
	await frames(2)
	pause.open()
	await frames(3)
	check(pause.is_open(), "pause opens")
	check(_has(pause, GoKbd), "the resume key hint stands up")
	pause.resume()
	await frames(2)
	check(not pause.is_open(), "pause closes")
	# 🛑 Leave the tree paused and **every check after this one stops.**
	check(not root.get_tree().paused, "closing lets the tree run again")
	pause.queue_free()
	await frames(1)


# ── ⑤ Inventory ───────────────────────────────────────────────────────

func _inventory_sheet() -> void:
	var bag: Node = _make("inventory_sheet.gd")
	check(bag != null, "inventory_sheet is built")
	if bag == null: return
	root.add_child(bag)
	await frames(2)
	bag.open()
	await frames(3)
	check(bag.sheet != null, "the sheet stands up")
	var rows := 0
	for child in _all(bag):
		if child is Button and child.has_meta(&"gohud_context_menu"): rows += 1
	check(rows > 0, "list rows get a long-press menu — %d rows" % rows)
	bag.close()
	await frames(2)
	bag.queue_free()
	await frames(1)


# ── ⑥ Settings ────────────────────────────────────────────────────────

func _settings_menu() -> void:
	var settings: Control = _make("settings_menu.gd")
	check(settings != null, "settings_menu is built")
	if settings == null: return
	root.add_child(settings)
	await frames(3)
	check(_has(settings, GoField), "settings rows stand up as GoField")
	# Per-field errors — not a single "check your input" line; the field itself speaks.
	for child in _all(settings):
		if child is GoField:
			var field := child as GoField
			field.set_error("그 이름은 이미 있습니다")
			await frames(2)
			check(field.has_error(), "GoField takes an error")
			check(field.error_text() == "그 이름은 이미 있습니다", "the error text stays exactly as given (it is not translated)")
			field.clear_error()
			await frames(1)
			check(not field.has_error(), "the error is cleared")
			break
	settings.queue_free()
	await frames(1)


# ── ⑦ App screen ──────────────────────────────────────────────────────

func _app_screen() -> void:
	var app: Control = _make("app_screen.gd")
	check(app != null, "app_screen is built")
	if app == null: return
	root.add_child(app)
	await frames(3)
	check(app.screen is GoScaffold and app.screen.app_bar != null, "the scaffold stands up with an app bar")
	check(app.screen.bottom_bar == app.nav and app.screen.fab != null and app.screen.drawer == app.drawer,
		"the navigation bar, the FAB and the drawer are wired into the scaffold")
	check(app.snackbar != null and app.snackbar.get_parent() == app, "the screen holds a snackbar")
	var heard: Array = []
	app.compose_requested.connect(func() -> void: heard.append("compose"))
	app.destination_changed.connect(func(index: int) -> void: heard.append("nav %d" % index))
	app.drawer_chosen.connect(func(index: int) -> void: heard.append("drawer %d" % index))

	# 🔑 The feed builds only the rows in view — two hundred posts, a screenful of rows.
	var many: Array = []
	for i in 200: many.append({"title": "Post %d" % i, "subtitle": "by player %d" % i})
	app.refresh.refreshing = true
	app.set_posts(many)
	await frames(3)
	var built: Array[int] = app.feed.built_indexes()
	check(app.feed.count == 200, "set_posts() sets the row count — %d" % app.feed.count)
	check(built.size() > 0 and built.size() < 200, "only the rows in view are built — %d of 200" % built.size())
	check(not app.refresh.refreshing, "set_posts() ends the refresh spinner")
	app.add_posts([{"title": "Post 200", "subtitle": ""}])
	check(app.feed.count == 201, "add_posts() appends — %d" % app.feed.count)

	# Saved: one swipe row per post, the empty state when there are none.
	app.set_saved([many[0], many[1], many[2]])
	await frames(2)
	var swipes := 0
	for child in app.saved_page.get_children():
		if child is GoSwipeRow: swipes += 1
	check(swipes == 3, "set_saved() lays out one swipe row per post — %d" % swipes)
	app.set_saved([])
	await frames(2)
	swipes = 0
	for child in app.saved_page.get_children():
		if child is GoSwipeRow and not child.is_queued_for_deletion(): swipes += 1
	check(swipes == 0 and app.saved_page.get_child_count() > 0, "no saved posts shows the empty state")
	app.show_tab(1)
	await frames(2)
	check(app.tabs.current() == 1, "show_tab(1) turns to Saved")

	app.set_unread(3)
	await frames(2)
	var badge: GoBadge = _find_badge(app.nav)
	check(badge != null and badge.visible, "set_unread(3) shows a badge on Alerts")
	app.screen.fab.pressed.emit()
	app.nav.cell(2).button_pressed = true
	app.screen.open_drawer()
	await frames(2)
	check(app.drawer.is_open(), "the menu button's drawer opens")
	var first: Button = null
	for child in app.drawer.body.get_children():
		if child is Button:
			first = child
			break
	if first != null: first.pressed.emit()
	await frames(2)
	check(not app.drawer.is_open(), "a drawer row closes the drawer")
	check(heard == ["compose", "nav 2", "drawer 0"], "the FAB, a destination and a drawer row reach their signals — %s" % str(heard))
	app.queue_free()
	await frames(2)


# ── ⑧ HUD along the edges ─────────────────────────────────────────────

func _edge_bar_hud() -> void:
	# 🔑 A landscape phone (844×390 dp) — the smallest screen this HUD is made for. Headless, the window is 64×64,
	#    so the logical size is set through the stretch (as gohud_layout_test.gd does) and put back afterwards.
	var mode := root.content_scale_mode
	var aspect := root.content_scale_aspect
	var stretch := root.content_scale_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(844, 390)
	await frames(2)
	var hud: CanvasLayer = _make("edge_bar_hud.gd")
	check(hud != null, "edge_bar_hud is built")
	if hud == null: return
	root.add_child(hud)
	await frames(4)
	check(hud.layer == 5, "the HUD stands on layer 5 — %d" % hud.layer)
	check(GoUi.icons().has_icon(GoGameIcons.PIG), "the game icon set is added for the animals")
	check(hud.root.layout_direction == Control.LAYOUT_DIRECTION_LTR, "a HUD keeps its physical sides")
	var screen: Rect2 = hud.root.get_global_rect()
	var top: Rect2 = hud.top.get_global_rect()
	var bottom: Rect2 = hud.bottom.get_global_rect()
	check(screen.size.is_equal_approx(Vector2(844, 390)), "the screen is a landscape phone — %s" % screen.size)
	check(is_zero_approx(top.position.y) and is_equal_approx(bottom.end.y, screen.end.y),
		"the top and bottom bars are pinned to their edges — %s / %s" % [top, bottom])
	check(is_zero_approx(hud.left.get_global_rect().position.x) and is_equal_approx(hud.right.get_global_rect().end.x, screen.end.x),
		"the side bars are pinned to their sides")
	# `clear_of()` keeps the side bars' items between the top and bottom bars (the bar itself runs the full height).
	var column: Rect2 = hud.animals.get_global_rect()
	check(column.position.y >= top.end.y - 0.5 and column.end.y <= bottom.position.y + 0.5,
		"the animals sit between the top and bottom bars — %s between %.0f and %.0f" % [column, top.end.y, bottom.position.y])
	var first_slot: Rect2 = hud.slots[0].get_global_rect()
	var last_slot: Rect2 = hud.slots[hud.slots.size() - 1].get_global_rect()
	check(first_slot.position.y >= top.end.y - 0.5 and last_slot.end.y <= bottom.position.y + 0.5,
		"the quick slots sit between the top and bottom bars — %s … %s" % [first_slot, last_slot])
	check(hud.menu_button.get_global_rect().end.x <= screen.end.x + 0.5 and top.size.x <= screen.size.x + 0.5,
		"the top bar fits across the screen — %s" % top)
	check(hud.slots.size() == 3 and hud.slots[0].touch_peers.has(hud.slots[1]),
		"the side bar makes its slots each other's touch peers")

	var heard: Array = []
	hud.summon_requested.connect(func(index: int) -> void: heard.append("summon %d" % index))
	hud.slot_used.connect(func(index: int) -> void: heard.append("slot %d" % index))
	hud.action_pressed.connect(func(index: int) -> void: heard.append("action %d" % index))
	# A real tap on the second animal — the column acts on a press that lets go on the same row.
	var animals: GoChoiceColumn = hud.animals
	var at: Vector2 = animals.get_global_rect().position + animals.row_rect(1).get_center()
	for held in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = held
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		click.position = at
		click.global_position = at
		Input.parse_input_event(click.xformed_by(root.get_final_transform()))
		await frames(1)
	await frames(1)
	hud.slots[0].pressed.emit()
	var actions: Array[Control] = hud.bottom.items(GoEdgeBar.Slot.START)
	if not actions.is_empty(): (actions[0] as Button).pressed.emit()
	check(heard == ["summon 1", "slot 0", "action 0"], "a tap, a slot and an action reach their signals — %s" % str(heard))
	check(hud.slots[0].quantity == 4 and hud.slots[0].cooldown_ratio() > 0.0, "a used slot loses one and cools down")

	hud.set_summoned(1)
	hud.set_resting(4)
	check(animals.is_selected(1) and animals.is_dimmed(4) and animals.selected_indices().size() == 1,
		"set_summoned() and set_resting() mark the rows")
	hud.set_coins(99)
	hud.set_stage("Boss")
	check(hud.coins.text == "99" and hud.stage.text == "Boss", "set_coins() and set_stage() show the values")
	hud.set_summons(["Hen", "Cat"])
	check(animals.item_count() == 2 and animals.is_selected(1), "set_summons() keeps the marks that still fit")
	hud.queue_free()
	await frames(2)
	root.content_scale_size = stretch
	root.content_scale_aspect = aspect
	root.content_scale_mode = mode
	await frames(1)
