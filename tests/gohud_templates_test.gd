## 🧪 **The five templates the skill hands out** — check that they really stand up.
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_templates_test.gd
##
## ## 🛑 Why this is needed (2026-09-16)
## The five files under `skills/gohud/assets/templates/` are **code people copy into their own project and use as-is**.
## Yet until now there was **not one check** that opened them — the docs (`SKILL.md`) merely said "headless-tested".
## Ship a single parse error and whoever receives it sees an empty screen and one error line.
##
## ## What is checked
## ① Do the five **load** (no parse errors) ② do they enter the tree and **stand up**
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


# ── ① Do the five open ────────────────────────────────────────────────

func _loads() -> void:
	for file in ["main_menu.gd", "game_hud.gd", "pause_menu.gd", "inventory_sheet.gd", "settings_menu.gd"]:
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
