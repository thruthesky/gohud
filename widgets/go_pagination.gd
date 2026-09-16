## 📑 **쪽 넘기기** — 우편함, 상점 목록, 친구 목록, 랭킹.
##
## ```gdscript
## var pager := GoPagination.make(1, 12, func(page: int) -> void: load_mail(page))
## sheet.add_footer(pager)
## pager.set_page(3)
##
## # 모바일에 어울리는 「더 보기」 한 줄
## var more := GoPagination.more(func() -> void: append_next_page())
## list.add_child(more)
## more.set_busy(true)          # 서버를 기다리는 동안 — 두 번 눌리지 않는다
## ```
##
## ## 🔑 폰에서는 「더 보기」가 낫다
## 쪽 번호는 마우스로 정확히 짚는 UI 다. 엄지로는 1·2·3 을 구분해 누르기 어렵고, 목록을 보다가
## 맨 아래로 내려가 번호를 찾는 것도 흐름이 끊긴다. **폰이면 `more()`, 태블릿·PC 면 `make()`** 를
## 쓰는 편이 대체로 맞다.
##
## ## 🛑 쪽 수를 모를 수도 있다
## 서버가 총 개수를 안 주는 목록(무한 스크롤)에서는 `total` 을 0 으로 둔다. 그러면 번호 대신
## 앞·뒤 버튼만 남는다 — **모르는 것을 아는 척하지 않는다.**
##
## ## 🛑 눌린 뒤에는 잠근다
## 서버 왕복 중에 다음 쪽을 두 번 누르면 두 쪽을 건너뛰거나 응답이 뒤섞인다. `set_busy(true)` 로
## 잠그고, 결과가 오면 푼다.
@tool
class_name GoPagination
extends HBoxContainer

## 쪽이 바뀌었다(1부터).
signal page_changed(page: int)

## 「더 보기」를 눌렀다.
signal more_requested

## 번호 버튼을 몇 개까지 늘어놓을 것인가. 넘으면 `…` 로 접는다.
@export var window := 5:
	set(value):
		window = maxi(3, value)
		_rebuild()

var _page := 1
var _total := 0
var _more_mode := false
var _busy := false
var _action := Callable()


func _init() -> void:
	name = "Pagination"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))


func _ready() -> void:
	_rebuild()
	GoUi.watch(_on_ui_changed)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


## 번호가 있는 쪽 넘기개. `total` 이 0 이면 총 쪽 수를 모르는 것으로 보고 앞·뒤만 둔다.
static func make(page: int, total: int, action := Callable()) -> GoPagination:
	var node := GoPagination.new()
	node._action = action
	node._total = maxi(0, total)
	node._page = maxi(1, page)
	return node


## 「더 보기」 한 줄. 목록 **맨 아래**에 둔다.
static func more(action := Callable()) -> GoPagination:
	var node := GoPagination.new()
	node._more_mode = true
	node._action = action
	return node


## 지금 쪽(1부터).
func page() -> int:
	return _page


func total() -> int:
	return _total


## 쪽을 옮긴다. 범위를 벗어나면 끝으로 잘린다. `notify` 를 끄면 신호·콜백을 부르지 않는다
## (서버가 준 쪽 번호를 **되비출 때** 쓴다 — 안 그러면 다시 불러오는 고리가 생긴다).
func set_page(value: int, notify := true) -> void:
	var limit := _total if _total > 0 else value
	var next := clampi(value, 1, maxi(1, limit))
	if next == _page and not _more_mode: return
	_page = next
	_rebuild()
	if not notify: return
	page_changed.emit(_page)
	if _action.is_valid(): _action.call(_page)


## 총 쪽 수를 바꾼다(목록을 다시 받았을 때).
func set_total(value: int) -> void:
	_total = maxi(0, value)
	if _total > 0: _page = clampi(_page, 1, _total)
	_rebuild()


## 서버를 기다리는 동안 잠근다 — 버튼이 도는 표시로 바뀌고 눌리지 않는다.
func set_busy(waiting: bool) -> void:
	_busy = waiting
	_rebuild()


func is_busy() -> bool:
	return _busy


func _rebuild() -> void:
	for child in get_children(): child.queue_free()
	if _more_mode:
		var button := GoStyle.button(GoUi.text(&"next"), func() -> void:
			if _busy: return
			more_requested.emit()
			if _action.is_valid(): _action.call())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(button)
		if _busy: GoSpinner.busy.call_deferred(button, true)
		return

	add_child(_step(&"back", _page - 1, _page > 1))
	if _total > 0:
		for number in _numbers():
			if number < 0:
				var gap := GoStyle.label("…", GoTheme.ROLE_BODY, GoUi.color(GoTheme.MUTED))
				gap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				add_child(gap)
				continue
			add_child(_number(number))
	# 🛑 아이콘 이름은 **세트에 실제로 있는 것**이어야 한다 — 없으면 빈 칸이 그려지고 경고만 남는다.
	#    기본 세트의 앞·뒤는 `back`/`forward` 다(`next` 는 문구 키이지 아이콘 이름이 아니다).
	add_child(_step(&"forward", _page + 1, _total <= 0 or _page < _total))


## 앞·뒤 버튼.
func _step(icon: StringName, target: int, enabled: bool) -> Control:
	var button := GoIconButton.new()
	button.icon_name = icon
	# 🔑 아이콘 이름과 문구 키는 **다른 목록**이다 — 그림은 `forward`, 읽어 줄 말은 `next` 다.
	button.tooltip_text_name = &"back" if icon == &"back" else &"next"
	button.disabled = not enabled or _busy
	button.pressed.connect(func() -> void: set_page(target))
	return button


## 번호 버튼 하나.
func _number(value: int) -> Control:
	var button := GoStyle.button(str(value), func() -> void: set_page(value),
		GoStyle.Tone.PRIMARY if value == _page else GoStyle.Tone.BARE)
	# 🛑 숫자는 번역하지 않는다 — 쪽 번호가 다른 글자로 바뀌면 안 된다.
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# 🛑 폭만이 아니라 **높이도** 터치 하한이다. 지금 쪽이 아닌 번호는 `Tone.BARE` 인데 그 톤은
	#    높이 하한을 걸지 않는다 — 정작 **누르는 대상**이 하한 아래가 된다(2026-09-16 실측).
	button.custom_minimum_size = Vector2.ONE * float(GoUi.metric(GoTheme.TOUCH))
	button.disabled = _busy
	# ♿ "3" 만으로는 무엇의 3 인지 모른다. 🔑 「n / m」 형식은 문구 키를 탄다.
	button.accessibility_name = GoUi.text(&"bar_fraction").format({"value": value, "max": _total})
	return button


## 늘어놓을 번호들. `-1` 은 `…` 자리다.
## 🔑 지금 쪽이 늘 **가운데**에 오게 창을 민다 — 가장자리에서만 접으면 9쪽에서 다음을 누를 때
##    번호가 통째로 갈아엎어져 어디였는지 놓친다.
func _numbers() -> Array[int]:
	var out: Array[int] = []
	if _total <= window:
		for i in range(1, _total + 1): out.append(i)
		return out
	var half := window / 2
	var first := clampi(_page - half, 1, maxi(1, _total - window + 1))
	var last := mini(_total, first + window - 1)
	if first > 1:
		out.append(1)
		if first > 2: out.append(-1)
	for i in range(first, last + 1): out.append(i)
	if last < _total:
		if last < _total - 1: out.append(-1)
		out.append(_total)
	return out


func _on_ui_changed() -> void:
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_TINY))
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _rebuild()
