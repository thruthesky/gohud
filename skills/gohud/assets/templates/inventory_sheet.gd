## Inventory in a GoSheet: sticky search + category filter, list rows, a detail page with Back, Use / Drop.
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
	_clear(sheet.footer())                 # 🛑 open() does not free footer children

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
		sheet.body.add_child(GoStyle.list_button(item.icon, "%s  ×%d" % [item.name, item.quantity],
			show_item.bind(item), Color.TRANSPARENT, item.description, false, GoIconSet.CHEVRON_RIGHT))


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
	item.quantity -= 1
	if item.quantity <= 0:
		items.erase(item)
	GoFeedback.confirmed()
	item_used.emit(item)
	show_list()


func _drop(item: Dictionary) -> void:
	# 🛑 GoDialogs fills {placeholders} in the body only — build the title string yourself.
	var yes := await dialogs.confirm("Drop %s?" % item.name, "{name} will be gone for good.", "Drop", "Keep",
		"", {"name": item.name}, true)
	if not yes:
		return
	items.erase(item)
	item_dropped.emit(item)
	show_list()


## Frees a container's children immediately (remove first, so counts and layout update this frame).
func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
