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
## ## 🛑 읽히는 폭이 먼저다
## 창이 넓다고 글을 창만큼 늘이면 한 줄이 120자를 넘고, 눈이 줄 끝에서 다음 줄 머리를 못 찾는다.
## 그래서 본문은 [constant PAGE_MAX_WIDTH] 안으로 모으고, 남는 폭은 양옆 여백으로 버린다.
## 소개·미리보기·카드가 모두 **격자**에 들어가 있어, 폭이 줄면 열이 줄고 글줄은 그대로 읽힌다.
##
## ```
## godot                       # 이 폴더에서 — 홈이 뜬다
## godot -- --open=gallery     # 홈을 건너뛰고 그 화면으로 바로
## ```
##
## 홈에서 `1`~`4` 로 화면을 고른다. 예제를 보는 중에는 위쪽 `Home` 을 눌러 돌아온다.
extends Control

const ThemePicker := preload("theme_picker.gd")

## 본문이 넘지 않는 폭(dp). 넓은 창에서는 양옆이 여백이 된다.
const PAGE_MAX_WIDTH := 1120.0
## 자랑할 만한 숫자들 — 아이콘 상수·번역본·프리셋을 센 값이다.
const ICON_COUNT := 84
const LANGUAGE_COUNT := 21

## 열 수 있는 화면. 홈의 카드도 `--open=` 인자도 이 표 하나를 본다.
## `tone` 은 그 카드가 입는 의미색이다 — 넷이 한눈에 구분된다.
const TARGETS: Array[Dictionary] = [
	{
		"key": "gallery", "scene": "res://addons/gohud/examples/gallery/gallery.tscn",
		"icon": GoIconSet.GRID, "tone": GoTheme.ACCENT, "title": "Widget gallery",
		"note": "Every widget on one page — buttons, inputs, lists, dialogs, HP bars, quick slots, a joystick.",
		"file": "examples/gallery/gallery.gd",
	},
	{
		"key": "tour", "scene": "res://sim.tscn",
		"icon": GoIconSet.PLAY, "tone": GoTheme.INFO, "title": "Guided tour",
		"note": "Fifteen scenes a bot plays for you — or pick one widget and try it with your own hands.",
		"file": "examples/demo/sim.gd",
	},
	{
		"key": "showcase", "scene": "res://demo.tscn",
		"icon": GoIconSet.STAR, "tone": GoTheme.WARNING, "title": "Showcase screen",
		"note": "Six cards on one screen. Nothing here is drawn by hand — it is all add-on widgets.",
		"file": "examples/demo/demo.gd",
	},
	{
		"key": "medieval", "scene": "res://addons/gohud/examples/medieval/medieval.tscn",
		"icon": GoIconSet.CROWN, "tone": GoTheme.SUCCESS, "title": "Medieval look",
		"note": "The same widgets under another preset — a character sheet, a satchel and a quest log.",
		"file": "examples/medieval/medieval.gd",
	},
]

## 클래스를 **하는 일별로** 묶는다. 스무 개를 한 무더기로 쌓으면 목록이지 설명이 아니다.
const GROUPS: Array[Dictionary] = [
	{"name": "Foundation", "icon": GoIconSet.SLIDERS, "tone": GoTheme.ACCENT,
		"note": "What the look is made of. Set it once and every screen follows."},
	{"name": "Building a screen", "icon": GoIconSet.COLUMNS, "tone": GoTheme.INFO,
		"note": "The pieces a page is assembled from, all at the same measurements."},
	{"name": "Talking to the player", "icon": GoIconSet.CHAT, "tone": GoTheme.WARNING,
		"note": "Asking, telling and guiding — with focus and the back key handled."},
	{"name": "The game HUD", "icon": GoIconSet.TARGET, "tone": GoTheme.SUCCESS,
		"note": "What sits over the world: corners, gauges, slots and a thumbstick."},
	{"name": "Forms and lists", "icon": GoIconSet.LIST, "tone": GoTheme.ACCENT,
		"note": "Where players type, search, sort and page through what the server sent."},
	{"name": "Game shapes", "icon": GoIconSet.CHART, "tone": GoTheme.WARNING,
		"note": "Attendance, stats and banners — web shapes rebuilt for what games need."},
]

