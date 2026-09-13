## ▶️ **gohud 데모 — 스스로 돌기도 하고, 손으로 만지기도 한다.**
##
## 두 가지 길이 있다.
##   **Tour**    시작을 누르면 열다섯 장면을 차례로 지난다. 장면마다 화면을 새로 짓고, 봇이 그
##               위젯을 실제로 누르고·치고·끌고·굴린다(`SimBot`).
##   **Explore** 왼쪽 사이드바에서 위젯 하나를 고르면 그 장면만 짓고 **사람이 직접** 만진다.
##               오른쪽 "Play this widget" 을 누르면 같은 화면 위에서 봇이 그 장면만 시연한다.
##
## ```
## godot                       # 이 폴더에서
## ```
##
## 왼쪽이 위젯 목록, 가운데가 무대(폰 한 대 폭), 오른쪽이 **위젯이 실제로 부른 콜백의 기록**과
## 지금 보는 위젯의 설명이다. 기록줄이 움직인다는 것은 그림이 아니라 진짜로 눌렸다는 뜻이다 —
## 봇이 눌러도, 사람이 눌러도 같은 줄이 움직인다.
##
## 진행 중: `Space` 멈춤·이어가기 · `←` `→` 장면 이동 · `Esc` 처음으로
## 탐색 중: `←` `→` 이전·다음 위젯 · `Space` 이 위젯 시연 · `Esc` 처음으로
extends Control

const ACCENT := Color("#71d9e9")
const VIOLET := Color("#8b7cf6")
const GREEN := Color("#81dcb0")
const BG := Color("#0b111e")
const PANEL := Color("#121c2b")
const SUBTITLE_INK := Color("#afbbce")
const NARROW := 1080.0          ## 이보다 좁으면 사이드바·기록을 접고 상단 메뉴로 고른다
const LOG_LINES := 9
const SIDE_WIDTH := 236.0
const PANEL_WIDTH := 256.0

var _acts := SimActs.new()
var _entries: Array[Dictionary] = []
var _bot: SimBot
var _stage: SimStage

var _side_box: Control            ## 왼쪽 위젯 목록
var _side_scroll: GoScroll
var _rows: Array[Button] = []
var _row_labels: Array[Label] = []
var _play_all: Button
var _log_box: Control             ## 오른쪽 기록·소개
var _log: VBoxContainer
var _log_empty: Control
var _about_icon_holder: CenterContainer
var _about_title: Label
var _about_note: Label
var _about_hint: Label
var _play_one: Button
var _caption: Label
var _caption_icon_holder: Control
var _caption_card: Control
var _journey: HBoxContainer
var _tag: Label
var _counter: Label
var _mode_chip: PanelContainer
var _mode_label: Label
var _progress: ProgressBar
var _pause_button: Button
var _rate_button: Button
var _cinema_button: Button
var _picker: MenuButton           ## 좁은 창에서 사이드바를 대신하는 위젯 메뉴
var _cover: Control               ## 시작·완료 화면
var _cover_card: Control
var _controls: HBoxContainer
var _top: VBoxContainer
var _brand: HBoxContainer
var _gutters: Array[Control] = []

var _index := 0
var _first := 0
var _last := 0
var _jump := 0
var _running := false
var _return_home := false
var _completed := 0
var _explore := -1                ## 탐색 중인 장면. -1 이면 탐색 중이 아니다
var _pending_explore := -1        ## 투어를 접은 뒤 열 장면
var _scaling := false
var _cinema := false
var _counting_down := false
signal tour_finished
signal chapter_finished(index: int)


## 명령줄에서 자동으로 돌린다 — 검사와 화면 녹화에 쓴다.
##   godot -- --auto            시작 버튼을 대신 눌러 준다
##   godot -- --auto --turbo    네 배속으로
##   godot -- --auto --exit     다 보고 나면 스스로 닫는다
##   godot -- --explore=hud     그 위젯을 탐색 모드로 바로 연다
var _auto_exit := false
var _trace := false
var _shot_dir := ""


func _ready() -> void:
	_cinema = OS.get_cmdline_user_args().has("--cinema")
	_configure()
	_entries = SimActs.list()
	_build()
	_show_intro()
	var args := OS.get_cmdline_user_args()
	_auto_exit = args.has("--exit")
	_trace = args.has("--trace")
	var explore_key := ""
	for arg in args:
		if arg.begins_with("--shots="): _shot_dir = arg.substr(8)
		if arg.begins_with("--explore="): explore_key = arg.substr(10)
	if not _shot_dir.is_empty(): DirAccess.make_dir_recursive_absolute(_shot_dir)
	_bot.verify = _trace or args.has("--verify")
	if args.has("--cinema"): _cinema = true
	if args.has("--turbo"): _set_speed(4.0)
	if args.has("--fullscreen"): _toggle_fullscreen()
	if _cinema: _show_intro()
	if args.has("--auto"): _auto_start.call_deferred()
	elif not explore_key.is_empty(): _open_explore.call_deferred(maxi(0, index_of(StringName(explore_key))))
	_relayout.call_deferred()


