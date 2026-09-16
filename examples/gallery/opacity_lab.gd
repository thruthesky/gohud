## 🔬 **판 불투명도 실험실** — 슬라이더를 끌면 **그 자리에서** 판이 묽어진다.
##
## ## 왜 이것이 있는가
## `bg_color.a == 0.8` 은 숫자다. "뒤가 실제로 보이는가", "그 위의 글자가 아직 읽히는가" 는
## **그려 봐야** 안다 — 판 불투명도는 그 두 가지가 전부인 기능이다. 그래서 판 뒤에 눈에 띄는
## 무늬를 깔고, 값을 손으로 만지며 두 가지를 동시에 본다. 문서의 설명 열 줄보다 슬라이더 한 번
## 끄는 것이 빠르다.
##
## ## 네 가지 길을 나란히
## 판을 반투명하게 만드는 길이 넷이고, 이 한 화면에 그 넷이 모두 있다.
##
## | 판 | 길 | 쓰는 자리 |
## |---|---|---|
## | ① 카드 | `GoStyle.card(…, alpha)` | 만들 때 인자로 준다 — **판 하나만** 다르게 |
## | ② HUD 도크 | `GoStyle.style_hud_panel(node, …, alpha)` | **이미 만든 노드**에 판을 다시 입힌다 |
## | ③ 맨 `PanelContainer` | `GoStyle.fade_panel(node, alpha)` | gohud 가 만들지 **않은** 판에 덮는다 |
## | ④ 전부 | `GoUi.config.container_alpha` | 프로젝트 전체 — 아래 버튼이 이것을 심는다 |
##
## ## 쓰는 법
## ```gdscript
## var lab := preload("res://addons/gohud/examples/gallery/opacity_lab.gd").new()
## page.add_child(lab)
## # ④ 를 쓰려면 호스트가 화면을 다시 지어야 한다 — 이미 태어난 위젯은 스스로 옷을 갈지 않는다.
## lab.applied.connect(func(_alpha: float) -> void: rebuild())
## # 뒤에 무늬를 깔아 달라는 요청(선택) — 연결하지 않으면 그 토글이 나오지 않는다.
## lab.backdrop_wanted.connect(func(on: bool) -> void: my_background.visible = not on)
## ```
##
## 🛑 애드온의 전역 클래스를 늘리지 않는다(`class_name` 없음) — 예제의 이름이 호스트 프로젝트로
##    새어 나가지 않게 `preload` 로만 쓴다.
extends VBoxContainer

## ④ "모든 판에 적용" 을 눌렀다 — 호스트가 화면을 다시 지어야 한다.
signal applied(alpha: float)
## 뒤에 무늬를 깔아 달라 / 걷어 달라. 🔑 **연결한 호스트에서만** 그 토글이 보인다.
signal backdrop_wanted(on: bool)

## 🔑 **프로젝트 전체에 적용하는 버튼을 보일 것인가.** sim 투어처럼 장면 하나만 보여 주는 자리에서는
## 끈다 — 프로젝트 설정은 전역이라 장면을 떠난 뒤에도 남아, 다음 장면의 판까지 묽게 만든다.
## 🛑 `add_child()` **전에** 정한다(`_ready` 에서 읽는다).
var allow_project_wide := true

## 슬라이더가 내려갈 수 있는 바닥. 🛑 0 까지 열어 두지 않는다 — 판이 아예 사라지면 무엇을 만지는지
## 알 수 없고, 그 상태를 "설정" 으로 착각한 사람이 판을 잃은 채 다음 화면으로 간다.
const FLOOR := 0.15

var _slider: HSlider
var _readout: Label
var _card: PanelContainer            ## ① 팩토리 인자
var _hud: PanelContainer             ## ② 이미 만든 노드에 다시 입히기
var _plain: PanelContainer           ## ③ gohud 가 만들지 않은 판
var _backdrop: Control


func _init() -> void:
	name = "OpacityLab"
	add_theme_constant_override(&"separation", GoUi.metric(GoTheme.GAP_SMALL))