## 이름 하나에 한 줄 설명과 **실제로 쓰는 코드 한 줄**. `group` 은 위 묶음의 번호다.
const PIECES: Array[Dictionary] = [
	{"group": 0, "name": "GoUi", "note": "The one place theme, colors and metrics come from.",
		"code": "theme = GoUi.theme()"},
	{"group": 0, "name": "GoConfig", "note": "One resource that settles the look of the whole app.",
		"code": "GoUi.config = settings"},
	{"group": 0, "name": "GoTheme", "note": "Token names — colors, metrics and boxes are asked for by name.",
		"code": "GoUi.color(GoTheme.ACCENT)"},
	{"group": 0, "name": "GoSkin", "note": "The look behind the tokens. A preset swaps it whole.",
		"code": "GoUi.use_preset(preset_id)"},
	{"group": 0, "name": "GoIconSet", "note": "Icons as names, so a set swaps without touching screens.",
		"code": "GoUi.icons().texture(icon)"},
	{"group": 0, "name": "GoFeedback", "note": "Taps and bumps — silent where the platform has none.",
		"code": "GoFeedback.tapped()"},
	{"group": 1, "name": "GoStyle", "note": "A factory for buttons, labels, rows, cards and chips.",
		"code": "GoStyle.button(\"Save\", _save)"},
	{"group": 1, "name": "GoForm", "note": "Keeps inputs clear of the keyboard and of the floating HUD.",
		"code": "form.avoid_hud = true"},
	{"group": 1, "name": "GoScroll", "note": "A scroll that behaves under a thumb and keeps its edges.",
		"code": "scroll.use_panel_edge(pad)"},
	{"group": 1, "name": "GoSurface", "note": "A full page with a title, a scroll and a back button.",
		"code": "surface.set_title(\"Settings\")"},
	{"group": 2, "name": "GoSheet", "note": "A page that slides up over the game and swaps its own pages.",
		"code": "sheet.open(\"Inventory\")"},
	{"group": 2, "name": "GoDialogs", "note": "Confirm and alert, with focus and the back key handled.",
		"code": "dialogs.confirm(title, body)"},
	{"group": 2, "name": "GoNotice", "note": "A line that fades in, waits, and leaves on its own.",
		"code": "notice.show_text(\"Saved\")"},
	{"group": 2, "name": "GoPromptCard", "note": "A card that asks for one answer — an invite, a reward.",
		"code": "prompt.set_actions(choices)"},
	{"group": 2, "name": "GoCoachMark", "note": "A first-run tour that points at the real widgets.",
		"code": "tour.start(steps)"},
	{"group": 3, "name": "GoHudAnchor", "note": "Pins a widget to a screen corner, inside the safe area.",
		"code": "anchor.spot = Spot.TOP_RIGHT"},
	{"group": 3, "name": "GoBar", "note": "HP, MP and XP — eased values and short readouts.",
		"code": "hp.set_values(320, 500)"},
	{"group": 3, "name": "GoSlot", "note": "A quick slot with a count, a cooldown and a shortcut label.",
		"code": "slot.quantity = 12"},
	{"group": 3, "name": "GoJoystick", "note": "A thumbstick that appears where the thumb lands.",
		"code": "joystick.moved.connect(_move)"},
	{"group": 2, "name": "GoSnackbar", "note": "Places itself at the bottom, queues, and can carry Undo.",
		"code": "await snack.post(options)"},
	{"group": 2, "name": "GoPopover", "note": "An info card beside the thing you pressed — one at a time.",
		"code": "GoPopover.open(slot, card)"},
	{"group": 2, "name": "GoDrawer", "note": "Slides in from the side, for screens wider than a phone.",
		"code": "drawer.open(\"Bag\")"},
	{"group": 2, "name": "GoContextMenu", "note": "Long-press or right-click; a moving finger cancels it.",
		"code": "GoContextMenu.attach(slot, items)"},
	{"group": 3, "name": "GoSpinner", "note": "A wait with no end in sight — and a button that cannot double-fire.",
		"code": "GoSpinner.busy(button, true)"},
	{"group": 3, "name": "GoBadge", "note": "The unread dot, the NEW tag, the 99+ — hidden at zero.",
		"code": "GoBadge.attach(mail, unread)"},
	{"group": 3, "name": "GoConsole", "note": "Cheat and debug commands. Refuses to open in a release build.",
		"code": "console.register(name, help, run)"},
	{"group": 4, "name": "GoField", "note": "Label, input, hint — and the error that says which box is wrong.",
		"code": "field.set_error(message)"},
	{"group": 4, "name": "GoInputGroup", "note": "An input and its button welded into one shape.",
		"code": "GoInputGroup.make(edit, parts)"},
	{"group": 4, "name": "GoCombobox", "note": "A picker that searches inside names, not just their start.",
		"code": "GoCombobox.make(friends)"},
	{"group": 4, "name": "GoCodeInput", "note": "Coupon codes — pasting works, and an IME cannot eat a letter.",
		"code": "GoCodeInput.make(12, 4)"},
	{"group": 4, "name": "GoTable", "note": "Sort by a header, pick a row — and numbers sort as numbers.",
		"code": "GoTable.make(columns, rows)"},
	{"group": 4, "name": "GoPagination", "note": "Pages that keep the current one centred, or a More row.",
		"code": "GoPagination.make(1, total, load)"},
	{"group": 5, "name": "GoRewardCalendar", "note": "Daily attendance — only today can be pressed.",
		"code": "GoRewardCalendar.make(days, got)"},
	{"group": 5, "name": "GoRadar", "note": "The stat pentagon, with a dashed line to compare gear.",
		"code": "GoRadar.make(stats, compare)"},
	{"group": 5, "name": "GoDonut", "note": "Damage share and currency splits, with a legend in words.",
		"code": "GoDonut.make(slices)"},
	{"group": 5, "name": "GoCarousel", "note": "Banners and character select — it never moves on its own.",
		"code": "carousel.set_pages(banners)"},
	{"group": 5, "name": "GoKbd", "note": "Key caps that read the real binding, and hide on phones.",
		"code": "GoKbd.for_action(&\"interact\")"},
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
var _snackbar: GoSnackbar
var _drawer: GoDrawer
var _home_field: GoField
var _mp: GoBar
var _log: Label
var _log_empty: Control
var _open_key := ""
var _history: Array[String] = []      ## 기록 줄 — 가장 최근이 맨 위
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
	# 🔑 읽는 화면이다 — 기본보다 한 칸 큰 본문이 훑기에 편하다.
	settings.base_font_size = 16
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
	# 창이 바뀌면 안전 영역도 읽히는 폭도 바뀐다 — 위쪽 줄과 본문 여백을 함께 다시 잰다.
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
	_mp = null
	_log = null
	_log_empty = null
	_history.clear()
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

	var backdrop := Backdrop.new()
	backdrop.name = "Backdrop"
	backdrop.base = GoUi.color(GoTheme.BACKGROUND)
	backdrop.grid = Color(GoUi.color(GoTheme.BORDER), 0.22)
	backdrop.glow = GoUi.color(GoTheme.ACCENT)
	backdrop.spark = GoUi.color(GoTheme.INFO)
	page_root.add_child(backdrop)

	# 🔑 가장자리 여백과 **읽히는 폭**을 한 컨테이너가 함께 맡는다 — 둘 다 창 크기에서 나온다.
	_home_inset = MarginContainer.new()
	_home_inset.name = "Inset"
	_home_inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(_home_inset)
	_sync_home_inset()
	var scroll := GoScroll.new()
	_home_inset.add_child(scroll)
	var page := GoStyle.column(GoUi.metric(GoTheme.GAP_LARGE) * 2)
	scroll.add_child(page)

	_add_hero(page)
	_add_targets(page)
	_add_playground(page)
	_add_pieces(page)
	_add_next(page)
	_add_floating(page_root)
	return page_root


## 화면 가장자리 여백 = 기본 여백 + 안전 영역 + **넘치는 폭**. 마지막 항이 줄 길이를 잡아 준다.
func _sync_home_inset() -> void:
	if not is_instance_valid(_home_inset): return
	var window := get_window()
	if window == null: return
	var view := window.get_visible_rect()
	var area := GoSafeArea.usable_rect(window)
	var base := GoUi.metric(GoTheme.SCREEN_MARGIN)
	var left := base + maxi(0, int(area.position.x))
	var right := base + maxi(0, int(view.end.x - area.end.x))
	# 🛑 넓은 창에서 글을 창만큼 늘이지 않는다 — 한 줄이 길면 눈이 다음 줄 머리를 잃는다.
	var usable := area.size.x - float(left + right)
	if usable > PAGE_MAX_WIDTH:
		var spare := int((usable - PAGE_MAX_WIDTH) * 0.5)
		left += spare
		right += spare
	_home_inset.add_theme_constant_override(&"margin_left", left)
	_home_inset.add_theme_constant_override(&"margin_right", right)
	_home_inset.add_theme_constant_override(&"margin_top", base + maxi(0, int(area.position.y)))
	_home_inset.add_theme_constant_override(&"margin_bottom", base + maxi(0, int(view.end.y - area.end.y)))


# ── ① 첫인상 ───────────────────────────────────────────────────────────

func _add_hero(page: VBoxContainer) -> void:
	var accent := GoUi.color(GoTheme.ACCENT)

	var narrow := _is_narrow()
	var mark := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	mark.add_child(_disc(GoIconSet.GRID, accent, 46 if narrow else 52, 24 if narrow else 27))
	var wordmark := GoStyle.label("gohud", GoTheme.ROLE_TITLE)
	# 🛑 남는 폭을 먹지 않게 좁히되 **줄바꿈까지 같이 꺼야** 한다 — 폭만 좁히면 최소 폭이 거의
	#    0 이 되어 `gohud` 가 글자마다 한 줄씩 내려간다(실측).
	GoStyle.natural_width(wordmark)
	wordmark.add_theme_font_size_override(&"font_size",
		roundi(GoUi.font_size(GoTheme.ROLE_TITLE) * (1.2 if narrow else 1.45)))
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_child(wordmark)
	var version := GoStyle.chip("v" + GoUi.VERSION, accent)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.add_child(version)

	var picker := ThemePicker.new()
	picker.theme_selected.connect(_change_theme)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 🛑 이름표와 선택기를 **한 줄에 억지로 묶지 않는다.** 가로 줄은 자식의 최소 폭 아래로는
	#    줄지 않으므로, 폰 폭에서 줄 하나가 페이지 전체를 밀어내 오른쪽을 잘라 먹는다(실측).
	var brand := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	if narrow:
		picker.custom_minimum_size.x = 0
		picker.size_flags_horizontal = Control.SIZE_FILL
		brand.add_child(mark)
		brand.add_child(picker)
	else:
		mark.add_child(GoStyle.spacer())
		mark.add_child(picker)
		brand.add_child(mark)
	var hero := GoStyle.column(GoUi.metric(GoTheme.GAP))
	page.add_child(hero)
	hero.add_child(brand)
	_guides.append({"target": picker, "title": "One switch, every screen",
		"body": "A preset carries a palette, a skin and an icon set. Change it here and the whole app is rebuilt."})

	# 🔑 소개와 **살아 있는 HUD** 를 나란히 둔다. 글만으로 설명하면 읽어야 믿지만, 옆에서
	#    막대가 실제로 차 있으면 읽기 전에 보인다. 좁아지면 격자가 알아서 한 줄로 접는다.
	var top := GoStyle.responsive_grid(400, GoUi.metric(GoTheme.GAP))
	hero.add_child(top)
	top.add_child(_hero_words())
	top.add_child(_hero_hud())


func _hero_words() -> Control:
	var accent := GoUi.color(GoTheme.ACCENT)
	var card := GoStyle.card(accent)
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)

	body.add_child(GoStyle.section("GODOT 4.6+   ·   MIT   ·   NO AUTOLOAD", false))
	var headline := GoStyle.label("Your game UI, already built.", GoTheme.ROLE_TITLE)
	body.add_child(headline)
	body.add_child(GoStyle.label(
		"Menus, HUDs, dialogs, sheets, forms and coach marks — one theme, one set of measurements, "
		+ "touch-safe and translated. Pick a screen below and it opens right here.",
		GoTheme.ROLE_BODY, GoUi.color(GoTheme.SECONDARY)))

	var facts := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for fact in [
		{"text": "%d classes" % PIECES.size(), "icon": GoIconSet.BOX, "tone": GoTheme.ACCENT},
		{"text": "%d presets" % GoThemePresets.ids().size(), "icon": GoIconSet.SUN, "tone": GoTheme.INFO},
		{"text": "%d icons" % ICON_COUNT, "icon": GoIconSet.STAR, "tone": GoTheme.WARNING},
		{"text": "%d languages" % LANGUAGE_COUNT, "icon": GoIconSet.GLOBE, "tone": GoTheme.SUCCESS},
	]:
		facts.add_child(GoStyle.chip(String(fact["text"]), GoUi.color(fact["tone"]), false,
			StringName(fact["icon"])))
	body.add_child(facts)
	return card


