## gohud 데모 — 홍보 이미지의 화면을 애드온 위젯만으로 그대로 만든 것.
##
## 카드 6장(HUD·버튼·대화상자·알림·터치·테마)이 한 화면에 있고, 전부 실제로 동작한다.
## 배경 격자와 제목 줄 말고는 새로 그린 것이 없다 — 나머지는 gohud 가 주는 그대로다.
extends Control

const ThemePicker := preload("theme_picker.gd")

var _accent := ACCENT
var _green := GREEN
var _bg := BG
var _grid_ink := GRID_INK
var _subtitle_ink := SUBTITLE_INK

const ACCENT := Color("#29b8f0")     ## 강조색 — 이 한 값이 화면 전체를 물들인다
const GREEN := Color("#3ee08f")      ## 체력·성공
const BG := Color("#06131f")
const GRID_INK := Color("#0f2b41")
const SUBTITLE_INK := Color("#8fb8d4")

var _volume_label: Label
var _hp: GoBar

## 언어 카드에 쓰는 자기표기. 🛑 영어 이름("Korean")이 아니라 **그 언어가 스스로를 부르는 말**이다 —
##    한국어를 찾는 사람은 "한국어" 를 찾는다. 애드온은 언어 이름을 담지 않으므로 데모가 들고 있다.
const LANGUAGE_NAMES := {
	"en": "English", "ko": "한국어", "ja": "日本語", "zh": "中文", "zh_TW": "繁體中文",
	"es": "Español", "pt": "Português", "de": "Deutsch", "fr": "Français", "it": "Italiano",
	"nl": "Nederlands", "pl": "Polski", "ru": "Русский", "uk": "Українська", "tr": "Türkçe",
	"vi": "Tiếng Việt", "id": "Bahasa Indonesia", "th": "ไทย", "hi": "हिन्दी",
	"ar": "العربية", "he": "עברית",
}
## 오른쪽에서 왼쪽으로 읽는 언어. 그 칸만 방향을 뒤집는다.
const RTL_LANGUAGES := ["ar", "he"]


func _ready() -> void:
	_configure()
	_build()


## 설정 한 장으로 전체 모습을 정한다.
func _configure() -> void:
	var settings := GoConfig.new()
	var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: ACCENT, GoTheme.SUCCESS: GREEN}
	settings.color_overrides = colors
	settings.base_font_size = 15
	ThemePicker.configure(settings, colors)
	_accent = GoUi.color(GoTheme.ACCENT)
	_green = GoUi.color(GoTheme.SUCCESS)
	_bg = BG if ThemePicker.active_preset == GoThemePresets.DEFAULT_DARK else GoUi.color(GoTheme.BACKGROUND)
	_grid_ink = GRID_INK if ThemePicker.active_preset == GoThemePresets.DEFAULT_DARK else GoUi.color(GoTheme.BORDER)
	_subtitle_ink = SUBTITLE_INK if ThemePicker.active_preset == GoThemePresets.DEFAULT_DARK else GoUi.color(GoTheme.SECONDARY)


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), _bg)
	for x in range(0, int(view.x), 42):
		draw_line(Vector2(x, 0), Vector2(x, view.y), Color(_grid_ink, 0.55), 1.0)
	for y in range(0, int(view.y), 42):
		draw_line(Vector2(0, y), Vector2(view.x, y), Color(_grid_ink, 0.55), 1.0)
	for spot in [Vector2(60, 40), Vector2(view.x - 60, 40),
			Vector2(60, view.y - 46), Vector2(view.x - 60, view.y - 46)]:
		draw_line(spot - Vector2(8, 0), spot + Vector2(8, 0), Color(_accent, 0.30), 1.5)
		draw_line(spot - Vector2(0, 8), spot + Vector2(0, 8), Color(_accent, 0.30), 1.5)


