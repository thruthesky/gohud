## An in-game HUD laid out along the screen's edges with gohud's layout bars. Copy it to your project (e.g.
## res://ui/edge_bar_hud.gd) and add it to the game scene: `add_child(preload("res://ui/edge_bar_hud.gd").new())`.
## It is its own CanvasLayer (layer 5), so GoSheet (10) and GoDialogs (100) always draw above it.
##
## Top bar: health and mana at the start · the stage name on the centre · coins and the menu button at the end ·
## left side bar: the animals the player can call (one tap calls one; those out stand out, resting ones are greyed) ·
## right side bar: three quick slots down the middle · bottom bar: Attack, Guard and Run on the centre.
##
## 📱 Made for a landscape screen — it fits a 844×390 dp phone held sideways and grows from there. On a portrait
##    phone two side bars squeeze the play field; place the pieces with GoHudAnchor there (game_hud.gd).
##
## 🔑 Bars or anchors? A bar lines its items up along one edge in one to three slots and keeps the centre slot on the
##    centre; the side bars stay between the top and bottom bars (`clear_of`). `GoHudAnchor` (game_hud.gd) places
##    loose pieces in corners and steps them aside from each other. Rows and columns along the edges → bars.
extends CanvasLayer

signal menu_requested
## The player tapped the animal at [param index]. Mark it with `set_summoned(index, true)` once it is out.
signal summon_requested(index: int)
signal slot_used(index: int)
## 0 Attack, 1 Guard, 2 Run.
signal action_pressed(index: int)

@export var slot_cooldown := 5.0

## A choice is a text or {"icon", "text"}. The icons come from the game set (added in `_ready`).
var summons: Array = [
	{"icon": GoGameIcons.EGG, "text": "Hen"}, {"icon": GoGameIcons.PAW, "text": "Cat"},
	{"icon": GoGameIcons.PAW, "text": "Dog"}, {"icon": GoGameIcons.PIG, "text": "Pig"},
	{"icon": GoGameIcons.HORSE, "text": "Horse"},
]
## Quick slot data: icon, colour token, quantity (GoSlot.NONE for skills).
var slot_specs: Array = [
	[GoIconSet.POTION, GoTheme.DANGER, 5],
	[GoIconSet.BOLT, GoTheme.WARNING, GoSlot.NONE],
	[GoIconSet.SHIELD, GoTheme.INFO, 2],
]
var actions: Array = ["Attack", "Guard", "Run"]

var root: Control
var top: GoTopBar
var bottom: GoBottomBar
var left: GoLeftSideBar
var right: GoRightSideBar
var hp: GoBar
var mp: GoBar
var stage: Label
var coins: Label
var menu_button: Button
var animals: GoChoiceColumn
var slots: Array[GoSlot] = []
# What the HUD shows, kept here so `build()` — after a look switch — puts it back instead of the starting values.
var _health := Vector2(320, 500)
var _mana := Vector2(88, 120)
var _stage := "Stage 1"
var _coins := 1250
var _out := {}
var _resting := {}


func _ready() -> void:
	if layer == 1:
		layer = 5
	GoUi.add_icons(GoGameIcons.icon_set())             # the animal drawings; kept across later use_preset() calls
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
	# 🔑 A HUD keeps its physical sides in every language — the bars below would otherwise mirror in Arabic.
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(root)
	_build_top()
	_build_bottom()
	_build_sides()
	for index: int in _out: animals.set_selected(index, true)
	for index: int in _resting: animals.set_dimmed(index, true)


# ── Public API ───────────────────────────────────────────────────────────

func set_health(value: float, maximum: float) -> void:
	_health = Vector2(value, maximum)
	hp.set_values(value, maximum)


func set_mana(value: float, maximum: float) -> void:
	_mana = Vector2(value, maximum)
	mp.set_values(value, maximum)


func set_stage(title: String) -> void:
	_stage = title
	stage.text = title


func set_coins(amount: int) -> void:
	_coins = amount
	coins.text = str(amount)


## The animal at [param index] is out (or back home) — its row stands out. The column never marks a row by itself.
func set_summoned(index: int, out := true) -> void:
	if out: _out[index] = true
	else: _out.erase(index)
	animals.set_selected(index, out)


## The animal at [param index] is resting — greyed, but a tap still reaches `summon_requested` so you can say why.
func set_resting(index: int, resting := true) -> void:
	if resting: _resting[index] = true
	else: _resting.erase(index)
	animals.set_dimmed(index, resting)


