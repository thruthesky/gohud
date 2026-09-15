## 📄 **아래에서 올라오는 시트** — 자체 `CanvasLayer` 를 갖는 페이지 컨테이너.
##
## `GoSurface` 를 쓰기 쉽게 감싼 것이다. 게임 화면 위에 목록·관리 페이지를 띄우고, 페이지를
## 갈아 끼우며 쓴다. 층(`layer`)을 스스로 들고 있어 HUD 위에 확실히 올라온다.
##
## ```gdscript
## var sheet := GoSheet.new()
## add_child(sheet)
## sheet.open("가방")
## sheet.body.add_child(item_list)
## sheet.add_footer(GoStyle.button("닫기", sheet.close))
## ```
##
## ## 🔑 페이지를 바꿀 때
## `open()` 은 본문·고정 줄을 비우고 뒤로 버튼·고정 줄·바닥 줄을 **끈다**. 돌아갈 데가 없는 화면에 죽은 버튼이
## 남으면 누른 사람은 아무 일도 안 일어나는 것을 고장으로 읽는다.
## 페이지마다 바뀌는 바닥 버튼은 `add_footer()` 로 넣는다 — 다음 `open()` 이 떼어 지운다.
@tool
class_name GoSheet
extends CanvasLayer

signal closed
signal page_changed

## 본문(스크롤됨).
var body: VBoxContainer
## 감싸고 있는 표면 — 세밀한 조정이 필요하면 직접 만진다.
var surface: GoSurface

## 배경을 눌러 닫을 수 있는가.
## 🛑 **되돌릴 수 없는 조작을 담은 시트는 꺼 둔다** — 거래창처럼 물건을 올려 둔 화면이
##    바깥 오탭 한 번으로 닫히면 올린 것이 전부 사라진다. 닫기 버튼과 Escape·뒤로가기는
##    그대로라 빠져나갈 길은 남는다.
var dismissable := true:
	set(value):
		dismissable = value
		if is_instance_valid(surface): surface.dismiss_on_scrim = value

## 차지할 화면 높이 비율.
var height_ratio := 0.6:
	set(value):
		height_ratio = value
		if is_instance_valid(surface): surface.height_ratio = value
	get:
		return surface.height_ratio if is_instance_valid(surface) and surface.height_ratio > 0.0 else height_ratio

var _back_action := Callable()
## `add_footer()` 로 넣은 이 페이지의 바닥 노드 — 다음 `open()` 이 치운다.
var _page_footer: Array[Node] = []


## 🛑 표면은 `_init` 에서 만든다 — 트리에 붙이기 전에 `sheet.open()`·`sheet.body` 를 쓰는 것이
##    자연스러운 사용법인데, `_ready` 에서 만들면 그때 `body` 가 아직 `null` 이라 죽는다.
func _init() -> void:
	visible = false
	surface = _make_surface()
	surface.placement = GoSurface.Placement.BOTTOM
	surface.fit_content = true
	surface.resizable = true
	surface.close_requested.connect(close)
	add_child(surface)
	body = surface.body


func _ready() -> void:
	if layer == 1: layer = 10
	# `new()` 뒤에 바꿨을 수 있는 값을 반영한다. 🛑 `true` 를 박지 않는다 — `dismissable = false`
	#    로 정한 시트(거래창처럼 오탭으로 닫히면 안 되는 것)를 덮어쓴다.
	surface.height_ratio = height_ratio
	surface.dismiss_on_scrim = dismissable


## 시트를 열고 제목을 정한다(이미 번역된 문구). 본문·뒤로·고정 줄과 `add_footer()` 로 넣은 바닥 노드를 초기화한다.
func open(title: String) -> void:
	if not visible: GoFeedback.opened()
	surface.set_title(title)
	surface.clear()
	set_back(Callable())
	for child in toolbar().get_children():
		toolbar().remove_child(child)
		child.queue_free()
	# 🛑 바닥 줄은 **`add_footer()` 로 넣은 것만** 치운다. 끄기만 하면 페이지마다 닫기를 더하는 화면에서 버튼이
	#    쌓였다(2026-09-15 확인). 그렇다고 통째로 비우면 `footer().add_child()` 로 한 번 넣고 계속 쓰는 노드
	#    (시트 전체의 스낵바처럼)가 페이지를 바꾸는 순간 사라진다 — 그렇게 쓰는 호스트가 이미 있다.
	for node in _page_footer:
		if is_instance_valid(node) and node.get_parent() == footer():
			footer().remove_child(node)
			node.queue_free()
	_page_footer.clear()
	toolbar().visible = false
	footer().visible = false
	visible = true
	surface.relayout()
	page_changed.emit()


## 번역 키로 연다.
func open_key(title_key: String) -> void:
	open("")
	surface.set_title_key(title_key)


## 제목만 바꾼다 — `open()` 과 달리 본문·뒤로·고정 줄을 건드리지 않는다.
## 같은 시트 안에서 하위 화면으로 들어갈 때(목록 → 상세) 제목이 따라가야 한다.
func set_title(value: String) -> void:
	surface.set_title(value)


## 머리말 아래의 **고정 줄**. 검색칸처럼 목록을 내려도 보여야 하는 것을 넣는다.
## 쓰는 쪽이 `visible = true` 를 켠다. `open()` 이 매 페이지마다 비우고 끈다.
func toolbar() -> VBoxContainer:
	return surface.toolbar


## **고정 바닥 줄**. 🛑 늘 보여야 하는 확인·취소는 여기 넣는다 — `body` 에 넣으면 목록과 함께
## 스크롤되어 긴 목록에서는 화면 밖으로 나간다. 쓰는 쪽이 `visible = true` 를 켠다. `open()` 은 끄기만 하고
## 여기에 직접 넣은 자식은 남긴다 — 페이지마다 바뀌는 버튼은 `add_footer()` 로 넣는다.
func footer() -> VBoxContainer:
	return surface.footer


## **이 페이지의** 바닥 줄에 넣고 바닥 줄을 켠다. 다음 `open()` 이 떼어 지운다.
## 🔑 페이지마다 닫기·확인을 더하는 화면은 이것을 쓴다 — `footer().add_child()` 로 넣은 것은 `open()` 뒤에도
##    남는다(시트 전체에 걸린 스낵바·고정 버튼 자리).
func add_footer(node: Node) -> Node:
	footer().add_child(node)
	footer().visible = true
	_page_footer.append(node)
	return node


## 같은 시트 안의 하위 화면이 쓰는 뒤로 버튼. 빈 `Callable` 이면 감춘다.
func set_back(action: Callable) -> void:
	_back_action = action
	surface.set_back(action)


func clear() -> void:
	surface.clear()


func close() -> void:
	if not visible: return
	GoFeedback.closed()
	visible = false
	closed.emit()


## 감싸는 표면을 만든다. 🔑 호스트가 `GoSurface` 의 서브클래스를 쓰고 싶으면(옛 타입 힌트 호환 등) 자식에서 덮어쓴다.
func _make_surface() -> GoSurface:
	return GoSurface.new()
