## 🧪 gohud 헤드리스 검사 — 오토로드·서버·게임 없이 애드온만으로 돈다.
##
## ```
## bash addons/gohud/tools/run_tests.sh                       # 권장 — 벽시계 제한·스크립트 오류 판정 포함
## godot --headless -s res://addons/gohud/tests/gohud_test.gd
## ```
##
## 🛑 이 파일(또는 gohud 스크립트)에 **파싱 오류**가 나면 `_initialize` 에 닿지 못해 출력이 0줄이고
##    프로세스가 끝나지 않는다 — "멈춘 것처럼" 보인다(2026-09-12 실측). 기다리지 말고
##    `run_tests.sh` 가 보여 주는 `SCRIPT ERROR` 를 본다. `:=` 오른쪽이 Variant(`dict.get()`,
##    배열 원소 등)이면 타입을 **명시**한다 — 추론 실패가 곧 파싱 오류다.
##
## 🛑 이 검사는 **호스트 프로젝트 안**과 **빈 프로젝트**(`tools/new_project_check.sh`) 양쪽에서
##    통과해야 한다. 그래서 기대값을 고정 픽셀로 쓰지 않고 뷰포트·안전영역에서 계산한다.
extends SceneTree

const ADDON := "res://addons/gohud"

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func near(a: float, b: float, tolerance := 1.0) -> bool:
	return absf(a - b) <= tolerance


func frames(count := 2) -> void:
	for i in count:
		await process_frame


func _initialize() -> void:
	# 어딘가에서 영원히 기다려도 검사는 끝나야 한다.
	create_timer(150.0).timeout.connect(_on_watchdog)
	GoUi.reset()
	GoUi.config = GoConfig.new()
	# 🛑 `--headless` 의 기본 창은 **64×64** 이고 `root.size` 로는 커지지 않는다(2026-09-12 실측) —
	#    그 안에서는 카드 최소 크기가 이미 화면보다 커서 배치 검사가 전부 거짓 실패한다.
	#    창 대신 **스트레치 기준 크기**를 폰 세로로 잡으면 논리 뷰포트가 그 크기가 된다.
	#    기대값은 그래도 이 값을 박지 않고 **실제 뷰포트·안전영역에서 계산**한다.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(390, 844)
	await frames(2)
	var view := root.get_visible_rect().size
	print("  viewport %s" % str(view))
	check(minf(view.x, view.y) >= 320.0, "검사용 뷰포트가 충분히 크다 (%s)" % str(view))
	await _section("back policy", _back_policy)
	await _section("tokens · themes", _tokens)
	await _section("icon sets", _icons)
	await _section("localization", _i18n)
	await _section("scale functions", _scale)
	await _section("style factories", _style)
	await _section("icon button", _icon_button)
	await _section("surface", _surface)
	await _section("sheet", _sheet)
	await _section("dialogs", _dialogs)
	await _section("notice", _notice)
	await _section("prompt card", _prompt)
	await _section("bar", _bar)
	await _section("slot", _slot)
	await _section("joystick", _joystick)
	await _section("hud anchor", _anchor)
	await _section("coach mark", _coach)
	await _section("form", _form)
	await _section("feedback", _feedback)
	await _section("rtl", _rtl)
	await _section("standalone", _standalone)
	# 🛑 정적 변수에 람다를 남긴 채 끝내면 종료 단계에서 죽을 수 있다 — 비우고 끝낸다.
	GoFeedback.sound_handler = Callable()
	GoFeedback.haptic_handler = Callable()
	GoUi.reset()
	print("gohud tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _on_watchdog() -> void:
	printerr("FAIL watchdog — 150초 안에 끝나지 않았다")
	quit(2)


func _section(title: String, body: Callable) -> void:
	var before := failures
	await body.call()
	print("  %s %s" % ["ok  " if failures == before else "FAIL", title])


# ── 뒤로가기 소유권 ────────────────────────────────────────────────────

func _back_policy() -> void:
	var start := quit_on_go_back
	var baseline := GoBackPolicy.owners()
	GoBackPolicy.acquire(self)
	GoBackPolicy.acquire(self)
	check(not quit_on_go_back, "창이 열려 있으면 뒤로가기가 앱을 끄지 않는다")
	GoBackPolicy.release(self)
	check(not quit_on_go_back, "하나라도 남아 있으면 계속 막는다")
	GoBackPolicy.release(self)
	check(GoBackPolicy.owners() == baseline, "소유 수가 원래대로")
	if baseline == 0: check(quit_on_go_back == start, "마지막이 놓으면 원래 값으로")


# ── 토큰·테마 ──────────────────────────────────────────────────────────

func _tokens() -> void:
	var settings := GoUi.config
	check(GoUi.theme() == GoUi.DEFAULT_THEME, "설정이 비면 기본(어두운) 테마")
	check(GoUi.color(GoTheme.ACCENT) != Color.MAGENTA, "accent 토큰이 있다")
	check(GoUi.metric(GoTheme.TOUCH) == 48, "터치 하한 48")
	check(GoUi.metric(GoTheme.BUTTON_HEIGHT) == 52, "버튼 높이 52")
	check(GoUi.font_size(GoTheme.ROLE_TITLE) > GoUi.font_size(GoTheme.ROLE_BODY), "제목 > 본문")

	var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: Color.RED}
	settings.color_overrides = colors
	check(GoUi.color(GoTheme.ACCENT) == Color.RED, "color_overrides 가 테마보다 우선")
	settings.color_overrides.clear()
	var metrics: Dictionary[StringName, int] = {GoTheme.PADDING: 7}
	settings.metric_overrides = metrics
	check(GoUi.metric(GoTheme.PADDING) == 7, "metric_overrides")
	settings.metric_overrides.clear()
	settings.min_touch_size = 44
	check(GoUi.metric(GoTheme.TOUCH) == 44, "min_touch_size 가 touch 토큰이 된다")
	settings.min_touch_size = 48

	# 토큰이 없는 평범한 Theme 를 넣어도 깨지지 않는다.
	settings.theme = Theme.new()
	check(GoUi.color(GoTheme.SURFACE) == GoTheme.color_of(GoUi.DEFAULT_THEME, GoTheme.SURFACE), "토큰 없는 Theme 도 기본 토큰으로 채운다")
	settings.token_fallback = false
	check(GoUi.color(GoTheme.SURFACE) == Color.MAGENTA, "token_fallback 을 끄면 빠진 토큰이 드러난다")
	settings.token_fallback = true
	settings.theme = null

	var notified := [0]
	var watcher := func() -> void: notified[0] += 1
	GoUi.watch(watcher)
	settings.theme = GoUi.LIGHT_THEME
	check(int(notified[0]) >= 1, "테마를 바꾸면 watch 콜백이 불린다")
	check(GoUi.color(GoTheme.BACKGROUND) != GoTheme.color_of(GoUi.DEFAULT_THEME, GoTheme.BACKGROUND), "라이트 테마 배경은 어두운 테마와 다르다")
	check(GoUi.color(GoTheme.TEXT).get_luminance() < 0.3, "라이트 테마 글자는 어둡다")
	var before: int = notified[0]
	GoUi.refresh()
	check(int(notified[0]) == before + 1, "GoUi.refresh() 가 콜백을 부른다")
	GoUi.unwatch(watcher)
	settings.theme = null

	# 🛑 `GoRuntime` 오토로드를 켜 두면 부팅 때 이미 축소를 적용한다(폰 크기 뷰포트) —
	#    "축소 전" 을 가정하면 거짓 실패한다. 기준을 맞추고 잰다.
	GoUi.set_mobile_type(false)
	var body := GoUi.font_size(GoTheme.ROLE_BODY)
	GoUi.set_mobile_type(true)
	check(GoUi.font_size(GoTheme.ROLE_BODY) == body - 2, "모바일 글자 한 단계 축소 (%d → %d)" % [body, GoUi.font_size(GoTheme.ROLE_BODY)])
	check(GoUi.metric(GoTheme.TOUCH) == 48, "모바일 축소는 터치 크기를 건드리지 않는다")
	GoUi.set_mobile_type(false)
	check(GoUi.font_size(GoTheme.ROLE_BODY) == body, "축소 해제")


