## In-game HUD built with gohud. Copy to your project (e.g. res://ui/game_hud.gd) and add it to the game
## scene: `add_child(preload("res://ui/game_hud.gd").new())`. It is its own CanvasLayer (layer 5), so
## GoSheet (10) and GoDialogs (100) always draw above it.
##
## Top-left: HP / MP / XP bars on a floating panel · top-right: menu button with an unread badge ·
## top-centre: toasts that step below the bars · centre-right: a non-blocking prompt card ·
## bottom-right: four quick slots · lower-left zone: a FOLLOW joystick (touch devices by default) ·
## bottom: a snackbar (layer 90) for messages the player can act on.
extends CanvasLayer

signal menu_requested
signal slot_used(index: int)
## Joystick direction, length 0..1. ZERO when released.
signal move_input(vector: Vector2)

enum TouchControls { AUTO, ALWAYS, NEVER }

## AUTO shows the joystick only on Android/iOS; on desktop it would swallow mouse clicks in its zone.
@export var touch_controls := TouchControls.AUTO
@export var slot_cooldown := 5.0

## Quick slot data: icon, colour token, quantity (GoSlot.NONE for skills), shortcut label.
var slot_specs: Array = [
	[GoIconSet.POTION, GoTheme.DANGER, 12, "1"],
	[GoIconSet.BOLT, GoTheme.WARNING, 3, "2"],
	[GoIconSet.SHIELD, GoTheme.INFO, 0, "3"],
	[GoIconSet.SWORD, GoTheme.SUCCESS, GoSlot.NONE, "4"],
]

var root: Control
var hp: GoBar
var mp: GoBar
var xp: GoBar
var slots: Array[GoSlot] = []
var joystick: GoJoystick
var notice: GoNotice
var prompt: GoPromptCard
## Bottom-of-screen messages that can carry buttons. It makes its own CanvasLayer (90), above this HUD.
var snackbar: GoSnackbar
var menu_button: Button
var _unread := 0


func _ready() -> void:
	if layer == 1:
		layer = 5
	build()


func build() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	slots.clear()
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE      # empty HUD space must not block the game
	root.theme = GoUi.theme()
	add_child(root)
	_build_status()
	_build_menu_button()
	_build_slots()
	_build_touch_controls()
	_build_toast()
	_build_prompt()
	_build_snackbar()


# ── Public API ───────────────────────────────────────────────────────────

func set_health(value: float, maximum: float) -> void: hp.set_values(value, maximum)
func set_mana(value: float, maximum: float) -> void: mp.set_values(value, maximum)
func set_experience(value: float, maximum: float) -> void: xp.set_values(value, maximum)


func toast(message: String, tone := GoTheme.TEXT) -> void:
	notice.show_text(message, tone)


## A message the player can act on — "Item dropped / Undo". Returns the index of the button that was
## pressed, or -1 when it expired. With no actions it takes no input at all, like a toast.
##
## Use this instead of `toast()` when there is something to press, and instead of a confirm dialog
## when the action is cheap and reversible — a dialog stops the fight to ask.
func say(message: String, actions: Array = [], tone := GoTheme.TEXT) -> int:
	return await snackbar.post({"text": message, "actions": actions, "tone": tone})


## The unread count on the menu button. 0 hides the badge.
## 🛑 The badge anchors to the button's corner, so it can only place itself once the button is in the
##    tree — this is called after `build()`, which is why `attach` is deferred there too.
func set_unread(count: int) -> void:
	_unread = maxi(0, count)
	if is_instance_valid(menu_button):
		GoBadge.attach(menu_button, _unread)


## Shows a question that does not pause the game. `decline` defaults to just hiding the card.
func ask(title: String, subtitle: String, accept_text: String, accept: Callable,
		decline_text := "Later", decline := Callable()) -> void:
	prompt.set_icon(GoIconSet.BELL, GoUi.color(GoTheme.ACCENT), true)
	prompt.set_title(title)
	prompt.set_subtitle(subtitle)
	prompt.set_actions([
		{"text": accept_text, "primary": true, "action": func() -> void:
			prompt.hide()
			accept.call()},
		{"text": decline_text, "action": func() -> void:
			prompt.hide()
			if decline.is_valid(): decline.call()},
	])
	prompt.fit_width(300)
	prompt.show()


# ── Pieces ───────────────────────────────────────────────────────────────