## 설정 한 장이 화면 전체의 모습을 정한다.
func _configure() -> void:
	TranslationServer.set_locale("en")
	Input.use_accumulated_input = false
	var window := get_window()
	if DisplayServer.get_name() == "headless" and window.size == Vector2i(64, 64):
		window.size = Vector2i(1680, 940)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if OS.has_feature("movie") else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.size_changed.connect(_scale_window)
	_scale_window()
	var settings := GoConfig.new()
	var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: ACCENT, GoTheme.SUCCESS: GREEN}
	settings.color_overrides = colors
	settings.base_font_size = 18
	settings.metric_overrides = {GoTheme.BUTTON_HEIGHT: 54, GoTheme.GAP: 14}
	colors[GoTheme.MUTED] = Color("#91a1b8")
	colors[GoTheme.SECONDARY] = SUBTITLE_INK
	settings.color_overrides = colors
	GoUi.config = settings


func _scale_window() -> void:
	if _scaling: return
	_scaling = true
	var window := get_window()
	if OS.has_feature("movie"):
		window.content_scale_size = Vector2i(1920, 1080)
		window.content_scale_factor = 1.5
		_scaling = false
		return
	var factor := GoScale.display_scale(DisplayServer.screen_get_scale(),
		DisplayServer.screen_get_dpi(), DisplayServer.screen_get_size())
	var logical := Vector2(window.size) / factor
	# Desktop presentation uses a reference canvas: enlarging the window enlarges
	# the entire UI. Narrow windows keep a responsive layout with readable text.
	if logical.x > logical.y:
		window.content_scale_size = Vector2i(1280, 720) if _cinema else Vector2i(1280, 800)
		window.content_scale_factor = 1.0
	else:
		window.content_scale_size = window.size
		window.content_scale_factor = factor
	_scaling = false


## 장면 키 → 차례. 모르는 키는 -1.
func index_of(key: StringName) -> int:
	for index in _entries.size():
		if _entries[index].key == key: return index
	return -1


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), BG)
	# 은은한 점 격자 — 무대가 허공에 뜬 것처럼 보이지 않게 바닥의 질감을 준다.
	var step := 36.0
	var dot := Color(ACCENT, 0.05)
	var x := 18.0
	while x < view.x:
		var y := 18.0
		while y < view.y:
			draw_circle(Vector2(x, y), 1.1, dot)
			y += step
		x += step
	# 두 개의 부드러운 광원: 왼쪽 위는 강조색, 오른쪽 아래는 보라.
	_glow(Vector2(view.x * 0.16, view.y * 0.10), 380.0, ACCENT)
	_glow(Vector2(view.x * 0.88, view.y * 0.94), 340.0, VIOLET)


func _glow(center: Vector2, radius: float, color: Color) -> void:
	for ring in range(16, 0, -1):
		draw_circle(center, radius * float(ring) / 16.0, Color(color, 0.0028))


# ── 화면 ───────────────────────────────────────────────────────────────

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GoUi.theme()
	resized.connect(_relayout)

	var margin := GoStyle.padding(18)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var page := GoStyle.column(12)
	margin.add_child(page)

	page.add_child(_top_bar())

	var middle := GoStyle.row(16)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(middle)

	_side_box = _side_panel()
	middle.add_child(_side_box)
	_stage = SimStage.new()
	_stage.leave_requested.connect(_leave_explore)
	var left_gap := GoStyle.spacer()
	middle.add_child(left_gap)
	middle.add_child(_stage)
	var right_gap := GoStyle.spacer()
	middle.add_child(right_gap)
	_gutters = [left_gap, right_gap]
	_log_box = _log_panel()
	middle.add_child(_log_box)

	page.add_child(_caption_bar())

	_bot = SimBot.new()
	_bot.set_ink(ACCENT)
	_bot.said.connect(_on_said)
	_bot.logged.connect(_on_logged)
	_bot.shortcut.connect(_on_shortcut)
	add_child(_bot)


func _panel_box(color := PANEL, radius := 14, inset := 16) -> StyleBoxFlat:
	var surface := StyleBoxFlat.new()
	surface.bg_color = color
	surface.border_color = Color("#22334a")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(radius)
	surface.set_content_margin_all(inset)
	return surface