# ── 아이콘 세트 ────────────────────────────────────────────────────────

func _icons() -> void:
	var icon_set := GoUi.icons()
	var names := icon_set.icon_names()
	check(names.size() == 84, "기본 아이콘 84종 (실제 %d)" % names.size())
	var script: Script = load(ADDON + "/core/go_icon_set.gd")
	var constants := script.get_script_constant_map()
	var missing: Array = []
	for key in constants:
		var value: Variant = constants[key]
		if value is StringName and not icon_set.has_icon(value): missing.append(value)
	check(missing.is_empty(), "GoIconSet 이름 상수가 전부 기본 세트에 있다 %s" % str(missing))

	var close := icon_set.texture(GoIconSet.CLOSE)
	check(close != null, "close 텍스처")
	check(close is DPITexture, "기본 아이콘은 DPITexture — 배율이 커지면 다시 래스터화된다 (%s)" % (close.get_class() if close != null else "null"))
	var drawn := icon_set.node(GoIconSet.SETTINGS, 20)
	check(drawn is TextureRect and drawn.custom_minimum_size == Vector2(20, 20), "node() — 텍스처 세트는 요청 크기의 TextureRect")
	drawn.free()
	var unknown := icon_set.node(&"no_such_icon_for_test", 16)
	check(unknown is Label and unknown.custom_minimum_size == Vector2(16, 16), "없는 이름도 자리는 차지한다")
	unknown.free()

	var custom := GoIconSet.new()
	custom.fallback = icon_set
	var mine := PlaceholderTexture2D.new()
	mine.size = Vector2(24, 24)
	var textures: Dictionary[StringName, Texture2D] = {GoIconSet.CLOSE: mine}
	custom.textures = textures
	check(custom.texture(GoIconSet.CLOSE) == mine, "부분 교체 — 덮어쓴 이름은 새 텍스처")
	check(custom.texture(GoIconSet.SETTINGS) == icon_set.texture(GoIconSet.SETTINGS), "부분 교체 — 나머지는 폴백 세트")
	check(custom.icon_names().size() == names.size(), "부분 교체 세트의 이름 목록은 폴백을 포함")

	var font_set := GoIconSet.new()
	font_set.font = SystemFont.new()
	var points: Dictionary[StringName, int] = {GoIconSet.CLOSE: 0x78}
	font_set.codepoints = points
	var glyph := font_set.node(GoIconSet.CLOSE, 18)
	check(glyph is Label and (glyph as Label).text == "x", "아이콘 폰트 세트 — 코드포인트 문자를 그린다")
	check(font_set.glyph_font(GoIconSet.CLOSE) != null and font_set.glyph(GoIconSet.CLOSE) == "x", "glyph()·glyph_font()")
	glyph.free()

	var first := GoIconSet.new()
	var second := GoIconSet.new()
	first.fallback = second
	second.fallback = first
	check(not first.has_icon(&"missing"), "순환으로 엮인 폴백도 멈추지 않는다")
	first.fallback = null
	second.fallback = null

	GoUi.config.icons = custom
	check(GoUi.icons() == custom, "GoConfig.icons 로 세트를 갈아 끼운다")
	GoUi.config.icons = null
	check(GoUi.icons() == GoUi.DEFAULT_ICONS, "비우면 기본 세트")


