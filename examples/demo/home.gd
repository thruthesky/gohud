## 🏠 **데모의 홈** — 무엇을 볼지 고르고, 고른 것을 이 화면 안에서 연다.
##
## ## 왜 홈이 있는가
## 처음 온 사람이 `godot` 을 치면 나오는 첫 장면이다. 예제 넷이 저마다 다른 것을 보여 주는데,
## 어느 파일을 열어야 하는지 아는 사람만 그것을 볼 수 있다면 있으나 마나다. 그래서 고르는
## 자리를 하나 만들고, **고른 것을 이 화면 안에서** 연다 — 돌아올 길(위쪽 `Home` 줄)이 늘 남는다.
##
## 🔑 이 화면 자체가 gohud 로만 지어져 있다. 카드도 목록 줄도 칩도 막대도 전부 애드온이 준
##    위젯이고, 가운데 카드의 것들은 **그림이 아니라 진짜로 눌린다**. 홈을 한 번 훑는 것이
##    이 키트가 무엇을 주는지 보는 가장 빠른 길이 되도록 했다.
##
## ```
## godot                       # 이 폴더에서 — 홈이 뜬다
## godot -- --open=gallery     # 홈을 건너뛰고 그 화면으로 바로
## ```
##
## 홈에서 `1`~`4` 로 화면을 고른다. 예제를 보는 중에는 위쪽 `Home` 을 눌러 돌아온다.
extends Control

const ThemePicker := preload("theme_picker.gd")

## 열 수 있는 화면. 홈의 카드도 `--open=` 인자도 이 표 하나를 본다.
const TARGETS: Array[Dictionary] = [
	{
		"key": "gallery", "scene": "res://addons/gohud/examples/gallery/gallery.tscn",
		"icon": GoIconSet.GRID, "title": "Widget gallery",
		"note": "Every widget on one page — buttons, inputs, lists, dialogs, HP bars, quick slots, a joystick.",
		"file": "addons/gohud/examples/gallery/gallery.gd",
	},
	{
		"key": "tour", "scene": "res://sim.tscn",
		"icon": GoIconSet.PLAY, "title": "Guided tour",
		"note": "Fifteen scenes a bot plays for you — or pick one widget and try it with your own hands.",
		"file": "examples/demo/sim.gd",
	},
	{
		"key": "showcase", "scene": "res://demo.tscn",
		"icon": GoIconSet.STAR, "title": "Showcase screen",
		"note": "Six cards on one screen. Nothing here is drawn by hand — it is all add-on widgets.",
		"file": "examples/demo/demo.gd",
	},
	{
		"key": "medieval", "scene": "res://addons/gohud/examples/medieval/medieval.tscn",
		"icon": GoIconSet.CROWN, "title": "Medieval look",
		"note": "The same widgets under another preset — a character sheet, a satchel and a quest log.",
		"file": "addons/gohud/examples/medieval/medieval.gd",
	},
]