## 강조색 원판 위의 아이콘 — 로고 마크와 소개 패널이 쓴다.
func _icon_disc(icon: StringName, diameter: int, color := ACCENT) -> PanelContainer:
	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(diameter, diameter)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_theme_stylebox_override(&"panel", GoStyle.disc(diameter, color, 0.18, 0.55))
	var center := CenterContainer.new()
	disc.add_child(center)
	center.add_child(GoUi.icons().node(icon, int(diameter * 0.5), color))
	return disc


func _top_bar() -> Control:
	_top = GoStyle.column(6)
	var frame := PanelContainer.new()
	var surface := _panel_box(PANEL, 14, 10)
	surface.content_margin_left = 14
	surface.content_margin_right = 14
	frame.add_theme_stylebox_override(&"panel", surface)
	_top.add_child(frame)
	var brand := GoStyle.row(10)
	brand.custom_minimum_size.y = 40
	_brand = brand
	frame.add_child(brand)
	brand.add_child(_icon_disc(GoIconSet.GRID, 32))
	var logo := GoStyle.label("gohud", GoTheme.ROLE_TITLE, Color.WHITE)
	GoStyle.natural_width(logo)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(logo)
	var version := GoStyle.chip("v" + GoUi.VERSION, ACCENT)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(version)
	_tag = GoStyle.label("WIDGET SHOWCASE", GoTheme.ROLE_CAPTION, SUBTITLE_INK)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tag.clip_text = true
	brand.add_child(_tag)

	_journey = GoStyle.row(12)
	_journey.size_flags_horizontal = Control.SIZE_SHRINK_END
	_journey.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(_journey)
	_mode_chip = GoStyle.chip("READY", SUBTITLE_INK)
	_mode_label = _mode_chip.get_child(0) as Label
	_mode_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_journey.add_child(_mode_chip)
	_progress = GoStyle.progress(ACCENT)
	_progress.custom_minimum_size = Vector2(120, 4)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.max_value = maxf(1.0, float(_entries.size()))
	for style in [&"background", &"fill"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color("#2a3c50") if style == &"background" else ACCENT
		rail.set_corner_radius_all(2)
		_progress.add_theme_stylebox_override(style, rail)
	_journey.add_child(_progress)
	_counter = GoStyle.label("", GoTheme.ROLE_COMPACT, SUBTITLE_INK)
	GoStyle.natural_width(_counter)
	_counter.custom_minimum_size.x = 72
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_journey.add_child(_counter)

	_controls = GoStyle.row(6)
	_controls.alignment = BoxContainer.ALIGNMENT_END
	_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	brand.add_child(_controls)
	var items: Array = []
	for entry in _entries: items.append({"text": entry.title, "icon": entry.icon})
	_picker = GoStyle.dropdown("Widgets", items, _open_explore)
	_picker.custom_minimum_size.y = GoUi.metric(GoTheme.TOUCH)
	_picker.tooltip_text = "Pick a widget to explore"
	_controls.add_child(_picker)
	_rate_button = GoStyle.button("1.0x", _cycle_speed, GoStyle.Tone.COMPACT)
	_rate_button.tooltip_text = "Playback speed"
	GoStyle.natural_width(_rate_button)
	_controls.add_child(_rate_button)
	_cinema_button = GoStyle.button("Cinema", _toggle_cinema, GoStyle.Tone.COMPACT)
	GoStyle.natural_width(_cinema_button)
	_cinema_button.tooltip_text = "C: toggle cinema mode"
	_controls.add_child(_cinema_button)
	for spec in [[GoIconSet.BACK, _previous, "Previous"],
			[GoIconSet.PAUSE, _toggle_pause, "Pause / resume"],
			[GoIconSet.FORWARD, _next, "Next"], [GoIconSet.CLOSE, _stop, "Back to start"]]:
		var button := GoStyle.icon_button(spec[0], spec[1])
		button.tooltip_text = spec[2]
		button.focus_mode = Control.FOCUS_NONE
		_controls.add_child(button)
		if spec[0] == GoIconSet.PAUSE: _pause_button = button
	return _top


func _side_panel() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", _panel_box(PANEL, 16, 12))
	card.custom_minimum_size.x = SIDE_WIDTH
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(column)

	var head := GoStyle.row(8)
	var heading := GoStyle.section("Widgets", false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(heading)
	var count := GoStyle.chip(str(_entries.size()), SUBTITLE_INK)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	column.add_child(head)

	_side_scroll = GoScroll.new()
	_side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_side_scroll)
	var list := GoStyle.column(2)
	_side_scroll.add_child(list)
	for index in _entries.size():
		var entry := _entries[index]
		var row := GoStyle.list_button(entry.icon, entry.title, _open_explore.bind(index),
			Color.TRANSPARENT, "", false)
		row.name = "Widget%02d" % (index + 1)
		row.focus_mode = Control.FOCUS_NONE
		row.tooltip_text = entry.note
		list.add_child(row)
		_rows.append(row)
		var labels := row.find_children("*", "Label", true, false)
		var label := labels[0] as Label if not labels.is_empty() else null
		if label != null:
			# 한 줄에 맞춘다 — 목록이 접히면 열다섯 개가 화면을 넘긴다.
			label.add_theme_font_size_override(&"font_size", 15)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.set_meta(&"go_no_wrap", true)
		_row_labels.append(label)

	column.add_child(GoStyle.divider())
	_play_all = GoStyle.button("Play the full tour", _start, GoStyle.Tone.PRIMARY)
	_play_all.name = "PlayAll"
	_play_all.custom_minimum_size.y = 46
	column.add_child(_play_all)
	column.add_child(GoStyle.label("Click a widget to try it yourself",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	return card


func _log_panel() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", _panel_box(PANEL, 16, 14))
	card.custom_minimum_size.x = PANEL_WIDTH
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	card.add_child(column)

	# 위: 지금 보는 위젯.
	var about := GoStyle.row(10)
	_about_icon_holder = CenterContainer.new()
	_about_icon_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	about.add_child(_about_icon_holder)
	var stack := GoStyle.column(2)
	_about_title = GoStyle.label("Pick a widget", GoTheme.ROLE_SUBTITLE, Color.WHITE)
	_about_title.add_theme_font_size_override(&"font_size", 21)
	stack.add_child(_about_title)
	_about_note = GoStyle.label("", GoTheme.ROLE_CAPTION, SUBTITLE_INK)
	stack.add_child(_about_note)
	about.add_child(stack)
	column.add_child(about)
	_about_hint = GoStyle.label("", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED))
	column.add_child(_about_hint)
	_play_one = GoStyle.button("Play this widget", _play_current, GoStyle.Tone.PRIMARY)
	_play_one.name = "PlayOne"
	_play_one.custom_minimum_size.y = 46
	column.add_child(_play_one)

	column.add_child(GoStyle.divider())

	# 아래: 콜백 기록.
	var head := GoStyle.row(8)
	var heading := GoStyle.section("Live activity", false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var pulse := GoUi.icons().node(GoIconSet.BOLT, 14, GREEN)
	pulse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pulse)
	column.add_child(head)
	column.add_child(GoStyle.label("Every line is a real widget callback.",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	_log = GoStyle.column(3)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_log)
	_log_empty = GoStyle.empty_state(GoIconSet.CHAT, "Nothing yet. Press, drag or type on the stage.", false)
	_log_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_log_empty)
	return card


func _caption_bar() -> Control:
	var center := CenterContainer.new()
	var card := PanelContainer.new()
	_caption_card = card
	card.custom_minimum_size.x = minf(920.0, size.x - 36.0)
	card.add_theme_stylebox_override(&"panel", _panel_box(Color("#141f30"), 14, 14))
	center.add_child(card)
	var row := GoStyle.row(14)
	card.add_child(row)
	_caption_icon_holder = CenterContainer.new()
	_caption_icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_caption_icon_holder)
	_set_caption_icon(GoIconSet.PLAY)
	_caption = GoStyle.label("Press Start and watch the guided demo, or pick a widget on the left.", GoTheme.ROLE_BODY)
	_caption.add_theme_font_size_override(&"font_size", 19)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_caption)
	return center