# ── 번역 ───────────────────────────────────────────────────────────────

func _i18n() -> void:
	var original := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(GoUi.text(&"close") == "Close", "en 번역 (%s)" % GoUi.text(&"close"))
	TranslationServer.set_locale("ko")
	check(GoUi.text(&"close") == "닫기", "ko 번역 (%s)" % GoUi.text(&"close"))
	TranslationServer.set_locale("ar")
	check(GoUi.text(&"cancel") == "إلغاء", "ar 번역")
	TranslationServer.set_locale("ja")
	check(GoUi.text(&"confirm") == "確認", "ja 번역")
	var overrides: Dictionary[StringName, String] = {&"close": "X"}
	GoUi.config.text_overrides = overrides
	check(GoUi.text(&"close") == "X", "text_overrides 가 번역보다 우선")
	GoUi.config.text_overrides.clear()
	check(GoUi.text_key(&"close") == "gohud_close", "text_key 는 번역 키")
	TranslationServer.set_locale(original)


# ── 배율 순수 함수 ─────────────────────────────────────────────────────

func _scale() -> void:
	check(GoScale.breakpoint_for_dp(360) == GoScale.Bp.MOBILE, "360dp 모바일")
	check(GoScale.breakpoint_for_dp(576) == GoScale.Bp.MOBILE, "576dp 경계는 모바일")
	check(GoScale.breakpoint_for_dp(800) == GoScale.Bp.TABLET, "800dp 태블릿")
	check(GoScale.breakpoint_for_dp(1200) == GoScale.Bp.DESKTOP, "1200dp 데스크톱")
	check(near(GoScale.display_scale(0.9, 300, Vector2i(720, 1600)), 1.875, 0.001), "손에 드는 기기는 DPI 로 — screen_get_scale 0.9 를 믿지 않는다")
	check(near(GoScale.display_scale(2.0, 144, Vector2i(3024, 1964)), 2.0, 0.001), "데스크톱은 screen_get_scale")
	check(near(GoScale.display_scale(0.0, 192, Vector2i(3840, 2160)), 2.0, 0.001), "screen_get_scale 미구현(0)이면 DPI/96")
	check(near(GoScale.gain_for(GoScale.Bp.MOBILE, true), 1.10, 0.001), "모바일 가독성 보정 1.10")
	check(near(GoScale.gain_for(GoScale.Bp.DESKTOP, false), 1.0, 0.001), "데스크톱 추가 확대 기본 1.0")
	var logical := GoScale.logical_size_for(Vector2i(720, 1600), 1.875, 1.10)
	check(near(logical.x, 349.09, 0.1), "720px·300dpi 폰의 논리 폭 349 (%.2f)" % logical.x)
	check(GoScale.form_width_for(GoScale.Bp.DESKTOP) == 480 and GoScale.form_width_for(GoScale.Bp.MOBILE) == 0, "폼 최대 폭")


# ── 공장 함수 ──────────────────────────────────────────────────────────

