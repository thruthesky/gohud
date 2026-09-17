## 🎒 **An inventory grid** — a fixed number of `GoSlot` cells that wrap to the width they are given.
##
## A bag, a chest, a shop shelf, a crafting bench: the same picture every time — *N* cells, some holding an
## icon and a count, the rest vacant, one of them picked. This widget owns that picture and nothing else;
## **what the cells mean stays in the game** (the grid never holds item data, only what to draw).
##
## ```gdscript
## var grid := GoSlotGrid.new()
## grid.slot_count = 30
## grid.cell_size = 60
## sheet.body.add_child(grid)
## var red := Color("e5484d")
## grid.set_cell(0, {"icon": GoGameIcons.APPLE, "quantity": 12, "accent": red, "ink": red, "tooltip": "Apple"})
## grid.set_cell(1, {})                                  # vacant
## grid.slot_pressed.connect(func(index): grid.selected = index)
## grid.slot_moved.connect(func(from, to): bag.move(from, to))   # only when `draggable`
## ```
##
## 🛑 The cells draw with the **global** icon set (`GoUi.icons()`) — `GoGameIcons` names need
##    `GoUi.config.icons = GoGameIcons.icon_set()` first, or the cells stay empty and warn `icon set has no …`.
##
## ## 🛑 Inside a scroll the finger belongs to the scroll
## Cells pass the drag on (`MOUSE_FILTER_PASS`), so dragging over the grid scrolls the sheet it sits in. That is
## also why `draggable` is **off** by default: drag-to-move and drag-to-scroll cannot share a finger. Turn it
## on for mouse play (`not DisplayServer.is_touchscreen_available()`), and keep a tap route (pick a cell, then
## a Move button) so touch players can rearrange too.
@tool
class_name GoSlotGrid
extends HFlowContainer

## A cell was pressed (vacant cells too — they are where a moved item lands).
signal slot_pressed(index: int)
## A cell was dragged onto another. 🛑 The grid moves **nothing** — the game decides (swap, merge, refuse) and redraws.
signal slot_moved(from: int, to: int)

## How many cells. Changing it rebuilds the cells; what was drawn in the kept ones is redrawn.
@export_range(0, 512) var slot_count := 20:
	set(value):
		slot_count = maxi(0, value)
		_rebuild()

## One side of a cell's visible panel (dp). Below the touch minimum the cells still take the touch size.
@export_range(16, 128) var cell_size := 56:
	set(value):
		cell_size = value
		for cell in _cells: cell.visual_size = cell_size

## Let a cell be dragged onto another (`slot_moved`). See the 🛑 above before turning it on for touch.
@export var draggable := false

## 🔑 **Reachable by Tab and gamepad?** On by default — a bag in a sheet is walked with the arrows.
## 🛑 Turn it **off** for a grid used as a HUD hotbar over gameplay: a clicked cell keeps focus, and Space / Enter
##    then presses the cell again instead of reaching the game (`GoSlot.keyboard_focus`, pitfalls.md).
@export var keyboard_focus := true:
	set(value):
		keyboard_focus = value
		for cell in _cells: cell.keyboard_focus = value

## The picked cell, or -1. Only one cell is picked at a time.
## 🔑 Checked against `slot_count`, not the cells built so far — a pick made before the grid enters the tree is
##    kept and drawn when the cells are made.
var selected := -1:
	set(value):
		selected = value if value >= 0 and value < slot_count else -1
		for index in _cells.size(): _cells[index].selected = index == selected

var _cells: Array[GoSlot] = []
var _data: Array[Dictionary] = []


func _init() -> void:
	name = "SlotGrid"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = FlowContainer.ALIGNMENT_CENTER
	# 🛑 A variable's initial value does not run its setter — without this `_data` stays empty until `_ready`, and
	#    `set_cell()` on a grid that is not in the tree yet fails with "Invalid assignment of index".
	_data.resize(slot_count)


func _ready() -> void:
	_restyle()
	_rebuild()
	GoUi.watch(_restyle)


func _exit_tree() -> void:
	GoUi.unwatch(_restyle)


## 🎨 Theme and cell spacing — run again on `GoUi.use_preset()` / `GoUi.refresh()`, so the gaps follow the new
##    preset (the cells follow by themselves).
func _restyle() -> void:
	theme = GoUi.theme()
	var gap := GoUi.metric(GoTheme.GAP_SMALL)
	add_theme_constant_override(&"h_separation", gap)
	add_theme_constant_override(&"v_separation", gap)


