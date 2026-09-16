## 💬 **붙어서 뜨는 작은 카드** — 아이템 정보, 스킬 설명, 스탯 비교.
##
## ```gdscript
## # 슬롯을 누르면 그 옆에 설명이 뜬다
## GoPopover.open(slot, item_card(item))
##
## # 제목을 달고, 바깥을 눌러도 닫히지 않게
## GoPopover.open(button, body, {"title": "강화 확률", "dismissable": false})
##
## # 닫힐 때까지 기다린다
## await GoPopover.open(slot, body).close_requested
## ```
##
## ## 🔑 이것이 푸는 문제는 **조립**이다
## `GoSurface` 에 이미 `Placement.ANCHOR` 가 있다. 하지만 쓰려면 층을 만들고, 표면을 만들고,
## 앵커를 물리고, 닫힐 때 치우는 것까지 매번 써야 했다 — 게임 UI 에서 가장 자주 하는 일인데
## 매번 열 줄이 든다. 여기서는 **한 줄**이다.
##
## ## 🛑 툴팁이 아니다
## 마우스를 올려 두는 동안만 뜨는 것(hover)은 **터치 기기에 없다.** 폰에는 "올려 두기" 가 없으므로
## 정보를 거기에만 두면 모바일 플레이어는 영영 못 본다. 그래서 이것은 **눌러서 열고 눌러서 닫는다.**
##
## ## 🛑 되돌릴 수 없는 조작을 여기 담지 않는다
## 바깥을 누르면 닫힌다(기본). 판매·해체 확인은 `GoDialogs.confirm()` 이다.
@tool
class_name GoPopover
extends RefCounted

## 이 층에 뜬다. HUD 보다 위, 대화상자보다 아래.
const LAYER := 95

## 지금 열려 있는 것 — **한 번에 하나**다. 새로 열면 앞의 것이 닫힌다.
static var _open: CanvasLayer


## `anchor` 옆에 `content` 를 담은 카드를 띄운다. 돌려주는 것은 그 `GoSurface` 다
## (`closed` 를 기다리거나 `request_close()` 로 닫는다).
##
## | 칸 | 뜻 | 기본 |
## |---|---|---|
## | `title` | 머리 줄 글자. 비우면 머리 줄이 없다 | `""` |
## | `translate` | 제목을 번역 키로 본다 | `false` |
## | `width` | 카드 폭(dp) | 320 |
## | `max_height` | 카드 최대 높이(dp) | 520 |
## | `dismissable` | 바깥을 눌러 닫을 수 있다 | `true` |
## | `compact` | 여백을 좁게 — 한두 줄짜리 설명에 | `false` |
## | `alpha` | 카드 바탕의 불투명도(0.0~1.0). 음수면 테마·설정 값 | `-1.0` |
##
## 🛑 **한 번에 하나만** 뜬다. 슬롯을 연달아 누르면 앞의 것이 닫히고 새것이 뜬다 —
##    쌓이면 화면이 카드로 덮이고 어느 것이 어느 슬롯의 것인지 알 수 없다.
static func open(anchor: Control, content: Control, options := {}) -> GoSurface:
	close()
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return null

	var layer := CanvasLayer.new()
	layer.name = "PopoverLayer"
	layer.layer = int(options.get("layer", LAYER))

	var surface := GoSurface.new()
	surface.placement = GoSurface.Placement.ANCHOR
	surface.anchor_control = anchor
	surface.anchor_width = float(options.get("width", surface.anchor_width))
	surface.anchor_max_height = float(options.get("max_height", surface.anchor_max_height))
	surface.fit_content = true
	surface.dismiss_on_scrim = bool(options.get("dismissable", true))
	# 🔑 가림막을 **투명하게** 둔다 — 정보를 보려고 연 카드 때문에 게임 화면이 어두워지면
	#    비교하려던 그 화면이 안 보인다. 바깥 탭을 받는 역할만 남긴다.
	surface.scrim_transparent = true
	surface.compact = bool(options.get("compact", false))
	# 🔑 정보를 **비교하려고** 연 카드다 — 뒤 화면이 보여야 할 때가 많아 창마다 정할 수 있게 둔다.
	surface.alpha = float(options.get("alpha", -1.0))
	var title := str(options.get("title", ""))
	surface.show_header = not title.is_empty()

	layer.add_child(surface)
	# 🛑 앵커와 **같은 트리**에 붙인다 — 창이 여러 개인 게임(별도 채팅 창)에서 다른 창에 붙이면
	#    좌표가 어긋나 카드가 엉뚱한 자리에 뜬다.
	anchor.get_tree().root.add_child(layer)
	_open = layer

	if not title.is_empty():
		if bool(options.get("translate", false)): surface.set_title_key(title)
		else: surface.set_title(title)
	if is_instance_valid(content): surface.body.add_child(content)

	# 🔑 닫는 길은 둘인데 하는 일은 하나다 — 같은 것을 두 번 쓰면 한쪽만 고치는 실수가 난다.
	var dispose := func() -> void:
		if is_instance_valid(layer): layer.queue_free()
		if _open == layer: _open = null
	surface.close_requested.connect(dispose, CONNECT_ONE_SHOT)
	# 앵커가 사라지면(아이템을 버렸다) 카드도 함께 사라진다 — 없는 것의 설명이 남지 않게.
	anchor.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	surface.visible = true
	surface.relayout()
	GoFeedback.opened()
	return surface


## 열려 있으면 닫는다.
static func close() -> void:
	if is_instance_valid(_open): _open.queue_free()
	_open = null


static func is_open() -> bool:
	return is_instance_valid(_open)