func _build() -> void:
	theme = GoUi.theme()
	var toolbar := GoStyle.padding(16)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(toolbar)
	var choices := GoStyle.row(12)
	toolbar.add_child(choices)
	var label := GoStyle.label("Theme", GoTheme.ROLE_CAPTION)
	GoStyle.natural_width(label)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choices.add_child(label)
	var picker := ThemePicker.new()
	picker.theme_selected.connect(_change_theme)
	choices.add_child(picker)
	var scroll := GoScroll.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 80
	add_child(scroll)
	var margin := GoStyle.padding(34)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var page := GoStyle.column(22)
	margin.add_child(page)
	page.add_child(_header())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 18)
	page.add_child(grid)

	_hud_card(grid)
	_input_card(grid)
	_dialog_card(grid)
	_notice_card(grid)
	_touch_card(grid)
	_theme_card(grid)
	_selection_card(grid)
	_data_card(grid)
	_states_card(grid)

	page.add_child(_language_card())

	var footer := GoStyle.label("Godot 4.6+    /    Pure GDScript    /    MIT license",
		GoTheme.ROLE_CAPTION, _subtitle_ink)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(footer)


# ── 10 Languages — 화면 전체 폭 ────────────────────────────────────────

## 내장 문구를 21개 언어로 한 장에 늘어놓는다. 카드가 두 가지를 한눈에 보여 준다 —
##   ① 번역이 실제로 붙었는가(키가 그대로 보이면 `.translation` 이 안 붙은 것이다)
##   ② **글자가 그려지는가** — 🛑 gohud 는 폰트를 담지 않으므로, 태국어·아랍어·히브리어·
##      데바나가리·CJK 는 호스트 프로젝트의 테마 폰트가 글리프를 덮어야 한다. 없으면 두부(□)가
##      뜨고 **오류는 나지 않는다.** 그래서 이 카드가 폰트 커버리지 점검표 역할을 한다.
func _language_card() -> Control:
	var card := GoStyle.card(_accent)
	var body := GoStyle.padding(20)
	card.add_child(body)
	var column := GoStyle.column(14)
	body.add_child(column)

	var head := GoStyle.row(10)
	head.add_child(_badge("10"))
	var titles := GoStyle.column(2)
	titles.add_child(GoStyle.label("%d built-in languages" % GoUi.LOCALES.size(), GoTheme.ROLE_TITLE))
	titles.add_child(GoStyle.label("Every cell is drawn by the host font — an empty box means a missing glyph, not a missing translation.",
		GoTheme.ROLE_CAPTION, _subtitle_ink))
	head.add_child(titles)
	column.add_child(head)
	column.add_child(GoStyle.divider())

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 12)
	# 🛑 로케일을 갈아 가며 문구를 읽는다 — 읽은 뒤 원래 로케일로 되돌린다.
	#    각 칸은 `auto_translate_mode = DISABLED` 라, 뒤에 언어가 바뀌어도 그 언어 문구를 유지한다.
	var before := TranslationServer.get_locale()
	for locale: String in GoUi.LOCALES:
		TranslationServer.set_locale(locale)
		grid.add_child(_language_cell(locale))
	TranslationServer.set_locale(before)
	column.add_child(grid)
	return card


const CELL_WIDTH := 150

func _language_cell(locale: String) -> Control:
	var cell := GoStyle.column(3)
	# 🛑 이 칸의 글은 **그 언어로 고정**한다 — 엔진이 현재 언어로 다시 번역하면 21칸이 한 언어가 된다.
	cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if locale in RTL_LANGUAGES:
		cell.layout_direction = Control.LAYOUT_DIRECTION_RTL

	cell.add_child(_language_line(locale, GoTheme.ROLE_CAPTION, _accent))
	cell.add_child(_language_line(String(LANGUAGE_NAMES.get(locale, locale)), GoTheme.ROLE_BODY))
	cell.add_child(_language_line(tr("gohud_confirm"), GoTheme.ROLE_SUBTITLE, _subtitle_ink))
	cell.add_child(_language_line(tr("gohud_empty"), GoTheme.ROLE_CAPTION, _subtitle_ink))
	return cell


## 🛑 모든 줄을 같은 폭으로 묶고 줄바꿈을 켠다. 그러지 않으면 긴 문구 하나가 그 열을 넓히고
##    ("Bahasa Indonesia" · "Burada henüz bir şey yok"), 21칸이 화면 밖으로 밀려 나간다 —
##    2560px 에서도 마지막 열이 잘렸다(2026-09-13 스크린샷 실측).
func _language_line(text: String, role: StringName, ink := Color.TRANSPARENT) -> Label:
	var line := GoStyle.label(text, role, ink)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CELL_WIDTH
	line.size_flags_horizontal = Control.SIZE_FILL
	return line