## 홍보 문구 옆에 두는 **진짜 HUD** — 막대도 슬롯도 게임에서 쓰는 그 위젯이다.
func _hero_hud() -> Control:
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("LIVE HUD", GoIconSet.HEART, GoUi.color(GoTheme.DANGER)))

	_hp = _bar("HP", GoTheme.DANGER_FILL, 320, 500)
	body.add_child(_hp)
	_mp = _bar("MP", GoTheme.INFO_FILL, 88, 120)
	body.add_child(_mp)
	var xp := _bar("XP", GoTheme.WARNING_FILL, 64, 100)
	xp.readout = GoBar.Readout.PERCENT
	body.add_child(xp)

	var slots := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_SMALL))
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
		slot.pressed.connect(func() -> void:
			_hp.set_values(minf(_hp.value() + 60.0, 500.0), 500.0)
			_say("quick slot %s used" % slot.icon_name))
		slots.add_child(slot)
	body.add_child(slots)
	body.add_child(GoStyle.label("Press a slot — the health bar answers.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	_guides.append({"target": card, "title": "A HUD out of the box",
		"body": "Bars ease their values and shorten large numbers; slots carry a count, a cooldown and a shortcut."})
	return card


# ── ② 화면 고르기 ──────────────────────────────────────────────────────