func _set_caption_icon(icon: StringName, color := ACCENT) -> void:
	for child in _caption_icon_holder.get_children(): child.queue_free()
	_caption_icon_holder.add_child(GoUi.icons().node(icon, 20, color))


## 좁은 창에서는 무대만 남긴다 — 폰 폭에서도 데모가 성립해야 한다. 위젯 고르기는 상단 메뉴가 맡는다.
func _relayout() -> void:
	var wide := size.x >= NARROW
	if is_instance_valid(_side_box): _side_box.visible = wide and not _cinema
	if is_instance_valid(_log_box): _log_box.visible = wide and not _cinema
	for gutter in _gutters: gutter.visible = wide
	if is_instance_valid(_stage):
		_stage.custom_minimum_size.x = (720.0 if _cinema else SimStage.WIDTH) if wide else maxf(0.0, size.x - 36.0)
		(_stage.get_parent() as HBoxContainer).add_theme_constant_override(&"separation", 12 if wide else 0)
	if is_instance_valid(_controls):
		var parent: Node = _brand if size.x >= 800.0 else _top
		if _controls.get_parent() != parent: _controls.reparent(parent)
		_controls.visible = not (_cinema and _running)
		_picker.visible = not wide or _cinema
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _cinema and _running else Input.MOUSE_MODE_VISIBLE
		_cinema_button.text = "Cinema on" if _cinema else "Cinema"
	# 폰 폭에서는 로고만 남긴다 — 진행 표시와 꼬리표까지 두면 글자가 잘린다.
	if is_instance_valid(_journey): _journey.visible = size.x >= 800.0
	if is_instance_valid(_tag): _tag.visible = size.x >= 640.0
	if is_instance_valid(_progress): _progress.visible = size.x >= 900.0
	if is_instance_valid(_mode_chip): _mode_chip.visible = size.x >= 900.0
	if is_instance_valid(_caption_card):
		_caption_card.custom_minimum_size.x = minf(920.0, size.x - 36.0)
		_caption.add_theme_font_size_override(&"font_size", 19 if size.x >= 800.0 else 16)
	if is_instance_valid(_cover_card): _cover_card.custom_minimum_size.x = minf(580.0, size.x - 36.0)
	queue_redraw()


