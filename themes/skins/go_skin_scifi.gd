## 🛸 **sci-fi 모양.** 둥근 것을 각지게, 원을 육각과 다이아몬드로, 링을 조준 표식으로 바꾼다.
##
## ## 무엇을 덮어쓰는가
## 테마(`gohud_scifi_*.tres`)가 이미 버튼·카드·입력칸을 각진 판으로 바꿔 놓았다. 그런데 **코드가
## 직접 그리는 자리**는 테마가 닿지 못한다 — 조이스틱의 원, 퀵슬롯의 판, 코치마크의 링, 칩·
## 스켈레톤·아바타. 그 자리만 여기서 다시 그린다. 덮어쓰지 않은 것은 `GoSkin` 의 기본 모양이 남는다.
##
## 🛑 `GoSkin` 의 기본 구현은 테마가 준 커스텀 StyleBox 를 **그대로 통과시킨다.** 그래서
##    `surface_box()` 같은 것은 덮어쓸 필요가 없다 — 각진 판이 이미 그대로 온다.
@tool
class_name GoSkinSciFi
extends GoSkin

# ── sci-fi 다이얼 — 스킨 리소스(.tres)에서 숫자만 바꾼다 ───────────────
# 🛑 기본값을 바꾸면 `tools/skin_dials.json` 도 같이 바꾼다 — 검사가 둘을 대조한다.
@export_group("Sci-fi dials")
# 🔑 다이얼마다 `##` 한 줄 — 사이트 생성기가 이 줄로 다이얼 표와 용어 사전을 채운다.
## 칩 판의 잘린 모서리 크기(dp).
@export var cut_chip := 7.0
## 스켈레톤 판의 잘린 모서리 크기(dp).
@export var cut_skeleton := 5.0
## 알림 상자 판의 잘린 모서리 크기(dp).
@export var cut_alert := 8.0
## 분절 선택 판의 잘린 모서리 크기(dp).
@export var cut_segment := 8.0
## 퀵슬롯 판의 잘린 모서리 크기(dp).
@export var cut_slot := 6.0
## 아바타·디스크의 잘린 모서리 = 지름 × 이 비율.
@export var cut_disc_ratio := 0.24
## 쿨다운이 도는 슬롯의 발광 투명도.
@export var slot_glow_alpha := 0.45
## 쿨다운이 도는 슬롯의 발광 거리(dp).
@export var slot_glow_size := 6.0
## 코치마크 조준 표식의 팔 길이(dp).
@export var bracket_arm := 12.0
## 코치마크 조준 표식의 선 두께(dp).
@export var bracket_thickness := 2.0
@export_group("")


# ── 표면 ───────────────────────────────────────────────────────────────

## 강조색을 줄 때 테두리뿐 아니라 **강조 변**까지 그 색으로 — 각진 판의 정체성이 그 한 줄이다.
func surface_box(variant := GoTheme.BOX_CARD, accent := Color.TRANSPARENT) -> StyleBox:
	var style := super(variant, accent)
	var cut := style as GoStyleBoxCut
	if cut != null and accent.a > 0 and cut.edge_color.a > 0:
		cut.edge_color = Color(accent, cut.edge_color.a)
	return style


## 알약 대신 **한쪽으로 기운 조각**. 네 모서리 중 둘만 잘라 방향이 생긴다.
func chip_box(color: Color) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = Color(color, chip_fill_alpha)
	box.border_color = Color(color, chip_edge_alpha)
	box.border_width = 1.0
	box.cut = cut_chip
	box.cut_corners = GoStyleBoxCut.DIAGONAL
	box.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	box.content_margin_right = GoUi.metric(GoTheme.GAP_SMALL)
	box.content_margin_top = GoUi.metric(GoTheme.GAP_TINY)
	box.content_margin_bottom = GoUi.metric(GoTheme.GAP_TINY)
	return box


func skeleton_box() -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	box.border_color = Color(GoUi.color(GoTheme.ACCENT), 0.22)
	box.border_width = 1.0
	box.cut = cut_skeleton
	return box


## 원 대신 각진 배지 — 아바타·프롬프트 카드의 아이콘 자리에 쓰인다.
func disc_box(diameter: float, accent: Color, fill_alpha := 0.14, edge_alpha := 0.38) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = Color(accent, fill_alpha)
	box.border_color = Color(accent, edge_alpha)
	box.border_width = 1.0
	box.cut = maxf(2.0, diameter * cut_disc_ratio)
	box.cut_corners = GoStyleBoxCut.ALL
	return box


## 왼쪽에 굵은 띠를 세운 안내 상자 — 목록 속에서 눈이 먼저 그 띠를 잡는다.
func alert_box(ink: Color) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE).lerp(ink, 0.12)
	box.border_color = Color(ink, 0.5)
	box.border_width = 1.0
	box.cut = cut_alert
	box.edge_color = ink
	box.edge_width = 3.0
	box.edge_side = SIDE_LEFT
	box.set_content_margin_all(GoUi.metric(GoTheme.GAP))
	return box