func _add_targets(page: VBoxContainer) -> void:
	_add_heading(page, "01", "Pick a screen",
		"Each one opens inside this window. Press 1 – 4, or click a card.")
	var grid := GoStyle.responsive_grid(400, GoUi.metric(GoTheme.GAP))
	for index in TARGETS.size():
		grid.add_child(_target_card(index, TARGETS[index]))
	page.add_child(grid)


## 🔑 **누를 수 있는 카드.** 목록 줄보다 크게 잡아 아이콘·제목·설명·소스 파일이 한자리에 온다.
## `style_choice_card` 가 평소·올림·누름 판을 한 번에 입혀 주므로, 여기서는 내용만 담는다.
func _target_card(index: int, item: Dictionary) -> Button:
	var accent := GoUi.color(item["tone"])
	var card := Button.new()
	card.name = "Target%d" % (index + 1)
	GoStyle.style_choice_card(card, accent, false, false, true, Control.MOUSE_FILTER_STOP)
	# 제목은 카드에 이미 크게 적혀 있다 — 툴팁은 **더 말해 주는 것**이어야 한다.
	card.tooltip_text = "Opens %s" % item["file"]
	card.accessibility_name = String(item["title"])
	card.pressed.connect(_open.bind(String(item["key"])))

	var body := GoStyle.card_body(card, GoUi.metric(GoTheme.PADDING), GoUi.metric(GoTheme.GAP_SMALL))
	var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	head.add_child(_disc(StringName(item["icon"]), accent, 52, 26))
	var titles := GoStyle.column(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(GoStyle.label("PRESS %d" % (index + 1), GoTheme.ROLE_MICRO, accent))
	titles.add_child(GoStyle.label(String(item["title"]), GoTheme.ROLE_SUBTITLE))
	head.add_child(titles)
	var chevron := GoUi.icons().node(GoIconSet.CHEVRON_RIGHT,
		GoUi.metric(GoTheme.ICON_SIZE), GoUi.color(GoTheme.MUTED))
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chevron)
	body.add_child(head)

	body.add_child(GoStyle.label(String(item["note"]), GoTheme.ROLE_CAPTION,
		GoUi.color(GoTheme.SECONDARY)))
	var file := GoStyle.chip(String(item["file"]), GoUi.color(GoTheme.MUTED), false, GoIconSet.BOOK)
	body.add_child(file)
	# 🛑 카드가 곧 버튼이다 — 그 위의 글자·아이콘이 마우스를 가로채면 올림 판이 켜지지 않는다.
	_pass_through(body)
	if index == 0:
		_guides.append({"target": card, "title": "Four screens, one window",
			"body": "A card opens its example in place. The bar across the top names the file it lives in."})
	return card


# ── ③ 만져 보는 자리 ───────────────────────────────────────────────────

## 🔑 위젯을 그림으로 보여 주는 소개는 믿기 어렵다 — 여기 있는 것은 전부 진짜 위젯이고,
##    무엇을 누르든 마지막 카드의 기록이 움직인다.
func _add_playground(page: VBoxContainer) -> void:
	_add_heading(page, "02", "Try it right here",
		"Nothing below is a picture. Press, drag and type — the activity card reports every callback.")
	var grid := GoStyle.responsive_grid(340, GoUi.metric(GoTheme.GAP))
	page.add_child(grid)
	grid.add_child(_card_buttons())
	grid.add_child(_card_inputs())
	grid.add_child(_card_choices())
	grid.add_child(_card_lists())
	grid.add_child(_card_feedback())
	grid.add_child(_card_new_widgets())
	grid.add_child(_card_activity())


