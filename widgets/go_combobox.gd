## 🔎 **A picker you search in** — find a friend, search items, choose a server, point at a guild member.
##
## ```gdscript
## var picker := GoCombobox.make(server_names, 0)
## picker.picked.connect(func(index: int) -> void: connect_to(servers[index]))
##
## # Entries with an icon and a hint
## GoCombobox.make([
##     {"text": "Flame Sword", "icon": &"sword", "hint": "Attack +12"},
##     {"text": "Ice Staff", "icon": &"staff", "hint": "Magic +8"},
## ])
## ```
##
## ## 🔑 Where this parts ways with `GoStyle.select()`
## With **under ten** entries `select()` (OptionButton) is better — everything is visible at a glance and it takes one
## interaction less. Past thirty, scanning the list becomes work. Picking one friend out of 200 is a job for this widget.
##
## ## 🛑 Search matches **inside the text**, not just the start
## `"sword"` has to turn up `"Flame Sword"`. Prefix-only matching finds almost nothing in a Korean or Japanese
## list — the names start with a modifier.
##
## ## 🛑 Never leave a blank space when nothing matches
## If you don't say "nothing found", people **read it as broken.**
@tool
class_name GoCombobox
extends Button

## An entry was picked. `index` is the index in the **original list**, not in the filtered one.
signal picked(index: int)

## The text shown while nothing is picked.
@export var placeholder := "":
	set(value):
		placeholder = value
		_sync_text()

## The entry count from which the list gets a search line. Below it, only the list appears.
@export var search_threshold := 8

## Width of the list card (dp). 0 means the same width as this button.
@export var list_width := 0.0

var _items: Array[Dictionary] = []
var _selected := -1
var _surface: GoSurface
var _layer: CanvasLayer
var _rows: VBoxContainer
var _empty: Control
var _search: LineEdit


func _init() -> void:
	name = "Combobox"
	# 🛑 The picked entry may be a person's name or an item name — leave auto-translation on and it turns into something else.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	pressed.connect(_open)


func _ready() -> void:
	theme = GoUi.theme()
	GoStyle.style_button(self, GoStyle.Tone.NORMAL)
	custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	_sync_text()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)
	_close()


## An entry is either a `String` or `{"text":…, "icon":…, "hint":…, "disabled":…}`.
static func make(items: Array, selected := -1, hint := "") -> GoCombobox:
	var node := GoCombobox.new()
	node.placeholder = hint
	node.set_items(items)
	node.select(selected)
	return node


func set_items(items: Array) -> void:
	_items.clear()
	for entry in items:
		var row: Dictionary = entry if entry is Dictionary else {"text": str(entry)}
		_items.append({
			"text": str(row.get("text", "")),
			"icon": StringName(row.get("icon", &"")),
			"hint": str(row.get("hint", "")),
			"disabled": bool(row.get("disabled", false)),
		})
	if _selected >= _items.size(): _selected = -1
	_sync_text()


func items() -> Array[Dictionary]:
	return _items


## Index of the picked entry (-1 for none).
func selected() -> int:
	return _selected


## Sets the selection. With `notify` off no signal is emitted (used when reflecting back a server value).
func select(index: int, notify := false) -> void:
	_selected = index if index >= 0 and index < _items.size() else -1
	_sync_text()
	if notify and _selected >= 0: picked.emit(_selected)


## Text of the picked entry (empty string if there is none).
func selected_text() -> String:
	return str(_items[_selected]["text"]) if _selected >= 0 else ""


func _sync_text() -> void:
	text = selected_text() if _selected >= 0 else placeholder
	# ♿ Read out as "what this picker is for" plus "what is picked right now".
	var spoken := placeholder if not placeholder.is_empty() else GoUi.text(&"search")
	accessibility_name = GoUi.spoken([spoken, selected_text()])
	if _selected < 0 and not placeholder.is_empty():
		add_theme_color_override(&"font_color", GoUi.color(GoTheme.MUTED))
	else:
		remove_theme_color_override(&"font_color")