## 이름 하나에 한 줄 설명과 **실제로 쓰는 코드 한 줄**. 카드로 깔아 두면 훑는 것만으로 목록이 된다.
const PIECES: Array[Dictionary] = [
	{"name": "GoUi", "note": "The one place theme, colors and metrics come from.",
		"code": "theme = GoUi.theme()"},
	{"name": "GoStyle", "note": "A factory for buttons, labels, rows, cards and chips.",
		"code": "GoStyle.button(\"Save\", _save)"},
	{"name": "GoSurface", "note": "A full page with a title, a scroll and a back button.",
		"code": "surface.set_title(\"Settings\")"},
	{"name": "GoSheet", "note": "A page that slides up over the game and swaps its own pages.",
		"code": "sheet.open(\"Inventory\")"},
	{"name": "GoDialogs", "note": "Confirm and alert, with focus and the back key handled.",
		"code": "dialogs.confirm(title, body)"},
	{"name": "GoNotice", "note": "A line that fades in, waits, and leaves on its own.",
		"code": "notice.show_text(\"Saved\")"},
	{"name": "GoPromptCard", "note": "A card that asks for one answer — an invite, a reward.",
		"code": "prompt.set_actions(choices)"},
	{"name": "GoForm", "note": "Keeps inputs clear of the keyboard and of the floating HUD.",
		"code": "form.avoid_hud = true"},
	{"name": "GoHudAnchor", "note": "Pins a widget to a screen corner, inside the safe area.",
		"code": "anchor.spot = Spot.TOP_RIGHT"},
	{"name": "GoBar", "note": "HP, MP and XP — eased values and short readouts.",
		"code": "hp.set_values(320, 500)"},
	{"name": "GoSlot", "note": "A quick slot with a count, a cooldown and a shortcut label.",
		"code": "slot.quantity = 12"},
	{"name": "GoJoystick", "note": "A thumbstick that appears where the thumb lands.",
		"code": "joystick.moved.connect(_move)"},
	{"name": "GoCoachMark", "note": "A first-run tour that points at the real widgets.",
		"code": "tour.start(steps)"},
	{"name": "GoTheme", "note": "Token names — colors, metrics and boxes are asked for by name.",
		"code": "GoUi.color(GoTheme.ACCENT)"},
	{"name": "GoSkin", "note": "The look behind the tokens. Presets swap it whole.",
		"code": "GoUi.use_preset(preset_id)"},
	{"name": "GoIconSet", "note": "Icons as names, so a set can be swapped without touching screens.",
		"code": "GoUi.icons().texture(GoIconSet.BAG)"},
	{"name": "GoConfig", "note": "One resource that settles the look of the whole app.",
		"code": "GoUi.config = settings"},
	{"name": "GoFeedback", "note": "Taps and bumps — silent where the platform has none.",
		"code": "GoFeedback.tapped()"},
]

## 테마를 갈아 끼우면 화면을 통째로 다시 짓는다 — 위젯은 태어날 때 옷을 입기 때문이다.
## 그때 돌아올 자리를 이 정적 값이 들고 있다(씬은 새로 만들어지므로 멤버로는 남지 않는다).
static var _resume := ""

var _stage: Control                ## 홈이든 예제든 여기 한 자리에 들어간다
var _chrome: PanelContainer        ## 예제를 볼 때만 나오는 위쪽 줄
var _chrome_inset: MarginContainer
var _home_inset: MarginContainer
var _chrome_title: Label
var _chrome_file: Label
var _dialogs: GoDialogs
var _sheet: GoSheet
var _notice: GoNotice
var _prompt: GoPromptCard
var _tour: GoCoachMark
var _hp: GoBar
var _log: Label
var _open_key := ""
var _guides: Array[Dictionary] = []   ## 코치마크가 가리킬 자리들


func _ready() -> void:
	name = "Home"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_configure()
	_build_shell()
	_dialogs = GoDialogs.new()
	add_child(_dialogs)
	_sheet = GoSheet.new()
	add_child(_sheet)
	var wanted := _requested()
	if wanted.is_empty(): _show_home()
	else: _open(wanted)


## 애플리케이션 전체의 모습을 설정 한 장으로 정한다 — 예제들이 쓰는 것과 같은 선택기다.
func _configure() -> void:
	var settings := GoConfig.new()
	var colors: Dictionary[StringName, Color] = {}
	settings.color_overrides = colors
	settings.base_font_size = 15
	ThemePicker.configure(settings, colors)
	theme = GoUi.theme()


# ── 껍데기 ─────────────────────────────────────────────────────────────

func _build_shell() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = GoUi.color(GoTheme.BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shell := GoStyle.column(0)
	shell.name = "Shell"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shell)

	shell.add_child(_build_chrome())
	# 창이 바뀌면 안전 영역도 바뀐다 — 위쪽 줄과 홈의 가장자리 여백을 함께 다시 잰다.
	get_window().size_changed.connect(_sync_chrome_inset)
	get_window().size_changed.connect(_sync_home_inset)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	shell.add_child(_stage)