# ── 시작·완료 화면 ─────────────────────────────────────────────────────

func _cover_screen() -> VBoxContainer:
	_drop_cover()
	_cover = Control.new()
	_cover.name = "Cover"
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	var veil := ColorRect.new()
	veil.color = Color(BG, 0.94)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(center)
	var card := GoStyle.card(ACCENT)
	card.custom_minimum_size.x = minf(580.0, size.x - 36.0)
	_cover_card = card
	center.add_child(card)
	var column := GoStyle.column(GoUi.metric(GoTheme.GAP))
	card.add_child(column)
	return column


func _drop_cover() -> void:
	if is_instance_valid(_cover):
		_cover.hide()
		_cover.queue_free()
	_cover = null


func _show_intro() -> void:
	_explore = -1
	_set_mode("READY", SUBTITLE_INK)
	_counter.text = ""
	_progress.value = 0
	_sync_marks()
	_sync_about()
	var column := _cover_screen()
	var eyebrow := GoStyle.row(8)
	eyebrow.add_child(_icon_disc(GoIconSet.GRID, 28))
	eyebrow.add_child(GoStyle.label("INTERACTIVE SHOWCASE", GoTheme.ROLE_CAPTION, ACCENT))
	column.add_child(eyebrow)
	var logo := Label.new()
	logo.text = "gohud"
	logo.add_theme_font_size_override(&"font_size", 68)
	logo.add_theme_color_override(&"font_color", Color.WHITE)
	column.add_child(logo)
	column.add_child(GoStyle.label("Your UI, in motion", GoTheme.ROLE_TITLE, ACCENT))
	column.add_child(GoStyle.label(
		"Watch a guided tour of %d widgets, or pick any widget and try it with your own hands. "
		% _entries.size()
		+ "Every click, drag and keystroke in the tour is real input.",
		GoTheme.ROLE_BODY, SUBTITLE_INK))
	column.add_child(GoStyle.divider())

	var speed_row := GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL))
	speed_row.add_child(GoStyle.label("Speed", GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.MUTED)))
	var rates := [0.7, 1.0, 1.6]
	speed_row.add_child(GoStyle.segmented(["Slow", "Normal", "Fast"], maxi(0, rates.find(_bot.speed)), func(index: int) -> void:
		_set_speed(rates[index])))
	speed_row.add_child(GoStyle.spacer())
	column.add_child(speed_row)
	var cinema := GoStyle.checkbox("Cinema mode · 3-second countdown", false)
	cinema.button_pressed = _cinema
	cinema.toggled.connect(func(on: bool) -> void:
		_cinema = on
		_scale_window()
		_relayout())
	column.add_child(cinema)

	var actions: BoxContainer = GoStyle.row(GoUi.metric(GoTheme.GAP_SMALL)) if size.x >= 560.0 \
		else GoStyle.column(GoUi.metric(GoTheme.GAP_SMALL))
	var start := GoStyle.button("Start demo", _start, GoStyle.Tone.PRIMARY)
	start.name = "Start"
	start.custom_minimum_size.y = 52
	actions.add_child(start)
	var explore := GoStyle.button("Explore widgets", _open_explore.bind(0))
	explore.name = "Explore"
	explore.custom_minimum_size.y = 52
	actions.add_child(explore)
	column.add_child(actions)
	column.add_child(GoStyle.label("Space: pause  ·  Arrows: navigate  ·  Esc: home  ·  C: cinema  ·  F11: fullscreen",
		GoTheme.ROLE_MICRO, GoUi.color(GoTheme.MUTED)))
	start.grab_focus()