# ── 🆕 뒤에 들인 위젯의 동작 ───────────────────────────────────────────

func _ensure_snackbar() -> GoSnackbar:
	if not is_instance_valid(_snackbar):
		_snackbar = GoSnackbar.new()
		add_child(_snackbar)
	return _snackbar


func _pop_snackbar() -> void:
	_say("snackbar")
	var picked: int = await _ensure_snackbar().post({
		"text": "Item dropped", "tone": GoTheme.WARNING, "icon": GoIconSet.TRASH, "actions": ["Undo"]})
	_say("undo pressed" if picked == 0 else "snackbar closed")


func _pop_drawer() -> void:
	if not is_instance_valid(_drawer):
		_drawer = GoDrawer.new()
		add_child(_drawer)
		for i in 8:
			_drawer.body.add_child(GoStyle.list_button(GoIconSet.POTION, "Potion %d" % (i + 1),
				_say.bind("potion %d" % (i + 1)), Color.TRANSPARENT, "Restores health", false))
	_drawer.open("Bag")
	_say("drawer")


## 🔑 누른 버튼이 그 자리에서 도는 것으로 바뀐다 — 크기도 그대로고 두 번 눌리지도 않는다.
func _demo_busy() -> void:
	var button := _find_named_button("Buy")
	if button == null: return
	GoSpinner.busy(button, true)
	_say("waiting for the server…")
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(button): GoSpinner.busy(button, false)
	_say("purchase done")


func _find_named_button(words: String) -> Button:
	for node in _all_nodes(self):
		var button := node as Button
		if button != null and button.text == words: return button
	return null


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all_nodes(child))
	return out


func _demo_field_error() -> void:
	if is_instance_valid(_home_field): _home_field.set_error("That name is taken")
	_say("field error")


func _demo_field_clear() -> void:
	if is_instance_valid(_home_field): _home_field.clear_error()
	_say("field cleared")


