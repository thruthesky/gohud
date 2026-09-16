## Inventory in a GoSheet: sticky search + category filter, list rows with a long-press menu, a detail
## page with Back, Use / Drop — and a snackbar that lets a drop be taken back.
## Copy to your project (e.g. res://ui/inventory_sheet.gd):
##     var inventory := preload("res://ui/inventory_sheet.gd").new()
##     add_child(inventory)
##     inventory.items = my_items          # [{id, name, description, icon, category, quantity}, …]
##     inventory.open()
## The sheet owns a CanvasLayer (10), so it rises above a HUD on a lower layer.
extends Node

signal item_used(item: Dictionary)
signal item_dropped(item: Dictionary)

const CATEGORIES := ["All", "Weapons", "Potions", "Quest"]

@export var title_text := "Inventory"

## Sample data — replace with your own. `icon` is any GoIconSet name, `category` one of CATEGORIES.
var items: Array[Dictionary] = [
	{"id": "oathkeeper", "name": "Oathkeeper", "description": "Longsword · Attack 42",
		"icon": GoIconSet.SWORD, "category": "Weapons", "quantity": 1},
	{"id": "crimson", "name": "Crimson draught", "description": "Potion · Restores 120 HP",
		"icon": GoIconSet.POTION, "category": "Potions", "quantity": 12},
	{"id": "azure", "name": "Azure tonic", "description": "Potion · Restores 40 MP",
		"icon": GoIconSet.POTION, "category": "Potions", "quantity": 6},
	{"id": "tower_key", "name": "Tower key", "description": "Opens the ruined tower",
		"icon": GoIconSet.KEY, "category": "Quest", "quantity": 1},
	{"id": "bulwark", "name": "Iron bulwark", "description": "Shield · Defence 28",
		"icon": GoIconSet.SHIELD, "category": "Weapons", "quantity": 1},
]

var sheet: GoSheet
var dialogs: GoDialogs
## Bottom-of-screen messages with buttons — a drop is reversible, so it is offered here rather than
## behind a confirm dialog. Created on demand so the template still works without it.
var snackbar: GoSnackbar
var _filter := "All"
var _query := ""


func _ready() -> void:
	sheet = GoSheet.new()
	sheet.height_ratio = 0.72
	add_child(sheet)
	dialogs = GoDialogs.new()
	add_child(dialogs)


func open() -> void:
	show_list()


func close() -> void:
	sheet.close()


func show_list() -> void:
	sheet.open(title_text)                 # clears body + toolbar, hides back, toolbar and footer
	_clear(sheet.footer())                 # 🛑 open() keeps footer().add_child() children — clearing works on every version

	var search := GoStyle.line_edit("Search items…")
	search.text = _query
	search.clear_button_enabled = true
	search.text_changed.connect(_on_search)
	sheet.toolbar().add_child(search)
	var strip := GoScroll.horizontal()
	strip.add_child(GoStyle.segmented(CATEGORIES, CATEGORIES.find(_filter), _on_category, false, true))
	sheet.toolbar().add_child(strip)
	sheet.toolbar().visible = true

	_fill_list()
	sheet.footer().add_child(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
	sheet.footer().visible = true


func show_item(item: Dictionary) -> void:
	sheet.clear()
	sheet.set_title(item.name)
	sheet.set_back(show_list)              # Back button + Android Back return to the list
	sheet.toolbar().visible = false
	_clear(sheet.footer())

	var hero := GoUi.icons().node(item.icon, 64, GoUi.color(GoTheme.ACCENT))
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet.body.add_child(hero)
	sheet.body.add_child(GoStyle.chip(item.category, GoUi.color(GoTheme.INFO)))
	sheet.body.add_child(GoStyle.label(item.description))
	sheet.body.add_child(GoStyle.table(["Quantity", "Category"], [[str(item.quantity), item.category]]))

	var actions := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	actions.add_child(GoStyle.button("Drop", _drop.bind(item), GoStyle.Tone.DANGER))
	actions.add_child(GoStyle.button("Use", _use.bind(item), GoStyle.Tone.PRIMARY))
	sheet.footer().add_child(actions)
	sheet.footer().visible = true


func _fill_list() -> void:
	sheet.clear()
	var shown := items.filter(_matches)
	if shown.is_empty():
		sheet.body.add_child(GoStyle.empty_state(GoIconSet.BAG, "Nothing matches", false))
		return
	for item in shown:
		var row := GoStyle.list_button(item.icon, "%s  ×%d" % [item.name, item.quantity],
			show_item.bind(item), Color.TRANSPARENT, item.description, false, GoIconSet.CHEVRON_RIGHT)
		sheet.body.add_child(row)
		# Long-press (or right-click) for the actions without opening the detail page.
		# 🛑 This is a shortcut, never the only route — touch has no hover and no right-click, so a
		#    player who never long-presses must still reach Use and Drop on the detail page.
		GoContextMenu.attach(row, [
			{"text": "Use", "icon": GoIconSet.CHECK, "action": _use.bind(item)},
			{"separator": true},
			{"text": "Drop", "icon": GoIconSet.TRASH, "danger": true, "action": _drop.bind(item)},
		])



func _matches(item: Dictionary) -> bool:
	if _filter != "All" and item.category != _filter:
		return false
	if _query.is_empty():
		return true
	var needle := _query.to_lower()
	return String(item.name).to_lower().contains(needle) or String(item.description).to_lower().contains(needle)


func _on_search(text: String) -> void:
	_query = text
	_fill_list()


func _on_category(index: int) -> void:
	_filter = CATEGORIES[index]
	_fill_list()


func _use(item: Dictionary) -> void:
	var name: String = item.name
	item.quantity -= 1
	if item.quantity <= 0:
		items.erase(item)
	GoFeedback.confirmed()
	item_used.emit(item)
	show_list()
	_say("Used %s" % name, [], GoTheme.SUCCESS)


## 🔑 Dropping is **reversible here**, so it does not stop the game to ask. A snackbar reports it and
##    offers Undo; `post()` returns the index of the button pressed, or -1 when it expired.
##    Keep `GoDialogs.confirm(…, destructive = true)` for what cannot be taken back — selling a unique
##    item, deleting a save. A dialog for every small action trains players to dismiss dialogs.
func _drop(item: Dictionary) -> void:
	var name: String = item.name
	items.erase(item)
	item_dropped.emit(item)
	show_list()
	if await _say("Dropped %s" % name, ["Undo"], GoTheme.WARNING) == 0:
		items.append(item)
		show_list()


## Bottom-of-screen message. The snackbar is made on first use, so a copy of this template that never
## says anything never builds one.
func _say(message: String, actions: Array, tone: StringName) -> int:
	if not is_instance_valid(snackbar):
		snackbar = GoSnackbar.new()
		add_child(snackbar)
	return await snackbar.post({"text": message, "actions": actions, "tone": tone})


## Frees a container's children immediately (remove first, so counts and layout update this frame).
func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