func _style() -> void:
	var host := VBoxContainer.new()
	host.size = Vector2(320, 900)
	root.add_child(host)
	var normal := GoStyle.button("A")
	var compact := GoStyle.button("B", Callable(), GoStyle.Tone.COMPACT)
	var primary := GoStyle.button("C", Callable(), GoStyle.Tone.PRIMARY)
	host.add_child(normal)
	host.add_child(compact)
	host.add_child(primary)
	check(normal.custom_minimum_size.y == 52, "일반 버튼 높이 = button_height")
	check(compact.custom_minimum_size.y == 48, "얇은 버튼도 터치 하한")
	check(primary.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON, "주 버튼 변형")
	check(normal.mouse_filter == Control.MOUSE_FILTER_PASS, "버튼은 PASS — 스크롤 끌기를 막지 않는다")

	var row := GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "Name and avatar", false)
	host.add_child(row)
	await frames(3)
	check(row.custom_minimum_size.y >= 48, "목록 항목 터치 하한")
	check(row.custom_minimum_size.y < 120, "폭이 있으면 두 줄 항목이 부풀지 않는다 (%.0f)" % row.custom_minimum_size.y)
	var inset := row.get_child(0) as MarginContainer
	check(inset != null and row.custom_minimum_size.y >= inset.get_combined_minimum_size().y - 0.5, "여백 포함 내용이 항목 안에 들어간다")

	var wrap := GoStyle.wrap_row(-1, FlowContainer.ALIGNMENT_CENTER, FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN)
	check(wrap is HFlowContainer and wrap.last_wrap_alignment == FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN, "흐르는 줄 · 마지막 줄 정렬")
	host.add_child(wrap)
	var flowing := GoStyle.button("Primary", Callable(), GoStyle.Tone.PRIMARY)
	wrap.add_child(flowing)
	GoStyle.form(host)   # 폼 규격을 입혀도 자연 폭이 되돌아오면 안 된다
	await frames(1)
	check(flowing.autowrap_mode == TextServer.AUTOWRAP_OFF, "흐르는 줄의 버튼은 줄바꿈하지 않는다")
	check(flowing.get_combined_minimum_size().x > 48.0, "자연 폭이 글자만큼 넓다 — 세로로 쪼개지지 않는다 (%.0f)" % flowing.get_combined_minimum_size().x)
	var fold := GoStyle.foldable("Advanced", true)
	check(fold is FoldableContainer and fold.title == "Advanced" and fold.folded, "FoldableContainer 섹션")
	fold.free()
	var chip := GoStyle.chip("new", GoUi.color(GoTheme.SUCCESS))
	check(chip.get_child_count() == 1, "칩")
	chip.free()

	var grid := GoStyle.responsive_grid(150.0)
	root.add_child(grid)
	for i in 6:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(40, 20)
		grid.add_child(cell)
	await frames(1)
	grid.size = Vector2(700, 0)
	await frames(1)
	check(grid.columns == 4, "반응형 격자 — 700 폭·최소 150 이면 4열 (%d)" % grid.columns)
	grid.size = Vector2(320, 0)
	await frames(1)
	check(grid.columns == 2, "320 폭이면 2열 (%d)" % grid.columns)
	grid.queue_free()
	host.queue_free()
	await frames(1)


# ── 아이콘 버튼 ────────────────────────────────────────────────────────

func _icon_button() -> void:
	var mark := GoStyle.icon_button(GoIconSet.CLOSE)
	mark.tooltip_text_name = &"close"
	root.add_child(mark)
	await frames(2)
	var visual := mark.size.x
	check(near(visual, 36.0), "보이는 크기 36 (%.1f)" % visual)
	var reach := (48.0 - visual) * 0.5
	check(mark._has_point(Vector2(-reach + 0.5, visual * 0.5)), "터치는 48 까지 넓어진다")
	check(not mark._has_point(Vector2(-reach - 1.5, visual * 0.5)), "48 밖은 받지 않는다")
	check(mark.icon is DPITexture, "텍스처 세트 → Button.icon")
	var cap := mark.get_theme_constant(&"icon_max_width")
	check(cap > 0 and cap < int(visual), "icon_max_width 로 글리프 크기를 묶는다 (%d)" % cap)
	TranslationServer.set_locale("en")
	mark.notification(NOTIFICATION_TRANSLATION_CHANGED)
	check(mark.accessibility_name == "Close", "접근성 이름 = 툴팁 문구 (%s)" % mark.accessibility_name)
	mark.queue_free()
	await frames(1)


# ── 표면 ───────────────────────────────────────────────────────────────