## The `GoSlot` of one cell — for a cooldown, a shortcut label or anything else the cell dictionary does not cover.
func slot(index: int) -> GoSlot:
	return _cells[index] if index >= 0 and index < _cells.size() else null


## What was last drawn in a cell (`{}` = vacant).
func cell(index: int) -> Dictionary:
	return _data[index] if index >= 0 and index < _data.size() else {}


## Draws one cell. `{}` makes it vacant. Keys, all optional:
## `icon` (name) · `quantity` (int; leave out for "no count", e.g. equipment) · `accent` (Color, the border) ·
## `ink` (Color, the icon itself — contrast-corrected by the slot; leave out for the text color) ·
## `tooltip` (String — also the accessible name) · `disabled` (bool) · `timer` (String, e.g. "2h").
func set_cell(index: int, data: Dictionary) -> void:
	if index < 0 or index >= slot_count: return
	_data[index] = data
	if index < _cells.size(): _paint(index)


## Draws every cell from a list; cells past the end of the list become vacant.
func set_cells(list: Array) -> void:
	for index in slot_count:
		var data: Variant = list[index] if index < list.size() else null
		set_cell(index, data if data is Dictionary else {})


func _rebuild() -> void:
	_data.resize(slot_count)
	if not is_inside_tree(): return
	while _cells.size() > slot_count:
		var last: GoSlot = _cells.pop_back()
		remove_child(last)
		last.queue_free()
	while _cells.size() < slot_count:
		var index := _cells.size()
		var made := GoSlot.new()
		made.name = "Cell%d" % index
		made.visual_size = cell_size
		# 🛑 The finger drag goes to the scroll this grid sits in (the same reason as `choice_grid`).
		made.mouse_filter = Control.MOUSE_FILTER_PASS
		made.keyboard_focus = keyboard_focus
		made.pressed.connect(_on_pressed.bind(index))
		made.set_drag_forwarding(_drag_from.bind(index), _can_drop_on.bind(index), _drop_on.bind(index))
		_cells.append(made)
		add_child(made)
		_paint(index)
	if selected >= slot_count: selected = -1


func _paint(index: int) -> void:
	var made := _cells[index]
	var data := _data[index]
	made.icon_name = StringName(str(data.get("icon", "")))
	made.quantity = int(data["quantity"]) if data.has("quantity") else GoSlot.NONE
	made.accent = _color(data.get("accent"))
	made.icon_ink = _color(data.get("ink"))
	made.timer_text = str(data.get("timer", ""))
	made.disabled = bool(data.get("disabled", false))
	made.tooltip_text = str(data.get("tooltip", ""))
	made.selected = index == selected


## A `Color`, or a colour string (`"e5484d"`) from a data file. Anything else — a missing key, `null` — is transparent.
static func _color(value: Variant) -> Color:
	if value is Color: return value
	if (value is String or value is StringName) and Color.html_is_valid(str(value)): return Color.html(str(value))
	return Color.TRANSPARENT


func _on_pressed(index: int) -> void:
	slot_pressed.emit(index)


# ── Drag to move ───────────────────────────────────────────────────────
# `set_drag_forwarding` hands the three drag callbacks of every cell to the grid, with the cell index bound last.

func _drag_from(_at: Vector2, index: int) -> Variant:
	# A disabled cell (locked, cooling down) stays where it is, like a vacant one.
	if not draggable or cell(index).is_empty() or bool(cell(index).get("disabled", false)): return null
	var icon := StringName(str(cell(index).get("icon", "")))
	if not icon.is_empty():
		var ghost := Control.new()
		var mark := GoUi.icons().node(icon, roundi(cell_size * 0.6), GoUi.color(GoTheme.TEXT))
		mark.position = -mark.custom_minimum_size * 0.5      # under the pointer, not hanging off its corner
		ghost.add_child(mark)
		_cells[index].set_drag_preview(ghost)
	return {"go_slot_grid": get_instance_id(), "index": index}


func _can_drop_on(_at: Vector2, data: Variant, index: int) -> bool:
	return draggable and data is Dictionary and data.get("go_slot_grid") == get_instance_id() \
		and int(data.get("index", -1)) != index


func _drop_on(at: Vector2, data: Variant, index: int) -> void:
	if _can_drop_on(at, data, index): slot_moved.emit(int(data["index"]), index)