## A new list of animals. 🛑 The marks belong to rows, not to animals — they are cleared here, so mark the ones out
## and resting again (a mark kept by index would move to whichever animal now stands in that row).
func set_summons(choices: Array) -> void:
	summons = choices.duplicate()
	_out.clear()
	_resting.clear()
	animals.set_items(summons)
	animals.clear_selected()
	for index in animals.item_count(): animals.set_dimmed(index, false)


# ── Pieces ───────────────────────────────────────────────────────────────

func _build_top() -> void:
	top = GoTopBar.make(3)
	# Side by side, not stacked: the top bar stays one bar tall, and the side bars keep the height between.
	var status := _plate()
	var bars := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	status.add_child(bars)
	hp = _bar(bars, "HP", GoTheme.DANGER_FILL, _health.x, _health.y)
	mp = _bar(bars, "MP", GoTheme.INFO_FILL, _mana.x, _mana.y)
	top.add_start(status)
	var title := _plate()
	stage = GoStyle.label(_stage, GoTheme.ROLE_SUBTITLE)
	title.add_child(stage)
	top.add_center(title)                                # on the bar's centre, however wide the two sides are
	var purse := _plate()
	var line := GoStyle.row(GoUi.metric(GoTheme.GAP_TINY))
	line.add_child(GoUi.icons().node(GoIconSet.COIN, GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.WARNING)))
	coins = GoStyle.label(str(_coins))
	coins.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.add_child(coins)
	purse.add_child(line)
	top.add_end(purse)
	menu_button = GoStyle.icon_button(GoIconSet.MENU, func() -> void:
		GoFeedback.tapped()
		menu_requested.emit(), -1, &"menu")               # gohud's own name: the tooltip comes translated
	# 🛑 Over gameplay: a clicked button would keep keyboard focus, and Space (jump, attack) would press it again.
	menu_button.keyboard_focus = false
	var behind := PanelContainer.new()                   # an icon straight over the world drowns in it
	behind.add_theme_stylebox_override(&"panel", GoUi.skin().overlay_box())
	behind.add_child(menu_button)
	top.add_end(behind)
	root.add_child(top)                                  # the root is not a container → pinned to the top edge


func _build_bottom() -> void:
	bottom = GoBottomBar.make(1, GoBottomBar.Justify.CENTER)
	for index in actions.size():
		var tone := GoStyle.Tone.PRIMARY if index == 0 else GoStyle.Tone.NORMAL
		var button := GoStyle.button(actions[index], _on_action.bind(index), tone)
		button.focus_mode = Control.FOCUS_NONE           # the same reason as the menu button
		bottom.add_start(button)
	root.add_child(bottom)


func _build_sides() -> void:
	left = GoLeftSideBar.make(1, GoLeftSideBar.Justify.CENTER)
	# 🔑 One tap acts at once on any row — a list of actions, not a value to settle on (that is GoWheelPicker).
	#    Its keyboard focus is off: over a game the arrow keys keep walking the player.
	#    Three rows show at a time and the rest scroll — a fourth would not fit a landscape phone.
	animals = GoChoiceColumn.make(summons, 3, func(index: int) -> void: summon_requested.emit(index))
	left.add_start(animals)
	root.add_child(left)
	right = GoRightSideBar.make(1, GoRightSideBar.Justify.CENTER)
	for index in slot_specs.size():
		var spec: Array = slot_specs[index]
		var slot := GoSlot.new()
		slot.icon_name = spec[0]
		slot.accent = GoUi.color(spec[1])
		slot.quantity = spec[2]
		slot.pressed.connect(_on_slot.bind(index))
		right.add_start(slot)                            # the bar makes slots side by side each other's touch_peers
		slots.append(slot)
	root.add_child(right)
	# Between the top and bottom bars, following their height (a notch, a rotation).
	left.clear_of([top, bottom])
	right.clear_of([top, bottom])


## A floating plate behind HUD text — text straight over the game reads only over some of it.
func _plate() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))
	return panel


func _bar(parent: Control, label: String, token: StringName, value: float, maximum: float) -> GoBar:
	var bar := GoBar.new()
	bar.label_text = label
	bar.ink = GoUi.color(token)
	bar.custom_minimum_size.x = 140
	parent.add_child(bar)
	bar.set_values(value, maximum, false)
	return bar


func _on_slot(index: int) -> void:
	var slot := slots[index]
	if slot.cooldown_ratio() > 0.0 or slot.quantity == 0:
		GoFeedback.failed()
		return
	GoFeedback.tapped()
	if slot.quantity > 0:
		slot.quantity -= 1
		slot_specs[index][2] = slot.quantity             # a rebuild keeps what is left
	slot.start_cooldown(slot_cooldown)
	slot_used.emit(index)


func _on_action(index: int) -> void:
	GoFeedback.tapped()
	action_pressed.emit(index)
