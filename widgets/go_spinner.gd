## ⏳ **대기 표시** — 서버에 붙는 중, 맵을 받는 중, 결제를 기다리는 중.
##
## ```gdscript
## var busy := GoSpinner.new()
## card.add_child(busy)
##
## # 버튼을 누르면 그 자리에서 도는 것으로 바꾼다 — 두 번 눌리지 않게 막아 준다
## GoSpinner.busy(buy_button, true)
## var ok := await server.purchase(item)
## GoSpinner.busy(buy_button, false)
## ```
##
## ## 🛑 "멈춘 것"과 "기다리는 것"은 다르게 보여야 한다
## 네트워크 게임에서 화면이 가만히 있으면 플레이어는 **게임이 죽었다고 읽는다.** 서버를 기다리는
## 동안은 반드시 도는 것을 보여 준다. 반대로 3초 안에 끝나는 것에 전체 화면 가림막을 씌우면
## 그것대로 굼떠 보인다 — 누른 **그 버튼 안에서** 도는 편이 빠르게 느껴진다.
##
## ## ♿ `reduce_motion` 을 켠 사람에게는 돌지 않는다
## 어지럼증(vestibular) 때문에 회전을 끈 사람에게 계속 도는 원을 보여 주면 안 된다. 그때는
## **점 세 개가 차례로 밝아지는** 표시로 바뀐다 — 여전히 "진행 중" 으로 읽히면서 회전이 없다.
##
## ## 🔑 얼마나 걸리는지 알면 막대를 쓴다
## 받은 바이트처럼 **진행률을 아는** 것은 `GoBar` 다. 이것은 "얼마나 걸릴지 모른다" 는 뜻이고,
## 그래서 끝을 약속하지 않는다.
@tool
class_name GoSpinner
extends Control

## 한 바퀴에 걸리는 시간(초).
@export var seconds_per_turn := 1.1:
	set(value):
		seconds_per_turn = maxf(0.05, value)

## 선 두께(dp). 음수면 지름의 1/9 — 작게 만들어도 비례가 유지된다.
@export var thickness := -1.0:
	set(value):
		thickness = value
		queue_redraw()

## 도는 색. 비우면 테마 강조색.
@export var ink := Color.TRANSPARENT:
	set(value):
		ink = value
		queue_redraw()

## 뒤에 깔리는 옅은 원을 그릴 것인가. 🔑 바탕이 복잡한 게임 화면 위에서는 켜 두면 잘 읽힌다.
@export var show_track := true:
	set(value):
		show_track = value
		queue_redraw()

var _phase := 0.0


func _init() -> void:
	name = "Spinner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 🛑 도는 것은 **물리적 방향**이다 — 아랍어라고 시계 반대로 돌지 않는다.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	var px := GoUi.metric(GoTheme.ICON_SIZE)
	custom_minimum_size = Vector2(px, px)


func _ready() -> void:
	# ♿ 스크린리더에게는 "불러오는 중" 한 마디면 된다 — 도는 모양은 눈으로만 읽는 정보다.
	accessibility_name = GoUi.text(&"loading")
	GoUi.watch(_on_ui_changed)
	set_process(visible and not GoUi.config.reduce_motion)


func _exit_tree() -> void:
	GoUi.unwatch(_on_ui_changed)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta / seconds_per_turn, 1.0)
	queue_redraw()


func _draw() -> void:
	var box := minf(size.x, size.y)
	if box <= 0.0: return
	var line := thickness if thickness > 0.0 else maxf(1.0, box / 9.0)
	var center := size * 0.5
	var radius := box * 0.5 - line * 0.5
	if radius <= 0.0: return
	var color := ink if ink.a > 0 else GoUi.color(GoTheme.ACCENT)

	if GoUi.config.reduce_motion:
		_draw_dots(center, box, color)
		return

	if show_track:
		draw_arc(center, radius, 0.0, TAU, 40, GoUi.color(GoTheme.TRACK), line, true)
	# 🔑 호의 길이를 함께 흔든다 — 길이가 고정이면 도는 것이 아니라 "그림이 회전할 뿐" 으로 보인다.
	#    Material 의 결정형 스피너가 쓰는 방식이고, 실제로 "일하고 있다" 는 느낌이 훨씬 강하다.
	var swing := (sin(_phase * TAU) * 0.5 + 0.5)
	var sweep := lerpf(PI * 0.25, PI * 1.35, swing)
	var start := _phase * TAU * 1.6
	draw_arc(center, radius, start, start + sweep, 48, color, line, true)


## ♿ 회전을 끈 사람에게 — 점 세 개가 차례로 밝아진다. 같은 "진행 중" 이되 도는 것이 없다.
## 🛑 시간이 아예 멈추면 "죽은 화면" 과 구별이 안 된다. 그래서 **밝기만** 흐른다.
func _draw_dots(center: Vector2, box: float, color: Color) -> void:
	var dot := maxf(1.0, box / 8.0)
	var gap := dot * 2.6
	var beat := float(Time.get_ticks_msec()) / 1000.0 / maxf(0.05, seconds_per_turn)
	for i in 3:
		var lit := 0.35 + 0.65 * (sin((beat - i * 0.18) * TAU) * 0.5 + 0.5)
		draw_circle(center + Vector2((i - 1) * gap, 0.0), dot, Color(color, color.a * lit))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# 🛑 안 보이는 동안은 돌지 않는다 — 숨긴 스피너가 매 프레임 다시 그리면 그만큼 공짜로 버린다.
		set_process(is_visible_in_tree() and not GoUi.config.reduce_motion)
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		accessibility_name = GoUi.text(&"loading")


