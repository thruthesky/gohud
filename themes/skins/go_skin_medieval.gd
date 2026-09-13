## Medieval skin: iron-bound leather, engraved menu frames and quiet gameplay controls.
@tool
class_name GoSkinMedieval
extends GoSkin

@export_group("Medieval dials")
## 퀵슬롯 금속 프레임의 모서리 반경(dp).
@export var slot_radius := 4.0
## 퀵슬롯 가죽 표면 질감의 투명도.
@export var leather_grain_alpha := 0.035
## 퀵슬롯 모서리의 금속 장식 배율. 메뉴 프레임은 팔레트의 shape에서 조절한다.
@export var ornament_scale := 1.0
## 퀵슬롯 위쪽 금속 반사의 강도.
@export var bevel_strength := 0.18
## 퀵슬롯에 리벳을 표시할지(0: 없음, 1: 표시).
@export var slot_rivets := 1
@export_group("")


func floating_box(variant := GoTheme.BOX_HUD, accent := Color.TRANSPARENT) -> StyleBox:
	var frame := surface_box(variant, accent)
	if frame is GoStyleBoxMedieval:
		frame.shadow_color = Color(GoUi.color(GoTheme.SHADOW), float_shadow_alpha)
		frame.shadow_size = float_shadow_size
		frame.shadow_offset = Vector2(0, float_shadow_lift)
	return frame


func slot_box(accent: Color, lit: bool) -> StyleBox:
	var frame := GoStyleBoxMedieval.new()
	frame.bg_color = GoUi.color(GoTheme.SURFACE).lerp(accent, slot_tint_lit if lit else slot_tint_idle)
	frame.border_color = accent if lit else GoUi.color(GoTheme.BORDER)
	frame.border_width = slot_border_lit if lit else slot_border_idle
	frame.radius = slot_radius
	frame.grain_alpha = leather_grain_alpha
	frame.bevel_strength = bevel_strength
	frame.ornament_scale = ornament_scale
	frame.ornament = clampi(slot_rivets, 0, 1)
	return frame


func badge_box(ink: Color) -> StyleBox:
	var frame := super(ink)
	if frame is GoStyleBoxMedieval:
		frame.ornament = 0
		frame.grain_alpha = 0.0
	return frame


func segment_box(index: int, count: int, state: StringName) -> StyleBox:
	# Keep the shared state colours and end-cap behaviour; add restrained metal relief.
	var frame := GoStyleBoxMedieval.new()
	frame.bg_color = GoUi.color(GoTheme.ACCENT) if state in [&"pressed", &"hover_pressed"] \
		else GoUi.color(GoTheme.SURFACE_HIGH if state == &"hover" else GoTheme.SURFACE_SOFT)
	frame.border_color = GoUi.color(GoTheme.BORDER)
	frame.radius = slot_radius if index == 0 or index == count - 1 else 0.0
	frame.ornament = 0
	frame.grain_alpha = 0.0
	return frame


func section_box() -> StyleBox:
	var rule := StyleBoxFlat.new()
	rule.draw_center = false
	rule.border_color = Color(GoUi.color(GoTheme.ACCENT), 0.45)
	rule.border_width_bottom = 1
	rule.content_margin_bottom = GoUi.metric(GoTheme.GAP_SMALL)
	return rule


func draw_joystick(canvas: CanvasItem, center: Vector2, knob: Vector2, radius: float,
		knob_radius: float, ink: Color, base: Color, active: bool) -> void:
	# A simple compass ring keeps the always-visible HUD quiet.
	super(canvas, center, knob, radius, knob_radius, ink, base, active)
	canvas.draw_arc(center, radius - 4.0, 0, TAU, 48, Color(ink, joystick_ring_alpha * 0.45), 1.0, true)
	for index in 4:
		var direction := Vector2.from_angle(float(index) * PI * 0.5)
		canvas.draw_line(center + direction * (radius - 7.0), center + direction * (radius - 2.0),
			Color(ink, joystick_ring_alpha), 2.0, true)