## 분절 선택 — 양 끝만 자르고 가운데는 각진 채로 이어 붙인다.
func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	var box := GoStyleBoxCut.new()
	var accent := GoUi.color(GoTheme.ACCENT)
	if state == &"pressed" or state == &"hover_pressed":
		box.bg_color = accent
	elif state == &"hover":
		box.bg_color = GoUi.color(GoTheme.SURFACE_HIGH)
	else:
		box.bg_color = GoUi.color(GoTheme.SURFACE_SOFT)
	box.border_color = Color(GoUi.color(GoTheme.BORDER), 0.9)
	box.border_width = 0.0 if index > 0 else 1.0
	box.cut = cut_segment
	var mask := 0
	if index == 0: mask |= GoStyleBoxCut.TOP_LEFT | GoStyleBoxCut.BOTTOM_LEFT
	if index == count - 1: mask |= GoStyleBoxCut.TOP_RIGHT | GoStyleBoxCut.BOTTOM_RIGHT
	box.cut_corners = mask
	return box


## 섹션 머리말 왼쪽에 강조 막대 — 화면이 구획으로 나뉘어 읽힌다.
func section_box() -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.draw_center = false
	box.border_width = 0.0
	box.cut = 0.0
	box.edge_color = GoUi.color(GoTheme.ACCENT)
	box.edge_width = 3.0
	box.edge_side = SIDE_LEFT
	box.content_margin_left = GoUi.metric(GoTheme.GAP_SMALL)
	return box


## 구분선을 강조색 선으로 — 화면을 구획하는 계기판의 선처럼 읽힌다.
func divider_color() -> Color:
	return Color(GoUi.color(GoTheme.ACCENT), 0.55)


# ── HUD ────────────────────────────────────────────────────────────────

## 퀵슬롯 — 각진 판에 위쪽 계기 선. 쿨다운이 돌면 발광이 붙는다.
func slot_box(accent: Color, lit: bool) -> StyleBox:
	var box := GoStyleBoxCut.new()
	box.bg_color = GoUi.color(GoTheme.SURFACE).lerp(Color(accent, 0.8), slot_tint_lit if lit else slot_tint_idle)
	box.border_color = Color(accent, 0.95 if lit else 0.5)
	box.border_width = 2.0 if lit else 1.0
	box.cut = cut_slot
	box.edge_color = Color(accent, 0.9 if lit else 0.45)
	box.edge_width = 2.0
	box.edge_side = SIDE_TOP
	# 🛑 발광은 켜졌을 때만 — 슬롯은 화면에 여러 개가 깔리므로 늘 켜 두면 그리기 비용이 그만큼 곱해진다.
	if lit:
		box.glow_color = Color(accent, slot_glow_alpha)
		box.glow_size = slot_glow_size
	return box


## 코치마크가 대상에 두르는 표식 — 테두리를 두르지 않고 **네 모서리만** 찍는다.
func coach_ring_box(accent: Color) -> StyleBox:
	var mark := GoStyleBoxBracket.new()
	mark.color = accent
	mark.arm = bracket_arm
	mark.thickness = bracket_thickness
	mark.bg_color = Color(accent, 0.06)
	return mark


# ── 직접 그리기 ─────────────────────────────────────────────────────────

## 조이스틱 — 육각 링 + 여덟 방향 눈금 + 다이아몬드 손잡이 + 중심 십자.
func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	var ring := _hexagon(center, radius)
	canvas.draw_colored_polygon(ring, Color(base, 0.40))
	var loop := ring.duplicate()
	loop.append(ring[0])
	canvas.draw_polyline(loop, Color(ink, 0.5), 2.0, true)
	# 여덟 방향 눈금 — 어느 쪽으로 밀고 있는지 눈금이 있어야 읽힌다.
	for step in 8:
		var heading := Vector2.RIGHT.rotated(TAU * float(step) / 8.0)
		canvas.draw_line(center + heading * (radius - 9.0), center + heading * (radius - 3.0),
			Color(ink, 0.30), 1.5, true)
	canvas.draw_colored_polygon(_diamond(knob, knob_radius), Color(ink, 0.85 if active else 0.5))
	canvas.draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color(ink, 0.55), 1.0, true)
	canvas.draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color(ink, 0.55), 1.0, true)


## 코치마크의 화살표 — 이어진 선 대신 점선. 계기판의 지시선처럼 보인다.
func draw_coach_pointer(canvas: CanvasItem, start: Vector2, tip: Vector2,
		direction: Vector2, ink: Color) -> void:
	var span := start.distance_to(tip)
	var dashes := clampi(int(span / 7.0), 1, 64)
	for step in dashes:
		# 🛑 한 칸 걸러 하나만 긋는다 — 전부 그으면 그냥 실선이다.
		if step % 2 == 1: continue
		var from := start.lerp(tip, float(step) / float(dashes))
		var to := start.lerp(tip, minf(float(step + 1) / float(dashes), 1.0))
		canvas.draw_line(from, to, Color(ink, 0.9), 2.0, true)
	var wing := direction.orthogonal() * 5.0
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, tip - direction * 9.0 + wing, tip - direction * 9.0 - wing]), ink)


# ── 도형 ───────────────────────────────────────────────────────────────

func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for step in 6:
		out.append(center + Vector2.RIGHT.rotated(TAU * float(step) / 6.0) * radius)
	return out


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)])