func _open() -> void:
	if not is_inside_tree() or _items.is_empty(): return
	_close()
	_layer = CanvasLayer.new()
	_layer.name = "ComboLayer"
	_layer.layer = 96

	_surface = GoSurface.new()
	_surface.placement = GoSurface.Placement.ANCHOR
	_surface.anchor_control = self
	_surface.anchor_width = list_width if list_width > 0.0 else maxf(size.x, 180.0)
	_surface.fit_content = true
	_surface.dismiss_on_scrim = true
	_surface.scrim_transparent = true
	_surface.show_header = false
	_layer.add_child(_surface)
	get_tree().root.add_child(_layer)

	# The search line — left out when there are few entries (on a list you take in at a glance it only gets in the way).
	if _items.size() >= search_threshold:
		_search = GoStyle.line_edit(GoUi.text(&"search"))
		_search.text_changed.connect(func(_t: String) -> void: _fill())
		_surface.body.add_child(_search)

	_rows = GoStyle.column(0)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.body.add_child(_rows)

	# 🛑 `empty_state` takes a **translation key** — hand it translated text and it looks that text up as a key and finds nothing.
	_empty = GoStyle.empty_state(&"search", GoUi.text_key(&"empty"))
	_empty.visible = false
	_surface.body.add_child(_empty)

	_fill()
	_surface.visible = true
	_surface.relayout()
	GoFeedback.opened()
	if _search != null: _search.grab_focus.call_deferred()
	# 🛑 Hold the layer through a **weak reference** — if `_close()` frees it first and this lambda runs afterwards, the
	#    engine prints `Lambda capture … was freed`.
	var held := weakref(_layer)
	var dispose := func() -> void:
		var node := held.get_ref() as CanvasLayer
		if is_instance_valid(node): node.queue_free()
		if _layer != null and _layer == node:
			_layer = null
			_surface = null
			_search = null
	_surface.close_requested.connect(dispose, CONNECT_ONE_SHOT)


## Lays out only the entries matching the current search text.
func _fill() -> void:
	if not is_instance_valid(_rows): return
	for child in _rows.get_children(): child.queue_free()
	var needle := _search.text.strip_edges().to_lower() if is_instance_valid(_search) else ""
	var shown := 0
	for index in _items.size():
		var row := _items[index]
		# 🛑 **Match inside the text too** — prefix-only matching never finds "Flame Sword" by typing "sword".
		if not needle.is_empty() and not str(row["text"]).to_lower().contains(needle) \
				and not str(row["hint"]).to_lower().contains(needle):
			continue
		shown += 1
		_rows.add_child(_row_button(index, row))
	# 🛑 Never leave an empty list as it is — it reads as broken.
	if is_instance_valid(_empty): _empty.visible = shown == 0


func _row_button(index: int, row: Dictionary) -> Control:
	var words := str(row["text"])
	var hint := str(row["hint"])
	var choose := func() -> void:
		select(index)
		picked.emit(index)
		GoFeedback.tapped()
		if is_instance_valid(_surface): _surface.request_close()
	# 🛑 `translate` is **off** — an entry may be a player name or an item name, and looking that up in the translation
	#    table hits a key that does not exist, so it either comes through unchanged or (with bad luck) turns into something else.
	#    `hint` goes in as the subtitle row — there is nothing to assemble by hand.
	var button := GoStyle.list_button(StringName(row["icon"]), words, choose, Color.TRANSPARENT, hint, false)
	button.disabled = bool(row["disabled"])
	if index == _selected: button.add_theme_color_override(&"font_color", GoUi.color(GoTheme.ACCENT))
	button.accessibility_name = GoUi.spoken([words, hint])
	return button


func _close() -> void:
	if is_instance_valid(_layer): _layer.queue_free()
	_layer = null
	_surface = null
	_search = null


func _on_ui_changed() -> void:
	theme = GoUi.theme()
	GoStyle.style_button(self, GoStyle.Tone.NORMAL)
	custom_minimum_size.y = GoUi.metric(GoTheme.BUTTON_HEIGHT)
	_sync_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _sync_text()
