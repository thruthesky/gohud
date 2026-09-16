## 👆 **길게 눌러 여는 메뉴** — 아이템에 쓰기·장착·버리기, 플레이어에 귓속말·초대·차단.
##
## ```gdscript
## GoContextMenu.attach(item_slot, [
##     {"text": "사용", "action": use},
##     {"text": "장착", "action": equip},
##     {"separator": true},
##     {"text": "버리기", "action": drop, "danger": true},
## ])
##
## # 누를 때마다 목록이 달라진다면 — 열리기 직전에 만든다
## GoContextMenu.attach(player_row, func() -> Array: return menu_for(player))
## ```
##
## ## 🔑 이 위젯의 값어치는 **제스처**다
## `PopupMenu` 는 엔진에 이미 있다. 없는 것은 "모바일에서 길게 누르면 뜨고, PC 에서 우클릭하면
## 뜨고, **손가락이 움직이면 취소되는**" 그 처리다. 그것을 화면마다 다시 쓰면 판정이 제각각이 된다.
##
## ## 🛑 끌기와 길게 누르기를 가른다
## 목록 안의 칸을 길게 누를 때, 손가락이 조금이라도 움직이면 그것은 **스크롤**이지 메뉴가 아니다.
## `slop` (기본 12dp) 을 넘게 움직이면 취소한다 — 이것이 없으면 목록을 넘길 때마다 메뉴가 튀어나온다.
##
## ## 🛑 길게 누르기는 **안내가 필요하다**
## 눌러 볼 생각을 못 하면 없는 기능이다. 아이콘 하나, 첫 실행의 코치마크(`GoCoachMark`), 또는
## 눈에 보이는 `⋯` 버튼을 함께 둔다 — 길게 누르기**만**으로 닿는 기능을 만들지 않는다.
@tool
class_name GoContextMenu
extends RefCounted

## 길게 누른 것으로 치는 시간(초). 🔑 Android 기본값(0.5)에 맞춘다 — 기기 습관과 어긋나면 느리게 느껴진다.
const HOLD_SECONDS := 0.5

## 이만큼(dp) 움직이면 끌기로 보고 취소한다.
const SLOP_DP := 12.0

## 붙여 둔 처리기를 찾는 메타 이름.
const _ATTACHED := &"gohud_context_menu"


## 컨트롤에 **길게 누르기·우클릭 메뉴**를 붙인다(두 번 불러도 하나만 붙는다).
##
## `items` 는 배열이거나, **열릴 때마다** 배열을 만들어 주는 `Callable` 이다.
## 목록이 상황에 따라 달라지면(파티장인지 아닌지) 반드시 `Callable` 을 쓴다.
##
## | 칸 | 뜻 |
## |---|---|
## | `text` | 항목 글자(번역 키면 `translate: true`) |
## | `action` | 고르면 부를 `Callable` |
## | `icon` | 아이콘 이름 |
## | `disabled` | 회색으로 두고 못 고르게 |
## | `danger` | 위험색으로(버리기·차단·탈퇴) |
## | `separator` | `true` 면 구분선 한 줄 |
## | `checked` | 켜짐 표시가 붙는 항목 |
static func attach(host: Control, items: Variant) -> void:
	if not is_instance_valid(host): return
	# 🛑 `get_meta(key, default)` 는 키가 없으면 오류를 찍는다 — 먼저 `has_meta` 로 묻는다.
	var holder: _Holder = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if holder == null:
		holder = _Holder.new()
		holder.host = host
		host.set_meta(_ATTACHED, holder)
		host.gui_input.connect(holder.on_input)
		# 🛑 컨트롤이 사라질 때 팝업도 함께 치운다 — 남으면 사라진 아이템의 메뉴가 화면에 떠 있다.
		host.tree_exiting.connect(holder.dispose)
	holder.items = items


## 붙여 둔 메뉴를 뗀다.
static func detach(host: Control) -> void:
	if not is_instance_valid(host): return
	var holder: _Holder = host.get_meta(_ATTACHED) if host.has_meta(_ATTACHED) else null
	if holder != null: holder.dispose()
	if host.has_meta(_ATTACHED): host.remove_meta(_ATTACHED)


