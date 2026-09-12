## 📜 세로 스크롤 한 칸. 손가락 끌기·포커스 따라가기·가장자리 여백을 한 곳에서 처리한다.
##
## ## 안에 딱 하나만 넣는다
## 머리말과 버튼 줄은 **밖**에 둔다. 목록이 길어지면 그것들이 화면 밖으로 나가면 안 된다.
##
## ```gdscript
## var scroll := GoScroll.new()
## scroll.add_child(body_column)      # 자식 하나
## card.add_child(scroll)
## ```
##
## ## 🔑 스크롤바가 글자를 가리지 않게
## `use_panel_edge()` 를 부르면 스크롤바가 **카드의 기존 여백 자리**로 나가고, 내용은 원래
## 들여쓰기를 유지한다. 스크롤바가 없을 때는 그 자리를 내용이 도로 쓴다.
@tool
class_name GoScroll
extends ScrollContainer

var _edge_frame: MarginContainer
var _content_inset: MarginContainer
var _edge_gutter := 0


func _init() -> void:
	name = "Scroll"
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	follow_focus = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 🛑 스크롤 **레일은 언제나 물리적 오른쪽**이다 — 아랍어·우르두에서도 마찬가지다.
	#    내용의 좌우 방향은 자식이 각자 정한다(`_prepare_branch` 가 LOCALE 로 되돌린다).
	layout_direction = Control.LAYOUT_DIRECTION_LTR


func _ready() -> void:
	theme = GoUi.theme()
	scroll_deadzone = GoUi.metric(GoTheme.SCROLL_DEADZONE)
	child_entered_tree.connect(_prepare_branch)
	for child in get_children(): _prepare_branch(child)


## 가로로 흐르는 스크롤(칩 줄·썸네일 줄).
static func horizontal() -> GoScroll:
	return as_horizontal(GoScroll.new())


## `horizontal()` 의 설정만 — 자식 클래스가 자기 인스턴스로 같은 팩토리를 다시 만들 때 쓴다
## (`static func horizontal() -> Child: return GoScroll.as_horizontal(Child.new())`). 정적 함수는 자식 타입을 모른다.
static func as_horizontal(node: GoScroll) -> GoScroll:
	node.horizontal_scroll_mode = SCROLL_MODE_AUTO
	node.vertical_scroll_mode = SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_FILL
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


## 이 노드를 감싸고 있는 `GoScroll`(없으면 null).
static func containing(node: Node) -> GoScroll:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is GoScroll: return ancestor
		ancestor = ancestor.get_parent()
	return null


## 스크롤바를 부모의 기존 오른쪽 여백으로 내보내고, 내용은 원래 들여쓰기를 지킨다.
## `parent_padding` 은 부모 카드가 쓰는 여백(dp)이다.
func use_panel_edge(parent_padding: int) -> void:
	if _edge_frame != null: return
	_edge_gutter = maxi(0, parent_padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	var parent := get_parent()
	if parent == null: return
	var index := get_index()
	_edge_frame = MarginContainer.new()
	_edge_frame.name = name + "Edge"
	_edge_frame.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_edge_frame.size_flags_horizontal = size_flags_horizontal
	_edge_frame.size_flags_vertical = size_flags_vertical
	_edge_frame.size_flags_stretch_ratio = size_flags_stretch_ratio
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		_edge_frame.add_theme_constant_override(side, 0)
	_edge_frame.add_theme_constant_override(&"margin_right", -_edge_gutter)
	parent.add_child(_edge_frame)
	parent.move_child(_edge_frame, index)
	reparent(_edge_frame)
	var content := get_children()
	_content_inset = MarginContainer.new()
	_content_inset.name = "ContentInset"
	_content_inset.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_content_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_top", &"margin_bottom"]:
		_content_inset.add_theme_constant_override(side, 0)
	add_child(_content_inset)
	for child in content: child.reparent(_content_inset)
	var bar := get_v_scroll_bar()
	bar.visibility_changed.connect(_sync_edge_inset)
	bar.resized.connect(_sync_edge_inset)
	_sync_edge_inset()


## 카드가 좁아져 여백이 바뀌었을 때 — 스크롤·내용 소유권을 다시 만들지 않고 여백만 고친다.
func set_panel_padding(padding: int) -> void:
	if _edge_frame == null: return
	_edge_gutter = maxi(0, padding - GoUi.metric(GoTheme.SCROLL_EDGE))
	_edge_frame.add_theme_constant_override(&"margin_right", -_edge_gutter)
	_sync_edge_inset()


## 스크롤 칸 전체를 함께 보이고 숨긴다(가장자리 프레임까지).
func set_section_visible(value: bool) -> void:
	if _edge_frame != null: _edge_frame.visible = value
	visible = value


func _sync_edge_inset() -> void:
	if _content_inset == null: return
	var bar := get_v_scroll_bar()
	var reserved := 0
	if bar.visible:
		reserved = ceili(bar.get_combined_minimum_size().x) + get_theme_constant(&"scrollbar_h_separation")
	_content_inset.add_theme_constant_override(&"margin_right", maxi(0, _edge_gutter - reserved))


## 평범한 버튼은 손가락 끌기를 `ScrollContainer` 가 보게 해야 한다 — 그래야 목록 위에서 시작한
## 스크롤이 먹힌다. 엔진이 끌기 문턱을 넘으면 버튼 누름을 취소해 준다.
## 🛑 글자 편집·슬라이더·`OptionButton` 팝업은 자기 제스처를 지켜야 하므로 건드리지 않는다.
func _prepare_branch(node: Node) -> void:
	if node is ScrollBar or node is ScrollContainer: return
	if node is Control and node.get_parent() == self and node.layout_direction == Control.LAYOUT_DIRECTION_INHERITED:
		node.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE  # 4.4+ 이름 — `LOCALE` 는 폐기 예정 별칭
	if node is Button and not node is OptionButton:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	if not node.child_entered_tree.is_connected(_prepare_branch):
		node.child_entered_tree.connect(_prepare_branch)
	for child in node.get_children(): _prepare_branch(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _content_inset != null:
		# 언어가 바뀌면 자식들이 좌우를 뒤집는다 — 우리의 물리적 오른쪽 여백 안으로 다시 맞춘다.
		_content_inset.queue_sort.call_deferred()