# ── 머리글 ─────────────────────────────────────────────────────────────

func _header() -> Control:
	var row := GoStyle.row(26)

	var logo := Label.new()
	logo.text = "gohud"
	logo.add_theme_font_size_override(&"font_size", 68)
	logo.add_theme_color_override(&"font_color", Color.WHITE)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)

	var block := GoStyle.column(4)
	block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 🛑 `[b]` 로 감싼 글은 normal_font_size 가 아니라 bold_font_size 를 쓴다.
	title.add_theme_font_size_override(&"bold_font_size", 44)
	title.add_theme_font_size_override(&"normal_font_size", 44)
	title.text = "[b]A complete [color=#%s]UI toolkit.[/color][/b]" % _accent.to_html(false)
	block.add_child(title)
	block.add_child(GoStyle.label("HUD controls, menus and feedback — styled together.",
		GoTheme.ROLE_SUBTITLE, _subtitle_ink))
	row.add_child(block)
	return row


# ── 카드 골격 ───────────────────────────────────────────────────────────

## 번호 배지 + 제목을 단 카드를 만들고, 내용을 담을 세로줄을 돌려준다.
func _card(grid: GridContainer, number: String, title: String) -> VBoxContainer:
	var card := GoStyle.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 330
	grid.add_child(card)

	var column := GoStyle.column(16)
	card.add_child(column)

	var head := GoStyle.row(11)
	head.add_child(_badge(number))
	var text := GoStyle.label(title, GoTheme.ROLE_TITLE)
	text.add_theme_font_size_override(&"font_size", 21)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(text)
	column.add_child(head)
	return column


func _badge(number: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _accent
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override(&"panel", style)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label := Label.new()
	label.text = number
	label.add_theme_font_size_override(&"font_size", 17)
	label.add_theme_color_override(&"font_color", Color("#04283f"))
	panel.add_child(label)
	return panel


# ── 01 HUD & quick slots ───────────────────────────────────────────────

func _hud_card(grid: GridContainer) -> void:
	var column := _card(grid, "01", "HUD & quick slots")

	var bar_row := GoStyle.row(10)
	bar_row.add_child(GoUi.icons().node(GoIconSet.HEART, 30, _green))
	_hp = GoBar.new()
	_hp.label_text = "HP"
	_hp.ink = _green
	_hp.readout = GoBar.Readout.PERCENT
	_hp.thickness = 16
	_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_hp)
	column.add_child(bar_row)

	var slots := GoStyle.row(12)
	slots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var peers: Array[Control] = []
	# 🛑 수량을 아예 안 보이려면 NONE 이다 — UNKNOWN 은 "모른다"는 뜻이라 `…` 를 그린다.
	for spec in [[GoIconSet.SWORD, true, GoSlot.NONE], [GoIconSet.SHIELD, false, GoSlot.NONE],
			[GoIconSet.POTION, false, 3], [GoIconSet.BOLT, false, GoSlot.NONE]]:
		var slot := GoSlot.new()
		slot.icon_name = spec[0]
		slot.accent = _accent if spec[1] else Color.TRANSPARENT
		slot.quantity = spec[2]
		slot.visual_size = 58
		slots.add_child(slot)
		slot.custom_minimum_size = Vector2(66, 66)   # _ready 가 48 로 잡은 뒤에 키운다
		peers.append(slot)
	for slot in peers:
		(slot as GoSlot).touch_peers = peers
	column.add_child(slots)
	column.add_child(GoStyle.spacer())
	_hp.set_values(80, 100, false)


# ── 02 Buttons & inputs ────────────────────────────────────────────────