## 예제를 보는 동안 위쪽에 남는 한 줄 — 돌아갈 길과, 지금 보는 것이 **어느 파일인지**.
## 🔑 파일 경로를 적는 이유: 화면이 마음에 든 사람이 다음으로 할 일은 그 소스를 여는 것이다.
func _build_chrome() -> PanelContainer:
	_chrome = PanelContainer.new()
	_chrome.name = "Chrome"
	var face := GoStyle.box(GoTheme.BOX_PANEL)
	# 화면 맨 위에 **딱 붙는** 줄이다 — 둥근 모서리와 그림자는 여기서 떠 있는 것처럼 보일 뿐이다.
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		face.set_corner_radius(corner, 0)
	face.shadow_size = 0
	face.border_width_bottom = 1
	face.border_color = GoUi.color(GoTheme.BORDER)
	_chrome.add_theme_stylebox_override(&"panel", face)
	_chrome.visible = false

	_chrome_inset = MarginContainer.new()
	_chrome_inset.name = "Inset"
	_chrome.add_child(_chrome_inset)
	_sync_chrome_inset()

	var line := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	_chrome_inset.add_child(line)

	var back := GoStyle.button("Home", _show_home, GoStyle.Tone.COMPACT)
	GoStyle.apply_icon(back, GoIconSet.BACK)
	GoStyle.natural_width(back)
	line.add_child(back)

	var names := GoStyle.column(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chrome_title = GoStyle.line("", GoTheme.ROLE_BUTTON)
	names.add_child(_chrome_title)
	_chrome_file = GoStyle.line("", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	names.add_child(_chrome_file)
	line.add_child(names)
	return _chrome


## 🔑 위쪽 줄은 화면 맨 끝에 붙으므로 **노치·상태 표시줄 밑으로 들어갈 수 있다.** 안전 영역이
## 깎아 내는 만큼을 위쪽 여백으로 되돌려 준다(데스크톱에서는 0 이라 아무 일도 없다).
func _sync_chrome_inset() -> void:
	if not is_instance_valid(_chrome_inset): return
	var window := get_window()
	var notch := 0
	if window != null:
		notch = maxi(0, int(GoSafeArea.usable_rect(window).position.y))
	var side := GoUi.metric(GoTheme.PADDING_COMPACT)
	var height := GoUi.metric(GoTheme.GAP_SMALL)
	_chrome_inset.add_theme_constant_override(&"margin_left", side)
	_chrome_inset.add_theme_constant_override(&"margin_right", side)
	_chrome_inset.add_theme_constant_override(&"margin_top", height + notch)
	_chrome_inset.add_theme_constant_override(&"margin_bottom", height)


# ── 화면 갈아 끼우기 ───────────────────────────────────────────────────

## 홈으로 돌아온다. 예제 안에서 테마를 바꿨다면 껍데기까지 새로 지어야 한다 —
## 🛑 배경·위쪽 줄은 옛 테마로 태어난 노드라, 내용만 갈면 색이 두 벌로 섞인다.
func _show_home() -> void:
	if _dialogs.is_open(): return    # 떠 있는 대화상자부터 답한다
	_dismiss_overlays()
	if ThemePicker.active_preset != GoUi.config.preset:
		_resume = ""
		# 🛑 예제를 **먼저 놓아 주고** 다시 짓는다. 씬을 통째로 갈면서 남은 위젯이 포커스를 되돌리려
		#    하면 이미 트리 밖이다(실측: medieval 을 닫을 때 `grab_focus` 조건 실패).
		_clear_stage()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().reload_current_scene()
		return
	_open_key = ""
	_clear_stage()
	_chrome.visible = false
	_stage.add_child(_build_home())


func _open(key: String) -> void:
	if _dialogs.is_open(): return
	_dismiss_overlays()
	var item := _target(key)
	if item.is_empty():
		push_warning("Unknown screen: %s" % key)
		_show_home()
		return
	var packed := load(String(item["scene"])) as PackedScene
	if packed == null:
		push_warning("Could not load %s" % item["scene"])
		_show_home()
		return
	_clear_stage()
	_open_key = key
	_chrome_title.text = String(item["title"])
	_chrome_file.text = String(item["file"])
	# 🛑 녹화·자동 재생 중에는 껍데기를 걷어 낸다 — 영상에 데모가 아닌 것이 찍히면 안 된다.
	_chrome.visible = not _is_bare()
	_stage.add_child(packed.instantiate())


## 화면을 갈기 전에 **띄워 둔 것부터 걷는다.** 시트나 코치마크를 남긴 채 밑판을 갈면,
## 닫히는 쪽이 이미 사라진 화면에 포커스를 되돌리려 한다(실측: `grab_focus` 조건 실패).
func _dismiss_overlays() -> void:
	if is_instance_valid(_sheet): _sheet.close()
	if is_instance_valid(_tour) and _tour.visible: _tour.finish(false)
	if is_instance_valid(_prompt): _prompt.hide()


func _clear_stage() -> void:
	# 🛑 **떼어 내지 않고 숨긴 뒤 놓아 준다.** `remove_child()` 는 그 자리에서 `_exit_tree` 를 돌리는데,
	#    그때 예약된 포커스 되돌리기가 다음 프레임에 트리 밖 노드를 붙잡는다(실측: `grab_focus`
	#    조건 실패). `queue_free()` 는 트리 안에서 제 순서로 정리하고, 숨겨 두었으므로 다음
	#    화면과 한 프레임도 겹치지 않는다.
	for child in _stage.get_children():
		if child is CanvasItem: (child as CanvasItem).hide()
		child.queue_free()
	_home_inset = null
	_notice = null
	_prompt = null
	_tour = null
	_hp = null
	_log = null
	_guides.clear()


func _target(key: String) -> Dictionary:
	for item in TARGETS:
		if String(item["key"]) == key: return item
	return {}


## 홈을 건너뛰고 열 화면. 테마를 바꾸며 다시 지은 것이면 보던 자리로 돌아간다.
func _requested() -> String:
	if not _resume.is_empty():
		var resumed := _resume
		_resume = ""
		return resumed
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--open="): return argument.substr(7)
		if argument.begins_with("--explore="): return "tour"
	return "tour" if arguments.has("--auto") or arguments.has("--cinema") else ""


## 녹화·자동 재생인가 — 그때는 껍데기 없이 예제만 보여 준다.
func _is_bare() -> bool:
	var arguments := OS.get_cmdline_user_args()
	return arguments.has("--auto") or arguments.has("--cinema") or arguments.has("--exit")


func _change_theme(preset: StringName) -> void:
	ThemePicker.active_preset = preset
	_resume = _open_key
	get_tree().reload_current_scene()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _open_key.is_empty(): return    # 예제가 보는 중이면 그쪽 단축키다
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo: return
	var index := key.keycode - KEY_1
	if index < 0 or index >= TARGETS.size(): return
	_open(String(TARGETS[index]["key"]))
	get_viewport().set_input_as_handled()


# ── 홈 화면 ────────────────────────────────────────────────────────────

func _build_home() -> Control:
	var page_root := Control.new()
	page_root.name = "HomePage"
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 🛑 카드 격자는 넓게 펴져야 읽힌다 — 폼 폭(480dp)에 가두지 않고 화면을 그대로 쓰되,
	#    잘릴 수 있는 가장자리만 안전 영역만큼 비켜 준다.
	_home_inset = MarginContainer.new()
	_home_inset.name = "Inset"
	_home_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(_home_inset)
	_sync_home_inset()
	var scroll := GoScroll.new()
	_home_inset.add_child(scroll)
	var page := GoStyle.column(GoUi.metric(GoTheme.GAP_LARGE))
	scroll.add_child(page)

	_add_brand(page)
	_add_targets(page)
	_add_playground(page)
	_add_pieces(page)
	_add_next(page)
	_add_floating(page_root)
	return page_root


## 화면 가장자리 여백 = 기본 여백 + 안전 영역이 깎아 내는 만큼(데스크톱에서는 0 이다).
func _sync_home_inset() -> void:
	if not is_instance_valid(_home_inset): return
	var window := get_window()
	if window == null: return
	var view := window.get_visible_rect()
	var area := GoSafeArea.usable_rect(window)
	var base := GoUi.metric(GoTheme.SCREEN_MARGIN)
	_home_inset.add_theme_constant_override(&"margin_left", base + maxi(0, int(area.position.x)))
	_home_inset.add_theme_constant_override(&"margin_top", base + maxi(0, int(area.position.y)))
	_home_inset.add_theme_constant_override(&"margin_right", base + maxi(0, int(view.end.x - area.end.x)))
	_home_inset.add_theme_constant_override(&"margin_bottom", base + maxi(0, int(view.end.y - area.end.y)))


func _add_brand(page: VBoxContainer) -> void:
	var brand := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var wordmark := GoStyle.label("gohud", GoTheme.ROLE_TITLE)
	# 🛑 남는 폭을 먹지 않게 좁히되 **줄바꿈까지 같이 꺼야** 한다 — 폭만 좁히면 최소 폭이 거의
	#    0 이 되어 `gohud` 가 글자마다 한 줄씩 내려간다(실측).
	GoStyle.natural_width(wordmark)
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(wordmark)
	var version := GoStyle.chip("v" + GoUi.VERSION, GoUi.color(GoTheme.ACCENT))
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(version)
	brand.add_child(GoStyle.spacer())
	var picker := ThemePicker.new()
	picker.theme_selected.connect(_change_theme)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(picker)
	page.add_child(brand)

	page.add_child(GoStyle.label(
		"A HUD and UI kit for Godot 4.6+. Pick a screen below and it opens right here — "
		+ "the bar at the top brings you back.",
		GoTheme.ROLE_SUBTITLE, GoUi.color(GoTheme.SECONDARY)))
	_guides.append({"target": picker, "title": "One switch, every screen",
		"body": "Presets carry a palette, a skin and an icon set. Change it here and the whole app is rebuilt."})


func _add_targets(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("PICK A SCREEN", false))
	var grid := GoStyle.responsive_grid(340)
	for index in TARGETS.size():
		var item := TARGETS[index]
		var row := GoStyle.list_button(StringName(item["icon"]),
			"%d   %s" % [index + 1, item["title"]], _open.bind(String(item["key"])),
			Color.TRANSPARENT, String(item["note"]), false, GoIconSet.CHEVRON_RIGHT)
		grid.add_child(row)
		if index == 0:
			_guides.append({"target": row, "title": "Four screens, one window",
				"body": "Each row opens an example in place. Press 1 to 4 if your hands are on the keyboard."})
	page.add_child(grid)


## 🔑 **만져 보는 자리.** 위젯을 그림으로 보여 주는 소개는 믿기 어렵다 — 여기 있는 것은 전부
##    진짜 위젯이고, 무엇을 누르든 맨 아래 기록 줄이 움직인다.
func _add_playground(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("TRY IT RIGHT HERE", false))
	var card := GoStyle.card()
	page.add_child(card)
	var body := GoStyle.card_body(card, -1, GoUi.metric(GoTheme.GAP))
	body.add_child(GoStyle.label(
		"Nothing in this card is a picture. Press anything and watch the last line.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))

	var tones := GoStyle.wrap_row()
	for spec in [["Primary", GoStyle.Tone.PRIMARY], ["Normal", GoStyle.Tone.NORMAL],
			["Danger", GoStyle.Tone.DANGER], ["Compact", GoStyle.Tone.COMPACT],
			["Bare", GoStyle.Tone.BARE]]:
		var button := GoStyle.button(String(spec[0]), _say.bind("%s button" % spec[0]), spec[1])
		GoStyle.natural_width(button)
		tones.add_child(button)
	body.add_child(tones)
	body.add_child(GoStyle.divider())

	_hp = GoBar.new()
	_hp.label_text = "HP"
	_hp.ink = GoUi.color(GoTheme.DANGER_FILL)
	body.add_child(_hp)
	_hp.set_values(320, 500, false)
	var health := GoStyle.slider(0, 500, 1)
	health.value = 320
	health.value_changed.connect(func(value: float) -> void: _hp.set_values(value, 500))
	body.add_child(health)

	var switches := GoStyle.wrap_row()
	var haptics := GoStyle.toggle("Haptics", false)
	haptics.button_pressed = true
	haptics.toggled.connect(func(on: bool) -> void: _say("haptics " + ("on" if on else "off")))
	GoStyle.natural_width(haptics)
	switches.add_child(haptics)
	switches.add_child(GoStyle.segmented(["Low", "Medium", "High"], 1,
		func(index: int) -> void: _say("quality %d" % index)))
	body.add_child(switches)

	var slots := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	for spec in [
		{"icon": GoIconSet.POTION, "color": GoTheme.DANGER, "count": 12, "key": "1"},
		{"icon": GoIconSet.BOLT, "color": GoTheme.WARNING, "count": 3, "key": "2"},
		{"icon": GoIconSet.SHIELD, "color": GoTheme.INFO, "count": 0, "key": "3"},
		{"icon": GoIconSet.SWORD, "color": GoTheme.SUCCESS, "count": GoSlot.NONE, "key": "4"},
	]:
		var slot := GoSlot.new()
		slot.icon_name = spec["icon"]
		slot.accent = GoUi.color(spec["color"])
		slot.quantity = spec["count"]
		slot.shortcut_label = String(spec["key"])
		slot.pressed.connect(func() -> void: _say("slot %s" % slot.icon_name))
		slots.add_child(slot)
	body.add_child(slots)
	body.add_child(GoStyle.divider())

	var actions := GoStyle.wrap_row()
	for spec in [["Notice", _pop_notice], ["Dialog", _pop_dialog],
			["Bottom sheet", _pop_sheet], ["Prompt card", _pop_prompt],
			["Coach marks", _pop_tour]]:
		var button := GoStyle.button(String(spec[0]), spec[1], GoStyle.Tone.COMPACT)
		GoStyle.natural_width(button)
		actions.add_child(button)
	body.add_child(actions)

	_log = GoStyle.line("Nothing pressed yet.", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	body.add_child(_log)
	_guides.append({"target": card, "title": "Real widgets, real callbacks",
		"body": "Every control here is the one your game would use. The line below it is the callback firing."})


func _add_pieces(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("THE PIECES", false))
	page.add_child(GoStyle.label(
		"Each class below does one job, and one line of code is usually the whole of it.",
		GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	var grid := GoStyle.responsive_grid(250)
	for item in PIECES:
		var card := GoStyle.card()
		var body := GoStyle.card_body(card)
		body.add_child(GoStyle.label(String(item["name"]), GoTheme.ROLE_BUTTON,
			GoUi.color(GoTheme.ACCENT)))
		body.add_child(GoStyle.label(String(item["note"]), GoTheme.ROLE_CAPTION,
			GoUi.color(GoTheme.SECONDARY)))
		body.add_child(GoStyle.line(String(item["code"]), GoTheme.ROLE_MICRO,
			GoUi.color(GoTheme.MUTED)))
		grid.add_child(card)
	page.add_child(grid)
	_guides.append({"target": grid, "title": "The whole surface",
		"body": "Eighteen classes. The gallery shows every one of them running; the tour explains them one at a time."})


func _add_next(page: VBoxContainer) -> void:
	page.add_child(GoStyle.section("WHERE TO GO NEXT", false))
	page.add_child(GoStyle.alert(
		"README.md has the full API, docs/ has the guides, and addons/gohud/examples holds the source "
		+ "of every screen here. In Claude Code, /gohud features lists what the kit can do.",
		GoTheme.INFO))


## 화면 귀퉁이에 떠 있는 것들 — 본문이 자리를 비켜 줄 필요가 없는 손님들이다.
func _add_floating(page_root: Control) -> void:
	var notice_spot := GoHudAnchor.new()
	notice_spot.name = "NoticeSpot"
	notice_spot.spot = GoHudAnchor.Spot.TOP_CENTER
	# 🛑 알림은 잠깐 떴다 사라진다 — 자리를 예약하면 뜰 때마다 본문이 통째로 출렁인다.
	notice_spot.reserve_space = false
	notice_spot.avoid_peers = true
	page_root.add_child(notice_spot)
	_notice = GoNotice.new()
	_notice.custom_minimum_size.x = 280
	notice_spot.add_child(_notice)

	var prompt_spot := GoHudAnchor.new()
	prompt_spot.name = "PromptSpot"
	prompt_spot.spot = GoHudAnchor.Spot.CENTER_RIGHT
	prompt_spot.reserve_space = false
	page_root.add_child(prompt_spot)
	_prompt = GoPromptCard.new()
	_prompt.set_closable(true)
	_prompt.closed.connect(func() -> void: _prompt.hide())
	_prompt.hide()
	prompt_spot.add_child(_prompt)

	_tour = GoCoachMark.new()
	_tour.name = "CoachMarks"
	_tour.finished.connect(func(done: bool) -> void:
		_say("coach marks " + ("completed" if done else "skipped")))
	page_root.add_child(_tour)


# ── 만져 봤을 때 ───────────────────────────────────────────────────────

func _say(what: String) -> void:
	GoFeedback.tapped()
	if is_instance_valid(_log): _log.text = "→ " + what


func _pop_notice() -> void:
	if not is_instance_valid(_notice): return
	_notice.show_text("Saved — a notice leaves on its own.", GoTheme.SUCCESS)
	_say("notice")


func _pop_dialog() -> void:
	_dialogs.confirm("Leave the keep?",
		"The dialog handles focus, the back key and a narrow screen for you.", "Leave", "Stay")
	var yes: bool = await _dialogs.answered
	_say("dialog → " + ("leave" if yes else "stay"))


func _pop_sheet() -> void:
	_sheet.open("Inventory")
	for index in 8:
		_sheet.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Item %d" % (index + 1),
			_say.bind("sheet item %d" % (index + 1)), Color.TRANSPARENT,
			"A row inside the sheet", false, GoIconSet.CHEVRON_RIGHT))
	_sheet.add_footer(GoStyle.button("Close", _sheet.close, GoStyle.Tone.PRIMARY))
	_say("bottom sheet")


func _pop_prompt() -> void:
	if not is_instance_valid(_prompt): return
	_prompt.set_accent(GoUi.color(GoTheme.ACCENT))
	_prompt.set_icon(GoIconSet.USER_PLUS, GoUi.color(GoTheme.ACCENT), true)
	_prompt.set_title("Aria invited you to a party")
	_prompt.set_subtitle("Level 42 · Guardian")
	_prompt.set_actions([
		{"text": "Decline", "action": func() -> void: _prompt.hide(); _say("prompt → decline")},
		{"text": "Join", "primary": true,
			"action": func() -> void: _prompt.hide(); _say("prompt → join")},
	])
	_prompt.fit_width(300)
	_prompt.show()
	_say("prompt card")


func _pop_tour() -> void:
	if not is_instance_valid(_tour) or _guides.is_empty(): return
	_tour.start(_guides)
