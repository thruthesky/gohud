## 🖼️ **gohud 갤러리** — 서버도 게임도 없이 모든 위젯을 한 화면에서 열어 본다.
##
## 이 파일은 예제이자 **살아 있는 검사**다. 위젯을 고치고 이것을 띄우면 그 자리에서 보인다.
##
## ```
## godot res://addons/gohud/examples/gallery/gallery.tscn
## ```
##
## 🛑 프로젝트의 오토로드·서버·계정에 의존하지 않는다 — 빈 프로젝트에 애드온만 넣어도 열려야
##    한다. 그것이 이 예제의 존재 이유다.
extends Control

var _sheet: GoSheet
var _dialogs: GoDialogs
var _notice: GoNotice
var _prompt: GoPromptCard
var _joystick: GoJoystick
var _hp: GoBar
var _slots: Array[GoSlot] = []
var _log: Label
var _dark := true
var _tour: GoCoachMark


func _ready() -> void:
	name = "Gallery"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_build_page()
	_build_hud()

	_dialogs = GoDialogs.new()
	add_child(_dialogs)
	_sheet = GoSheet.new()
	add_child(_sheet)


# ── 스크롤되는 본문 ────────────────────────────────────────────────────

func _build_page() -> void:
	var form := GoForm.new()
	form.name = "Form"
	add_child(form)
	# 🛑 **떠 있는 HUD 자리를 비운다.** 그대로 두면 스크롤 내용이 퀵슬롯 뒤로 흘러 글자가 슬롯
	#    사이 틈으로 삐져나온다 — RTL 에서 입력칸 글자가 오른쪽으로 가며 실제로 그랬다
	#    (2026-09-13 아랍어 스크린샷 실측). 폼이 `GoHudAnchor` 들의 자리를 알아서 피한다.
	form.avoid_hud = true

	var scroll := GoScroll.new()
	scroll.name = "Scroll"
	form.add_child(scroll)

	var page := GoStyle.column()
	page.name = "Page"
	scroll.add_child(page)

	page.add_child(GoStyle.label("gohud", GoTheme.ROLE_TITLE))
	page.add_child(GoStyle.label("Customizable HUD & UI kit — every widget below is themeable and icon-swappable.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))

	_log = GoStyle.label("", GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.SUCCESS))
	_log.name = "Log"
	page.add_child(_log)

	# 버튼 종류
	page.add_child(GoStyle.section("Buttons", false))
	var buttons := GoStyle.wrap_row()
	buttons.add_child(GoStyle.button("Primary", _say.bind("primary"), GoStyle.Tone.PRIMARY))
	buttons.add_child(GoStyle.button("Normal", _say.bind("normal")))
	buttons.add_child(GoStyle.button("Danger", _say.bind("danger"), GoStyle.Tone.DANGER))
	buttons.add_child(GoStyle.button("Compact", _say.bind("compact"), GoStyle.Tone.COMPACT))
	buttons.add_child(GoStyle.button("Bare", _say.bind("bare"), GoStyle.Tone.BARE))
	var disabled := GoStyle.button("Disabled")
	disabled.disabled = true
	buttons.add_child(disabled)
	page.add_child(buttons)

	var icon_row := GoStyle.wrap_row()
	# ♿ **아이콘 버튼에는 설명을 단다.** 글자가 없으므로 마우스 사용자에게는 툴팁이, 화면 낭독기에게는
	#    접근성 이름이 유일한 설명이다 — 둘 다 `tooltip_key` 하나에서 나온다.
	for icon in [GoIconSet.SETTINGS, GoIconSet.SEARCH, GoIconSet.HEART, GoIconSet.BELL, GoIconSet.TRASH]:
		icon_row.add_child(GoStyle.icon_button(icon, _say.bind(String(icon)), -1, StringName(icon)))
	page.add_child(icon_row)

	# 목록 항목
	page.add_child(GoStyle.section("List rows", false))
	var list := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	list.add_child(GoStyle.list_button(GoIconSet.USER, "Profile", _say.bind("profile"),
		Color.TRANSPARENT, "Name, avatar and title", false))
	list.add_child(GoStyle.list_button(GoIconSet.VOLUME_HIGH, "Sound", _say.bind("sound"),
		Color.TRANSPARENT, "", false))
	list.add_child(GoStyle.list_button(GoIconSet.DISPLAY, "Display", _say.bind("display"),
		Color.TRANSPARENT, "", false))
	list.add_child(GoStyle.divider())
	list.add_child(GoStyle.list_button(GoIconSet.LOGOUT, "Sign out", _say.bind("sign out"),
		GoUi.color(GoTheme.DANGER), "", false))
	page.add_child(list)

	# 입력
	page.add_child(GoStyle.section("Inputs", false))
	page.add_child(GoStyle.line_edit("Type here…"))
	var toggle := GoStyle.toggle("Enable haptics", false)
	toggle.button_pressed = true
	page.add_child(toggle)
	page.add_child(GoStyle.checkbox("Remember me", false))
	var volume := GoStyle.slider(0.0, 1.0, 0.01)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 팩토리는 폭을 정하지 않는다
	volume.value = 0.7
	page.add_child(volume)
	var picker := GoStyle.picker()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["Low", "Medium", "High"]: picker.add_item(option)
	page.add_child(picker)

	# 표면
	page.add_child(GoStyle.section("Surfaces", false))
	var surfaces := GoStyle.wrap_row()
	surfaces.add_child(GoStyle.button("Dialog", _open_dialog, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Alert", _open_alert, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Sheet", _open_sheet, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Popup", _open_popup, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Notice", _show_notice, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Prompt card", _show_prompt, GoStyle.Tone.COMPACT))
	surfaces.add_child(GoStyle.button("Coach tour", _start_tour, GoStyle.Tone.COMPACT))
	page.add_child(surfaces)

	# 접이식 섹션 — Godot 4.5+ FoldableContainer. 같은 FoldableGroup 이라 한 번에 하나만 펼쳐진다.
	page.add_child(GoStyle.section("Foldable sections", false))
	var accordion := FoldableGroup.new()
	for title in ["Graphics", "Audio", "Controls"]:
		var fold := GoStyle.foldable(title, title != "Graphics", accordion, false)
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
		inner.add_child(GoStyle.label("%s options live here." % title, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
		inner.add_child(GoStyle.toggle("Enable %s tweaks" % title.to_lower(), false))
		fold.add_child(inner)
		page.add_child(fold)

	# 칩·빈 상태
	page.add_child(GoStyle.section("Chips", false))
	var chips := GoStyle.wrap_row()
	chips.add_child(GoStyle.chip("default"))
	chips.add_child(GoStyle.chip("success", GoUi.color(GoTheme.SUCCESS)))
	chips.add_child(GoStyle.chip("warning", GoUi.color(GoTheme.WARNING)))
	chips.add_child(GoStyle.chip("danger", GoUi.color(GoTheme.DANGER)))
	page.add_child(chips)

	# 반응형 격자 — 창을 좁히면 열이 줄어든다
	page.add_child(GoStyle.section("Responsive grid (resize the window)", false))
	var grid := GoStyle.responsive_grid(150.0)
	for i in 6:
		var tile := GoStyle.card()
		var inner := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
		inner.add_child(GoStyle.label("Item %d" % (i + 1)))
		inner.add_child(GoStyle.label("subtitle", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
		tile.add_child(inner)
		grid.add_child(tile)
	page.add_child(grid)

	# 아이콘 세트 전체
	page.add_child(GoStyle.section("Icon set — swap it in GoConfig.icons", false))
	var icons := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP))
	for icon in GoUi.icons().icon_names():
		icons.add_child(GoUi.icons().node(StringName(icon), 22, GoUi.color(GoTheme.SECONDARY)))
	page.add_child(icons)

	# 생김새 고르기 — 색뿐 아니라 **모양**까지 통째로 바뀐다(테마 + 스킨).
	page.add_child(GoStyle.section("Theme preset", false))
	var presets := GoThemePresets.all()
	var names: Array = []
	var current := 0
	for index in presets.size():
		names.append(presets[index].label())
		if presets[index].id == GoUi.config.preset: current = index
	var preset_picker := GoStyle.select(names, "", false)
	preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_picker.selected = current
	preset_picker.item_selected.connect(_pick_preset)
	page.add_child(preset_picker)
	page.add_child(GoStyle.label(
		"Presets swap the theme (colours, engine controls) and the skin (joystick, slots, coach mark) together.",
		GoTheme.ROLE_COMPACT, GoUi.color(GoTheme.MUTED)))
	page.add_child(GoStyle.button("Toggle light / dark", _toggle_theme, GoStyle.Tone.COMPACT))
	page.add_child(GoStyle.empty_state(GoIconSet.BOX, "Nothing here yet", false))


# ── 화면에 떠 있는 HUD ─────────────────────────────────────────────────

func _build_hud() -> void:
	var top := GoHudAnchor.new()
	top.name = "TopLeft"
	top.spot = GoHudAnchor.Spot.TOP_RIGHT
	add_child(top)
	# 🛑 **떠 있는 HUD 는 판 위에 올린다.** 배경 없이 두면 스크롤 본문이 그 뒤를 지나가면서
	#    글자끼리 뒤섞여 둘 다 못 읽는다 — 세로에서 입력칸 자리표시자가, 가로에서 토글 손잡이가
	#    체력바 위에 그대로 얹혔다(2026-09-13 실측). `hud` 판은 표면색 82% 라 뒤를 가린다.
	var bars_panel := PanelContainer.new()
	bars_panel.name = "Bars"
	bars_panel.add_theme_stylebox_override(&"panel", GoStyle.floating(GoTheme.BOX_HUD))
	top.add_child(bars_panel)
	var bars := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	bars.custom_minimum_size.x = 180
	_hp = GoBar.new()
	_hp.label_text = "HP"
	_hp.ink = GoUi.color(GoTheme.DANGER_FILL)
	bars.add_child(_hp)
	var mp := GoBar.new()
	mp.label_text = "MP"
	mp.ink = GoUi.color(GoTheme.INFO_FILL)
	bars.add_child(mp)
	var xp := GoBar.new()
	xp.label_text = "XP"
	xp.readout = GoBar.Readout.PERCENT
	xp.ink = GoUi.color(GoTheme.WARNING_FILL)
	bars.add_child(xp)
	bars_panel.add_child(bars)
	_hp.set_values(320, 500, false)
	mp.set_values(88, 120, false)
	xp.set_values(64, 100, false)

	var slots_anchor := GoHudAnchor.new()
	slots_anchor.name = "Slots"
	slots_anchor.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	add_child(slots_anchor)
	var slot_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	slot_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	for spec in [
		{"icon": GoIconSet.POTION, "color": GoTheme.DANGER, "count": 12, "key": "1"},
		{"icon": GoIconSet.BOLT, "color": GoTheme.WARNING, "count": 3, "key": "2"},
		{"icon": GoIconSet.SHIELD, "color": GoTheme.INFO, "count": 0, "key": "3"},
		{"icon": GoIconSet.SWORD, "color": GoTheme.SUCCESS, "count": GoSlot.NONE, "key": "4"},
	]:
		var slot := GoSlot.new()
		slot.icon_name = spec.icon
		slot.accent = GoUi.color(spec.color)
		slot.quantity = spec.count
		slot.shortcut_label = spec.key
		slot.pressed.connect(_use_slot.bind(slot))
		slot_row.add_child(slot)
		_slots.append(slot)
	slots_anchor.add_child(slot_row)
	# 촘촘히 놓인 슬롯끼리 넓힌 터치 영역을 나눠 갖게 알려 준다.
	var peers: Array[Control] = []
	for slot in _slots: peers.append(slot)
	for slot in _slots: slot.touch_peers = peers

	var pad := GoHudAnchor.new()
	pad.name = "Joystick"
	pad.spot = GoHudAnchor.Spot.BOTTOM_LEFT
	# 🛑 조이스틱은 손을 얹은 동안에만 나타난다 — 본문에서 자리를 비워 두면 보이지도 않는 칸이
	#    화면 아래 한 줄을 통째로 깎는다.
	pad.reserve_space = false
	add_child(pad)
	_joystick = GoJoystick.new()
	# 데모에서는 본문을 가리지 않게 — 손을 얹으면 그 자리에 나타난다.
	_joystick.hide_when_idle = true
	_joystick.moved.connect(func(v: Vector2) -> void:
		if not v.is_zero_approx(): _say("joystick %.2f, %.2f" % [v.x, v.y]))
	pad.add_child(_joystick)

	var notice_anchor := GoHudAnchor.new()
	notice_anchor.name = "NoticeSpot"
	notice_anchor.spot = GoHudAnchor.Spot.TOP_CENTER
	# 🛑 알림은 **잠깐 떴다 사라진다.** 자리를 예약하면 뜰 때마다 본문이 통째로 출렁이고,
	#    비키지 않으면 오른쪽 위 체력바 위에 그대로 얹힌다(둘 다 실측).
	notice_anchor.reserve_space = false
	notice_anchor.avoid_peers = true
	add_child(notice_anchor)
	_notice = GoNotice.new()
	_notice.custom_minimum_size.x = 260
	notice_anchor.add_child(_notice)

	var prompt_anchor := GoHudAnchor.new()
	prompt_anchor.name = "PromptSpot"
	prompt_anchor.spot = GoHudAnchor.Spot.CENTER_RIGHT
	# 이것도 필요할 때만 나타난다 — 본문이 미리 자리를 비워 둘 것은 아니다.
	prompt_anchor.reserve_space = false
	add_child(prompt_anchor)
	_prompt = GoPromptCard.new()
	_prompt.set_closable(true)
	_prompt.closed.connect(func() -> void: _prompt.hide())
	prompt_anchor.add_child(_prompt)


# ── 동작 ───────────────────────────────────────────────────────────────

func _say(what: String) -> void:
	GoFeedback.tapped()
	if is_instance_valid(_log): _log.text = "→ %s" % what


func _use_slot(slot: GoSlot) -> void:
	_say("slot %s" % slot.icon_name)
	slot.start_cooldown(5.0)
	if slot.quantity > 0: slot.quantity -= 1
	_hp.set_values(minf(_hp.value() + 60.0, 500.0), 500.0)


func _open_dialog() -> void:
	# 되돌릴 수 없는 동작이므로 확인 버튼을 **위험색**으로 — 색이 먼저 읽히고 글자가 뒤따른다.
	var yes := await _dialogs.confirm("Delete character",
		"This cannot be undone. Delete \"{name}\"?", "", "", "", {"name": "Aria"}, true)
	_say("dialog → %s" % ("confirmed" if yes else "cancelled"))


func _open_alert() -> void:
	await _dialogs.alert("Connection lost", "Could not reach the server. Try again in a moment.")
	_say("alert dismissed")


func _open_sheet() -> void:
	_sheet.open("Inventory")
	var search := GoStyle.line_edit("Search items…")
	_sheet.toolbar().add_child(search)
	_sheet.toolbar().visible = true
	for i in 24:
		_sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Item %d" % (i + 1),
			_say.bind("item %d" % (i + 1)), Color.TRANSPARENT, "A description line", false))
	_sheet.footer().add_child(GoStyle.button("Close", _sheet.close, GoStyle.Tone.PRIMARY))
	_sheet.footer().visible = true


func _open_popup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var surface := GoSurface.new()
	surface.dismiss_on_scrim = true
	surface.set_title("Centred popup")
	surface.close_requested.connect(func() -> void:
		layer.queue_free()
		_say("popup closed"))
	layer.add_child(surface)
	surface.body.add_child(GoStyle.label(
		"This is a GoSurface with placement CENTER. It respects the safe area, caps its height, "
		+ "and closes on Escape, Android Back, the X button, or a tap on the scrim."))
	surface.footer.add_child(GoStyle.button("Got it", func() -> void: surface.request_close(), GoStyle.Tone.PRIMARY))
	surface.footer.visible = true


func _show_notice() -> void:
	_notice.show_text("Saved successfully", GoTheme.SUCCESS)
	GoFeedback.confirmed()


func _show_prompt() -> void:
	_prompt.set_accent(GoUi.color(GoTheme.ACCENT))
	_prompt.set_icon(GoIconSet.USER_PLUS, GoUi.color(GoTheme.ACCENT), true)
	_prompt.set_title("Aria invited you to a party")
	_prompt.set_subtitle("Level 42 · Guardian")
	_prompt.set_actions([
		{"text": "Accept", "action": _say.bind("accepted"), "primary": true},
		{"text": "Decline", "action": _say.bind("declined")},
	])
	_prompt.fit_width(300)
	_prompt.show()


func _start_tour() -> void:
	if not is_instance_valid(_tour):
		_tour = GoCoachMark.new()
		add_child(_tour)
		_tour.finished.connect(func(done: bool) -> void: _say("tour " + ("completed" if done else "skipped")))
	_tour.start([
		{"target": _hp, "title": "Health bar", "body": "Values ease smoothly and large numbers are abbreviated."},
		{"target": _slots[0], "title": "Quick slot", "body": "Tap the slot itself — the highlighted control stays usable and the tour moves on."},
		{"target": _joystick, "title": "Joystick", "body": "Follow mode: the stick appears wherever your thumb lands."},
	])


## 생김새 묶음을 고른다 — 한 줄이면 테마·스킨·아이콘이 함께 바뀐다.
func _pick_preset(index: int) -> void:
	var presets := GoThemePresets.all()
	if index < 0 or index >= presets.size(): return
	GoUi.use_preset(presets[index].id)
	_rebuild()


func _toggle_theme() -> void:
	_dark = not _dark
	var settings := GoUi.config
	settings.theme = GoUi.DEFAULT_THEME if _dark else GoUi.LIGHT_THEME
	_rebuild()


## 🛑 이미 만들어진 노드는 자기 `theme` 를 들고 있다 — 통째로 다시 짓는 것이 가장 확실하다.
##    실제 게임에서는 보통 부팅 때 한 번만 생김새를 정하므로 이 비용이 들지 않는다.
func _rebuild() -> void:
	for child in get_children(): child.queue_free()
	_slots.clear()
	_tour = null
	_ready.call_deferred()