func _card_buttons() -> Control:
	var tone := GoUi.color(GoTheme.ACCENT)
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("BUTTONS", GoIconSet.TARGET, tone))

	var tones := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for spec in [["Primary", GoStyle.Tone.PRIMARY], ["Normal", GoStyle.Tone.NORMAL],
			["Danger", GoStyle.Tone.DANGER], ["Compact", GoStyle.Tone.COMPACT],
			["Bare", GoStyle.Tone.BARE]]:
		var button := GoStyle.button(String(spec[0]), _say.bind("%s button" % spec[0]), spec[1])
		GoStyle.natural_width(button)
		tones.add_child(button)
	body.add_child(tones)

	var icons := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for spec in [[GoIconSet.SETTINGS, "settings"], [GoIconSet.SEARCH, "search"],
			[GoIconSet.HEART, "favourite"], [GoIconSet.BELL, "alerts"], [GoIconSet.TRASH, "delete"]]:
		icons.add_child(GoStyle.icon_button(spec[0], _say.bind("icon button · %s" % spec[1]),
			-1, StringName(spec[1])))
	body.add_child(icons)
	body.add_child(GoStyle.label("Five tones and an icon-only row, all at one touch size.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return card


func _card_inputs() -> Control:
	var tone := GoUi.color(GoTheme.INFO)
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("INPUTS", GoIconSet.EDIT, tone))

	var field := GoStyle.line_edit("Player name")
	field.text_submitted.connect(func(value: String) -> void: _say("typed \"%s\"" % value))
	body.add_child(field)

	var haptics := GoStyle.toggle("Haptics", false)
	haptics.button_pressed = true
	haptics.toggled.connect(func(on: bool) -> void: _say("haptics " + ("on" if on else "off")))
	body.add_child(haptics)

	var volume := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	volume.add_child(GoUi.icons().node(GoIconSet.VOLUME_HIGH,
		GoUi.metric(GoTheme.LIST_GLYPH), GoUi.color(GoTheme.SECONDARY)))
	var slider := GoStyle.slider(0, 500, 1)
	slider.value = 320
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		if is_instance_valid(_hp): _hp.set_values(value, 500))
	volume.add_child(slider)
	body.add_child(volume)
	body.add_child(GoStyle.label("The slider drives the health bar in the card above.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return card


func _card_choices() -> Control:
	var tone := GoUi.color(GoTheme.WARNING)
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("CHOICES", GoIconSet.LIST, tone))

	body.add_child(GoStyle.segmented(["Low", "Medium", "High"], 1,
		func(index: int) -> void: _say("quality → %d" % index)))
	var difficulty := GoStyle.select(["Story", "Normal", "Veteran", "Ironman"], "", false)
	difficulty.select(1)
	difficulty.item_selected.connect(func(index: int) -> void: _say("difficulty → %d" % index))
	body.add_child(difficulty)
	body.add_child(GoStyle.choice_grid([
		{"text": "Iron", "color": GoUi.color(GoTheme.SECONDARY)},
		{"text": "Ember", "color": GoUi.color(GoTheme.DANGER)},
		{"text": "Tide", "color": GoUi.color(GoTheme.INFO)},
		{"text": "Moss", "color": GoUi.color(GoTheme.SUCCESS)},
	], 0, func(index: int) -> void: _say("banner colour → %d" % index)))
	body.add_child(GoStyle.label("Segments, a picker and a colour grid — one selection each.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return card


## 이름·목록 줄·진행도처럼 **화면에 값을 얹는** 것들. 게임 UI 의 절반이 이 모양이다.
func _card_lists() -> Control:
	var tone := GoUi.color(GoTheme.SUCCESS)
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("LISTS & DATA", GoIconSet.COLUMNS, tone))

	var who := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	who.add_child(GoStyle.avatar("Aria Vale", 42, tone))
	var names := GoStyle.column(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(GoStyle.label("Aria Vale", GoTheme.ROLE_BUTTON))
	names.add_child(GoStyle.label("Guardian  ·  Level 42", GoTheme.ROLE_MICRO,
		GoUi.color(GoTheme.SECONDARY)))
	who.add_child(names)
	var state := GoStyle.chip("Online", tone)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(state)
	body.add_child(who)

	body.add_child(GoStyle.list_button(GoIconSet.USER, "Profile",
		_say.bind("list row · profile"), Color.TRANSPARENT, "Name, avatar and title",
		false, GoIconSet.CHEVRON_RIGHT))
	body.add_child(GoStyle.list_button(GoIconSet.BAG, "Satchel",
		_say.bind("list row · satchel"), Color.TRANSPARENT, "8 items  ·  250 crowns",
		false, GoIconSet.CHEVRON_RIGHT))

	body.add_child(GoStyle.divider())
	var quest := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var chapter := GoStyle.label("Chapter III", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	GoStyle.natural_width(chapter)
	quest.add_child(chapter)
	var progress := GoStyle.progress(tone)
	progress.value = 64
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quest.add_child(progress)
	var percent := GoStyle.label("64%", GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	GoStyle.natural_width(percent)
	quest.add_child(percent)
	body.add_child(quest)
	return card


func _card_feedback() -> Control:
	var tone := GoUi.color(GoTheme.DANGER)
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("TELLING THE PLAYER", GoIconSet.CHAT, tone))

	var actions := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for spec in [["Notice", _pop_notice], ["Snackbar", _pop_snackbar], ["Dialog", _pop_dialog],
			["Sheet", _pop_sheet], ["Drawer", _pop_drawer], ["Prompt", _pop_prompt],
			["Coach marks", _pop_tour]]:
		var button := GoStyle.button(String(spec[0]), spec[1], GoStyle.Tone.COMPACT)
		GoStyle.natural_width(button)
		actions.add_child(button)
	body.add_child(actions)
	body.add_child(GoStyle.alert(
		"Each one handles focus and the back key for you, on a phone as much as on a desktop.",
		GoTheme.INFO))
	return card


## 🆕 뒤에 들인 위젯을 **살아 있는 채로** 한 카드에. 목록에 이름만 적어 두면 아무도 눌러 보지 않는다.
func _card_new_widgets() -> Control:
	var tone := GoUi.color(GoTheme.WARNING)
	var card := GoStyle.card(tone)
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("NEWEST WIDGETS", GoIconSet.STAR, tone))

	# 배지가 달린 아이콘 — 우편함의 안 읽음 표시 그대로.
	var top := GoStyle.row(GoUi.metric(GoTheme.GAP))
	var mail := GoIconButton.new()
	mail.icon_name = GoIconSet.BELL
	mail.tooltip_text_name = &"next"
	mail.pressed.connect(func() -> void:
		GoBadge.attach(mail, 0)
		_say("mail read"))
	top.add_child(mail)
	GoBadge.attach.call_deferred(mail, 3)
	var busy := GoStyle.button("Buy", _demo_busy, GoStyle.Tone.PRIMARY)
	GoStyle.natural_width(busy)
	top.add_child(busy)
	var keys := GoKbd.make("Ctrl", "S")
	keys.hide_on_handheld = false
	top.add_child(keys)
	body.add_child(top)

	# 오류를 띄웠다 지우는 폼 한 줄.
	_home_field = GoField.make("Guild name", GoStyle.line_edit("2-16 characters"), "Everyone sees this")
	body.add_child(_home_field)
	var field_row := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP_TINY))
	for spec in [["Show error", _demo_field_error], ["Clear", _demo_field_clear]]:
		var button := GoStyle.button(String(spec[0]), spec[1], GoStyle.Tone.COMPACT)
		GoStyle.natural_width(button)
		field_row.add_child(button)
	body.add_child(field_row)

	body.add_child(GoInputGroup.make(GoStyle.line_edit("Message"),
		{"suffix": GoStyle.button("Send", _say.bind("sent"))}))

	# 정렬되는 표 — 점수는 수로 견준다.
	var board := GoTable.make(
		[{"text": "Rank", "width": 48}, {"text": "Name"}, {"text": "Score", "numeric": true}],
		[[1, "Aria", 91240], [2, "Brin", 48210], [3, "Cade", 9124]])
	board.sort_by(2, false)
	board.row_selected.connect(func(index: int) -> void: _say("row %d" % index))
	body.add_child(board)

	var charts := GoStyle.wrap_row(GoUi.metric(GoTheme.GAP))
	var radar := GoRadar.make({"STR": 0.85, "AGI": 0.5, "INT": 0.3, "VIT": 0.7, "LUK": 0.45},
		{"STR": 0.6, "AGI": 0.75, "INT": 0.35, "VIT": 0.55, "LUK": 0.45})
	radar.custom_minimum_size = Vector2(150, 150)
	charts.add_child(radar)
	var donut := GoDonut.make([{"label": "Physical", "value": 620}, {"label": "Magic", "value": 340}])
	donut.center_text = "960"
	donut.center_hint = "Damage"
	donut.custom_minimum_size = Vector2(130, 130)
	charts.add_child(donut)
	body.add_child(charts)

	var days: Array = []
	for i in 7:
		days.append({"icon": GoIconSet.CROWN if i == 6 else GoIconSet.COIN,
			"amount": (i + 1) * 100, "special": i == 6})
	var calendar := GoRewardCalendar.make(days, 2)
	calendar.claimed.connect(func(day: int) -> void:
		calendar.set_claimed_until(day)
		_say("claimed day %d" % (day + 1)))
	body.add_child(calendar)

	var coupon := GoCodeInput.make(8, 4)
	coupon.completed.connect(func(code: String) -> void: _say("coupon %s" % code))
	body.add_child(coupon)

	body.add_child(GoStyle.alert(
		"Long-press the table rows for a context menu; every press here writes to Live activity.",
		GoTheme.WARNING))
	GoContextMenu.attach(board, [
		{"text": "Whisper", "action": _say.bind("whisper")},
		{"text": "Invite", "action": _say.bind("invite")},
		{"separator": true},
		{"text": "Block", "action": _say.bind("blocked"), "danger": true},
	])
	return card


func _card_activity() -> Control:
	var tone := GoUi.color(GoTheme.ACCENT)
	var card := GoStyle.card(tone)
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(body)
	body.add_child(_card_head("LIVE ACTIVITY", GoIconSet.BOLT, tone))
	# 🛑 빈 카드는 고장처럼 보인다 — 아직 아무 일도 없다는 것을 **말해 주는** 자리를 둔다.
	_log_empty = GoStyle.empty_state(GoIconSet.BOLT, "Press anything on this page", false)
	body.add_child(_log_empty)
	_log = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log.hide()
	body.add_child(_log)
	body.add_child(GoStyle.label("Every line is a real widget callback, not a script pretending.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	_guides.append({"target": card, "title": "Real widgets, real callbacks",
		"body": "Whatever you press on this page reports here — the same signal your game would connect."})
	return card


# ── ④ 조각들 ───────────────────────────────────────────────────────────

func _add_pieces(page: VBoxContainer) -> void:
	_add_heading(page, "03", "The pieces",
		"%d classes, grouped by the job they do. One line of code is usually the whole of it."
			% PIECES.size())
	for index in GROUPS.size():
		var group := GROUPS[index]
		var tone := GoUi.color(group["tone"])
		# 🔑 머리와 그 카드들은 **한 덩어리**다 — 구획 간격만큼 떨어지면 어느 머리에 딸린
		#    카드인지 눈으로 이어지지 않는다.
		var block := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
		page.add_child(block)

		var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
		head.add_child(_disc(StringName(group["icon"]), tone, 34, 17))
		var titles := GoStyle.column(2)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		titles.add_child(GoStyle.label(String(group["name"]), GoTheme.ROLE_BUTTON, tone))
		titles.add_child(GoStyle.label(String(group["note"]), GoTheme.ROLE_MICRO,
			GoUi.color(GoTheme.SECONDARY)))
		head.add_child(titles)
		block.add_child(head)

		var grid := GoStyle.responsive_grid(260, GoUi.metric(GoTheme.GAP_SMALL))
		for item in PIECES:
			if int(item["group"]) != index: continue
			grid.add_child(_piece_card(item, tone))
		block.add_child(grid)
		if index == 0:
			_guides.append({"target": grid, "title": "The whole surface",
				"body": "The gallery shows every one of these running; the guided tour explains them one at a time."})


func _piece_card(item: Dictionary, tone: Color) -> Control:
	var card := GoStyle.card()
	var body := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	card.add_child(body)
	body.add_child(GoStyle.label(String(item["name"]), GoTheme.ROLE_BUTTON, tone))
	body.add_child(GoStyle.label(String(item["note"]), GoTheme.ROLE_CAPTION,
		GoUi.color(GoTheme.SECONDARY)))
	body.add_child(GoStyle.divider())
	body.add_child(GoStyle.label(String(item["code"]), GoTheme.ROLE_MICRO,
		GoUi.color(GoTheme.MUTED)))
	return card


# ── ⑤ 다음 걸음 ────────────────────────────────────────────────────────

func _add_next(page: VBoxContainer) -> void:
	_add_heading(page, "04", "Where to go next",
		"Everything on this page is a file you can open and change.")
	var grid := GoStyle.responsive_grid(340, GoUi.metric(GoTheme.GAP))
	page.add_child(grid)
	for spec in [
		{"icon": GoIconSet.BOOK, "tone": GoTheme.ACCENT, "title": "README.md",
			"note": "The whole API, class by class, with the reasoning behind each rule."},
		{"icon": GoIconSet.MAP, "tone": GoTheme.INFO, "title": "docs/",
			"note": "Guides: theming, skins, icon sets, layout and the design loop."},
		{"icon": GoIconSet.BOX, "tone": GoTheme.WARNING, "title": "addons/gohud/examples",
			"note": "The source of every screen here — the gallery is the shortest read."},
		{"icon": GoIconSet.BOLT, "tone": GoTheme.SUCCESS, "title": "/gohud features",
			"note": "In Claude Code: one line per feature, with a link into the details."},
	]:
		var tone := GoUi.color(spec["tone"])
		var card := GoStyle.card()
		var body := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
		card.add_child(body)
		var head := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
		head.add_child(GoUi.icons().node(StringName(spec["icon"]),
			GoUi.metric(GoTheme.LIST_GLYPH), tone))
		var name := GoStyle.label(String(spec["title"]), GoTheme.ROLE_BUTTON, tone)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		body.add_child(head)
		body.add_child(GoStyle.label(String(spec["note"]), GoTheme.ROLE_CAPTION,
			GoUi.color(GoTheme.SECONDARY)))
		grid.add_child(card)

	var foot := GoStyle.label(
		"gohud " + GoUi.VERSION + "   ·   MIT   ·   github.com/thruthesky/gohud",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(foot)


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


# ── 작은 부품들 ────────────────────────────────────────────────────────

## 번호 배지가 붙은 구획 제목. 🔑 번호가 있으면 긴 페이지에서 **어디쯤인지**가 늘 보인다.
func _add_heading(page: VBoxContainer, number: String, title: String, note: String) -> void:
	var accent := GoUi.color(GoTheme.ACCENT)
	var head := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	head.add_child(GoStyle.divider())
	var line := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	var badge := GoStyle.chip(number, accent)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(badge)
	var name := GoStyle.label(title, GoTheme.ROLE_SUBTITLE)
	GoStyle.natural_width(name)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name)
	head.add_child(line)
	head.add_child(GoStyle.label(note, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY)))
	page.add_child(head)