func _ready() -> void:
	add_child(GoStyle.section("Container opacity", false))
	add_child(GoStyle.label(
		"Panels can let the game show through. Only the panel fill thins out — text, icons, borders "
		+ "and buttons stay at full strength, so the screen keeps reading as a screen.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))

	add_child(_dial())
	add_child(_preview())
	add_child(_actions())
	add_child(GoStyle.label(
		"Defaults live in the theme (panel_alpha, card_alpha, hud_alpha, notice_alpha, popup_alpha), "
		+ "a project overrides them in GoConfig, and a single widget can always set its own alpha.",
		GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	# 🛑 판을 입히는 것은 **트리에 붙은 뒤**다 — ③ 은 부모에서 물려받은 테마에서 판을 읽는다.
	_apply(_slider.value)


# ── 다이얼 ─────────────────────────────────────────────────────────────

func _dial() -> Control:
	var row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var caption := GoStyle.label("Panel fill", GoTheme.ROLE_COMPACT)
	GoStyle.natural_width(caption)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)

	_slider = GoStyle.slider(FLOOR, 1.0, 0.01)
	_slider.value = GoUi.surface_alpha(GoTheme.BOX_CARD)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.accessibility_name = "Panel opacity"
	_slider.value_changed.connect(_apply)
	row.add_child(_slider)

	_readout = GoStyle.label("", GoTheme.ROLE_COMPACT)
	# 🛑 값에 따라 폭이 흔들리면 그 옆의 슬라이더가 함께 움직인다 — 끄는 중에 손이 미끄러진다.
	_readout.custom_minimum_size.x = 48.0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_readout)
	return row


# ── 미리보기 ───────────────────────────────────────────────────────────

## 무늬 위에 판 셋을 얹는다. 🔑 **단색 배경이면 안 된다** — 판이 "조금 다른 색" 이 된 것과
## "뒤가 비치는 것" 이 구별되지 않는다.
func _preview() -> Control:
	var frame := Control.new()
	frame.name = "Preview"
	frame.clip_contents = true
	# 🛑 `Control` 은 자식의 크기를 모른다 — 고정 높이를 박으면 판 아래로 무늬만 남은 빈 띠가 생긴다
	#    (첫 촬영에서 200px 가 그렇게 남았다). 내용의 최소 높이를 그대로 따라간다.
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_backdrop)

	var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(inset)
	var row := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	inset.add_child(row)
	var fit := func() -> void: frame.custom_minimum_size.y = inset.get_combined_minimum_size().y
	inset.minimum_size_changed.connect(fit)
	# 🛑 첫 높이는 **다음 프레임에** 잡는다 — 지금은 자식들이 아직 자기 최소 크기를 모른다.
	fit.call_deferred()

	_card = GoStyle.card()
	_fill(_card, "GoStyle.card()", "alpha argument")
	row.add_child(_card)

	_hud = GoStyle.hud_panel()
	_fill(_hud, "GoStyle.hud_panel()", "restyled in place")
	row.add_child(_hud)

	# ③ 🔑 **애드온이 만들지 않은 판.** 씬에 그려 둔 `PanelContainer`·호스트가 손으로 만든 판이
	#    이것이고, 테마의 꽉 찬 `PanelContainer/panel` 을 그대로 쓴다.
	# 🛑 그 판은 **여백이 0** 이다(`panel_solid`) — 애드온의 판들과 달리 글자가 테두리에 붙는다.
	#    여기서만 여백 칸을 두른다(카드·HUD 판에 그러면 여백이 두 겹이 된다).
	_plain = PanelContainer.new()
	_plain.name = "PlainPanel"
	_fill(_plain, "PanelContainer", "GoStyle.fade_panel()", true)
	row.add_child(_plain)
	return frame


## 판 한 장에 이름과 한 줄 설명을 담는다 — 뒤가 비치는 것과 글자가 읽히는 것을 한자리에서 본다.
## [param pad] 는 **판 자체가 여백을 갖지 않을 때만** 켠다(위 ③ 주석).
func _fill(panel: PanelContainer, title: String, note: String, pad := false) -> void:
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	# 🛑 gohud 의 판은 이미 여백을 가졌다 — 거기에 `padding()` 칸을 또 두르면 여백이 두 겹이 된다.
	if pad:
		var inset := GoStyle.padding(GoUi.metric(GoTheme.PADDING_COMPACT))
		panel.add_child(inset)
		inset.add_child(body)
	else:
		panel.add_child(body)
	var name_label := GoStyle.label(title, GoTheme.ROLE_BUTTON)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(name_label)
	var note_label := GoStyle.label(note, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	note_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(note_label)


# ── 버튼 줄 ────────────────────────────────────────────────────────────

func _actions() -> Control:
	var row := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
	if allow_project_wide:
		row.add_child(GoStyle.button("Apply to every panel", _apply_to_project, GoStyle.Tone.PRIMARY))
		row.add_child(GoStyle.button("Back to the theme value", _reset_to_theme, GoStyle.Tone.COMPACT))
	# 🔑 호스트가 배경을 갈아 줄 수 있을 때만 이 토글을 보인다 — 아무 일도 하지 않는 스위치를
	#    화면에 두지 않는다.
	if backdrop_wanted.get_connections().size() > 0:
		var busy := GoStyle.toggle("Busy background", false)
		GoStyle.font_role(busy, GoTheme.ROLE_COMPACT)
		busy.toggled.connect(func(on: bool) -> void: backdrop_wanted.emit(on))
		row.add_child(busy)
	return row


## ④ 프로젝트 전체를 이 값으로. 🛑 **이미 태어난 위젯은 스스로 옷을 갈지 않는다** — 화면을 다시
##    지어야 보인다. 그 일은 화면을 가진 호스트가 한다(시그널).
func _apply_to_project() -> void:
	GoUi.config.container_alpha = _slider.value
	GoUi.refresh()
	applied.emit(_slider.value)


func _reset_to_theme() -> void:
	GoUi.config.container_alpha = -1.0
	GoUi.refresh()
	_slider.set_value_no_signal(GoUi.surface_alpha(GoTheme.BOX_CARD))
	_apply(_slider.value)
	applied.emit(-1.0)


# ── 바깥에서 들여다보는 창 ─────────────────────────────────────────────

## 투어·검사가 끌 슬라이더.
func dial() -> HSlider:
	return _slider


## 🔑 미리보기 카드가 **지금 실제로** 얼마나 불투명한가. 슬라이더 값이 아니라 **판에 박힌 값**을
## 읽는다 — 값이 판까지 도달했는지는 그것만이 증명한다(손잡이만 움직이고 판은 그대로인 버그가
## 정확히 이 지점에서 숨는다).
func fill_alpha() -> float:
	if _card == null: return -1.0
	var face := _card.get_theme_stylebox(&"panel")
	if face == null or not (&"bg_color" in face): return -1.0
	var fill: Color = face.get(&"bg_color")
	return fill.a


# ── 값을 판에 입힌다 ───────────────────────────────────────────────────

## 🔑 세 판이 **저마다 다른 길**로 같은 값을 받는다. 어느 길이든 결과가 같아야 한다 — 다르면
##    그 길 하나가 빠진 것이다(각진 판·중세 판에서 실제로 그런 일이 있었다).
func _apply(alpha: float) -> void:
	_readout.text = "%d%%" % roundi(alpha * 100.0)
	# ① 판을 만들 때 주는 값과 같은 것을 다시 입힌다(`GoStyle.card(…, alpha)` 와 같은 판이 나온다).
	GoStyle.style_panel(_card, GoStyle.surface(GoTheme.BOX_CARD, Color.TRANSPARENT, alpha))
	# ② 떠 있는 HUD 판 — 그림자·테두리까지 스킨이 정한 그대로 두고 바탕만 묽어진다.
	GoStyle.style_hud_panel(_hud, Color.TRANSPARENT, -1.0, -1.0, GoTheme.BOX_HUD, alpha)
	# ③ 남의 판에 덮어씌운다. 🔑 여러 번 불러도 한 번만 묽어진다(원래 판을 메타에 적어 둔다).
	GoStyle.fade_panel(_plain, alpha, &"panel", GoTheme.BOX_PANEL)


# ── 뒤에 깔 무늬 ───────────────────────────────────────────────────────

## 굵은 사선 띠. 🛑 `ColorRect` 를 돌려 여러 장 쌓지 않고 한 노드가 직접 그린다 — 미리보기 칸
## 하나에 노드 스무 개를 만들 이유가 없고, 크기가 바뀔 때 자리를 다시 잡을 일도 없다.
class Backdrop extends Control:
	const BANDS: Array[Color] = [Color("#1f7a4d"), Color("#b8481f"), Color("#2a55a8"), Color("#a89620")]
	const BAND_WIDTH := 30.0

	## 🛑 **세기를 반드시 낮춰서 쓰는 자리가 있다.** 미리보기 칸 안에서는 1.0 이 맞다 — 판이
	## 무엇을 통과시키는지 정확히 보려면 뒤가 선명해야 한다. 그러나 이것을 **화면 전체**에 깔면
	## 판 밖에 놓인 본문 글자가 무늬와 싸워 한 줄도 읽히지 않는다(첫 촬영에서 그랬다). 실제 게임의
	## 배경도 UI 글자를 죽일 만큼 강렬하지 않다 — 그래서 화면용은 0.3 쯤으로 깔고 쓴다.
	var intensity := 1.0:
		set(value):
			intensity = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		name = "Backdrop"
		# 🛑 입력을 받지 않는다 — 미리보기 뒤의 무늬가 그 위 판의 누름을 가로채면 안 된다.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var step := BAND_WIDTH * 1.55
		var index := 0
		# 🔑 대각선이므로 화면 왼쪽 밖(`-size.y`)에서 시작해야 왼쪽 위 구석이 비지 않는다.
		var offset := -size.y
		while offset < size.x + step:
			draw_line(Vector2(offset, 0.0), Vector2(offset + size.y, size.y),
				Color(BANDS[index % BANDS.size()], intensity), BAND_WIDTH)
			offset += step
			index += 1