## 지금 그 자리에 메뉴를 **바로** 연다(길게 누르기를 기다리지 않고). `⋯` 버튼에 쓴다.
static func open_at(host: Control, items: Variant, where := Vector2.INF) -> PopupMenu:
	if not is_instance_valid(host) or not host.is_inside_tree(): return null
	var entries := _entries(items)
	if entries.is_empty(): return null
	var popup := _build(entries)
	host.add_child(popup)
	GoStyle.style_popup(popup)
	var spot := where if where.is_finite() else host.get_global_rect().get_center()
	# 🛑 창을 **품고 있으면**(`gui_embed_subwindows`, Godot 4 기본) 팝업 좌표는 뷰포트 기준이다 —
	#    거기에 OS 창 위치를 더하면 팝업이 화면 밖으로 날아간다. 품지 않을 때만 창 위치를 더한다.
	var window := host.get_window()
	var embedded := window == null or window.gui_embed_subwindows
	var origin := Vector2i.ZERO if embedded else window.position
	popup.position = Vector2i(spot.round()) + origin
	popup.reset_size()
	popup.popup()
	GoFeedback.opened()
	popup.popup_hide.connect(popup.queue_free, CONNECT_ONE_SHOT)
	return popup


## `items` 가 배열이든 `Callable` 이든 **지금의 목록**으로 만든다.
static func _entries(items: Variant) -> Array:
	if items is Callable:
		var made: Variant = (items as Callable).call()
		return made if made is Array else []
	return items if items is Array else []


static func _build(entries: Array) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.name = "ContextMenu"
	var actions: Array[Callable] = []
	for entry in entries:
		var row: Dictionary = entry if entry is Dictionary else {"text": str(entry)}
		if bool(row.get("separator", false)):
			popup.add_separator()
			actions.append(Callable())
			continue
		var words := str(row.get("text", ""))
		var index := popup.item_count
		if bool(row.get("checked", false)):
			popup.add_check_item(words, index)
			popup.set_item_checked(index, true)
		else:
			popup.add_item(words, index)
		# 🛑 번역은 **항목마다** 정한다 — 플레이어 이름처럼 번역하면 안 되는 것이 섞인다.
		popup.set_item_auto_translate_mode(index,
			Node.AUTO_TRANSLATE_MODE_ALWAYS if bool(row.get("translate", false)) else Node.AUTO_TRANSLATE_MODE_DISABLED)
		if row.has("icon"):
			var texture := GoUi.icons().texture(StringName(row["icon"]))
			if texture != null: popup.set_item_icon(index, texture)
		if bool(row.get("disabled", false)): popup.set_item_disabled(index, true)
		# 되돌릴 수 없는 항목은 눈으로 가려낼 수 있어야 오탭이 준다.
		# 🛑 `add_theme_color_override` 는 **메뉴 전체**에 걸린다 — 한 항목을 위험색으로 만들려다
		#    모든 항목을 물들인다. `PopupMenu` 는 항목별 글자색을 주지 않는다.
		# 🛑 그렇다고 **글자 앞에 기호를 이어 붙이면 안 된다** — 그 글자가 번역 키일 수 있고,
		#    그러면 엔진이 `"⚠ menu_drop"` 을 통째로 키로 찾아 못 찾고 화면에 키가 그대로 드러난다
		#    (`go_table.gd` 가 정렬 화살표에서 같은 함정을 겪었다). 번역을 **먼저 끝내고** 붙인다.
		# ♿ 기호는 색이 아니라 모양이라 색각 이상인 사람에게도 똑같이 읽힌다.
		if bool(row.get("danger", false)):
			# 🛑 `tr()` 은 `Object` 의 **인스턴스** 메서드라 `static func` 에서 못 부른다 — 부르면
			#    파싱 단계에서 죽고, 이 파일을 참조하는 화면과 검사가 통째로 로드되지 않는다.
			#    `TranslationServer.translate()` 는 싱글턴이라 여기서 부를 수 있고, `GoUi.text()` 도
			#    같은 것을 쓴다(2026-09-16: `tr()` 로 썼다가 커밋까지 간 것을 다른 세션이 잡아 줬다).
			var shown := TranslationServer.translate(words) if bool(row.get("translate", false)) else words
			popup.set_item_text(index, "⚠ " + shown)
			popup.set_item_auto_translate_mode(index, Node.AUTO_TRANSLATE_MODE_DISABLED)
			popup.set_item_metadata(index, &"danger")
		actions.append(row.get("action", Callable()))
	popup.id_pressed.connect(func(id: int) -> void:
		if id < 0 or id >= actions.size(): return
		var action := actions[id]
		GoFeedback.tapped()
		if action.is_valid(): action.call())
	return popup