## 카드 안쪽의 머리 줄 — 작은 아이콘, 의미색 이름, 그 아래 구분선.
func _card_head(title: String, icon: StringName, tone: Color) -> Control:
	var wrap := GoStyle.column(GoUi.metric(GoTheme.GAP_TINY))
	var line := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	line.add_child(GoUi.icons().node(icon, GoUi.metric(GoTheme.LIST_GLYPH), tone))
	var name := GoStyle.label(title, GoTheme.ROLE_MICRO, tone)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name)
	wrap.add_child(line)
	wrap.add_child(GoStyle.divider())
	return wrap


## 한 줄에 이름표와 선택기를 함께 놓기에 **모자란 폭**인가.
func _is_narrow() -> bool:
	var window := get_window()
	if window == null: return false
	return GoSafeArea.usable_rect(window).size.x < 640.0


## 아이콘 한 개를 담은 **동그란 판**. 스킨의 원판을 그대로 쓰므로 각진 테마에서도 어울린다.
func _disc(icon: StringName, tone: Color, diameter: int, glyph: int) -> Control:
	var disc := PanelContainer.new()
	disc.name = "Disc"
	disc.custom_minimum_size = Vector2(diameter, diameter)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override(&"panel", GoStyle.disc(diameter, tone))
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(centre)
	centre.add_child(GoUi.icons().node(icon, glyph, tone))
	return disc