func _show_outro() -> void:
	var column := _cover_screen()
	column.add_child(GoUi.icons().node(GoIconSet.SUCCESS, 48, GREEN))
	column.add_child(GoStyle.label("Tour complete", GoTheme.ROLE_TITLE))
	column.add_child(GoStyle.label(
		"You have explored the gohud widget kit. Replay the tour, or pick a widget and try it yourself.",
		GoTheme.ROLE_BODY, SUBTITLE_INK))
	column.add_child(GoStyle.divider())
	var again := GoStyle.button("Replay demo", _start, GoStyle.Tone.PRIMARY)
	again.custom_minimum_size.y = 48
	column.add_child(again)
	column.add_child(GoStyle.button("Explore widgets", _open_explore.bind(0)))
	column.add_child(GoStyle.button("Back to start", _show_intro, GoStyle.Tone.BARE))
	again.grab_focus()


# ── 진행 ───────────────────────────────────────────────────────────────

func _auto_start() -> void:
	await _bot.settle(0.1)
	await _bot.click(_cover.find_child("Start", true, false) as Control)


## 전체 투어.
func _start() -> void:
	if _running: return
	_explore = -1
	_clear_log()
	_completed = 0
	_start_range(0, _entries.size())


## 탐색 중인 장면 하나만 봇이 시연한다. 끝나면 같은 장면을 다시 지어 탐색으로 돌아온다.
func _clear_log() -> void:
	for child in _log.get_children():
		_log.remove_child(child)
		child.queue_free()
	_log_empty.visible = true


func _play_current() -> void:
	if _running or _explore < 0: return
	_start_range(_explore, _explore + 1)


func _start_range(from: int, to: int) -> void:
	if _running: return
	_drop_cover()
	_index = from
	_first = from
	_last = to
	_jump = 0
	_return_home = false
	_pending_explore = -1
	_bot.failures.clear()
	_bot.checks = 0
	_bot.paused = false
	_bot.rearm()
	_sync_pause()
	_begin()


func _begin() -> void:
	_running = true
	_relayout()
	_sync_about()
	if _cinema and _explore < 0:
		_counting_down = true
		var column := _cover_screen()
		column.add_child(GoStyle.label("Ready to record", GoTheme.ROLE_TITLE))
		var count := GoStyle.label("3", GoTheme.ROLE_TITLE, ACCENT)
		count.add_theme_font_size_override(&"font_size", 96)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(count)
		for number in [3, 2, 1]:
			count.text = str(number)
			await _bot.wait(_bot.speed)
			if _return_home or _bot.skipping(): break
		_counting_down = false
		_drop_cover()
	_run()


func _toggle_cinema() -> void:
	_cinema = not _cinema
	_scale_window()
	_relayout()


func _toggle_fullscreen() -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _run() -> void:
	_running = true
	_sync_pause()
	_set_mode("TOUR" if _explore < 0 else "PLAYING", ACCENT)
	while not _return_home and _index < _last:
		var entry := _entries[_index]
		_sync_marks()
		_sync_about()
		if _trace: print("[%02d] %s" % [_index + 1, entry.title])
		_stage.open("%02d" % (_index + 1), entry.title, entry.note)
		_on_said(entry.note)
		_set_caption_icon(GoIconSet.PLAY)
		_bot.rearm()
		var refs: Dictionary = _acts.build(entry.key, _stage, _bot)
		await _acts.play(entry.key, _stage, _bot, refs)
		_bot.rest()
		if not _bot.skipping():
			_completed += 1
			await _capture(_index + 1, entry.key)
		if _return_home: break
		var step := 1 if _jump == 0 else _jump
		_jump = 0
		_index = clampi(_index + step, _first, _last)
		_stage.clear()
		await _bot.wait(0.25)
	# Keep _running true until the old coroutine has unwound and its nodes are gone.
	_stage.clear()
	await get_tree().process_frame
	_bot.rest()
	_bot.rearm()
	_bot.paused = false
	_sync_pause()
	_running = false
	_relayout()
	if _pending_explore >= 0:
		var wanted := _pending_explore
		_pending_explore = -1
		_explore = -1
		_open_explore(wanted)
		return
	if _return_home:
		_stage.open("", "", "")
		_show_intro()
		return
	if _explore >= 0:
		var played := _explore
		_open_explore(played)
		chapter_finished.emit(played)
		return
	_stage.open("✓", "Complete", "")
	_index = _entries.size()
	_sync_marks()
	_counter.text = "%02d / %02d" % [_entries.size(), _entries.size()]
	_progress.value = float(_entries.size())
	_set_mode("DONE", GREEN)
	_show_outro()
	if _bot.verify:
		print("SIM RESULT: %d/%d chapters, %d checks, %d failures" % [
			_completed, _entries.size(), _bot.checks, _bot.failures.size()])
	tour_finished.emit()
	if _auto_exit:
		await _bot.wait(0.5)
		get_tree().quit(0 if _bot.failures.is_empty() else 1)