## 컨트롤 하나에 붙어 길게 누르기를 재는 작은 상태 기계.
## 🛑 `RefCounted` 다 — 노드를 더하지 않는다. 붙는 쪽의 트리 모양을 바꾸면 그 화면의 배치가 흔들린다.
class _Holder extends RefCounted:
	var host: Control
	var items: Variant = []
	var _pressed_at := Vector2.ZERO
	var _timer: SceneTreeTimer
	var _index := -1

	func on_input(event: InputEvent) -> void:
		if not is_instance_valid(host): return
		# PC — 우클릭은 그 자리에서 곧바로.
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			host.accept_event()
			GoContextMenu.open_at(host, items, host.get_global_mouse_position())
			return
		# 모바일 — 누르고 있는 동안 잰다.
		var touch := event as InputEventScreenTouch
		if touch != null:
			if touch.pressed and _index < 0:
				_index = touch.index
				_begin(touch.position)
			elif not touch.pressed and touch.index == _index:
				_cancel()
			return
		var drag := event as InputEventScreenDrag
		if drag != null and drag.index == _index:
			# 🛑 손가락이 움직였다 — 이것은 **스크롤**이다. 여기서 취소하지 않으면 목록을 넘길
			#    때마다 메뉴가 튀어나온다.
			if drag.position.distance_to(_pressed_at) > GoContextMenu.SLOP_DP: _cancel()
			return
		# 데스크톱에서 왼쪽 버튼을 오래 누르는 것도 같게 본다 — 개발 중 시험이 쉬워진다.
		if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and _index < 0:
				_index = -2
				_begin(mouse.position)
			elif not mouse.pressed and _index == -2:
				_cancel()

	func _begin(at: Vector2) -> void:
		_pressed_at = at
		var tree := host.get_tree()
		if tree == null: return
		_timer = tree.create_timer(GoContextMenu.HOLD_SECONDS)
		_timer.timeout.connect(_fire.bind(at), CONNECT_ONE_SHOT)

	func _fire(at: Vector2) -> void:
		if _index < 0 and _index != -2: return
		if not is_instance_valid(host) or not host.is_inside_tree(): return
		_index = -1
		# 🔔 길게 누르기는 **손끝으로 알려야 한다** — 화면을 보고 있지 않을 수도 있고,
		#    "언제 떴는지" 를 모르면 손을 언제 떼야 할지 알 수 없다.
		GoFeedback.tapped()
		GoContextMenu.open_at(host, items, host.get_global_transform() * at)

	func _cancel() -> void:
		_index = -1
		if _timer != null and _timer.time_left > 0.0:
			# 타이머는 취소할 수 없다 — 연결을 끊어 불려도 아무 일이 없게 한다.
			for connection in _timer.timeout.get_connections():
				_timer.timeout.disconnect(connection.callable)
		_timer = null

	func dispose() -> void:
		_cancel()
		if not is_instance_valid(host): return
		if host.gui_input.is_connected(on_input): host.gui_input.disconnect(on_input)
		if host.tree_exiting.is_connected(dispose): host.tree_exiting.disconnect(dispose)
		# 🛑 **메타도 지운다.** 남겨 두면 그 컨트롤을 다시 트리에 넣고 `attach()` 를 불러도
		#    "이미 붙어 있다" 로 보고 죽은 처리기를 그대로 둬, 길게 눌러도 아무 일이 없다.
		if host.has_meta(GoContextMenu._ATTACHED): host.remove_meta(GoContextMenu._ATTACHED)