func _surface() -> void:
	var baseline := GoBackPolicy.owners()
	var low := CanvasLayer.new()
	low.layer = 10
	root.add_child(low)
	var high := CanvasLayer.new()
	high.layer = 20
	root.add_child(high)
	var a := GoSurface.new()
	low.add_child(a)
	var b := GoSurface.new()
	high.add_child(b)
	await frames(3)
	check(GoSurface.is_any_open(), "열린 표면이 있다")
	check(GoBackPolicy.owners() == baseline + 2, "표면마다 뒤로가기 소유 (%d)" % GoBackPolicy.owners())
	check(b.is_top() and not a.is_top(), "높은 층의 표면이 가장 위")

	var closes := [0, 0]
	a.close_requested.connect(func() -> void: closes[0] += 1)
	b.close_requested.connect(func() -> void: closes[1] += 1)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	a._input(cancel)
	b._input(cancel)
	check(int(closes[0]) == 0 and int(closes[1]) == 1, "Escape 한 번은 가장 위 창만 닫는다")
	b.hide()
	await frames(1)
	check(a.is_top(), "위 창이 숨으면 아래 창이 가장 위")

	var view := a.get_viewport_rect().size
	check(a.card.size.x <= GoUi.config.surface_max_width + 0.5, "카드 최대 폭")
	check(a.card.position.x >= -0.5 and a.card.get_global_rect().end.x <= view.x + 0.5,
		"카드가 화면 안 (pos %s size %s view %s)" % [str(a.card.position), str(a.card.size), str(view)])
	check(near(a.close_button.size.x, GoUi.config.close_button_visual), "닫기 버튼 보이는 크기")
	check(a.back_button.autowrap_mode == TextServer.AUTOWRAP_OFF, "뒤로 버튼은 줄바꿈하지 않는다(빈 알약 방지)")

	a.body.add_child(GoStyle.label("short"))
	await frames(3)
	var short_height := a.card.size.y
	for i in 40:
		a.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Row %d" % i, Callable(), Color.TRANSPARENT, "", false))
	await frames(4)
	var area := GoSafeArea.usable_rect(a.get_window())
	check(a.card.size.y > short_height, "내용이 늘면 카드가 자란다 (%.0f → %.0f)" % [short_height, a.card.size.y])
	check(a.card.size.y <= area.size.y * GoUi.config.surface_max_height_ratio + 1.0,
		"높이 상한 %d%% (%.0f ≤ %.0f)" % [roundi(GoUi.config.surface_max_height_ratio * 100), a.card.size.y, area.size.y * GoUi.config.surface_max_height_ratio])

	var desired := a._desired_height()
	a.toolbar.add_child(GoStyle.line_edit("search"))
	a.toolbar.visible = true
	await frames(1)
	check(a._desired_height() > desired + 40.0, "고정 줄(toolbar)도 원하는 높이에 들어간다 (%.0f → %.0f)" % [desired, a._desired_height()])

	a.placement = GoSurface.Placement.BOTTOM
	a.relayout()
	var edge := minf(float(GoUi.metric(GoTheme.SCREEN_MARGIN)), minf(area.size.x, area.size.y) * 0.1)
	check(near(a.card.get_global_rect().end.y, area.end.y - edge, 1.5), "BOTTOM 은 아래 가장자리에 붙는다")

	var anchor := Button.new()
	anchor.position = Vector2(40, 40)
	anchor.size = Vector2(80, 40)
	root.add_child(anchor)
	a.placement = GoSurface.Placement.ANCHOR
	a.anchor_control = anchor
	a.relayout()
	check(a.card.position.y >= anchor.get_global_rect().end.y,
		"ANCHOR 는 대상 아래에 붙는다 (card y %.0f · anchor end %.0f)" % [a.card.position.y, anchor.get_global_rect().end.y])

	a.hide()
	await frames(1)
	check(not GoSurface.is_any_open(), "모두 숨기면 열린 표면 0")
	check(GoBackPolicy.owners() == baseline, "뒤로가기 소유 반납")
	low.queue_free()
	high.queue_free()
	anchor.queue_free()
	await frames(2)


# ── 시트 ───────────────────────────────────────────────────────────────

func _sheet() -> void:
	GoUi.config.dismiss_on_scrim = true
	var sheet := GoSheet.new()
	sheet.dismissable = false
	root.add_child(sheet)
	await frames(2)
	check(not sheet.surface.dismiss_on_scrim, "명시한 dismissable=false 가 설정 기본값(true)에 덮이지 않는다")
	GoUi.config.dismiss_on_scrim = false

	sheet.open("Bag")
	await frames(1)
	check(sheet.visible and sheet.surface.placement == GoSurface.Placement.BOTTOM, "시트는 아래에서")
	sheet.set_back(func() -> void: pass)
	check(sheet.surface.back_button.visible, "set_back 으로 뒤로 버튼")
	sheet.toolbar().visible = true
	sheet.open("Other")
	check(not sheet.surface.back_button.visible, "open() 은 이전 페이지의 뒤로 버튼을 끈다")
	check(not sheet.toolbar().visible, "open() 은 고정 줄을 끈다")
	var closed := [false]
	sheet.closed.connect(func() -> void: closed[0] = true)
	sheet.close()
	check(bool(closed[0]) and not sheet.visible, "close()")
	sheet.queue_free()
	await frames(2)


# ── 확인·알림 창 ───────────────────────────────────────────────────────

func _dialogs() -> void:
	var dialogs := GoDialogs.new()
	root.add_child(dialogs)
	await frames(2)

	var seen := [""]
	create_timer(0.05).timeout.connect(func() -> void:
		seen[0] = dialogs._body.text
		dialogs._ok.pressed.emit())
	var yes: bool = await dialogs.confirm("Delete", "Delete \"{name}\"?", "", "", "", {"name": "Aria"})
	check(yes, "confirm → 확인")
	check(str(seen[0]) == "Delete \"Aria\"?", "args 가 {name} 을 채운다 (%s)" % str(seen[0]))

	create_timer(0.05).timeout.connect(func() -> void: dialogs._cancel.pressed.emit())
	var no: bool = await dialogs.confirm("Question", "Body")
	check(not no, "confirm → 취소")

	var cancel_shown := [true]
	create_timer(0.05).timeout.connect(func() -> void:
		cancel_shown[0] = dialogs._cancel.visible
		dialogs._ok.pressed.emit())
	await dialogs.alert("Title", "Body")
	check(not bool(cancel_shown[0]), "alert 에는 취소 버튼이 없다")

	dialogs._open = true
	var refused: bool = await dialogs.confirm("A", "B")
	check(not refused, "이미 떠 있으면 두 번째 confirm 은 곧바로 false")
	dialogs._open = false
	check(not dialogs.is_open(), "닫힌 상태")
	dialogs.queue_free()
	await frames(2)


# ── 알림 ───────────────────────────────────────────────────────────────