## 장면이 끝난 모습을 파일로 남긴다 — `--shots=<폴더>`. 눈으로 확인하는 가장 빠른 길이다.
func _capture(number: int, key: StringName) -> void:
	if _shot_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null: return
	image.save_png("%s/%02d-%s.png" % [_shot_dir, number, key])


# ── 탐색 ───────────────────────────────────────────────────────────────

## 🔑 장면 하나를 짓고 사람에게 맡긴다. 투어 중이면 투어를 접은 뒤 연다.
func _open_explore(index: int) -> void:
	index = clampi(index, 0, _entries.size() - 1)
	if _running:
		_pending_explore = index
		_return_home = true
		_bot.paused = false
		_bot.skip()
		return
	_drop_cover()
	_stage.clear()
	if _explore != index: _clear_log()
	_explore = index
	_index = index
	var entry := _entries[index]
	_stage.open("%02d" % (index + 1), entry.title, entry.note)
	_bot.rearm()
	_acts.build(entry.key, _stage, _bot)
	_set_mode("EXPLORE", GREEN)
	_sync_marks()
	_sync_about()
	_sync_pause()
	_set_caption_icon(GoIconSet.TARGET, GREEN)
	_on_said(entry.hint)
	_relayout()


## 화면 전체를 덮는 장면에서 "위젯 목록으로" — 무대를 비우고 사이드바를 다시 드러낸다.
func _leave_explore() -> void:
	if _running: return
	_stage.clear()
	_stage.open("", "", "")
	_explore = -1
	_set_mode("EXPLORE", GREEN)
	_sync_marks()
	_sync_about()
	_set_caption_icon(GoIconSet.LIST, GREEN)
	_on_said("Pick a widget from the list on the left.")


func _next() -> void:
	if _counting_down: return
	if not _running:
		if not is_instance_valid(_cover): _open_explore(_explore + 1 if _explore >= 0 else 0)
		return
	_jump = 1
	_bot.paused = false
	_sync_pause()
	_bot.skip()


func _previous() -> void:
	if _counting_down: return
	if not _running:
		if not is_instance_valid(_cover): _open_explore(_explore - 1 if _explore >= 0 else 0)
		return
	_jump = -1
	_bot.paused = false
	_sync_pause()
	_bot.skip()


func _stop() -> void:
	if not _running:
		_stage.clear()
		_stage.open("", "", "")
		_show_intro()
		return
	_return_home = true
	_bot.paused = false
	_bot.skip()


## 상단의 ▶/⏸ — 투어 중에는 멈춤·이어가기, 탐색 중에는 "이 위젯 시연". 폰처럼 오른쪽 패널이 접힌
## 화면에서는 이것이 시연을 시작하는 유일한 버튼이다.
func _toggle_pause() -> void:
	if not _running:
		if _explore >= 0 and not is_instance_valid(_cover): _play_current()
		return
	_bot.paused = not _bot.paused
	_sync_pause()


func _sync_pause() -> void:
	if not is_instance_valid(_pause_button): return
	var show_play := _bot.paused or not _running
	(_pause_button as GoIconButton).set_icon_name(GoIconSet.PLAY if show_play else GoIconSet.PAUSE)
	_pause_button.tooltip_text = "Play this widget" if not _running and _explore >= 0 else "Pause / resume"


func _cycle_speed() -> void:
	var rates := [1.0, 1.6, 2.4, 0.7]
	var at := rates.find(snappedf(_bot.speed, 0.1))
	_set_speed(rates[(at + 1) % rates.size()] if at >= 0 else 1.0)


func _set_speed(value: float) -> void:
	_bot.speed = value
	if is_instance_valid(_rate_button): _rate_button.text = "%.1fx" % value


func _set_mode(text: String, color: Color) -> void:
	if not is_instance_valid(_mode_chip): return
	_mode_label.text = text
	_mode_chip.add_theme_stylebox_override(&"panel", GoUi.skin().chip_box(color))
	_mode_label.add_theme_color_override(&"font_color", GoUi.skin().chip_ink(color))


## 사이드바·진행·번호를 현재 장면에 맞춘다.
func _sync_marks() -> void:
	var touring := _running and _explore < 0
	var active := _index if (_running or _explore >= 0) and _index < _entries.size() else -1
	if active >= 0:
		_counter.text = "%02d / %02d" % [active + 1, _entries.size()]
		_progress.value = float(active + 1)
	for index in _rows.size():
		var row := _rows[index]
		var label := _row_labels[index]
		if index == active:
			row.add_theme_stylebox_override(&"normal", _row_box(0.18))
			row.add_theme_stylebox_override(&"hover", _row_box(0.24))
			row.add_theme_stylebox_override(&"pressed", _row_box(0.30))
			if label != null: label.add_theme_color_override(&"font_color", Color.WHITE)
			_reveal_row(row)
		else:
			for state in [&"normal", &"hover", &"pressed"]: row.remove_theme_stylebox_override(state)
			if label != null:
				if touring and index < _index: label.add_theme_color_override(&"font_color", GREEN)
				else: label.remove_theme_color_override(&"font_color")