func _input_card(grid: GridContainer) -> void:
	var column := _card(grid, "02", "Buttons & inputs")

	var buttons := GoStyle.row(12)
	for spec in [["Primary", GoStyle.Tone.PRIMARY], ["Secondary", GoStyle.Tone.NORMAL]]:
		var button := GoStyle.button(spec[0], Callable(), spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	column.add_child(buttons)
	column.add_child(GoStyle.line_edit("Player name"))

	var haptics := GoStyle.row(10)
	haptics.add_child(GoUi.icons().node(GoIconSet.MOBILE, 24, _subtitle_ink))
	var haptics_label := GoStyle.label("Haptics")
	haptics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptics.add_child(haptics_label)
	var toggle := GoStyle.toggle()
	toggle.button_pressed = true
	haptics.add_child(toggle)
	column.add_child(haptics)

	var volume := GoStyle.row(10)
	volume.add_child(GoUi.icons().node(GoIconSet.VOLUME_HIGH, 24, _subtitle_ink))
	var slider := GoStyle.slider(0.0, 100.0, 1.0)
	slider.value = 70.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_volume)
	volume.add_child(slider)
	_volume_label = GoStyle.label("70%")
	_volume_label.custom_minimum_size.x = 48
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume.add_child(_volume_label)
	column.add_child(volume)
	column.add_child(GoStyle.spacer())


func _on_volume(value: float) -> void:
	_volume_label.text = "%d%%" % int(value)


# ── 03 Dialogs & sheets ────────────────────────────────────────────────