func _bar(title: String, ink: StringName, value: float, maximum: float) -> GoBar:
	var bar := GoBar.new()
	bar.label_text = title
	bar.ink = GoUi.color(ink)
	bar.set_values(value, maximum, false)
	return bar


## 카드 버튼 위의 내용이 마우스를 가로채지 않게 — 누르는 것도 올림 판을 켜는 것도 카드다.
func _pass_through(node: Node) -> void:
	GoStyle.let_input_through(node)
	for child in node.get_children(): _pass_through(child)


# ── 만져 봤을 때 ───────────────────────────────────────────────────────

func _say(what: String) -> void:
	GoFeedback.tapped()
	if not is_instance_valid(_log): return
	if is_instance_valid(_log_empty) and _log_empty.visible:
		_log_empty.hide()
		_log.show()
	_history.push_front("→ " + what)
	if _history.size() > 4: _history.resize(4)
	_log.text = "\n".join(_history)


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


# ── 배경 ───────────────────────────────────────────────────────────────

## 본문 뒤에 까는 한 장. 격자는 화면에 **자를 대 주고**, 번짐 두 점은 위아래를 구분해 준다.
## 🛑 색은 밖에서 받는다 — 테마가 바뀌면 배경도 같이 바뀌어야 한다.
class Backdrop extends Control:
	const CELL := 44.0
	const RINGS := 26

	var base := Color.BLACK
	var grid := Color.TRANSPARENT
	var glow := Color.TRANSPARENT
	var spark := Color.TRANSPARENT


	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)


	func _draw() -> void:
		var view := size
		if view.x <= 0.0 or view.y <= 0.0: return
		draw_rect(Rect2(Vector2.ZERO, view), base)
		_bloom(Vector2(view.x * 0.16, -view.y * 0.10), maxf(view.x, view.y) * 0.72, glow)
		_bloom(Vector2(view.x * 0.94, view.y * 1.04), maxf(view.x, view.y) * 0.55, spark)
		var x := CELL
		while x < view.x:
			draw_line(Vector2(x, 0.0), Vector2(x, view.y), grid, 1.0)
			x += CELL
		var y := CELL
		while y < view.y:
			draw_line(Vector2(0.0, y), Vector2(view.x, y), grid, 1.0)
			y += CELL


	## 동심원을 겹쳐 만드는 번짐. 🔑 셰이더도 그라디언트 텍스처도 없이 어느 렌더러에서나 같다.
	func _bloom(centre: Vector2, radius: float, ink: Color) -> void:
		if ink.a <= 0.0: return
		for step in RINGS:
			var ratio := 1.0 - float(step) / float(RINGS)
			draw_circle(centre, radius * ratio, Color(ink, 0.006))