func _notice() -> void:
	var notice := GoNotice.new()
	root.add_child(notice)
	await frames(1)
	check(notice.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "알림 서브트리 전체가 입력을 받지 않는다")
	check(notice.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED, "알림은 포커스를 훔치지 않는다")
	var expired := [false]
	notice.expired.connect(func() -> void: expired[0] = true)
	notice.show_text("hello", GoTheme.SUCCESS, 0.1)
	check(notice.visible, "show_text 로 보인다")
	await create_timer(0.35).timeout
	check(bool(expired[0]) and not notice.visible, "시간이 지나면 사라진다")
	TranslationServer.set_locale("en")
	notice.show_key("gohud_close")
	check(notice.label.text == "Close", "show_key 번역")
	notice.queue_free()
	await frames(1)


# ── 질문 카드 ──────────────────────────────────────────────────────────

func _prompt() -> void:
	var card := GoPromptCard.new()
	root.add_child(card)
	await frames(1)
	var hits := [0]
	card.set_actions([{"text": "Accept", "action": func() -> void: hits[0] += 1, "primary": true}, {"text": "No"}])
	var first := card.actions.get_child(0) as Button
	var first_id := first.get_instance_id()
	card.set_actions([{"text": "Accept", "action": func() -> void: hits[0] += 10, "primary": true}, {"text": "No"}])
	check(card.actions.get_child(0).get_instance_id() == first_id, "같은 구성이면 버튼을 다시 만들지 않는다 — 누르던 탭이 살아남는다")
	first.pressed.emit()
	check(int(hits[0]) == 10, "동작은 새 Callable 로 갱신된다")
	card.set_actions([{"text": "Other"}])
	await frames(1)
	check(card.actions.get_child_count() == 1 and card.actions.get_child(0).get_instance_id() != first_id, "구성이 바뀌면 다시 만든다")
	card.set_icon(GoIconSet.USER_PLUS, Color.WHITE, true)
	check(card.icon_slot.visible and card.icon_slot.get_node_or_null(^"Disc") != null, "원형 배지 아이콘")
	card.fit_width(300)
	check(near(card.custom_minimum_size.x, 300.0), "fit_width")
	card.queue_free()
	await frames(1)


# ── 값 막대 ────────────────────────────────────────────────────────────

func _bar() -> void:
	var bar := GoBar.new()
	root.add_child(bar)
	await frames(1)
	bar.set_values(320, 500, false)
	var value_label := bar.get_node(^"Column/Head/Value") as Label
	check(value_label != null and value_label.text == "320 / 500", "분수 표시")
	bar.readout = GoBar.Readout.PERCENT
	check(value_label.text == "64%", "퍼센트 표시")
	var fill := bar.get_node(^"Column/Fill") as ProgressBar
	check(near(fill.value, 0.64, 0.001), "막대 비율")
	check(fill.get_theme_stylebox(&"fill").get_margin(SIDE_TOP) <= 1.0, "채움 스타일에 카드 여백이 딸려 오지 않는다")
	check(bar.get_combined_minimum_size().y >= 24.0, "막대 최소 높이가 이름 줄과 막대를 함께 담는다 — 겹치지 않는다 (%.0f)" % bar.get_combined_minimum_size().y)
	check(GoBar.abbreviate(999) == "999" and GoBar.abbreviate(12345) == "12.3k" and GoBar.abbreviate(1234567) == "1.2m", "큰 수 줄임")
	bar.queue_free()
	await frames(1)


# ── 퀵슬롯 ─────────────────────────────────────────────────────────────

func _slot() -> void:
	var a := GoSlot.new()
	var b := GoSlot.new()
	a.icon_name = GoIconSet.POTION
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(0, 0)
	b.position = Vector2(40, 0)
	await frames(2)
	var quantity := a.get_node(^"Face/Quantity") as Label
	a.quantity = GoSlot.NONE
	check(not quantity.visible, "NONE 은 수량 줄을 그리지 않는다")
	a.quantity = GoSlot.UNKNOWN
	check(quantity.visible and quantity.text == "…", "UNKNOWN 은 …")
	a.quantity = 12
	check(quantity.text == "×12", "수량 ×12")
	check(near((a.get_node(^"Face") as Panel).size.x, 44.0), "보이는 판은 한 장 44")
	var peers: Array[Control] = [a, b]
	a.touch_peers = peers
	b.touch_peers = peers
	var point := Vector2(46, 24)
	check(not a._has_point(point - a.global_position) and b._has_point(point - b.global_position), "겹친 자리는 중심이 가까운 슬롯이 받는다")
	a.start_cooldown(1.0)
	await frames(1)
	check((a.get_node(^"Face/Timer") as Label).visible, "쿨다운 남은 시간 표시")
	a.queue_free()
	b.queue_free()
	await frames(1)


# ── 조이스틱 ───────────────────────────────────────────────────────────

func _joystick() -> void:
	var pad := GoJoystick.new()
	pad.mode = GoJoystick.Mode.FIXED
	root.add_child(pad)
	await frames(1)
	var center := pad.size * 0.5
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = center
	pad._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(pad.radius * 2.0, 0)
	pad._gui_input(drag)
	check(near(pad.vector().x, 1.0, 0.01) and near(pad.vector().y, 0.0, 0.01), "반지름 밖으로 끌어도 길이 1")
	drag.position = center + Vector2(pad.radius * 0.05, 0)
	pad._gui_input(drag)
	check(pad.vector() == Vector2.ZERO, "데드존 안은 0")
	var released := [false]
	pad.released.connect(func() -> void: released[0] = true)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = center
	pad._gui_input(up)
	check(bool(released[0]) and pad.vector() == Vector2.ZERO and not pad.is_active(), "떼면 0 · released")
	pad.queue_free()
	await frames(1)


