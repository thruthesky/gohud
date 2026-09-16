## 🔎 **찾아서 고르는 선택칸** — 친구 찾기, 아이템 검색, 서버 고르기, 길드원 지목.
##
## ```gdscript
## var picker := GoCombobox.make(server_names, 0)
## picker.picked.connect(func(index: int) -> void: connect_to(servers[index]))
##
## # 아이콘·설명이 붙는 항목
## GoCombobox.make([
##     {"text": "불꽃의 검", "icon": &"sword", "hint": "공격력 +12"},
##     {"text": "얼음 지팡이", "icon": &"staff", "hint": "마력 +8"},
## ])
## ```
##
## ## 🔑 `GoStyle.select()` 와 언제 갈리나
## 항목이 **열 개 안쪽**이면 `select()`(OptionButton)가 낫다 — 한눈에 다 보이고 조작이 한 번 적다.
## 서른 개가 넘어가면 목록을 훑는 것이 일이 된다. 친구 200명에서 한 명을 고르는 자리는 이쪽이다.
##
## ## 🛑 검색은 **가운데 글자도** 잡는다
## `"검"` 으로 `"불꽃의 검"` 이 나와야 한다. 앞글자만 맞추면(prefix) 한국어·일본어 목록에서 거의
## 아무것도 안 나온다 — 이름이 수식어로 시작하기 때문이다.
##
## ## 🛑 결과가 없을 때 빈 칸을 두지 않는다
## "찾는 것이 없다" 를 말해 주지 않으면 사용자는 **고장으로 읽는다.**
@tool
class_name GoCombobox
extends Button

## 항목을 골랐다. `index` 는 **원래 목록**의 번호다(걸러진 목록의 번호가 아니다).
signal picked(index: int)

## 아무것도 고르지 않았을 때 보여 줄 글자.
@export var placeholder := "":
	set(value):
		placeholder = value
		_sync_text()

## 목록에 검색줄을 붙일 최소 항목 수. 이보다 적으면 검색줄 없이 목록만 뜬다.
@export var search_threshold := 8

## 목록 카드의 폭(dp). 0 이면 이 버튼과 같은 폭.
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
	# 🛑 고른 항목이 사람 이름·아이템 이름일 수 있다 — 자동 번역을 켜 두면 엉뚱하게 바뀐다.
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


## 항목은 글자(`String`)이거나 `{"text":…, "icon":…, "hint":…, "disabled":…}` 다.
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


## 고른 항목의 번호(-1 이면 없음).
func selected() -> int:
	return _selected


## 골라 둔다. `notify` 를 끄면 신호를 부르지 않는다(서버 값을 되비출 때).
func select(index: int, notify := false) -> void:
	_selected = index if index >= 0 and index < _items.size() else -1
	_sync_text()
	if notify and _selected >= 0: picked.emit(_selected)


## 고른 항목의 글자(없으면 빈 글).
func selected_text() -> String:
	return str(_items[_selected]["text"]) if _selected >= 0 else ""


func _sync_text() -> void:
	text = selected_text() if _selected >= 0 else placeholder
	# ♿ "무엇을 고르는 칸인지" + "지금 무엇이 골라져 있는지" 를 함께 읽힌다.
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

	# 검색줄 — 항목이 적으면 넣지 않는다(한눈에 보이는 목록에 검색칸은 방해다).
	if _items.size() >= search_threshold:
		_search = GoStyle.line_edit(GoUi.text(&"search"))
		_search.text_changed.connect(func(_t: String) -> void: _fill())
		_surface.body.add_child(_search)

	_rows = GoStyle.column(0)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.body.add_child(_rows)

	# 🛑 `empty_state` 는 **번역 키**를 받는다 — 번역된 글자를 넘기면 그것을 다시 키로 찾아 못 찾는다.
	_empty = GoStyle.empty_state(&"search", GoUi.text_key(&"empty"))
	_empty.visible = false
	_surface.body.add_child(_empty)

	_fill()
	_surface.visible = true
	_surface.relayout()
	GoFeedback.opened()
	if _search != null: _search.grab_focus.call_deferred()
	var layer := _layer
	var dispose := func() -> void:
		if is_instance_valid(layer): layer.queue_free()
		if _layer == layer:
			_layer = null
			_surface = null
			_search = null
	_surface.close_requested.connect(dispose, CONNECT_ONE_SHOT)


## 지금 검색어에 맞는 항목만 다시 늘어놓는다.
func _fill() -> void:
	if not is_instance_valid(_rows): return
	for child in _rows.get_children(): child.queue_free()
	var needle := _search.text.strip_edges().to_lower() if is_instance_valid(_search) else ""
	var shown := 0
	for index in _items.size():
		var row := _items[index]
		# 🛑 **가운데 글자도 잡는다** — 앞글자만 맞추면 "불꽃의 검" 을 "검" 으로 못 찾는다.
		if not needle.is_empty() and not str(row["text"]).to_lower().contains(needle) \
				and not str(row["hint"]).to_lower().contains(needle):
			continue
		shown += 1
		_rows.add_child(_row_button(index, row))
	# 🛑 빈 목록을 그냥 두지 않는다 — 고장으로 읽힌다.
	if is_instance_valid(_empty): _empty.visible = shown == 0


func _row_button(index: int, row: Dictionary) -> Control:
	var words := str(row["text"])
	var hint := str(row["hint"])
	var choose := func() -> void:
		select(index)
		picked.emit(index)
		GoFeedback.tapped()
		if is_instance_valid(_surface): _surface.request_close()
	# 🛑 `translate` 를 **끈다** — 항목이 플레이어 이름·아이템 이름일 수 있고, 그것을 번역
	#    테이블에서 찾으면 없는 키라 글자가 그대로 나오거나(운 나쁘면) 엉뚱하게 바뀐다.
	#    `hint` 는 부제 줄로 들어간다 — 따로 조립할 필요가 없다.
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