func _on_ui_changed() -> void:
	accessibility_name = GoUi.text(&"loading")
	set_process(is_visible_in_tree() and not GoUi.config.reduce_motion)
	queue_redraw()


# ── 버튼을 대기 상태로 ──────────────────────────────────────────────────

## 이 메타 이름으로 버튼에 원래 글자와 스피너를 매달아 둔다.
const _BUSY_META := &"gohud_busy"


## 버튼을 **기다리는 중**으로 바꾼다 — 글자를 감추고 그 자리에서 스피너가 돈다. 누를 수 없다.
##
## ```gdscript
## GoSpinner.busy(buy, true)
## var ok := await server.purchase(item)
## GoSpinner.busy(buy, false)
## ```
##
## 🛑 **크기가 변하지 않는다.** 글자를 지우고 스피너로 바꾸면 버튼이 홀쭉해져 줄 전체가 출렁인다.
##    그래서 글자는 `modulate.a = 0` 으로 **자리를 지킨 채** 투명해지고, 스피너는 그 위에 겹친다
##    (2026-09-16 설계: 글자를 지우는 방식은 "구매" 두 글자 버튼이 정사각형으로 쪼그라들었다).
## 🛑 **두 번 눌리는 것을 막는 것이 이 함수의 절반이다.** 결제·거래처럼 두 번 나가면 안 되는
##    요청은 `disabled` 만으로 부족하다 — 이미 눌린 뒤 `await` 사이에 한 번 더 들어온다.
static func busy(button: Button, waiting: bool) -> void:
	if not is_instance_valid(button): return
	var carried: Dictionary = button.get_meta(_BUSY_META, {})

	if not waiting:
		if carried.is_empty(): return
		var spinner: GoSpinner = carried.get("spinner")
		if is_instance_valid(spinner): spinner.queue_free()
		button.disabled = bool(carried.get("disabled", false))
		# 🛑 감춰 두었던 글자색을 **되돌려 놓는다** — 안 지우면 그 버튼은 이후 정말로 비활성일 때도
		#    글자가 투명해서 빈 판으로 보인다.
		if bool(carried.get("had_font", false)):
			button.add_theme_color_override(&"font_disabled_color", carried["font"])
		else:
			button.remove_theme_color_override(&"font_disabled_color")
		if bool(carried.get("had_icon", false)):
			button.add_theme_color_override(&"icon_disabled_color", carried["icon"])
		else:
			button.remove_theme_color_override(&"icon_disabled_color")
		button.remove_meta(_BUSY_META)
		return

	if not carried.is_empty(): return   # 이미 기다리는 중이다 — 스피너를 두 개 얹지 않는다
	var spinner := GoSpinner.new()
	spinner.name = "BusySpinner"
	# 버튼 글자 높이에 맞춘다 — 크면 버튼 밖으로 삐져나오고, 작으면 안 보인다.
	var px := maxi(12, roundi(float(GoUi.metric(GoTheme.ICON_SIZE)) * 0.8))
	spinner.custom_minimum_size = Vector2(px, px)
	spinner.size = Vector2(px, px)
	# 🛑 앵커가 **가운데**라 `position` 은 그 점에서의 거리다. 부모 크기를 다시 더하면 버튼 밖으로
	#    나가 보이지 않는다(2026-09-16 촬영: 글자만 사라지고 도는 것이 없는 빈 버튼이 남았다).
	#    앵커로 두면 버튼 크기가 나중에 정해져도 가운데를 지킨다.
	spinner.set_anchors_preset(Control.PRESET_CENTER)
	spinner.position = -Vector2(px, px) * 0.5
	# 🔑 색은 **그 버튼의 글자색**이다 — 강조 버튼(채워진 판) 위에서 강조색 스피너는 묻힌다.
	if button.has_theme_color(&"font_color"): spinner.ink = button.get_theme_color(&"font_color")
	button.add_child(spinner)
	# 되돌릴 때 쓰려고 **원래 있던 덮어쓰기**까지 적어 둔다 — 없던 것을 지우는 것과 있던 것을
	# 되돌리는 것은 다르다.
	button.set_meta(_BUSY_META, {
		"spinner": spinner, "disabled": button.disabled,
		"had_font": button.has_theme_color_override(&"font_disabled_color"),
		"font": button.get_theme_color(&"font_disabled_color") if button.has_theme_color_override(&"font_disabled_color") else Color.WHITE,
		"had_icon": button.has_theme_color_override(&"icon_disabled_color"),
		"icon": button.get_theme_color(&"icon_disabled_color") if button.has_theme_color_override(&"icon_disabled_color") else Color.WHITE,
	})
	button.disabled = true
	# 글자만 투명하게 — 버튼 판과 크기는 그대로 둔다.
	button.add_theme_color_override(&"font_disabled_color", Color(0, 0, 0, 0))
	button.add_theme_color_override(&"icon_disabled_color", Color(0, 0, 0, 0))


## 이 버튼이 지금 기다리는 중인가.
static func is_busy(button: Button) -> bool:
	return is_instance_valid(button) and button.has_meta(_BUSY_META)