# ── HUD 자리 ───────────────────────────────────────────────────────────

func _anchor() -> void:
	var spot := GoHudAnchor.new()
	spot.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	root.add_child(spot)
	var box := Control.new()
	box.custom_minimum_size = Vector2(100, 40)
	spot.add_child(box)
	await frames(3)
	var area := GoSafeArea.usable_rect(spot.get_window()).grow(-GoUi.metric(GoTheme.SCREEN_MARGIN))
	var rect := spot.get_global_rect()
	check(near(rect.end.x, area.end.x) and near(rect.end.y, area.end.y), "BOTTOM_RIGHT — 여백 안쪽 모서리")
	check(near(spot.size.x, 100.0) and near(spot.size.y, 40.0), "자식 최소 크기만큼 (%s · 남은 영역 %s)" % [str(spot.size), str(area.size)])
	box.custom_minimum_size = Vector2(160, 60)
	await frames(2)
	check(near(spot.size.x, 160.0) and near(spot.get_global_rect().end.x, area.end.x),
		"자식이 커지면 따라 커지고 모서리를 지킨다 (%s)" % str(spot.get_global_rect()))
	spot.queue_free()
	await frames(1)


# ── 안내 투어 ──────────────────────────────────────────────────────────

func _coach() -> void:
	var baseline := GoBackPolicy.owners()
	var first := Button.new()
	first.position = Vector2(20, 20)
	first.size = Vector2(80, 40)
	var second := Button.new()
	second.position = Vector2(200, 300)
	second.size = Vector2(80, 40)
	root.add_child(first)
	root.add_child(second)
	var tour := GoCoachMark.new()
	root.add_child(tour)
	await frames(1)
	var done := [false, false]
	tour.finished.connect(func(completed: bool) -> void:
		done[0] = true
		done[1] = completed)
	tour.start([{"target": first, "title": "One", "body": "b"}, {"target": second, "title": "Two", "body": "b"}])
	await frames(1)
	check(tour.visible and tour.progress_label.text == "1 / 2", "투어 시작 (%s)" % tour.progress_label.text)
	check(GoBackPolicy.owners() == baseline + 1, "투어도 뒤로가기를 붙잡는다")
	first.pressed.emit()
	await frames(2)
	check(tour.step == 1, "가리킨 컨트롤을 실제로 누르면 다음 단계")
	tour.next_button.pressed.emit()
	await frames(2)
	check(bool(done[0]) and bool(done[1]) and not tour.visible, "마지막 단계 뒤 완료")
	check(GoBackPolicy.owners() == baseline, "완료하면 뒤로가기 반납")
	tour.queue_free()
	first.queue_free()
	second.queue_free()
	await frames(1)


# ── 폼 ─────────────────────────────────────────────────────────────────

func _form() -> void:
	var form := GoForm.new()
	var scroll := GoScroll.new()
	form.add_child(scroll)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	root.add_child(form)
	await frames(2)
	var view := form.get_viewport_rect().size
	var area := GoSafeArea.usable_rect(form.get_window())
	var cap := float(GoScale.form_width_for(GoScale.breakpoint_for_dp(minf(view.x, view.y))))
	var side := float(GoUi.metric(GoTheme.PADDING))
	if cap > 0.0 and area.size.x > cap: side = maxf(side, (area.size.x - cap) * 0.5)
	check(near(form.get_theme_constant(&"margin_left"), roundf(area.position.x + side)), "좌우 여백 = 브레이크포인트 최대 폼 폭")
	check(form.scroll == scroll, "Scroll 자식을 찾는다")
	var late := Label.new()
	late.text = "a long sentence that has to wrap on narrow phones"
	column.add_child(late)
	await frames(1)
	check(late.autowrap_mode != TextServer.AUTOWRAP_OFF, "나중에 들어온 라벨도 줄바꿈이 보장된다")
	form.queue_free()
	await frames(1)


# ── 소리·진동 ──────────────────────────────────────────────────────────

func _feedback() -> void:
	var cues := []
	var buzz := []
	GoFeedback.sound_handler = func(cue: String) -> void: cues.append(cue)
	GoFeedback.haptic_handler = func(ms: int, amplitude: float) -> void: buzz.append([ms, amplitude])
	GoFeedback.opened()
	GoFeedback.failed()
	check(cues == ["ui_open", "ui_error"], "신호 이름 → 프로젝트 음원 이름 (%s)" % str(cues))
	check(buzz.size() == 2 and int(buzz[0][0]) == 20 and int(buzz[1][0]) == 40, "열림 20ms · 오류 40ms")
	GoUi.config.haptics_enabled = false
	GoFeedback.tapped()
	check(buzz.size() == 2, "haptics_enabled=false 면 떨지 않는다")
	GoUi.config.haptics_enabled = true
	var remapped: Dictionary[StringName, String] = {GoFeedback.OPENED: "door"}
	GoUi.config.sound_cues = remapped
	GoFeedback.opened()
	check(cues.back() == "door", "sound_cues 로 음원 이름을 바꿔 끼운다")
	GoUi.config.sound_cues = GoConfig.new().sound_cues
	GoFeedback.sound_handler = Callable()
	GoFeedback.haptic_handler = Callable()