func _build_status() -> void:
	var anchor := GoHudAnchor.new()
	anchor.name = "Status"
	anchor.spot = GoHudAnchor.Spot.TOP_LEFT
	root.add_child(anchor)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))
	anchor.add_child(panel)
	var bars := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	bars.custom_minimum_size.x = 180
	panel.add_child(bars)
	hp = _bar(bars, "HP", GoTheme.DANGER_FILL, 320, 500)
	mp = _bar(bars, "MP", GoTheme.INFO_FILL, 88, 120)
	xp = _bar(bars, "XP", GoTheme.WARNING_FILL, 64, 100)
	xp.readout = GoBar.Readout.PERCENT


func _bar(parent: Control, label: String, token: StringName, value: float, maximum: float) -> GoBar:
	var bar := GoBar.new()
	bar.label_text = label
	bar.ink = GoUi.color(token)
	parent.add_child(bar)
	bar.set_values(value, maximum, false)
	return bar


func _build_menu_button() -> void:
	var anchor := GoHudAnchor.new()
	anchor.name = "Menu"
	anchor.spot = GoHudAnchor.Spot.TOP_RIGHT
	root.add_child(anchor)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box())
	anchor.add_child(panel)
	menu_button = GoStyle.icon_button(GoIconSet.MENU, func() -> void:
		GoFeedback.tapped()
		menu_requested.emit(), -1, &"Menu")
	panel.add_child(menu_button)
	# 🛑 Deferred: a badge hangs off a corner through anchors, and the corner is only known once the
	#    button has been laid out. Attaching in the same frame pins it to (0, 0).
	GoBadge.attach.call_deferred(menu_button, _unread)


func _build_slots() -> void:
	var anchor := GoHudAnchor.new()
	anchor.name = "Slots"
	anchor.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	root.add_child(anchor)
	var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	anchor.add_child(row)
	var peers: Array[Control] = []
	for index in slot_specs.size():
		var spec: Array = slot_specs[index]
		var slot := GoSlot.new()
		slot.icon_name = spec[0]
		slot.accent = GoUi.color(spec[1])
		slot.quantity = spec[2]
		slot.shortcut_label = spec[3]
		slot.pressed.connect(_on_slot.bind(index))
		row.add_child(slot)
		slots.append(slot)
		peers.append(slot)
	for slot in slots:
		slot.touch_peers = peers                     # overlapping 48 dp areas go to the nearer slot


func _on_slot(index: int) -> void:
	var slot := slots[index]
	if slot.cooldown_ratio() > 0.0 or slot.quantity == 0:
		GoFeedback.failed()
		return
	GoFeedback.tapped()
	if slot.quantity > 0:
		slot.quantity -= 1
	slot.start_cooldown(slot_cooldown)
	slot_used.emit(index)


func _build_touch_controls() -> void:
	var wanted := touch_controls == TouchControls.ALWAYS \
		or (touch_controls == TouchControls.AUTO and GoUi.is_handheld_platform())
	if not wanted:
		return
	joystick = GoJoystick.new()
	joystick.name = "Joystick"
	joystick.mode = GoJoystick.Mode.FOLLOW
	joystick.hide_when_idle = true
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.45                     # the thumb can land anywhere in the lower-left zone
	joystick.anchor_top = 0.4
	joystick.anchor_bottom = 1.0
	joystick.moved.connect(func(vector: Vector2) -> void: move_input.emit(vector))
	root.add_child(joystick)


func _build_toast() -> void:
	var anchor := GoHudAnchor.new()
	anchor.name = "Toast"
	anchor.spot = GoHudAnchor.Spot.TOP_CENTER
	anchor.reserve_space = false                     # transient: never pushes other content
	anchor.avoid_peers = true                        # settles below the status panel when they overlap
	root.add_child(anchor)
	notice = GoNotice.new()
	notice.custom_minimum_size.x = 260
	anchor.add_child(notice)


## 🔑 The snackbar makes its own CanvasLayer (90), so it is added to this node, **not** to `root` —
##    putting it inside the HUD's Control tree would nail it to layer 5 and a sheet would cover it.
func _build_snackbar() -> void:
	if is_instance_valid(snackbar):
		return
	snackbar = GoSnackbar.new()
	add_child(snackbar)


func _build_prompt() -> void:
	var anchor := GoHudAnchor.new()
	anchor.name = "Prompt"
	anchor.spot = GoHudAnchor.Spot.CENTER_RIGHT
	anchor.reserve_space = false
	root.add_child(anchor)
	prompt = GoPromptCard.new()
	prompt.set_closable(true)
	prompt.closed.connect(prompt.hide)
	anchor.add_child(prompt)