## 목록 행의 높이는 다음 프레임에야 정해진다 — 두 프레임 뒤에 굴린다.
func _reveal_row(row: Control) -> void:
	if not is_instance_valid(_side_scroll) or not _side_scroll.is_inside_tree(): return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(row) and is_instance_valid(_side_scroll) and row.is_visible_in_tree():
		_side_scroll.ensure_control_visible(row)


func _row_box(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ACCENT, alpha)
	box.border_color = ACCENT
	box.border_width_left = 3
	box.set_corner_radius_all(GoUi.metric(GoTheme.RADIUS_SMALL))
	return box


## 오른쪽 소개 패널을 현재 장면에 맞춘다.
func _sync_about() -> void:
	if not is_instance_valid(_about_title): return
	for child in _about_icon_holder.get_children(): child.queue_free()
	var index := _index if (_running or _explore >= 0) and _index < _entries.size() else -1
	if index < 0:
		_about_icon_holder.add_child(_icon_disc(GoIconSet.LIST, 40, SUBTITLE_INK))
		_about_title.text = "Pick a widget"
		_about_note.text = "Choose one on the left, or play the full tour."
		_about_hint.text = ""
		_about_hint.visible = false
		_play_one.visible = false
		return
	var entry := _entries[index]
	_about_icon_holder.add_child(_icon_disc(entry.icon, 40, GREEN if _explore >= 0 and not _running else ACCENT))
	_about_title.text = entry.title
	_about_note.text = entry.note
	_about_hint.visible = true
	_play_one.visible = true
	if _running:
		_about_hint.text = "The bot is driving this widget with real input." if _explore < 0 \
			else "The bot is demonstrating this widget. Press Escape or ✕ to take over again."
		_play_one.text = "Playing..."
		_play_one.disabled = true
	else:
		_about_hint.text = "Try it: " + entry.hint
		_play_one.text = "Play this widget"
		_play_one.disabled = false


func _on_said(text: String) -> void:
	if text.is_empty() or not is_instance_valid(_caption): return
	_caption.text = text
	_caption.modulate.a = 0.35
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.2)


func _on_logged(text: String) -> void:
	if not is_instance_valid(_log): return
	if _trace: print("      → %s" % text)
	var line := GoStyle.row(6)
	var mark := GoUi.icons().node(GoIconSet.CHEVRON_RIGHT, 12, GREEN)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(mark)
	var label := GoStyle.label(text, GoTheme.ROLE_CAPTION, GREEN)
	label.add_theme_font_size_override(&"font_size", 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	_log.add_child(line)
	_log_empty.visible = false
	if not GoUi.config.reduce_motion:
		line.modulate.a = 0.0
		create_tween().tween_property(line, "modulate:a", 1.0, 0.18)
	while _log.get_child_count() > LOG_LINES:
		var oldest := _log.get_child(0)
		_log.remove_child(oldest)
		oldest.queue_free()


## 글을 치는 칸이 포커스를 쥐고 있는가 — 탐색 중에는 그 키를 위젯에 양보한다.
func _typing() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


# 🛑 `keycode` 로만 본다 — 봇이 글을 칠 때 보내는 키는 `unicode` 만 실은 것이라 여기 걸리지 않는다.
func _on_shortcut(event: InputEvent) -> void:
	if event.has_meta(&"simulated"): return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo: return
	if key.keycode == KEY_F11:
		_toggle_fullscreen()
		accept_event()
		return
	if key.keycode == KEY_C and not (_explore >= 0 and _typing()):
		_toggle_cinema()
		accept_event()
		return
	if not _running:
		# 시작 화면이 떠 있으면 키는 그 화면의 버튼이 받는다. 탐색 중이거나 빈 무대면 여기서 듣는다.
		if is_instance_valid(_cover): return
		if key.keycode == KEY_ESCAPE:
			_stop()
			accept_event()
			return
		if _typing(): return
		match key.keycode:
			KEY_SPACE:
				_play_current()
				accept_event()
			KEY_RIGHT:
				_next()
				accept_event()
			KEY_LEFT:
				_previous()
				accept_event()
		return
	match key.keycode:
		KEY_SPACE:
			_toggle_pause()
			accept_event()
		KEY_RIGHT:
			_next()
			accept_event()
		KEY_LEFT:
			_previous()
			accept_event()
		KEY_ESCAPE:
			_stop()
			accept_event()