# ── 좌우 방향 ──────────────────────────────────────────────────────────

func _rtl() -> void:
	var scroll := GoScroll.new()
	var content := VBoxContainer.new()
	scroll.add_child(content)
	root.add_child(scroll)
	await frames(1)
	check(scroll.layout_direction == Control.LAYOUT_DIRECTION_LTR, "스크롤 레일은 물리적 오른쪽")
	check(content.layout_direction == Control.LAYOUT_DIRECTION_APPLICATION_LOCALE, "내용은 앱 언어 방향")
	var pad := GoJoystick.new()
	check(pad.layout_direction == Control.LAYOUT_DIRECTION_LTR, "조이스틱은 물리적 방향")
	pad.free()
	scroll.queue_free()
	await frames(1)


# ── 독립성 ─────────────────────────────────────────────────────────────

## 애드온이 호스트 프로젝트에 기대면 스토어에서 받은 사람의 프로젝트에서 깨진다.
func _standalone() -> void:
	var outside_ref := RegEx.create_from_string("res://[A-Za-z0-9_./%-]+")
	# 🛑 호스트 프로젝트의 클래스 이름을 하드코딩하지 않는다 — 어느 프로젝트에 설치될지 모른다.
	#    애드온이 스스로 선언한 이름도, 엔진이 아는 이름도 아닌 것에 `X.` 로 접근한다면 그것이 외부 의존이다.
	var known := _own_symbols()
	var static_access := RegEx.create_from_string("(?<![A-Za-z0-9_.\"'])([A-Z][A-Za-z0-9_]*)\\s*\\.")
	var trailing_comment := RegEx.create_from_string("\\s#.*$")
	# 🛑 문자열 안은 코드가 아니다 — 영문 문장 끝의 마침표("… placement CENTER. It respects …")가
	#    `X.` 로 보여 오탐이 났다. 심볼 검사에서는 리터럴을 지우고 본다(res:// 검사는 원문에서 한다).
	var literal := RegEx.create_from_string("\"[^\"]*\"|'[^']*'")
	var problems: Array[String] = []
	for path in _files(ADDON, ["gd", "tscn", "tres", "cfg"]):
		if path.begins_with(ADDON + "/tests/") or path.begins_with(ADDON + "/tools/"): continue
		var number := 0
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var line := raw.strip_edges()
			if line.begins_with("#"): continue
			line = trailing_comment.sub(line, "")
			for found in outside_ref.search_all(line):
				if not found.get_string().begins_with(ADDON + "/"):
					problems.append("%s:%d %s" % [path.get_file(), number, found.get_string()])
			for found in static_access.search_all(literal.sub(line, "\"\"", true)):
				var symbol := found.get_string(1)
				if known.has(symbol) or ClassDB.class_exists(symbol): continue
				problems.append("%s:%d %s (외부 심볼)" % [path.get_file(), number, symbol])
			if "\"/root/" in line: problems.append("%s:%d /root/ 경로" % [path.get_file(), number])
	check(problems.is_empty(), "애드온 밖 res://·호스트 프로젝트 심볼·오토로드 경로에 기대지 않는다 %s" % str(problems.slice(0, 6)))
	check(FileAccess.file_exists(ADDON + "/LICENSE") and FileAccess.file_exists(ADDON + "/THIRD_PARTY_NOTICES.md"), "라이선스 고지 파일이 있다")
	var plugin := ConfigFile.new()
	check(plugin.load(ADDON + "/plugin.cfg") == OK and str(plugin.get_value("plugin", "version", "")) == GoUi.VERSION, "plugin.cfg 버전 = GoUi.VERSION")


## 애드온이 스스로 선언한 이름(class_name·enum)과 엔진 내장 Variant 타입.
## 🛑 Variant 타입(Vector2·Color…)은 ClassDB 에 없으므로 여기서 따로 인정한다.
func _own_symbols() -> Dictionary:
	var known := {}
	for builtin in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
			"Rect2", "Rect2i", "Color", "Transform2D", "Transform3D", "Basis", "Quaternion",
			"AABB", "Plane", "Projection", "RID", "Callable", "Signal", "StringName", "NodePath",
			"Dictionary", "Array", "String", "PackedByteArray", "PackedInt32Array",
			"PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array", "PackedStringArray",
			"PackedVector2Array", "PackedVector3Array", "PackedVector4Array", "PackedColorArray"]:
		known[builtin] = true
	var declared := RegEx.create_from_string("^\\s*(?:class_name\\s+|enum\\s+|const\\s+)([A-Z][A-Za-z0-9_]*)")
	for path in _files(ADDON, ["gd"]):
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			var found := declared.search(raw)
			if found != null: known[found.get_string(1)] = true
	return known


func _files(dir: String, extensions: Array) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension() in extensions: found.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("."): continue
		found.append_array(_files(dir.path_join(sub), extensions))
	return found