func _dialog_card(grid: GridContainer) -> void:
	var column := _card(grid, "03", "Dialogs & sheets")

	var dialog := GoStyle.card()
	var dialog_column := GoStyle.column(13)
	dialog.add_child(dialog_column)
	var question := GoStyle.label("Ready to continue?", GoTheme.ROLE_SUBTITLE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_column.add_child(question)
	var answers := GoStyle.row(10)
	for spec in [["Cancel", GoStyle.Tone.NORMAL], ["Confirm", GoStyle.Tone.PRIMARY]]:
		var button := GoStyle.button(spec[0], Callable(), spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answers.add_child(button)
	dialog_column.add_child(answers)
	column.add_child(dialog)

	var sheet := GoStyle.card()
	var sheet_column := GoStyle.column(6)
	sheet.add_child(sheet_column)
	var handle := Panel.new()
	handle.custom_minimum_size = Vector2(46, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var handle_style := StyleBoxFlat.new()
	handle_style.bg_color = Color(_subtitle_ink, 0.5)
	handle_style.set_corner_radius_all(3)
	handle.add_theme_stylebox_override(&"panel", handle_style)
	sheet_column.add_child(handle)
	sheet_column.add_child(_sheet_row(GoIconSet.BOOK, "Load Game"))
	sheet_column.add_child(_sheet_row(GoIconSet.SETTINGS, "Settings"))
	column.add_child(sheet)
	column.add_child(GoStyle.spacer())


## 목록 한 줄 — 오른쪽 꺾쇠는 목록 버튼 위에 겹쳐 둔다.
func _sheet_row(icon: StringName, text: String) -> Control:
	return GoStyle.list_button(icon, text, Callable(), Color.TRANSPARENT, "", false, GoIconSet.CHEVRON_RIGHT)


# ── 04 Notices & prompts ───────────────────────────────────────────────

func _notice_card(grid: GridContainer) -> void:
	var column := _card(grid, "04", "Notices & prompts")

	var notice := GoNotice.new()
	var content := GoStyle.row(11)
	content.add_child(GoUi.icons().node(GoIconSet.SUCCESS, 24, _green))
	var saved := GoStyle.label("Settings saved")
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(saved)
	content.add_child(GoStyle.icon_button(GoIconSet.CLOSE, Callable(), 20))
	notice.set_content(content, _green)
	column.add_child(notice)

	var prompt := GoStyle.card()
	var prompt_column := GoStyle.column(13)
	prompt.add_child(prompt_column)
	var question := GoStyle.label("Join the party?", GoTheme.ROLE_SUBTITLE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_column.add_child(question)
	var answers := GoStyle.row(10)
	for spec in [["Decline", GoStyle.Tone.NORMAL], ["Accept", GoStyle.Tone.PRIMARY]]:
		var button := GoStyle.button(spec[0], Callable(), spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answers.add_child(button)
	prompt_column.add_child(answers)
	column.add_child(prompt)
	column.add_child(GoStyle.spacer())


# ── 05 Touch controls ──────────────────────────────────────────────────

func _touch_card(grid: GridContainer) -> void:
	var column := _card(grid, "05", "Touch controls")
	var row := GoStyle.row(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(186, 186)
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stick := GoJoystick.new()
	stick.mode = GoJoystick.Mode.FIXED
	stick.radius = 84.0
	stick.knob_radius = 30.0
	stick.ink = _accent
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(stick)
	for spec in [[GoIconSet.UP, Vector2(0, -62)], [GoIconSet.DOWN, Vector2(0, 62)],
			[GoIconSet.BACK, Vector2(-62, 0)], [GoIconSet.FORWARD, Vector2(62, 0)]]:
		var arrow := GoUi.icons().node(spec[0], 18, Color(_subtitle_ink, 0.85))
		arrow.set_anchors_preset(Control.PRESET_CENTER)
		arrow.position += spec[1]
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(arrow)
	row.add_child(stage)

	var actions := Control.new()
	actions.custom_minimum_size = Vector2(168, 186)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 🛑 좌표는 stage 좌상단 기준으로 직접 준다 — PRESET_CENTER 는 크기가 정해지기 전에 계산돼 어긋난다.
	for spec in [[GoIconSet.SHIELD, Vector2(78, 6)], [GoIconSet.SWORD, Vector2(8, 82)],
			[GoIconSet.BOLT, Vector2(92, 104)]]:
		# 🛑 `visual_size` 하나가 버튼 크기와 아이콘 크기(58%)를 함께 정한다 — 크기를 따로 강제하면 어긋난다.
		var diameter := 62.0
		var button := GoStyle.icon_button(spec[0], Callable(), int(diameter))
		# 🛑 글자 없는 버튼의 아이콘은 기본이 왼쪽 정렬이다 — 원 안에서는 가운데로 맞춘다.
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.size = Vector2(diameter, diameter)
		for state in [[&"normal", 0.20], [&"hover", 0.30], [&"pressed", 0.40]]:
			button.add_theme_stylebox_override(state[0], GoStyle.disc(diameter, _accent, state[1], 0.60))
		button.position = spec[1]
		actions.add_child(button)
	row.add_child(actions)
	column.add_child(row)


# ── 06 Themes & icons ──────────────────────────────────────────────────

func _theme_card(grid: GridContainer) -> void:
	var column := _card(grid, "06", "Themes & icons")

	var themes := GoStyle.row(12)
	var pair := ThemePicker.pair()
	themes.add_child(_theme_panel("Dark", pair[0], GoTheme.color_of(pair[0], GoTheme.TEXT)))
	themes.add_child(_theme_panel("Light", pair[1], GoTheme.color_of(pair[1], GoTheme.TEXT)))
	column.add_child(themes)

	var icons := GoStyle.row(20)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	for name in [GoIconSet.SETTINGS, GoIconSet.HEART, GoIconSet.BELL, GoIconSet.SEARCH]:
		icons.add_child(GoUi.icons().node(name, 32, Color(_subtitle_ink, 0.95)))
	column.add_child(icons)
	column.add_child(GoStyle.spacer())


## 같은 위젯을 테마만 바꿔 나란히 둔다 — 코드는 한 벌이다.
func _theme_panel(title: String, theme: Theme, ink: Color) -> Control:
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.theme_type_variation = GoTheme.VAR_CARD
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := GoStyle.column(10)
	panel.add_child(column)
	var label := Label.new()
	label.text = title
	label.add_theme_color_override(&"font_color", ink)
	label.add_theme_font_size_override(&"font_size", 16)
	column.add_child(label)

	var brightness := GoStyle.row(8)
	brightness.add_child(GoUi.icons().node(GoIconSet.SUN, 20, ink))
	var slider := GoStyle.slider(0.0, 100.0, 1.0)
	slider.value = 62.0
	slider.theme = theme
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brightness.add_child(slider)
	column.add_child(brightness)

	var haptics := GoStyle.row(8)
	haptics.add_child(GoUi.icons().node(GoIconSet.MOBILE, 20, ink))
	var label_haptics := Label.new()
	label_haptics.text = "Haptics"
	label_haptics.add_theme_color_override(&"font_color", ink)
	label_haptics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haptics.add_child(label_haptics)
	var toggle := GoStyle.toggle()
	toggle.theme = theme
	toggle.button_pressed = true
	haptics.add_child(toggle)
	column.add_child(haptics)
	return panel


# ── 07 Selection & menus ──────────────────────────────────────────────

func _selection_card(grid: GridContainer) -> void:
	var column := _card(grid, "07", "Selection & menus")
	var top := GoStyle.row(12)
	var select := GoStyle.select(["Warrior", "Mage", "Ranger", "Engineer"], "Choose a class")
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(select)
	top.add_child(GoStyle.dropdown("Actions", [{"text": "Rename", "icon": GoIconSet.EDIT},
		{"text": "Duplicate", "icon": GoIconSet.COPY}, {"text": "Delete", "icon": GoIconSet.TRASH, "disabled": true}]))
	column.add_child(top)
	column.add_child(GoStyle.segmented(["Day", "Week", "Month"], 1))
	column.add_child(GoStyle.tabs(["Overview", "Stats", "Gear"], 0))
	var radios := GoStyle.row(18)
	radios.add_child(GoStyle.radio_group(["Easy", "Normal", "Hard"], 1))
	var checks := GoStyle.column(4)
	for spec in [["Auto-loot", true], ["Show damage", true], ["Voice chat", false]]:
		var box := GoStyle.checkbox(spec[0], false)
		box.button_pressed = spec[1]
		checks.add_child(box)
	radios.add_child(checks)
	column.add_child(radios)


# ── 08 Data & layout ──────────────────────────────────────────────────

func _data_card(grid: GridContainer) -> void:
	var column := _card(grid, "08", "Data & layout")
	column.add_child(GoStyle.breadcrumb(["Home", "Inventory", "Weapons"]))
	var people := GoStyle.row(10)
	for spec in [["Ada Lovelace", _accent], ["Grace Hopper", _green], ["Linus T", Color("#f0a36b")]]:
		people.add_child(GoStyle.avatar(spec[0], 40, spec[1]))
	var loading := GoStyle.column(6)
	loading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loading.add_child(GoStyle.skeleton(0, 12))
	loading.add_child(GoStyle.skeleton(140, 12))
	people.add_child(loading)
	column.add_child(people)
	column.add_child(GoStyle.table(["Item", "Qty", "Rarity"], [["Iron Sword", "1", "Common"],
		["Mana Potion", "12", "Rare"], ["Dragon Scale", "3", "Epic"]]))
	column.add_child(GoStyle.textarea("Write a note…", 2))


# ── 09 States & feedback ──────────────────────────────────────────────

func _states_card(grid: GridContainer) -> void:
	var column := _card(grid, "09", "States & feedback")
	column.add_child(GoStyle.alert("Your progress is saved to the cloud.", GoTheme.INFO))
	column.add_child(GoStyle.alert("Quest completed — reward claimed.", GoTheme.SUCCESS))
	column.add_child(GoStyle.alert("Low on potions. Restock before the boss.", GoTheme.WARNING))
	column.add_child(GoStyle.alert("Connection lost. Retrying…", GoTheme.DANGER))
	var chips := GoStyle.wrap_row(8)
	for spec in [["Online", _green], ["Level 42", _accent], ["Guild", Color("#c58bff")], ["Beta", Color("#f0a36b")]]:
		chips.add_child(GoStyle.chip(spec[0], spec[1]))
	column.add_child(chips)
	var fold := GoStyle.foldable("Advanced options", true, null, false)
	fold.add_child(GoStyle.label("Frame cap, shadow quality and telemetry live here.", GoTheme.ROLE_CAPTION, _subtitle_ink))
	column.add_child(fold)


func _change_theme(preset: StringName) -> void:
	if preset == ThemePicker.active_preset: return
	ThemePicker.active_preset = preset
	_rebuild_theme.call_deferred()


func _rebuild_theme() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_configure()
	_build()
	queue_redraw()
