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
	# 🛑 **화면 하나로만 검사하면, 다른 화면에서만 도는 코드는 통째로 미검증이다.**
	#    폼의 폭 제한이 그랬다 — 폰에서는 상한이 "없음" 이라 규칙이 아예 발동하지 않았다(반복 15).
	#    `GOHUD_VIEWPORT=1280x800` 으로 크기를 바꿔 같은 검사를 다시 돌린다.
	var wanted := Vector2i(390, 844)
	var asked := OS.get_environment("GOHUD_VIEWPORT")
	if asked.contains("x"):
		var parts := asked.split("x")
		wanted = Vector2i(maxi(200, int(parts[0])), maxi(200, int(parts[1])))
	root.content_scale_size = wanted
	await frames(2)
	var view := root.get_visible_rect().size
	print("  viewport %s" % str(view))
	check(minf(view.x, view.y) >= 320.0, "검사용 뷰포트가 충분히 크다 (%s)" % str(view))
	await _section("back policy", _back_policy)
	await _section("tokens · themes", _tokens)
	await _section("presets · skins", _presets)
	await _section("medieval theme", _medieval)
	await _section("skin contrast", _skin_contrast)
	await _section("icon sets", _icons)
	await _section("localization", _i18n)
	await _section("text customisation", _text_customisation)
	await _section("scale functions", _scale)
	await _section("widgets", _widgets)
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


# ── 생김새 묶음 · 스킨 ─────────────────────────────────────────────────

func _presets() -> void:
	# ── 스킨 다이얼 — 리소스에서 숫자만 바꾼다 ──────────────────────────
	# 🔑 코드에 박혀 있던 숫자를 `@export` 로 냈다(2026-09-13). 값이 실제 판에 닿는지, 그리고
	#    스캐폴딩이 쓰는 표(`tools/skin_dials.json`)가 GDScript 기본값과 같은지 잰다 — 표가 어긋나면
	#    새 테마의 JSON 에 엉뚱한 기본값이 풀어 적힌다.
	var dialed := GoSkin.new()
	dialed.slot_border_lit = 3
	dialed.badge_pad_x = 9
	var dial_box := dialed.slot_box(Color.RED, true) as StyleBoxFlat
	check(dial_box != null and dial_box.border_width_top == 3, "슬롯 테두리 다이얼이 판에 닿는다 (%s)"
		% (str(dial_box.border_width_top) if dial_box != null else "null"))
	check(int(dialed.badge_box(Color.RED).content_margin_left) == 9, "배지 여백 다이얼이 판에 닿는다")
	# 떠 있는 카드의 깊이감도 다이얼 — 그림자(둥근 판) / 발광(사선 판).
	var lifted := GoSkin.new()
	lifted.float_shadow_size = 21
	lifted.float_shadow_lift = 6
	var lifted_box := lifted.floating_box(GoTheme.BOX_CARD) as StyleBoxFlat
	check(lifted_box != null and lifted_box.shadow_size == 21 and lifted_box.shadow_offset.y == 6.0,
		"떠 있는 카드의 그림자 다이얼이 판에 닿는다 (%s)" % (str(lifted_box.shadow_size) if lifted_box != null else "null"))
	# 🛑 사선 판은 **테마**가 준다 — 스킨 인스턴스만 만들고 재면 기본 테마의 둥근 판이 와서 발광 칸이 없다
	#    (실제로 그렇게 실패했다). 프리셋을 sci-fi 로 바꾼 뒤 재고 되돌린다.
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	var glowing := GoSkinSciFi.new()
	glowing.float_glow_size = 13.0
	var glow_box := glowing.floating_box(GoTheme.BOX_HUD)
	check(&"glow_size" in glow_box and is_equal_approx(float(glow_box.get(&"glow_size")), 13.0),
		"사선 판은 떠 있을 때 발광 다이얼을 따른다 (%s)" % (str(glow_box.get(&"glow_size")) if &"glow_size" in glow_box else "없음"))
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.preset = &""
	var scifi_dialed := GoSkinSciFi.new()
	scifi_dialed.cut_slot = 9.0
	var cut_box := scifi_dialed.slot_box(Color.RED, false)
	check(&"cut" in cut_box and is_equal_approx(float(cut_box.get(&"cut")), 9.0), "sci-fi 잘린 모서리 다이얼이 판에 닿는다")
	# Store ZIPs omit tools/. The ZIP harness supplies the same fixture beside this
	# external test script, keeping the installed add-on identical to the shipped ZIP.
	var table_path := "res://addons/gohud/tools/skin_dials.json"
	if not FileAccess.file_exists(table_path):
		table_path = String(get_script().resource_path).get_base_dir().path_join("skin_dials.json")
	var table_text := FileAccess.get_file_as_string(table_path)
	var table: Variant = JSON.parse_string(table_text) if not table_text.is_empty() else null
	check(table is Dictionary, "tools/skin_dials.json 을 읽는다")
	if table is Dictionary:
		var fresh_default := GoSkin.new()
		var fresh_scifi := GoSkinSciFi.new()
		var fresh_medieval := GoSkinMedieval.new()
		var off: Array = []
		for key in table.get("default", {}):
			if not is_equal_approx(float(fresh_default.get(key)), float(table["default"][key])): off.append(key)
		for key in table.get("scifi", {}):
			if not is_equal_approx(float(fresh_scifi.get(key)), float(table["scifi"][key])): off.append(key)
		for key in table.get("medieval", {}):
			if not is_equal_approx(float(fresh_medieval.get(key)), float(table["medieval"][key])): off.append(key)
		check(off.is_empty(), "다이얼 표가 GDScript 기본값과 같다 %s" % str(off))

	# ── 폴더에 놓인 프리셋은 코드 수정 없이 뜬다 ──────────────────────
	# 🛑 새 테마를 더할 때 레지스트리 상수까지 고쳐야 했다면, 테마를 더 들이겠다는 요청(2026-09-13)에
	#    맞지 않는다. `.tres` 를 폴더에 두는 것으로 끝나야 하고, 그것을 지키는 것이 이 검사다.
	var probe_dir := "user://gohud_presets_probe"
	DirAccess.make_dir_recursive_absolute(probe_dir)
	var probe := GoThemePreset.new()
	probe.id = &"probe_theme"
	probe.title = "Probe"
	probe.theme = GoUi.DEFAULT_THEME
	var saved := ResourceSaver.save(probe, probe_dir + "/probe_theme.tres")
	check(saved == OK, "프리셋 리소스를 임시 폴더에 저장한다")
	var seen := GoThemePresets.scan_folder(probe_dir)
	check(seen.has(&"probe_theme"), "폴더의 프리셋을 파일 이름으로 찾는다 %s" % str(seen))
	# 내보낸 게임에서는 텍스트 리소스가 `.remap` 을 달 수 있다 — 그 꼬리도 벗긴다.
	var remap := FileAccess.open(probe_dir + "/shipped.tres.remap", FileAccess.WRITE)
	if remap != null: remap.close()
	check(GoThemePresets.scan_folder(probe_dir).has(&"shipped"), ".remap 꼬리를 벗겨 이름을 얻는다")
	DirAccess.remove_absolute(probe_dir + "/probe_theme.tres")
	DirAccess.remove_absolute(probe_dir + "/shipped.tres.remap")
	check(GoThemePresets.names().size() >= GoThemePresets.BUILTIN.size()
		and GoThemePresets.names()[0] == GoThemePresets.DEFAULT_DARK,
		"names() 는 기본 순서를 지키고 폴더의 것을 뒤에 붙인다 %s" % str(GoThemePresets.names()))

	# 🛑 이 애드온은 4.6 미만에서는 **파싱 단계에서 죽는다** — 여기까지 왔다면 이미 통과한 셈이지만,
	#    검사 로그에 실제로 돌린 엔진을 남겨 두면 "어느 버전에서 통과했나" 를 나중에 따질 수 있다.
	var info := Engine.get_version_info()
	check(GoUi.engine_supported(), "엔진 %d.%d 는 최소 %s 이상 — 지원 범위 안" % [
		info.major, info.minor, GoUi.min_engine_string()])

	var ids := GoThemePresets.ids()
	for wanted in [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT,
			GoThemePresets.SCIFI_DARK, GoThemePresets.SCIFI_LIGHT,
			GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		check(ids.has(wanted), "프리셋이 있다 — %s" % wanted)
	for preset in GoThemePresets.all():
		check(preset.theme != null and preset.skin != null and not preset.label().is_empty(),
			"%s: 테마·스킨·이름이 채워져 있다" % preset.id)

	check(GoUi.skin() is GoSkin, "기본 스킨은 GoSkin")
	var plain := GoUi.skin()
	check(GoUi.skin() == plain, "기본 스킨은 매번 새로 만들지 않는다")

	# 🛑 여기서부터 생김새를 갈아 끼운다 — 섹션 끝에서 반드시 되돌린다.
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	check(GoUi.theme() != GoUi.DEFAULT_THEME, "sci-fi 테마로 바뀐다")
	check(GoUi.skin() is GoSkinSciFi, "sci-fi 스킨으로 바뀐다")

	# 모양을 바꾸는 테마는 **커스텀 StyleBox** 를 준다 — 이것이 색만 바꾸는 것과의 차이다.
	var panel := GoUi.box(GoTheme.BOX_PANEL)
	check(panel is GoStyleBoxCut, "sci-fi 패널은 각진 판(GoStyleBoxCut)")
	check((panel as GoStyleBoxCut).cut > 0.0, "자르는 크기가 0 이 아니다")
	check(GoStyle.surface(GoTheme.BOX_PANEL) is GoStyleBoxCut, "GoStyle.surface() 는 커스텀 모양을 그대로 넘긴다")
	# 🛑 옛 호출부와의 약속 — `box()` 는 무슨 테마에서든 StyleBoxFlat 이다.
	check(GoStyle.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "GoStyle.box() 는 sci-fi 에서도 StyleBoxFlat")
	# 🛑 평판으로 옮겨도 판의 여백·색·테두리는 이어받는다 — 빈 평판(여백 0)이면 호스트 카드의 글자가 테두리에 붙는다
	#    (2026-09-15 라리엔 생김새 전환 · 호스트의 옛 `box()` 호출이 전부 이 경로다).
	var cut_card := GoStyle.surface(GoTheme.BOX_CARD) as GoStyleBoxCut
	var flat_card := GoStyle.box(GoTheme.BOX_CARD)
	check(cut_card != null and flat_card.content_margin_left == cut_card.content_margin_left
		and flat_card.content_margin_top == cut_card.content_margin_top and flat_card.bg_color == cut_card.bg_color
		and flat_card.border_color == cut_card.border_color and flat_card.border_width_top == roundi(cut_card.border_width),
		"GoStyle.box() 평판은 각진 판의 여백·색·테두리를 이어받는다 (여백 %.0f / 판 %.0f)" % [flat_card.content_margin_left, cut_card.content_margin_left if cut_card != null else -1.0])

	var missing: Array[StringName] = []
	for key in [GoTheme.BACKGROUND, GoTheme.SURFACE, GoTheme.SURFACE_SOFT, GoTheme.SURFACE_HIGH,
			GoTheme.BORDER, GoTheme.TEXT, GoTheme.SECONDARY, GoTheme.MUTED, GoTheme.ACCENT,
			GoTheme.ON_ACCENT, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER, GoTheme.INFO,
			GoTheme.SCRIM, GoTheme.SHADOW, GoTheme.TRACK]:
		if GoUi.color(key) == Color.MAGENTA: missing.append(key)
	check(missing.is_empty(), "sci-fi 테마에 색 토큰이 전부 있다 (빠짐: %s)" % str(missing))
	check(GoUi.metric(GoTheme.RADIUS) > 0 and GoUi.metric(GoTheme.PADDING) > 0, "sci-fi 치수 토큰")

	# 코드가 직접 그리는 자리도 실제로 모양이 바뀌는가
	var slot := GoSlot.new()
	root.add_child(slot)
	await frames(2)
	check(slot.get_node(^"Face").get_theme_stylebox(&"panel") is GoStyleBoxCut, "퀵슬롯 판이 각진 판으로 바뀐다")
	check(GoUi.skin().coach_ring_box(Color.CYAN) is GoStyleBoxBracket, "코치마크 링이 모서리 표식으로 바뀐다")
	check(GoStyle.chip("x").get_theme_stylebox(&"panel") is GoStyleBoxCut, "칩이 각진 판으로 바뀐다")
	var pad := GoJoystick.new()
	root.add_child(pad)
	await frames(2)
	check(is_instance_valid(pad), "sci-fi 스킨으로 조이스틱이 그려진다")
	slot.queue_free()
	pad.queue_free()
	await frames(1)

	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	check(GoUi.theme() == GoUi.DEFAULT_THEME, "기본으로 되돌아온다")
	check(GoUi.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "기본 패널은 평판 그대로")
	GoUi.config.preset = &""


# New presets exercise the public widget path, including switching back to the originals.
func _medieval() -> void:
	for preset in [GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		GoUi.use_preset(preset)
		var theme := GoUi.theme()
		check(GoUi.skin() is GoSkinMedieval, "%s: medieval skin selected" % preset)
		var menu := GoStyle.surface(GoTheme.BOX_PANEL) as GoStyleBoxMedieval
		var hud := GoStyle.surface(GoTheme.BOX_HUD) as GoStyleBoxMedieval
		check(menu != null and hud != null, "%s: menu and HUD use forged frames" % preset)
		if menu != null and hud != null:
			check(menu.ornament == 2 and hud.ornament == 0, "%s: menu ornaments stay off the gameplay HUD" % preset)
			check(menu.material == (1 if preset == GoThemePresets.MEDIEVAL_DARK else 2), "%s: leather / parchment material" % preset)
		check(theme.get_font(&"font", &"GoTitleLabel").resource_path.ends_with("Cinzel.ttf"), "%s: title uses Cinzel" % preset)
		check(not theme.has_font(&"font", &"Label") and theme.default_font == null, "%s: readable body font stays inherited" % preset)
		var icons := GoUi.icons()
		check(icons.texture(GoIconSet.SWORD) is DPITexture, "%s: engraved icons scale without raster blur" % preset)
		check(icons.texture(GoIconSet.CLOSE) == icons.fallback.texture(GoIconSet.CLOSE), "%s: navigation icons keep their fallback" % preset)
		var slot := GoSlot.new()
		slot.icon_name = GoIconSet.SHIELD
		root.add_child(slot)
		await frames(2)
		check(slot.get_node(^"Face").get_theme_stylebox(&"panel") is GoStyleBoxMedieval, "%s: real inventory slot uses the skin" % preset)
		slot.queue_free()
		# Changing a copied skin must affect real drawing resources without changing the preset.
		var skin := GoUi.skin().duplicate() as GoSkinMedieval
		skin.ornament_scale = 0.7
		skin.slot_rivets = 0
		skin.leather_grain_alpha = 0.0
		var face := skin.slot_box(GoUi.color(GoTheme.ACCENT), true) as GoStyleBoxMedieval
		check(face.ornament == 0 and face.grain_alpha == 0.0 and near(face.ornament_scale, 0.7, 0.001), "%s: custom dials reach the slot" % preset)
		check((GoUi.skin() as GoSkinMedieval).slot_rivets == 1, "%s: copied skin leaves source unchanged" % preset)
		check(GoStyle.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "%s: legacy flat-box API stays compatible" % preset)
		var forged := GoStyle.surface(GoTheme.BOX_CARD) as GoStyleBoxMedieval
		var flat_face := GoStyle.box(GoTheme.BOX_CARD)
		check(forged != null and flat_face.content_margin_left == forged.content_margin_left
			and flat_face.bg_color == forged.bg_color and flat_face.corner_radius_top_left == roundi(forged.radius),
			"%s: flat box keeps the frame's padding, colour and radius" % preset)
		await frames(1)
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	check(GoUi.theme() == GoUi.DEFAULT_THEME and GoUi.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "medieval returns to unchanged default")
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	check(GoUi.skin() is GoSkinSciFi and GoUi.box(GoTheme.BOX_PANEL) is GoStyleBoxCut, "medieval returns to sci-fi geometry")
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.preset = &""


# ── 스킨이 만드는 색의 대비 ────────────────────────────────────────────
#
# 🛑 `tools/check_contrast.py` 는 테마 `.tres` 만 읽는다. 스킨이 **실행 중에** 만드는 색
#    (칩의 같은 색 틴트, 슬롯 판, 알림 상자)은 그 바깥이라, 여기서만 잡힌다.

func _skin_contrast() -> void:
	var tones := [GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER, GoTheme.INFO, GoTheme.SECONDARY]
	for preset in [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT,
			GoThemePresets.SCIFI_DARK, GoThemePresets.SCIFI_LIGHT,
			GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		GoUi.use_preset(preset)
		var skin := GoUi.skin()
		var under := GoSkin.blend(GoUi.color(GoTheme.SURFACE_SOFT), GoUi.color(GoTheme.BACKGROUND))
		# 🛑 **배열에 담는다.** GDScript 람다는 바깥 지역 변수를 **값으로 캡처**하므로, 람다 안에서
		#    `worst = value` 를 해도 바깥에는 반영되지 않는다 — 그러면 이 검사는 무엇을 재든
		#    늘 통과한다. 실제로 그랬다(2026-09-13: 보정을 세 곳 다 걷어내도 초록불이었다).
		#    배열·사전은 참조로 캡처되므로 안쪽의 쓰기가 바깥에 보인다.
		var worst := [99.0, ""]

		var note := func(name: String, ink: Color, back: Color) -> void:
			var value := GoSkin.contrast_ratio(GoSkin.blend(ink, back), back)
			if value < worst[0]:
				worst[0] = value
				worst[1] = name

		for tone in tones:
			var ink: Color = GoUi.color(tone)
			# 🛑 **실제로 만들어진 칩**에서 읽는다 — 스킨 메서드만 재면 위젯이 그 값을 쓰는지는 모른다.
			var chip := GoStyle.chip("42", ink)
			root.add_child(chip)
			await frames(1)
			var back := GoSkin.blend(GoSkin.box_background(chip.get_theme_stylebox(&"panel")), under)
			var label := chip.get_child(0) as Label
			note.call("칩 %s" % tone, label.get_theme_color(&"font_color"), back)
			chip.queue_free()
			await frames(1)

		var accent := GoUi.color(GoTheme.ACCENT)
		# 🛑 **실제로 그려지는 글자색**을 읽는다. 스킨 메서드의 반환값만 재면, 위젯이 그 값을 쓰지
		#    않고 고정색을 칠하는 경우를 놓친다 — 빈 슬롯의 수량이 그랬다(2026-09-13: 쿨다운 중 3.97:1).
		for state in [{"q": 3, "cd": 0.0}, {"q": 0, "cd": 5.0}]:
			var probe := GoSlot.new()
			probe.accent = accent
			probe.icon_name = GoIconSet.POTION
			probe.quantity = state["q"]
			root.add_child(probe)
			probe.set_cooldown(state["cd"], 8.0)
			await frames(2)
			var panel := (probe.get_node(^"Face") as Panel).get_theme_stylebox(&"panel")
			var face := GoSkin.blend(GoSkin.box_background(panel), under)
			for child in [^"Face/QuantityBadge/Quantity", ^"Face/TimerBadge/Timer", ^"Face/Shortcut"]:
				var label := probe.get_node_or_null(child) as Label
				if label == null or not label.is_visible_in_tree(): continue
				# 배지 안의 글자는 **배지 판** 위에 놓인다 — 슬롯 판이 아니라.
				var under_label := face
				var badge_panel := label.get_parent() as PanelContainer
				if badge_panel != null:
					under_label = GoSkin.blend(GoSkin.box_background(badge_panel.get_theme_stylebox(&"panel")), face)
				note.call("슬롯 %s(수량 %d)" % [child, state["q"]],
					label.get_theme_color(&"font_color"), under_label)
			# 🛑 **아이콘도 잰다.** 라벨만 재던 동안 아이콘은 `Color.WHITE` 로 고정되어 있었고,
			#    밝은 테마에서 흰 물약이 흰 판에 통째로 묻혔다(2026-09-13 갤러리 실측).
			#    그려지는 색은 칸의 `modulate` 와 그림 자신의 `modulate` 가 곱해진 것이다.
			var icon_slot := probe.get_node_or_null(^"Face/IconSlot") as Control
			# 🛑 쿨다운이 도는 동안 아이콘은 **일부러** 판 색 쪽으로 물린다 — 그때 정보는 그 위의 남은
			#    시간 배지가 맡고, 그 글자는 위에서 잰다. 비활성 상태 표시는 WCAG 1.4.3 의 예외이기도 하다.
			if state["cd"] <= 0.0 and icon_slot != null and icon_slot.get_child_count() > 0:
				var glyph := icon_slot.get_child(0) as CanvasItem
				note.call("슬롯 아이콘(수량 %d)" % state["q"],
					icon_slot.modulate * glyph.modulate, face)
			probe.queue_free()
			await frames(1)

		# 🛑 **자식 라벨로 떨어지는 글리프.** 텍스처가 없는 이름(또는 폰트 아이콘 세트)은 버튼 안에
		#    Label 로 그려지는데, 버튼 테마의 `icon_normal_color` 는 자식에게 닿지 않는다 —
		#    색을 안 집어 주면 흰색이 되어 밝은 테마에서 판에 묻힌다.
		var glyph_button := GoIconButton.new()
		glyph_button.icon_name = &"no_such_icon_for_test"
		root.add_child(glyph_button)
		await frames(2)
		var glyph_label := glyph_button.get_node_or_null(^"Icon") as Label
		if glyph_label != null:
			note.call("아이콘 버튼 글리프", glyph_label.get_theme_color(&"font_color"),
				GoSkin.blend(GoSkin.box_background(glyph_button.get_theme_stylebox(&"normal")), under))
		glyph_button.queue_free()
		await frames(1)

		for tone in [GoTheme.INFO, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER]:
			var ink2: Color = GoUi.color(tone)
			var back2 := GoSkin.blend(GoSkin.box_background(skin.alert_box(ink2)), under)
			note.call("알림 %s 본문" % tone, GoUi.color(GoTheme.TEXT), back2)

		# ── 막대 채움 ───────────────────────────────────────────────────
		# 🛑 **색만으로 대비를 맞추려 하면 색을 잃는다.** 노랑은 휘도가 본래 높아 어떤 회색 바탕
		#    위에서도 3:1 이 안 나오고, 기준을 맞추려 명도를 내리면 경험치 막대가 **갈색**이 된다
		#    (밝은 테마에서 실제로 `#A05000` 이었다). 그래서 두 가지를 **함께** 요구한다 —
		#    ① 바탕에서 구분될 것(색이 모자라면 윤곽이 대신한다) ② 색이 죽지 않을 것.
		var track := GoSkin.blend(GoUi.color(GoTheme.TRACK), GoUi.color(GoTheme.SURFACE))
		for pair in [[GoTheme.SUCCESS_FILL, "성공"], [GoTheme.WARNING_FILL, "경고"],
				[GoTheme.DANGER_FILL, "위험"], [GoTheme.INFO_FILL, "정보"]]:
			var fill: Color = GoUi.color(pair[0])
			var box := GoUi.skin().progress_fill_box(fill)
			var flat := box as StyleBoxFlat
			var seen := GoSkin.contrast_ratio(GoSkin.blend(fill, track), track)
			var edge := Color.TRANSPARENT
			if flat != null and flat.border_width_top > 0: edge = flat.border_color
			elif flat == null and &"border_color" in box and float(box.get(&"border_width")) > 0.0:
				edge = box.get(&"border_color")
			if edge.a > 0.0:
				seen = maxf(seen, GoSkin.contrast_ratio(GoSkin.blend(edge, track), track))
			check(seen >= 3.0, "%s: %s 막대가 바탕에서 구분된다 (%.2f:1 — 색 또는 윤곽으로)"
				% [preset, pair[1], seen])
			# 갈색으로 가라앉지 않았는가. 채도는 갈색도 높으므로 **명도**로 잰다(#A05000 은 0.63).
			check(fill.v >= 0.70, "%s: %s 막대 색이 죽지 않았다 (명도 %.2f)"
				% [preset, pair[1], fill.v])

		check(worst[0] >= 4.5, "%s: 스킨이 만드는 색도 본문 대비를 넘는다 (최저 %.2f:1 — %s)"
			% [preset, worst[0], worst[1]])
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.preset = &""


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

	# 🛑 CSV 열과 `GoUi.LOCALES` 가 어긋나면 **아무 오류 없이** 그 언어만 영어로 나온다.
	#    조각 파일(.translation)은 임포트가 만들어 주지만, LOCALES 에 없으면 등록되지 않는다.
	#    반대로 LOCALES 에만 있고 CSV 열이 없으면 파일이 없어 조용히 지나간다. 양방향으로 본다.
	var header := ""
	var f := FileAccess.open(GoUi.BUILTIN_TRANSLATIONS, FileAccess.READ)
	if f != null:
		header = f.get_line()
		f.close()
	var columns := header.split(",")
	var csv_locales: Array[String] = []
	for i in range(1, columns.size()):
		csv_locales.append(columns[i].strip_edges())
	check(not csv_locales.is_empty(), "CSV 헤더를 읽었다 (%d열)" % csv_locales.size())
	for locale: String in csv_locales:
		check(GoUi.LOCALES.has(locale), "CSV 열 %s 가 GoUi.LOCALES 에 있다" % locale)
	for locale: String in GoUi.LOCALES:
		check(csv_locales.has(locale), "GoUi.LOCALES 의 %s 가 CSV 열에 있다" % locale)

	# 선언한 언어마다 문구가 실제로 **나오는지** 본다 — 키가 그대로 보이면 조각 파일이 안 붙은 것이다.
	for locale: String in GoUi.LOCALES:
		TranslationServer.set_locale(locale)
		var got := tr("gohud_confirm")
		check(got != "gohud_confirm" and got != "", "%s 에서 문구가 나온다 (%s)" % [locale, got])

	# 2026-09-12 에 더한 언어의 표본 — 열 순서가 밀리면 여기서 잡힌다(자리만 맞고 내용이 다른 사고).
	TranslationServer.set_locale("tr")
	check(tr("gohud_cancel") == "İptal", "tr 번역")
	TranslationServer.set_locale("th")
	check(tr("gohud_close") == "ปิด", "th 번역")
	TranslationServer.set_locale("vi")
	check(tr("gohud_retry") == "Thử lại", "vi 번역")
	TranslationServer.set_locale("id")
	check(tr("gohud_next") == "Berikutnya", "id 번역")
	# 🛑 번체는 간체를 변환한 것이 아니라 **대만 어휘**여야 한다 — 搜索(중국)이 아니라 搜尋.
	TranslationServer.set_locale("zh_TW")
	check(tr("gohud_search") == "搜尋", "zh_TW 는 대만 어휘 (%s)" % tr("gohud_search"))
	TranslationServer.set_locale("zh")
	check(tr("gohud_search") == "搜索", "zh 는 중국 어휘 (%s)" % tr("gohud_search"))
	TranslationServer.set_locale("he")
	check(tr("gohud_done") == "סיום", "he 번역")

	TranslationServer.set_locale(original)


# ── 문구 커스터마이징 ──────────────────────────────────────────────────

## 🛑 **호스트가 화면의 모든 글자를 바꿀 수 있어야 한다.** 위젯이 문구를 코드에 박아 두면
##    그 한 줄만 영원히 gohud 의 것으로 남는다 — 프로젝트가 "확인" 대신 "예" 를 쓰고 싶어도,
##    번역 체계가 달라도, 손댈 방법이 없다. 이 절이 그 빈틈을 막는다.
func _text_customisation() -> void:
	# ① 애드온 본체(예제·검사 제외)에 **화면에 나가는 리터럴이 없다**.
	#    새 위젯이 `label.text = "Retry"` 로 쓰면 여기서 걸린다.
	var literal := RegEx.new()
	literal.compile('\\.(text|tooltip_text|accessibility_name|placeholder_text)\\s*=\\s*"[^"]')
	var offenders: Array[String] = []
	for folder in ["widgets", "core", "services"]:
		var dir := DirAccess.open("%s/%s" % [ADDON, folder])
		if dir == null: continue
		for file in dir.get_files():
			if not file.ends_with(".gd"): continue
			var path := "%s/%s/%s" % [ADDON, folder, file]
			var source := FileAccess.get_file_as_string(path)
			for line in source.split("\n"):
				var trimmed := line.strip_edges()
				if trimmed.begins_with("#") or trimmed.begins_with("##"): continue
				if literal.search(line) != null:
					offenders.append("%s: %s" % [file, trimmed.substr(0, 60)])
	check(offenders.is_empty(), "애드온 본체에 화면 리터럴 없음 (%s)" % ", ".join(offenders.slice(0, 3)))

	# ② 설정에 적힌 **모든 이름**이 override 로 덮인다 — 하나라도 새면 그 문구는 못 바꾼다.
	var names: Array = GoUi.config.text_keys.keys()
	check(names.size() >= 16, "문구 이름 %d개" % names.size())
	var overrides: Dictionary[StringName, String] = {}
	for name: StringName in names:
		overrides[name] = "«%s»" % name
	GoUi.config.text_overrides = overrides
	var leaked: Array[String] = []
	for name: StringName in names:
		if GoUi.text(name) != "«%s»" % name:
			leaked.append(String(name))
	check(leaked.is_empty(), "모든 이름이 text_overrides 로 덮인다 (%s)" % ", ".join(leaked))

	# ③ 위젯이 실제로 그 값을 쓴다 — 이름만 있고 안 쓰면 ②는 통과하고 화면은 안 바뀐다.
	var bar := GoBar.new()
	bar.readout = GoBar.Readout.FRACTION
	root.add_child(bar)
	bar.set_values(3.0, 10.0, false)
	await frames(1)
	var bar_line := _first_label_text(bar)
	check(bar_line.contains("«bar_fraction»"), "GoBar 수치 형식이 설정을 탄다 (%s)" % bar_line)
	bar.readout = GoBar.Readout.PERCENT
	await frames(1)
	check(_first_label_text(bar).contains("«bar_percent»"), "GoBar 백분율 형식이 설정을 탄다")
	bar.queue_free()

	var slot := GoSlot.new()
	root.add_child(slot)
	slot.quantity = 3
	slot.refresh()
	await frames(1)
	check(_label_texts(slot).any(func(t: String) -> bool: return t.contains("«slot_quantity»")),
		"GoSlot 수량 형식이 설정을 탄다")
	slot.queue_free()

	# ④ 형식 문자열은 **자리표시자가 사라져도** 죽지 않는다 — 번역자가 `{value}` 를 빠뜨리는 일은 있다.
	var broken: Dictionary[StringName, String] = overrides.duplicate()
	broken[&"bar_fraction"] = "자리표시자 없음"
	GoUi.config.text_overrides = broken
	var safe := GoBar.new()
	safe.readout = GoBar.Readout.FRACTION
	root.add_child(safe)
	safe.set_values(3.0, 10.0, false)
	await frames(1)
	check(_first_label_text(safe) == "자리표시자 없음", "자리표시자가 빠져도 화면이 죽지 않는다")
	safe.queue_free()

	# ⑤ 숫자 축약은 훅으로 바꾼다 — 만·억 단위처럼 **계산 자체가 다른** 언어를 위해.
	GoUi.config.text_overrides = {}
	GoUi.config.number_formatter = func(amount: float) -> String: return "▲%d" % int(amount)
	check(GoBar.format_amount(12345.0) == "▲12345", "number_formatter 훅이 축약을 대신한다 (%s)"
		% GoBar.format_amount(12345.0))
	GoUi.config.number_formatter = Callable()
	check(GoBar.format_amount(12345.0) == "12.3k", "훅을 비우면 내장 규칙으로 돌아온다 (%s)"
		% GoBar.format_amount(12345.0))

	# ⑥ 언어를 바꾸면 조립 문자열도 새 형식이 된다(엔진 자동 번역을 타지 않는 자리다).
	#    터키어는 백분율 기호를 **앞**에 붙인다 — 형식까지 번역해야 하는 이유.
	var before := TranslationServer.get_locale()
	var live := GoBar.new()
	live.readout = GoBar.Readout.PERCENT
	root.add_child(live)
	live.set_values(5.0, 10.0, false)
	TranslationServer.set_locale("en")
	await frames(1)
	check(_first_label_text(live) == "50%", "en 백분율 (%s)" % _first_label_text(live))
	TranslationServer.set_locale("tr")
	await frames(1)
	check(_first_label_text(live) == "%50", "언어를 바꾸면 백분율 형식이 따라 바뀐다 (%s)"
		% _first_label_text(live))
	TranslationServer.set_locale(before)
	live.queue_free()
	await frames(1)


func _label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label and not (node as Label).text.is_empty():
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_label_texts(child))
	return out


func _first_label_text(node: Node) -> String:
	var all := _label_texts(node)
	return all[0] if not all.is_empty() else ""


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
	# 🔑 작은 글자 버튼 여백 계약 — 판 여백이 토큰과 같고, 검증 함수가 여백 0 판을 실제로 잡는다(양성 대조).
	var pad_x := float(GoUi.metric(GoTheme.COMPACT_PADDING_X))
	var pad_y := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	var compact_face := compact.get_theme_stylebox(&"normal")
	check(pad_x > 0.0 and pad_y > 0.0 and near(compact_face.get_margin(SIDE_LEFT), pad_x) and near(compact_face.get_margin(SIDE_RIGHT), pad_x)
		and near(compact_face.get_margin(SIDE_TOP), pad_y),
		"작은 버튼 판 여백 = 토큰 (판 %.0f·%.0f · 토큰 %.0f·%.0f)" % [compact_face.get_margin(SIDE_LEFT), compact_face.get_margin(SIDE_TOP), pad_x, pad_y])
	check(GoStyle.audit_compact_padding(host).is_empty(), "기본 테마의 작은 글자 버튼은 여백 계약을 지킨다 %s" % str(GoStyle.audit_compact_padding(host)))
	var glued := GoStyle.button("Glued", Callable(), GoStyle.Tone.COMPACT)
	glued.name = "Glued"
	var zero := StyleBoxFlat.new()
	zero.set_content_margin_all(0)
	glued.add_theme_stylebox_override(&"normal", zero)
	var glyph_only := GoStyle.button("", Callable(), GoStyle.Tone.COMPACT)
	glyph_only.add_theme_stylebox_override(&"normal", zero)
	host.add_child(glued)
	host.add_child(glyph_only)
	var caught: Array[String] = GoStyle.audit_compact_padding(host, true)
	check(caught.size() == 1 and caught[0].contains("Glued:normal"),
		"검증 함수가 여백 0 판을 잡고 글자 없는 아이콘 버튼은 건너뛴다 %s" % str(caught))
	check(GoStyle.audit_compact_padding(host).is_empty(), "덮어쓴 판은 기본으로 건너뛴다(의도한 예외)")
	glued.queue_free()
	glyph_only.queue_free()

	var row := GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "Name and avatar", false)
	host.add_child(row)
	await frames(3)
	check(row.custom_minimum_size.y >= 48, "목록 항목 터치 하한")
	check(row.custom_minimum_size.y < 120, "폭이 있으면 두 줄 항목이 부풀지 않는다 (%.0f)" % row.custom_minimum_size.y)
	var inset := row.get_child(0) as MarginContainer
	check(inset != null and row.custom_minimum_size.y >= inset.get_combined_minimum_size().y - 0.5, "여백 포함 내용이 항목 안에 들어간다")
	var list_line := inset.get_child(0) as HBoxContainer
	var text_stack := list_line.get_child(1) as VBoxContainer
	var list_title := text_stack.get_child(0) as Label
	var description := text_stack.get_child(1) as Label
	var top := list_title.global_position.y - row.global_position.y
	var bottom := row.get_global_rect().end.y - description.get_global_rect().end.y
	check(top >= 8.0 and bottom >= 8.0 and near(top, bottom), "두 줄 목록은 위아래에 균형 잡힌 여백을 둔다")
	# 행이 컨테이너의 남는 높이를 받아도 글자 사이에 빈 공간을 끼워 넣지 않는다.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	await frames(3)
	check(row.size.y > row.get_combined_minimum_size().y + 20.0, "목록 정렬 검사가 실제로 늘어난 행을 확인한다")
	var text_center := (list_title.global_position.y + description.get_global_rect().end.y) * 0.5
	check(near(text_center, row.get_global_rect().get_center().y),
		"늘어난 목록 행에서도 제목·요약 묶음은 세로 가운데")
	check(near(list_title.size.y, list_title.get_combined_minimum_size().y)
		and near(description.size.y, description.get_combined_minimum_size().y)
		and description.global_position.y - list_title.get_global_rect().end.y <= 8.0,
		"제목·요약은 자연 높이와 짧은 간격을 유지한다")
	row.size_flags_vertical = Control.SIZE_FILL
	description.text = "A longer description that wraps onto several lines without touching the row border."
	await frames(4)
	check(description.get_line_count() > 1, "목록 여백 검사가 줄바꿈된 요약을 확인한다")
	top = list_title.global_position.y - row.global_position.y
	bottom = row.get_global_rect().end.y - description.get_global_rect().end.y
	check(top >= 8.0 and bottom >= 8.0 and near(top, bottom), "줄바꿈 뒤에도 목록의 위아래 여백이 균형을 유지한다")

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
	# 🛑 칸이 **남는 폭을 나눠 가져야** 한다. `GridContainer` 는 `SIZE_EXPAND` 가 붙은 자식에게만
	#    남는 폭을 주므로, 기본값으로 두면 카드가 내용의 최소 폭(줄바꿈 라벨이라 거의 0)으로 접힌다 —
	#    글자가 세로로 한 자씩 내려갔다(2026-09-13 실측: 어느 창 폭에서나 카드 25px).
	check((grid.get_child(0) as Control).size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"격자 칸이 남는 폭을 나눠 가진다 — 카드가 한 글자 폭으로 접히지 않는다")

	# 🛑 긴 글자는 줄바꿈해야 한다. 없으면 한 줄이 길게 뻗어 그 최소 폭이 화면을 넘긴다.
	var wrapper := GoStyle.button("A fairly long button label that must wrap")
	check(wrapper.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"버튼 글자가 줄바꿈한다 — 한 줄로 뻗어 화면을 넘기지 않는다")
	wrapper.free()
	var long_label := GoStyle.label("A sentence long enough that it must wrap inside a narrow card")
	check(long_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"라벨 글자가 줄바꿈한다 — 이것이 없으면 최소 폭이 화면을 넘겨 좌우가 잘린다")
	long_label.free()
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
	check(mark.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER and mark.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER, "텍스처 아이콘은 가운데 정렬(Button 기본은 왼쪽)")
	mark.native_texture_size = true
	check(not mark.expand_icon and not mark.has_theme_constant_override(&"icon_max_width") and mark.icon is DPITexture, "native_texture_size: 늘리지 않고 icon_max_width 도 풀린다")
	mark.native_texture_size = false
	check(mark.expand_icon and mark.get_theme_constant(&"icon_max_width") == cap, "native_texture_size 끄면 다시 글리프 크기로 묶는다")
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
	# 🛑 카드 크기·위치는 정수 — 가운데 정렬 위치가 소수면 크기가 "위치 + 크기" 로 저장되며 184 가 183.99997 이 되고,
	#    안쪽 여백(MarginContainer)이 자식 크기를 정수로 내려 본문 칸이 1px 모자랐다(한 줄 본문 옆 스크롤바 · 2026-09-15 라리엔
	#    폰 세로 창 실측 — 헤드리스 논리 크기로는 재현되지 않았다). 판정하는 동안만 홀수 상한을 줘 소수 위치가 나오게 한다.
	var saved_max_height := a.max_height
	var saved_max_width := a.max_width
	a.max_height = 301.0
	a.max_width = 301.0
	a.relayout()
	check(a.card.size == a.card.size.round() and a.card.position == a.card.position.round(),
		"카드 크기·위치는 정수 (pos %s size %s)" % [str(a.card.position), str(a.card.size)])
	a.max_height = saved_max_height
	a.max_width = saved_max_width
	a.relayout()

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
	sheet.toolbar().add_child(GoStyle.line_edit("Search"))
	sheet.toolbar().visible = true
	var kept := Label.new()                      # 시트 전체가 쓰는 자리(스낵바 등) — footer().add_child
	sheet.footer().add_child(kept)
	var page_close := sheet.add_footer(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
	check(sheet.footer().visible and page_close.get_parent() == sheet.footer(), "add_footer() 는 바닥 줄에 넣고 켠다")
	sheet.open("Other")
	check(not sheet.surface.back_button.visible, "open() 은 이전 페이지의 뒤로 버튼을 끈다")
	check(not sheet.toolbar().visible and sheet.toolbar().get_child_count() == 0, "open() 은 고정 줄을 비우고 끈다")
	# 🛑 페이지 버튼만 치운다 — 끄기만 하면 페이지마다 닫기를 더하는 화면에서 버튼이 쌓였고(2026-09-15),
	#    통째로 비우면 한 번 넣고 계속 쓰는 스낵바가 사라진다.
	check(not sheet.footer().visible and page_close.get_parent() == null and kept.get_parent() == sheet.footer(),
		"open() 은 add_footer() 로 넣은 것만 떼고 footer().add_child() 로 넣은 노드는 남긴다 (자식 %d)"
		% sheet.footer().get_child_count())
	sheet.add_footer(GoStyle.button("Close", sheet.close))
	sheet.open("Third")
	check(sheet.footer().get_child_count() == 1,
		"페이지를 거듭 열어도 바닥 버튼이 쌓이지 않는다 (자식 %d)" % sheet.footer().get_child_count())
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
	# 🛑 **제목도 같은 args 로 채운다** — 본문만 채우면 `Drop {item}?` 가 글자 그대로 보였다(2026-09-15).
	var titled := ["", -1]
	var read_title := func() -> void:
		titled[0] = dialogs._surface.title_label.text
		titled[1] = dialogs._surface.title_label.auto_translate_mode
		dialogs._ok.pressed.emit()
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm("Drop {item}?", "Drop {count} × {item}?", "", "", "", {"item": "Potion", "count": 3})
	check(str(titled[0]) == "Drop Potion?", "args 가 제목의 {item} 도 채운다 (%s)" % str(titled[0]))
	var probe_locale := TranslationServer.get_locale()
	var drop := Translation.new()
	drop.locale = "xx"
	drop.add_message("probe_drop_title", "Drop {item}?")
	TranslationServer.add_translation(drop)
	TranslationServer.set_locale("xx")
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm_key("probe_drop_title", "probe_drop_body", "", "", "", {"item": "Potion"})
	check(str(titled[0]) == "Drop Potion?", "번역 키 제목은 번역한 뒤 args 로 채운다 (%s)" % str(titled[0]))
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm_key("probe_drop_title", "probe_drop_body")
	check(str(titled[0]) == "probe_drop_title" and int(titled[1]) == Node.AUTO_TRANSLATE_MODE_ALWAYS,
		"args 가 없는 키 제목은 지금처럼 키를 두고 자동 번역한다 (%s · 모드 %d)" % [str(titled[0]), int(titled[1])])
	TranslationServer.set_locale(probe_locale)
	TranslationServer.remove_translation(drop)
	check(dialogs._ok.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON,
		"보통 확인은 강조 버튼 (%s)" % dialogs._ok.theme_type_variation)

	# 🛑 **되돌릴 수 없는 동작은 색이 먼저 말해야 한다.** 옅은 위험 버튼으로는 모자랐다 — 판이
	#    옅으면 글자를 아주 어둡게 밀어야 읽혀서(밝은 테마에서 `#9B2626`) 그냥 검은 글자가 된다.
	#    채운 위험 버튼은 흰 글자로 5.7:1 이 나온다.
	create_timer(0.05).timeout.connect(func() -> void: dialogs._ok.pressed.emit())
	var removed: bool = await dialogs.confirm("Delete", "Sure?", "", "", "", {}, true)
	check(removed and dialogs._ok.theme_type_variation == GoTheme.VAR_DANGER_SOLID_BUTTON,
		"destructive 면 확인 버튼이 채운 위험색 (%s)" % dialogs._ok.theme_type_variation)
	# 🛑 창 하나를 **돌려 쓴다** — 되돌리지 않으면 그 다음 평범한 확인창까지 빨갛게 뜬다.
	create_timer(0.05).timeout.connect(func() -> void: dialogs._ok.pressed.emit())
	await dialogs.confirm("Save", "Save now?")
	check(dialogs._ok.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON,
		"다음 확인창은 다시 강조색으로 돌아온다 (%s)" % dialogs._ok.theme_type_variation)

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

	# 🔑 버튼 배치 — 기본 세로 · 한 줄 · 자동 · 1회용. 🛑 버튼 줄은 **처음 열 때** 생긴다(오토로드 입장 비용 0).
	var fresh := GoDialogs.new()
	check(fresh._actions == null and fresh._surface.footer.get_child_count() == 2, "만든 직후에는 버튼 줄 노드가 없다(버튼 둘만 footer 에)")
	fresh.queue_free()
	var shape := {}
	var measure := func() -> void:
		var cancel_rect := dialogs._cancel.get_global_rect()
		var ok_rect := dialogs._ok.get_global_rect()
		shape["vertical"] = dialogs._actions.vertical
		shape["same_row"] = absf(cancel_rect.position.y - ok_rect.position.y) < 1.0
		shape["cancel_left"] = cancel_rect.position.x < ok_rect.position.x
		shape["gap_x"] = ok_rect.position.x - cancel_rect.end.x
		shape["body_to_actions"] = minf(cancel_rect.position.y, ok_rect.position.y) - dialogs._body.get_global_rect().end.y
		shape["bottom_gap"] = dialogs._surface.card.get_global_rect().end.y - maxf(cancel_rect.end.y, ok_rect.end.y)
		shape["inset"] = float(dialogs._surface.content_inset())
		shape["ok_min_w"] = dialogs._ok.custom_minimum_size.x
	var answer_after_measure := func() -> void:
		measure.call()
		dialogs._ok.pressed.emit()

	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(dialogs._actions != null and shape["vertical"] and not shape["same_row"], "기본 배치는 세로 (%s)" % str(shape))

	dialogs.action_layout = GoDialogs.ActionLayout.HORIZONTAL
	dialogs.action_gap = 8
	dialogs.body_gap = 20
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(not shape["vertical"] and shape["same_row"] and shape["cancel_left"], "HORIZONTAL — 한 줄 · 취소가 앞 (%s)" % str(shape))
	check(near(shape["gap_x"], 8.0, 1.5), "버튼 사이 간격 = action_gap (%.1f)" % shape["gap_x"])
	check(near(shape["body_to_actions"], 20.0, 1.5), "본문 뒤 간격 = body_gap (%.1f)" % shape["body_to_actions"])
	check(near(shape["bottom_gap"], shape["inset"], 1.5), "마지막 버튼 아래 여백 = 카드 안쪽 여백 (%.1f · %.1f)" % [shape["bottom_gap"], shape["inset"]])

	# 🛑 좁은 화면은 구획 간격이 한 단계 작다 — 표면이 토큰 `gap` 으로 높이를 세면 본문 뒤가 그만큼 벌어진다.
	dialogs._surface.compact = true
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(near(shape["body_to_actions"], 20.0, 1.5), "좁은 화면에서도 본문 뒤 간격 = body_gap — 구획 간격을 실제 값으로 센다 (%.1f)" % shape["body_to_actions"])
	check(near(shape["bottom_gap"], shape["inset"], 1.5), "좁은 화면에서도 카드가 필요보다 크지 않다 (%.1f · %.1f)" % [shape["bottom_gap"], shape["inset"]])
	dialogs._surface.compact = false

	dialogs.action_layout = GoDialogs.ActionLayout.AUTO
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Delete", "Sure?", "Permanently remove this character and every item it carries", "Keep the character as it is")
	check(shape["vertical"], "AUTO — 반 폭에 한 줄로 안 들어가면 세로 (%s)" % str(shape))
	var long_min: float = shape["ok_min_w"]
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Save", "Save now?", "OK", "No")
	check(not shape["vertical"], "AUTO — 짧은 문구는 한 줄 (%s)" % str(shape))
	check(float(shape["ok_min_w"]) < long_min, "긴 문구 다음 짧은 문구에서 버튼 최소 폭이 남지 않는다 (%.0f < %.0f)" % [shape["ok_min_w"], long_min])

	dialogs.action_layout = GoDialogs.ActionLayout.VERTICAL
	dialogs.set_next_action_layout(GoDialogs.ActionLayout.HORIZONTAL)
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(not shape["vertical"], "set_next_action_layout — 이번 창만 한 줄")
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(shape["vertical"], "다음 창은 다시 action_layout(세로)으로 돌아온다")
	dialogs.action_gap = -1
	dialogs.body_gap = -1
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
	var content := HBoxContainer.new(); var inner := Button.new(); content.add_child(inner)
	notice.set_content(content)
	check(content.mouse_filter == Control.MOUSE_FILTER_IGNORE and inner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "set_content: 내용 서브트리의 mouse_filter 값도 IGNORE")
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
	# 🛑 슬롯은 기본적으로 **노드 자체가 48dp** 다(`_ready` 가 `custom_minimum_size` 를 그렇게 잡는다) —
	#    보이는 판만 44dp 이고, 터치 확장 코드는 그때 발동하지 않는다. 확장이 실제로 일하는 것은
	#    **호스트가 슬롯을 48dp 보다 작게 강제했을 때**다. 그 경우를 재현해 하한이 지켜지는지 본다.
	var reachable := GoSlot.new()
	root.add_child(reachable)
	await frames(2)
	reachable.custom_minimum_size = Vector2(30, 30)
	reachable.size = Vector2(30, 30)
	await frames(2)
	check(reachable.touch_hit(Vector2(-5, 15)),
		"작게 강제된 슬롯도 노드 밖까지 눌린다 (48dp 하한 · 실제 %.0fdp)" % reachable.size.x)
	check(not reachable.touch_hit(Vector2(-40, 15)), "그렇다고 아무 데나 눌리지는 않는다")
	reachable.queue_free()
	await frames(1)

	var a := GoSlot.new()
	var b := GoSlot.new()
	a.icon_name = GoIconSet.POTION
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(0, 0)
	b.position = Vector2(40, 0)
	await frames(2)
	var quantity := a.get_node(^"Face/QuantityBadge/Quantity") as Label
	a.quantity = GoSlot.NONE
	check(not quantity.is_visible_in_tree(), "NONE 은 수량 줄을 그리지 않는다")
	a.quantity = GoSlot.UNKNOWN
	check(quantity.is_visible_in_tree() and quantity.text == "…", "UNKNOWN 은 …")
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
	check((a.get_node(^"Face/TimerBadge/Timer") as Label).is_visible_in_tree(), "쿨다운 남은 시간 표시")
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
	# 🛑 **가로에서만 도는 코드는 세로 검사로 잡히지 않는다.** 화면을 실제로 눕혀 본다.
	var was := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(3)
	var turned := GoHudAnchor.new()
	turned.spot = GoHudAnchor.Spot.BOTTOM_CENTER
	turned.landscape_spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	root.add_child(turned)
	await frames(2)
	check(turned.active_spot() == GoHudAnchor.Spot.BOTTOM_RIGHT,
		"가로에서 HUD 가 landscape_spot 으로 옮겨 간다")
	root.content_scale_size = Vector2i(390, 844)
	await frames(3)
	check(turned.active_spot() == GoHudAnchor.Spot.BOTTOM_CENTER, "세로로 돌아오면 원래 자리")
	turned.queue_free()

	# 가로에서는 좌우가 남으므로 카드가 화면 폭의 **더 적은 비율**을 쓴다.
	# 🛑 최대 폭 제한을 **풀고 본다** — 넓은 화면에서는 두 비율이 모두 480dp 상한에 잘려
	#    차이가 드러나지 않는다(844×0.72 도 844×0.94 도 480 이 된다).
	var cap_was := GoUi.config.surface_max_width
	GoUi.config.surface_max_width = 4000.0
	var card_surface := GoSurface.new()
	root.add_child(card_surface)
	await frames(3)
	var portrait_share := card_surface.card.size.x / 390.0
	root.content_scale_size = Vector2i(844, 390)
	await frames(4)
	var landscape_share := card_surface.card.size.x / 844.0
	check(landscape_share < portrait_share,
		"가로에서 창이 화면 폭의 더 적은 비율을 쓴다 (세로 %.2f · 가로 %.2f)"
		% [portrait_share, landscape_share])
	card_surface.queue_free()
	GoUi.config.surface_max_width = cap_was
	root.content_scale_size = was
	await frames(3)

	# ── 키보드만으로 쓰는 사람 ─────────────────────────────────────────
	# 🛑 **창이 떠 있는데 Tab 이 뒤쪽 화면으로 나가면, Enter 가 보이지도 않는 버튼을 누른다.**
	#    반대로 닫은 뒤 포커스가 사라지면, 키보드 사용자는 화면 어디에도 없는 상태가 된다.
	#    이 두 규칙은 손가락으로는 드러나지 않아 검사가 없으면 조용히 깨진다.
	var outside := GoStyle.button("바깥")
	root.add_child(outside)
	await frames(2)
	outside.grab_focus()
	await frames(2)
	check(root.gui_get_focus_owner() == outside, "바탕 버튼이 포커스를 쥐었다")

	# 🛑 **키보드로 조작 중이라고 알린다.** gohud 는 마지막 입력 장치를 보고, 포인터로 연 창에는
	#    일부러 포커스 링을 띄우지 않는다(탭으로 연 창에 링이 번쩍이면 거슬린다). 그러니 키보드
	#    순회를 검사하려면 **키 입력을 한 번 흘려보내** 그 상태를 만들어야 한다.
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	root.push_input(key)
	await frames(2)

	var win := GoSurface.new()
	var inside := GoStyle.button("안쪽")
	root.add_child(win)
	await frames(2)
	win.body.add_child(inside)
	win.initial_focus = inside
	win._focus_default()
	await frames(5)
	var holder := root.gui_get_focus_owner()
	check(holder != null and win.is_ancestor_of(holder),
		"창을 열면 포커스가 창 안으로 (%s)" % (holder.name if holder != null else "없음"))

	outside.grab_focus()
	await frames(5)
	holder = root.gui_get_focus_owner()
	check(holder != null and win.is_ancestor_of(holder),
		"창 밖으로 새어 나간 포커스는 되돌아온다 (%s)" % (holder.name if holder != null else "없음"))

	# 🛑 닫기 **직전**에 포커스가 창 안에 있어야, 닫은 뒤의 복귀가 의미를 갖는다 — 이 줄이 없으면
	#    "원래 자리로 돌아왔다" 가 사실은 "한 번도 떠난 적이 없다" 일 수 있다.
	holder = root.gui_get_focus_owner()
	check(holder != null and win.is_ancestor_of(holder),
		"닫기 직전 포커스는 창 안에 있다 (%s)" % (holder.name if holder != null else "없음"))
	# 🛑 `GoSurface` 에는 `close()` 가 없다 — `request_close()` 는 **신호만** 내고, 실제로 닫는 것은
	#    그 창을 가진 쪽(시트·다이얼로그)이다. 창 자체는 숨는 것으로 닫힌다.
	win.hide()
	await frames(6)
	check(root.gui_get_focus_owner() == outside, "창을 닫으면 원래 자리로 돌아온다 (%s)"
		% (root.gui_get_focus_owner().name if root.gui_get_focus_owner() != null else "없음"))
	win.queue_free()
	outside.queue_free()
	await frames(2)

	# ── 툴팁 ────────────────────────────────────────────────────────────
	# 🛑 **아이콘 버튼에게 툴팁은 유일한 설명이다.** 엔진 기본 툴팁은 라벨에 줄바꿈이 걸린 채 최대
	#    폭이 1dp 로 계산되어, `settings` 가 **한 자씩 세로로** 쪼개졌다(2026-09-13 실측: 폭 1 · 높이 186).
	#    폭을 gohud 가 정하므로 그 계산에 기대지 않는다.
	var tip_button := GoIconButton.new()
	tip_button.icon_name = GoIconSet.SETTINGS
	tip_button.tooltip_text_name = &"settings"
	root.add_child(tip_button)
	await frames(2)
	var short_tip := tip_button._make_custom_tooltip("settings") as Label
	check(short_tip != null, "아이콘 버튼이 자기 툴팁을 만든다")
	if short_tip != null:
		root.add_child(short_tip)
		await frames(2)
		check(short_tip.get_combined_minimum_size().x > 24.0,
			"짧은 툴팁은 한 줄로 — 최소 폭이 글자를 담는다 (%.0f dp)" % short_tip.get_combined_minimum_size().x)
		check(short_tip.autowrap_mode == TextServer.AUTOWRAP_OFF, "짧은 문구는 접지 않는다")
		short_tip.queue_free()
	var long_text := "이 버튼은 아주 긴 설명을 담고 있어서 한 줄로는 도저히 담기지 않는다"
	var long_tip := tip_button._make_custom_tooltip(long_text) as Label
	if long_tip != null:
		root.add_child(long_tip)
		await frames(2)
		check(long_tip.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and long_tip.custom_minimum_size.x > 24.0,
			"긴 툴팁은 **정해진 폭**에서 접힌다 (%.0f dp)" % long_tip.custom_minimum_size.x)
		long_tip.queue_free()
	tip_button.queue_free()
	await frames(1)

	# 퀵슬롯은 기본적으로 Tab 순회에서 빠지되, **키보드로만 하는 조작**이 필요하면 켤 수 있어야 한다.
	var key_slot := GoSlot.new()
	root.add_child(key_slot)
	await frames(2)
	check(key_slot.focus_mode == Control.FOCUS_NONE, "슬롯은 기본적으로 Tab 순회에서 빠진다")
	key_slot.keyboard_focus = true
	await frames(1)
	check(key_slot.focus_mode == Control.FOCUS_ALL, "keyboard_focus 를 켜면 키보드로 닿는다")
	key_slot.queue_free()
	await frames(1)

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

	# ── 고정 칸 피하기 ──────────────────────────────────────────────────
	# 🛑 **아홉 자리는 자리를 나눌 뿐, 겹치지 않는다고 보장하지 않는다.** 위쪽 가운데에 뜨는 스낵바는
	#    폭이 넓어 오른쪽 위 체력바 위에 그대로 얹혔다 — 값이 가려져 체력을 읽을 수 없었다(실측).
	var bars_spot := GoHudAnchor.new()
	bars_spot.spot = GoHudAnchor.Spot.TOP_RIGHT
	var bars_box := Control.new()
	bars_box.custom_minimum_size = Vector2(180, 100)
	bars_spot.add_child(bars_box)
	root.add_child(bars_spot)
	var toast_spot := GoHudAnchor.new()
	toast_spot.spot = GoHudAnchor.Spot.TOP_CENTER
	var toast_box := Control.new()
	# 🛑 폭을 숫자로 박으면 **넓은 화면에서는 원래 안 겹쳐** 검사의 전제가 무너진다(844dp 에서
	#    300dp 알림은 180dp 체력바에 닿지 않는다). 화면에 비례해 잡아 어디서든 겹치게 둔다.
	var usable := GoSafeArea.usable_rect(root).grow(-GoUi.metric(GoTheme.SCREEN_MARGIN))
	toast_box.custom_minimum_size = Vector2(maxf(300.0, usable.size.x * 0.9), 44)
	toast_spot.add_child(toast_box)
	root.add_child(toast_spot)
	await frames(4)

	# ① 그냥 두면 겹친다 — 아홉 자리만으로는 안 풀린다.
	check(bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"넓은 알림은 모서리 HUD 와 겹친다 (알림 %s · HUD %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])

	# ② 비키라고 하면 아래로 내려가 앉는다.
	var toast_x := toast_spot.global_position.x
	toast_spot.avoid_peers = true
	await frames(4)
	check(not bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"avoid_peers — 알림 %s 가 HUD %s 를 피한다"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	check(toast_spot.global_position.y >= bars_spot.get_global_rect().end.y,
		"위쪽 칸은 **아래로** 비킨다 (알림 위 %.0f · HUD 아래 %.0f)"
		% [toast_spot.global_position.y, bars_spot.get_global_rect().end.y])
	# 🛑 좌우로는 튀지 않는다 — 뜰 때마다 다른 자리에 나타나면 눈이 따라가지 못한다.
	check(near(toast_spot.global_position.x, toast_x),
		"가운데 정렬은 그대로다 (비키기 전 %.0f · 뒤 %.0f)" % [toast_x, toast_spot.global_position.x])

	# ③ 고정 칸끼리는 서로 피하지 않는다 — 둘 다 피하면 영원히 자리를 맞바꾼다.
	var before := bars_spot.global_position
	await frames(3)
	check(bars_spot.global_position == before, "피하지 않는 칸은 제자리에 있다")

	# ④ **붙박이가 아닌 칸은 피할 대상이 아니다.** 잠깐 뜨는 것끼리 서로 피하게 두었더니 알림이
	#    프롬프트 카드까지 피해 화면 한복판까지 달아났다(2026-09-13 가로 실측).
	bars_spot.reserve_space = false
	await frames(4)
	check(bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"잠깐 뜨는 칸끼리는 서로 피하지 않는다 (알림 %s · 상대 %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	bars_spot.reserve_space = true
	await frames(4)

	# ⑤ **붙박이가 커지면 비키는 칸도 따라 내려간다.** 알림은 체력바가 커진 것을 스스로 알 길이
	#    없다 — 알려 주지 않으면 비킨 자리에 그대로 남아 다시 겹친다.
	var toast_y := toast_spot.global_position.y
	bars_box.custom_minimum_size = Vector2(180, 170)
	await frames(6)
	check(toast_spot.global_position.y > toast_y,
		"붙박이가 커지면 비키는 칸도 따라 내려간다 (%.0f → %.0f)"
		% [toast_y, toast_spot.global_position.y])
	check(not bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"커진 뒤에도 겹치지 않는다 (알림 %s · HUD %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	bars_spot.queue_free()
	toast_spot.queue_free()
	await frames(1)


# ── 안내 투어 ──────────────────────────────────────────────────────────

func _coach() -> void:
	# ── 카드는 붙박이를 덮지 않는다 ────────────────────────────────────
	# 🛑 가로 화면에서 카드를 화면 맨 위/아래 끝으로 보내던 규칙이 헤더의 조작 버튼을 덮었다(2026-09-13
	#    데모 실측). 이제 **대상과 같은 높이**에 두고, 붙박이 HUD(`reserve_space`)와 `keep_clear` 를 피한다.
	var was_size := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(4)
	var mark := Button.new()
	mark.text = "Target"
	mark.position = Vector2(300, 60)          # 화면 왼쪽 위쪽 — 카드는 오른쪽 옆으로 간다
	mark.size = Vector2(120, 40)
	root.add_child(mark)
	var guide := GoCoachMark.new()
	root.add_child(guide)
	await frames(3)
	guide.start([{"target": mark, "title": "T", "body": "b"}])
	await frames(5)
	# 🛑 붙박이를 **세우기 전에** 잰다 — 세워 두면 회피가 카드를 옮겨 "대상 높이" 규칙이 가려진다
	#    (변이 검사가 실제로 그 규칙을 놓쳤다).
	var card_rect := guide.card.get_global_rect()
	check(near(card_rect.position.y, mark.get_global_rect().position.y, 1.0),
		"가로에서 카드는 대상과 같은 높이에 (카드 y %.0f · 대상 y %.0f)" % [card_rect.position.y, mark.get_global_rect().position.y])
	var fixture := GoHudAnchor.new()          # 오른쪽 위 붙박이 — 카드가 놓인 바로 그 자리
	fixture.spot = GoHudAnchor.Spot.TOP_RIGHT
	var fixture_box := Control.new()
	fixture_box.custom_minimum_size = Vector2(300, 90)
	fixture.add_child(fixture_box)
	root.add_child(fixture)
	await frames(4)
	guide.call("_layout")
	await frames(3)
	card_rect = guide.card.get_global_rect()
	check(not card_rect.intersects(fixture.get_global_rect()),
		"카드가 붙박이 HUD 를 피한다 (카드 %s · HUD %s)" % [str(card_rect), str(fixture.get_global_rect())])
	check(not card_rect.intersects(mark.get_global_rect()), "비키면서도 대상을 가리지 않는다")
	# 앵커가 아닌 것(머리띠·툴바)은 `keep_clear` 로 알려 준다.
	var bar := Panel.new()
	bar.position = Vector2(0, 100)
	bar.size = Vector2(844, 60)
	root.add_child(bar)
	guide.keep_clear = [bar]
	guide.call("_layout")
	await frames(3)
	check(not guide.card.get_global_rect().intersects(bar.get_global_rect()),
		"keep_clear 에 넣은 것도 피한다 (카드 %s · 띠 %s)" % [str(guide.card.get_global_rect()), str(bar.get_global_rect())])
	guide.finish(false)
	guide.queue_free(); fixture.queue_free(); mark.queue_free(); bar.queue_free()
	root.content_scale_size = was_size
	await frames(4)

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
	# 🛑 **글로우가 잘리지 않을 자리.** 스크롤은 자기 경계에서 무조건 자르므로, 꽉 찬 폭 버튼의 왼쪽
	#    글로우가 세로로 뚝 잘렸다(2026-09-13 사용자 지적). 스크롤 경계는 내용보다 좌·상·하로 넓어야
	#    한다 — 오른쪽은 레일 자리가 이미 그 일을 한다.
	var inset := scroll.get_node_or_null(^"ContentInset") as Control
	check(inset != null, "스크롤이 내용을 안쪽 여백으로 감싼다")
	if inset != null and inset.get_child_count() > 0:
		# 🛑 `ContentInset` 컨테이너 자체는 스크롤을 꽉 채운다 — 여백은 그 **자식**에 걸린다.
		#    컨테이너를 재면 "왼 0" 으로 나와 구현이 맞는데도 빨간불이었다(2026-09-13).
		var outer := scroll.get_global_rect()
		var inner := (inset.get_child(0) as Control).get_global_rect()
		check(inner.position.x - outer.position.x >= 8.0 and inner.position.y - outer.position.y >= 8.0
			and outer.end.y - inner.end.y >= 8.0,
			"스크롤 경계가 내용보다 좌·상·하로 넓다 — 글로우가 살 자리 (왼 %.0f · 위 %.0f · 아래 %.0f)"
			% [inner.position.x - outer.position.x, inner.position.y - outer.position.y, outer.end.y - inner.end.y])
		# 내용의 왼쪽 끝은 폼이 정한 자리 그대로다 — 여백을 빌렸을 뿐 내용이 밀리지는 않았다.
		check(near(inner.position.x, form.get_global_rect().position.x + form.get_theme_constant(&"margin_left"), 1.0),
			"내용 위치는 그대로다 (내용 %.0f · 폼 안쪽 %.0f)"
			% [inner.position.x, form.get_global_rect().position.x + form.get_theme_constant(&"margin_left")])
	var late := Label.new()
	late.text = "a long sentence that has to wrap on narrow phones"
	column.add_child(late)
	await frames(1)
	check(late.autowrap_mode != TextServer.AUTOWRAP_OFF, "나중에 들어온 라벨도 줄바꿈이 보장된다")

	# ── 버튼 글자는 낱말 단위로만 접힌다 ──────────────────────────────
	# 🛑 줄바꿈이 켜진 버튼은 최소 폭에서 **글자 폭을 뺀다**. 그래서 자연 폭 버튼이 좁아지면 `Done` 이
	#    `Don`/`e` 로 갈라졌다(2026-09-13 코치마크 실측). 한 낱말은 접지 않고, 여러 낱말은 가장 긴
	#    낱말이 한 줄에 들어갈 폭을 보장한다.
	var one := GoStyle.button("Done", Callable(), GoStyle.Tone.PRIMARY)
	one.custom_minimum_size.x = 72
	one.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(one)
	await frames(1)
	check(one.autowrap_mode == TextServer.AUTOWRAP_OFF, "한 낱말 버튼은 접지 않는다 (%d)" % one.autowrap_mode)
	var many := GoStyle.button("Delete everything permanently", Callable(), GoStyle.Tone.PRIMARY)
	column.add_child(many)
	await frames(1)
	var font := many.get_theme_font(&"font")
	var longest := font.get_string_size("permanently", HORIZONTAL_ALIGNMENT_LEFT, -1.0, many.get_theme_font_size(&"font_size")).x
	check(many.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and many.custom_minimum_size.x >= longest,
		"여러 낱말 버튼은 접되 가장 긴 낱말은 한 줄에 (최소 %.0f ≥ 낱말 %.0f)" % [many.custom_minimum_size.x, longest])
	# 🛑 **번역 키가 아니라 보이는 글자로 판단한다**(I-57). 키 `probe_two_words` 는 한 낱말이지만 번역문은
	#    두 낱말이다 — 키만 보면 접지 않기로 하고, 좁아지면 낱말 안에서 갈라진다. 언어가 바뀌어 한 낱말
	#    번역이 오면 폼이 알림을 받아 다시 정한다.
	var probe_locale := TranslationServer.get_locale()
	var two := Translation.new()
	two.locale = "xx"
	two.add_message("probe_two_words", "two words here")
	var one_word := Translation.new()
	one_word.locale = "yy"
	one_word.add_message("probe_two_words", "single")
	TranslationServer.add_translation(two)
	TranslationServer.add_translation(one_word)
	TranslationServer.set_locale("xx")
	var keyed_button := GoStyle.button_key("probe_two_words", Callable(), GoStyle.Tone.PRIMARY)
	column.add_child(keyed_button)
	await frames(2)
	check(keyed_button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"번역문이 두 낱말이면 키가 한 낱말이어도 접는다 (%d)" % keyed_button.autowrap_mode)
	TranslationServer.set_locale("yy")
	await frames(3)
	check(keyed_button.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"언어가 바뀌어 한 낱말이 되면 폼이 다시 정한다 (%d)" % keyed_button.autowrap_mode)
	TranslationServer.set_locale(probe_locale)
	TranslationServer.remove_translation(two)
	TranslationServer.remove_translation(one_word)
	await frames(2)

	# ── 드롭다운 두 종류는 한 부품처럼 보여야 한다 ────────────────────
	# 🛑 `select()`(OptionButton) 와 `dropdown()`(MenuButton) 이 데모에서 위아래로 붙어 있는데, 글자 정렬과
	#    화살표 크기가 달라 다른 부품처럼 보였다(2026-09-13 데모 촬영 실측).
	var choose := GoStyle.select(["A", "B"], "Choose")
	var more := GoStyle.dropdown("More", ["x", "y"])
	column.add_child(choose)
	column.add_child(more)
	await frames(2)
	check(more.alignment == HORIZONTAL_ALIGNMENT_LEFT, "MenuButton 드롭다운도 글자를 왼쪽에 둔다")
	var arrow_w := choose.get_theme_icon(&"arrow").get_width()
	check(more.get_theme_constant(&"icon_max_width") == arrow_w,
		"두 드롭다운의 화살표 크기가 같다 (OptionButton %d · MenuButton %d)" % [arrow_w, more.get_theme_constant(&"icon_max_width")])
	# 🛑 크기만이 아니라 **자리**도 — OptionButton 은 `arrow_margin` 만큼, MenuButton 은 판의 오른쪽 여백만큼
	#    들여 놓는다. 둘이 다르면 화살표 x 가 12dp 어긋난다(2026-09-13 데모 실측).
	check(choose.get_theme_constant(&"arrow_margin") == int(more.get_theme_stylebox(&"normal").content_margin_right),
		"두 드롭다운의 화살표가 같은 자리에 (arrow_margin %d · 판 여백 %d)"
		% [choose.get_theme_constant(&"arrow_margin"), int(more.get_theme_stylebox(&"normal").content_margin_right)])
	choose.queue_free(); more.queue_free()

	# 글자를 바꾼 뒤 다시 부르면 규칙이 다시 적용된다 — 코치마크가 `Next` → `Done` 으로 바꾸는 길이다.
	many.text = "Done"
	GoStyle.fit_words(many)
	check(many.autowrap_mode == TextServer.AUTOWRAP_OFF, "글자를 바꾼 뒤 fit_words 를 부르면 한 낱말 규칙으로 돌아온다")
	# 🛑 토글은 **폼 밖**에 둔다 — 폼 안에서는 `GoStyle.form()` 이 자손 버튼에 같은 규칙을 다시 걸어
	#    `toggle()` 자체의 규칙이 빠져도 초록불이 된다(변이 검사가 실제로 그렇게 놓쳤다).
	var toggle_one := GoStyle.toggle("Haptics", false)
	var toggle_many := GoStyle.toggle("Enable haptic feedback on every press", false)
	root.add_child(toggle_one)
	root.add_child(toggle_many)
	await frames(1)
	check(toggle_one.autowrap_mode == TextServer.AUTOWRAP_OFF and toggle_many.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"토글도 같은 낱말 규칙 (한 낱말 %d · 여러 낱말 %d)" % [toggle_one.autowrap_mode, toggle_many.autowrap_mode])
	toggle_one.queue_free()
	toggle_many.queue_free()
	form.queue_free()
	await frames(1)

	# 🛑 폼 **폭 제한은 폰에서 발동하지 않는다** — 모바일 최대 폭이 0(제한 없음)이기 때문이다.
	#    그래서 폰 크기로만 검사하면 이 규칙은 있으나 마나다. 데스크톱 폭을 만들어 확인한다.
	var restore := root.content_scale_size
	root.content_scale_size = Vector2i(1280, 800)
	await frames(3)
	var wide := GoForm.new()
	root.add_child(wide)
	await frames(3)
	var desktop_cap := GoScale.form_width_for(GoScale.breakpoint_for_dp(800.0))
	check(desktop_cap > 0, "데스크톱 폼 최대 폭이 정해져 있다 (%d dp)" % desktop_cap)
	var side_margin := wide.get_theme_constant(&"margin_left")
	check(side_margin > GoUi.metric(GoTheme.PADDING) * 2,
		"넓은 화면에서 폼이 폭을 제한해 여백을 키운다 (%d dp — 기본 여백 %d)"
		% [side_margin, GoUi.metric(GoTheme.PADDING)])
	wide.queue_free()
	root.content_scale_size = restore
	await frames(3)

	# 🛑 가상 키보드는 데스크톱 검사에 **올라오지 않는다** — 높이를 직접 넣어 재현한다.
	#    그러지 않으면 "키보드를 피한다" 는 규칙을 아무도 지키지 않는다.
	var keyed := GoForm.new()
	root.add_child(keyed)
	await frames(2)
	var bottom_before := keyed.get_theme_constant(&"margin_bottom")
	keyed._on_keyboard(300)
	await frames(2)
	check(keyed.get_theme_constant(&"margin_bottom") > bottom_before,
		"가상 키보드가 올라오면 폼이 그 위로 비킨다 (%d → %d)"
		% [bottom_before, keyed.get_theme_constant(&"margin_bottom")])
	keyed._on_keyboard(0)
	await frames(2)
	check(keyed.get_theme_constant(&"margin_bottom") == bottom_before, "키보드가 내려가면 되돌아온다")
	keyed.queue_free()
	await frames(1)

	# ── 코드로 조립한 폼의 뒤로가기 버튼 ──────────────────────────────
	# 🛑 `_ready` 가 스크롤을 테두리 칸으로 옮긴다. 엔진 `reparent()` 는 스크롤과 **같은 owner** 인 자손만 owner 를
	#    되돌리므로, 버튼만 소유한 폼은 owner 가 지워져 `%BackButton` 을 못 찾고 Android 뒤로가기가 조용히 꺼졌다
	#    (2026-09-15 실측). 씬 루트가 전부 소유하는 `.tscn` 에서는 드러나지 않아 코드 조립으로만 잡힌다.
	for mode in ["form", "holder"]:
		var holder := Control.new()
		var coded := GoForm.new()
		holder.add_child(coded)
		var coded_scroll := GoScroll.new()
		coded.add_child(coded_scroll)
		var coded_column := VBoxContainer.new()
		coded_scroll.add_child(coded_column)
		var back := Button.new()
		back.name = "BackButton"
		back.text = "Back"
		coded_column.add_child(back)
		var keeper: Node = coded if mode == "form" else holder
		if mode == "holder": coded.owner = holder          # 폼과 버튼만 소유 — 스크롤·칸은 owner 없음
		back.owner = keeper
		back.unique_name_in_owner = true
		root.add_child(holder)
		await frames(2)
		check(coded_scroll.get_parent() != coded and back.owner == keeper and coded._back_button == back and coded._holds_back,
			"코드 폼(owner=%s) — 스크롤을 옮긴 뒤에도 %%BackButton 이 남아 뒤로가기를 잡는다 (옮김 %s · owner 유지 %s · 찾음 %s · 잡음 %s)"
			% [mode, coded_scroll.get_parent() != coded, back.owner == keeper, coded._back_button == back, coded._holds_back])
		holder.queue_free()
		await frames(1)
	# ── 떠 있는 HUD 피하기 ──────────────────────────────────────────────
	# 🛑 **겹침은 눈으로만 잡혀 왔다.** 스크롤 본문이 체력바 뒤로 흘러 글자끼리 뒤섞인 것도,
	#    입력칸이 퀵슬롯에 가려진 것도 스크린샷을 열어야 보였다(2026-09-13). 사각형이 겹치는지는
	#    좌표로 잴 수 있다 — 여기서 잰다.
	var screen := GoForm.new()
	var screen_scroll := GoScroll.new()
	screen.add_child(screen_scroll)
	root.add_child(screen)
	var corner := GoHudAnchor.new()
	corner.spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	var block := Control.new()
	block.custom_minimum_size = Vector2(160, 90)
	corner.add_child(block)
	root.add_child(corner)
	await frames(4)

	var hud_rect := func() -> Rect2: return Rect2(corner.global_position, corner.size)
	# 🛑 **자식의 사각형으로 재지 않는다.** 컨테이너는 여백이 바뀐 **다음 프레임**에 자식을 다시
	#    놓으므로, 자식을 읽으면 한 박자 전의 배치를 보게 된다(16dp 차이로 엇갈렸다).
	#    폼이 **내주는 안쪽 영역**이 우리가 보장하는 것이고, 그것은 즉시 정확하다.
	var body := func() -> Rect2:
		return screen.get_global_rect().grow_individual(
			-screen.get_theme_constant(&"margin_left"), -screen.get_theme_constant(&"margin_top"),
			-screen.get_theme_constant(&"margin_right"), -screen.get_theme_constant(&"margin_bottom"))
	check(hud_rect.call().get_area() > 0.0, "HUD 칸이 자리를 차지한다 %s" % str(hud_rect.call()))
	# 🛑 **여백으로 판정하지 않는다.** 폼의 좌우 여백은 브레이크포인트별 폭 제한에서도 생긴다 —
	#    넓은 화면에서는 그쪽이 훨씬 커서, 여백만 보면 "옆으로 피했다" 고 오판한다(실제로 했다:
	#    768×1024 에서 오른쪽 164 는 폭 제한이고 HUD 회피는 0 이었다). 회피분만 따로 본다.
	# ① 기본은 지금까지의 동작 그대로 — 한 칸도 비키지 않는다.
	check(screen._hud_pad == Vector4.ZERO, "avoid_hud 를 끄면 자리를 비우지 않는다(기존 동작) %s"
		% str(screen._hud_pad))

	# ② 켜면 겹치지 않는다.
	# 🛑 HUD 는 자기 크기를 **미룬 호출**로 정하고, 폼은 그 변화를 다음 프레임에 따라잡는다 —
	#    네 프레임으로는 아슬아슬해서 화면 크기에 따라 16dp 차이로 엇갈렸다. 넉넉히 기다린다.
	screen.avoid_hud = true
	await frames(10)
	check(not body.call().intersects(hud_rect.call()),
		"avoid_hud — 본문 %s 가 HUD %s 를 피한다" % [str(body.call()), str(hud_rect.call())])

	# ③ **어느 쪽으로 피하는가.** "안 겹치니 됐다" 로 끝내면, 가로 화면에서 세로로만 물러나
	#    본문이 화면의 27% 를 잃는 것을 놓친다(I-38 이 그랬다).
	#    🛑 방향 이름을 박아 두지 않는다 — 1280×800 은 가로지만 비율이 1.6:1 이라 아래가 근소하게
	#       싸다(136k vs 141k). 박아 두면 알고리즘이 옳아도 검사가 틀린다. **규칙 자체**를 잰다.
	var pad := screen._hud_pad
	var full := GoSafeArea.usable_rect(screen.get_window())
	var mark := hud_rect.call() as Rect2
	# 🛑 **구현과 같은 영역에서 잰다.** 폼은 좌우 여백을 뺀 자기 자리에서 겹침을 보므로(넓은 화면에서
	#    폭 제한으로 이미 가운데에 몰려 있다), 안전영역 전체로 재면 검사만 다른 답을 낸다.
	var side_now := maxf(float(screen._side_margin()),
		(full.size.x - float(screen._max_width())) * 0.5 if screen._max_width() > 0 else 0.0)
	full = full.grow_individual(-side_now, 0.0, -side_now, 0.0)
	var cost := [
		(mark.end.x - full.position.x) * full.size.y,     # 왼쪽으로
		(mark.end.y - full.position.y) * full.size.x,     # 위로
		(full.end.x - mark.position.x) * full.size.y,     # 오른쪽으로
		(full.end.y - mark.position.y) * full.size.x,     # 아래로
	]
	if pad == Vector4.ZERO:
		# 🔑 **넓은 화면에서는 밀 필요가 없다.** 폭 제한으로 폼이 이미 가운데에 몰려 있어 구석의
		#    HUD 와 닿지 않는다 — 그런데도 밀면 본문이 왼쪽으로 치우쳐 가운데 정렬이 깨진다
		#    (1280 화면에서 실제로 214dp 치우쳤다).
		check(not body.call().intersects(hud_rect.call()),
			"이미 비껴 있으면 밀지 않는다 (본문 %s · HUD %s)"
			% [str(body.call()), str(hud_rect.call())])
	else:
		var took := 2 if pad.z > 0.0 else 3               # 이 HUD 는 오른쪽 아래 구석이다
		# 🛑 **밖에 있는 방향은 세지 않는다**(깊이가 음수다) — 구현도 그렇게 거른다.
		var reachable: Array = []
		for value in cost:
			if value > 0.0: reachable.append(value)
		var cheapest: float = reachable.min() if not reachable.is_empty() else cost[took]
		check(is_equal_approx(cost[took], cheapest),
			"가장 싼 방향으로 피한다 (고른 값 %.0f · 가장 싼 값 %.0f)" % [cost[took], cheapest])

	# ④ **가로에서는 세로 공간을 지킨다.** I-38 의 본래 증상이다 — 844×390 에서 아래로만 피하면
	#    본문 높이가 390 에서 286 으로 줄어 버튼 한 줄이 통째로 잘린다.
	var restore_size := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(5)
	check(screen._hud_pad.z > screen._hud_pad.w,
		"가로 폰에서는 옆으로 피해 세로를 지킨다 (오른쪽 %.0f · 아래 %.0f)"
		% [screen._hud_pad.z, screen._hud_pad.w])
	# ⑤ **넓은 화면에서는 한 칸도 밀지 않는다.** 폭 제한으로 이미 가운데에 몰려 구석의 HUD 와
	#    닿지 않기 때문이다 — 그런데도 밀면 본문이 왼쪽으로 치우쳐 가운데 정렬이 깨진다.
	#    🛑 이 규칙은 **폰 화면에서는 드러나지 않는다**(상한이 없어 폼이 화면을 다 쓴다).
	root.content_scale_size = Vector2i(1280, 800)
	await frames(8)
	check(screen._hud_pad == Vector4.ZERO,
		"넓은 화면에서는 헛되이 밀지 않는다 (pad %s)" % str(screen._hud_pad))
	root.content_scale_size = restore_size
	await frames(4)

	# ⑤ 자리를 예약하지 않겠다고 한 칸은 못 본 척한다 — 손을 얹을 때만 나타나는 조이스틱이 그렇다.
	corner.reserve_space = false
	await frames(4)
	check(screen._hud_pad == Vector4.ZERO, "reserve_space 를 끈 칸은 자리를 안 먹는다 %s"
		% str(screen._hud_pad))
	screen.queue_free()
	corner.queue_free()
	await frames(1)

	# 가로 스크롤 팩토리 — 자식 클래스가 자기 인스턴스로 다시 만들 수 있게 설정만 분리돼 있다.
	var lane := GoScroll.horizontal()
	var own := GoScroll.new()
	var made := GoScroll.as_horizontal(own)
	check(made == own and lane.horizontal_scroll_mode == made.horizontal_scroll_mode and made.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and made.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and made.mouse_filter == Control.MOUSE_FILTER_PASS, "as_horizontal = horizontal 의 설정 · 같은 인스턴스를 돌려준다")
	lane.free(); own.free()


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
	# 🛑 RTL 언어는 ar 하나가 아니다 — he 를 더했으므로 둘 다 엔진이 RTL 로 보는지 확인한다.
	#    위젯은 LAYOUT_DIRECTION_APPLICATION_LOCALE 에 맡기므로, 판정이 맞으면 레이아웃도 맞다.
	var before := TranslationServer.get_locale()
	for locale: String in ["ar", "he"]:
		TranslationServer.set_locale(locale)
		check(TranslationServer.get_locale().begins_with(locale), "%s 로케일이 적용된다" % locale)
		check(not TranslationServer.get_tool_locale().is_empty(), "%s 에서 로케일이 비지 않는다" % locale)

	# 🛑 **숫자는 언어를 따라 뒤집히지 않는다.** 아랍어에서도 `320 / 500` 의 순서는 그대로다 —
	#    뒤집히면 남은 체력과 최대 체력이 자리를 바꿔 읽힌다.
	var numbers := GoBar.new()
	root.add_child(numbers)
	await frames(2)
	numbers.set_values(320, 500, false)
	var readout := numbers.get_node(^"Column/Head/Value") as Label
	check(readout.text_direction == Control.TEXT_DIRECTION_LTR, "막대 숫자는 RTL 에서도 왼→오")
	numbers.queue_free()

	# 🛑 **뒤집혀야 하는 것은 실제로 뒤집히는가.** 값만 확인하면 "설정은 맞는데 화면은 그대로" 를 놓친다.
	#    아랍어를 켜고 목록 줄의 아이콘과 글자가 자리를 바꾸는지 **좌표로** 본다.
	TranslationServer.set_locale("ar")
	var mirrored := GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "", false)
	root.add_child(mirrored)
	mirrored.size = Vector2(300, 56)
	await frames(3)
	var line := mirrored.get_child(0).get_child(0) as Control
	var glyph := line.get_child(0) as Control
	var words := line.get_child(1) as Control
	check(glyph.global_position.x > words.global_position.x,
		"RTL 에서 목록 줄이 거울처럼 뒤집힌다 (아이콘 %.0f · 글자 %.0f)"
		% [glyph.global_position.x, words.global_position.x])
	TranslationServer.set_locale(before)
	await frames(3)
	check(glyph.global_position.x < words.global_position.x, "LTR 로 돌아오면 원래 순서")
	mirrored.queue_free()
	await frames(1)

	TranslationServer.set_locale(before)
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
		# 🛑 데모는 자체 project.godot 을 가진 **별도 프로젝트**다 — 그 안의 `res://` 는 데모 루트를 가리킨다.
		if path.begins_with(ADDON + "/tests/") or path.begins_with(ADDON + "/tools/") \
				or path.begins_with(ADDON + "/examples/demo/"): continue
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
# ── 위젯 팩토리(선택·메뉴·표시) ─────────────────────────────────────────

func _widgets() -> void:
	var select := GoStyle.select(["a", "b", "c"], "pick")
	check(select is OptionButton and select.item_count == 3 and select.selected == -1 and select.text == "pick", "select: 항목 3 · 미선택 placeholder")
	var menu := GoStyle.dropdown("Actions", ["Rename", {"text": "Delete", "disabled": true}])
	check(menu is MenuButton and menu.get_popup().item_count == 2 and menu.get_popup().is_item_disabled(1)
		and menu.custom_minimum_size.y == GoUi.metric(GoTheme.BUTTON_HEIGHT), "dropdown: 항목 2 · 둘째 비활성 · 버튼 높이")
	var radios := GoStyle.radio_group(["x", "y", "z"], 2)
	var group: ButtonGroup = radios.get_meta(&"group")
	check(radios.get_child_count() == 3 and group != null and group.get_pressed_button() == radios.get_child(2)
		and (radios.get_child(0) as Control).custom_minimum_size.y == GoUi.metric(GoTheme.TOUCH), "radio_group: 3항목 · 셋째 선택 · 터치 하한")
	var picked := [-1]
	var seg := GoStyle.segmented(["Day", "Week"], 0, func(i: int) -> void: picked[0] = i)
	root.add_child(seg); await frames(1)
	(seg.get_child(1) as Button).button_pressed = true
	(seg.get_child(1) as Button).pressed.emit()
	check((seg.get_meta(&"group") as ButtonGroup).get_pressed_button() == seg.get_child(1) and picked[0] == 1, "segmented: 하나만 눌림 · 콜백 index")
	check((seg.get_child(0) as Button).autowrap_mode == TextServer.AUTOWRAP_OFF and (seg.get_child(0) as Control).size.x >= 40, "segmented: 줄바꿈 끔 · 자연 폭(글자가 세로로 쪼개지지 않는다)")
	seg.queue_free()
	# 🔑 작은 칸 — 좁은 크롬(지도 위 알약)용. 칸 최소 폭 = 터치, 칸 판 여백 = 작은 버튼 토큰, 눌린 칸만 강조색.
	var tight := GoStyle.segmented(["Nearby", "Overview"], 1, Callable(), false, true)
	root.add_child(tight); await frames(1)
	var tight_first := tight.get_child(0) as Button
	var tight_face := tight_first.get_theme_stylebox(&"normal")
	check(near(tight_first.custom_minimum_size.x, GoUi.metric(GoTheme.TOUCH)) and near(tight_face.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X))
		and near(tight_face.get_margin(SIDE_TOP), GoUi.metric(GoTheme.COMPACT_PADDING_Y)),
		"segmented(compact): 칸 최소 폭 터치 · 판 여백 = 작은 버튼 토큰 (%.0f · %.0f)" % [tight_first.custom_minimum_size.x, tight_face.get_margin(SIDE_LEFT)])
	var picked_face := (tight.get_child(1) as Button).get_theme_stylebox(&"pressed") as StyleBoxFlat
	check(picked_face == null or picked_face.bg_color.is_equal_approx(GoUi.color(GoTheme.ACCENT)), "segmented(compact): 눌린 칸은 강조색으로 채운다")
	check(near(tight_first.get_theme_stylebox(&"pressed").get_margin(SIDE_LEFT), tight_face.get_margin(SIDE_LEFT)),
		"segmented(compact): 상태가 바뀌어도 칸 여백이 같다(누를 때 폭이 흔들리지 않는다)")
	var idle_face := tight_first.get_theme_stylebox(&"normal")
	check(idle_face is StyleBoxEmpty or (idle_face is StyleBoxFlat and (idle_face as StyleBoxFlat).bg_color.a < 0.01 and (idle_face as StyleBoxFlat).border_width_left == 0),
		"segmented(compact): 고르지 않은 칸은 판을 그리지 않는다 — 바깥 알약 안에서 테두리가 두 겹이 되지 않는다")
	var focus_face := tight_first.get_theme_stylebox(&"focus")
	check(focus_face != null and near(focus_face.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X)) and not (focus_face is StyleBoxEmpty),
		"segmented(compact): 키보드 포커스는 옅은 링으로 보인다 · 여백 같음")
	tight.queue_free()
	# 🔑 고르는 카드 — 모든 상태 판 여백 0 · 토글/목록형 선택 · 비활성 옅게/그대로 · mouse_filter 는 줄 때만 바꾼다.
	var pick_ink := Color(0.9, 0.3, 0.2)
	var pick := Button.new()
	GoStyle.style_choice_card(pick, pick_ink)
	root.add_child(pick); await frames(1)
	var zero_margins := true
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var face := pick.get_theme_stylebox(state)
		zero_margins = zero_margins and face != null and near(face.get_margin(SIDE_LEFT), 0.0) and near(face.get_margin(SIDE_TOP), 0.0)
	check(zero_margins and pick.toggle_mode and pick.text == "",
		"style_choice_card: 모든 상태 판 여백 0(고른 카드만 넓어지지 않는다) · 토글 · 글자 없음")
	check(pick.mouse_filter == Control.MOUSE_FILTER_STOP, "style_choice_card: filter 를 주지 않으면 mouse_filter 를 건드리지 않는다")
	check(GoSkin.box_background(pick.get_theme_stylebox(&"pressed")) != GoSkin.box_background(pick.get_theme_stylebox(&"normal")),
		"style_choice_card: 고른 판은 평소 판과 채움이 다르다")
	check(GoSkin.box_background(pick.get_theme_stylebox(&"disabled")).a < GoSkin.box_background(pick.get_theme_stylebox(&"normal")).a,
		"style_choice_card: 비활성 판은 옅다(dim_disabled 기본)")
	pick.queue_free()
	var listed := Button.new()
	GoStyle.style_choice_card(listed, pick_ink, true, false, false, Control.MOUSE_FILTER_PASS)
	check(not listed.toggle_mode and listed.mouse_filter == Control.MOUSE_FILTER_PASS
		and listed.get_theme_stylebox(&"normal") == listed.get_theme_stylebox(&"pressed")
		and listed.get_theme_stylebox(&"disabled") == listed.get_theme_stylebox(&"normal"),
		"style_choice_card(selected·토글 없음): 평소 판이 고른 판 · 비활성도 같은 판(색·폭이 튀지 않는다) · 준 filter 그대로")
	listed.free()
	# 🔑 카드 안 내용 칸 · 입력 통과 · 한 줄 라벨 — 고르는 카드를 채우는 조립.
	var tile := Button.new()
	GoStyle.style_choice_card(tile, pick_ink, false, false)
	root.add_child(tile)
	var tile_body := GoStyle.card_body(tile, 9, 3)
	var tile_row := GoStyle.row(4)
	tile_body.add_child(tile_row)
	var tile_name := GoStyle.line("A very long item name that cannot fit on one line", GoTheme.ROLE_CAPTION)
	tile_row.add_child(tile_name)
	var tile_desc := GoStyle.label("Wraps onto several lines inside the card without spilling out of it at all.")
	tile_body.add_child(tile_desc)
	GoStyle.let_input_through(tile_body)
	tile.size.x = 160
	await frames(4)
	var tile_inset := tile_body.get_parent() as MarginContainer
	check(tile_inset != null and tile_inset.get_theme_constant(&"margin_left") == 9 and tile_body.get_theme_constant(&"separation") == 3,
		"card_body: 준 안쪽 여백 9 · 줄 간격 3")
	check(tile_desc.get_line_count() > 1 and tile.size.y >= tile_inset.get_combined_minimum_size().y - 0.5,
		"card_body: 카드 높이가 줄바꿈된 내용을 감싼다 (%.0f ≥ %.0f)" % [tile.size.y, tile_inset.get_combined_minimum_size().y])
	check(tile_inset.mouse_filter == Control.MOUSE_FILTER_IGNORE and tile_body.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and tile_row.mouse_filter == Control.MOUSE_FILTER_IGNORE and tile_name.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and tile_desc.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"let_input_through: 카드 안 컨트롤이 모두 입력을 받지 않는다(누르는 것은 카드)")
	check(tile_name.autowrap_mode == TextServer.AUTOWRAP_OFF and tile_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
		and tile_name.clip_text and tile_name.get_line_count() == 1,
		"line: 줄바꿈 끔 · 말줄임 · 자르기 · 한 줄")
	tile.queue_free()
	# 🔑 칩 — 아이콘만 · 아이콘 + 글자 · 경고 테두리 · 누를 수 있는 칩 버튼(채움).
	var icon_chip := GoStyle.chip("", pick_ink, false, GoIconSet.HEART, 20)
	var icon_face := icon_chip.get_theme_stylebox(&"panel")
	# 🔑 아이콘 칸은 세트에 따라 글리프 라벨이거나 텍스처다 — 어느 쪽이든 같은 칸을 차지한다.
	check(icon_chip.get_child_count() == 1 and icon_chip.get_child(0) is Control
		and (icon_chip.get_child(0) as Control).custom_minimum_size == Vector2(20, 20)
		and near(icon_face.get_margin(SIDE_LEFT), icon_face.get_margin(SIDE_TOP)),
		"chip(icon): 글자가 없으면 아이콘 한 칸만 들고 판도 정사각 (좌 %.1f · 위 %.1f · 자식 %d)"
			% [icon_face.get_margin(SIDE_LEFT), icon_face.get_margin(SIDE_TOP), icon_chip.get_child_count()])
	var both_chip := GoStyle.chip("12", pick_ink, false, GoIconSet.HEART, 16)
	var both_row := both_chip.get_child(0) as HBoxContainer
	check(both_row != null and both_row.get_child_count() == 2 and both_row.get_child(1) is Label
		and (both_row.get_child(1) as Label).text == "12",
		"chip(icon, text): 아이콘 다음에 글자")
	var calm_face := GoStyle.chip("x", pick_ink).get_theme_stylebox(&"panel")
	var urgent_face := GoStyle.chip("x", pick_ink, false, &"", -1, true).get_theme_stylebox(&"panel")
	check(&"border_color" not in calm_face or calm_face.get(&"border_color") != urgent_face.get(&"border_color"),
		"chip(urgent): 경고 테두리는 평상 칩과 다르다")
	var chip_button := Button.new()
	GoStyle.style_chip_button(chip_button, pick_ink)
	var filled_button := Button.new()
	GoStyle.style_chip_button(filled_button, pick_ink, 0.85)
	check(chip_button.mouse_filter == Control.MOUSE_FILTER_STOP
		and chip_button.get_theme_stylebox(&"normal") != null and chip_button.get_theme_stylebox(&"disabled") != null
		and not chip_button.has_theme_stylebox_override(&"focus")
		and chip_button.has_theme_color_override(&"font_color") and chip_button.has_theme_color_override(&"font_hover_color"),
		"style_chip_button: 상태 판·판 위에서 읽히는 글자색을 입히고 mouse_filter·포커스 판은 건드리지 않는다")
	check(GoSkin.box_background(filled_button.get_theme_stylebox(&"normal")).a
		> GoSkin.box_background(chip_button.get_theme_stylebox(&"normal")).a,
		"style_chip_button(filled): 의미색으로 채운다")
	var chip_label := GoStyle.label("42")
	GoStyle.style_chip_label(chip_label, pick_ink)
	check(chip_label.get_theme_stylebox(&"normal") != null and chip_label.has_theme_color_override(&"font_color"),
		"style_chip_label: 이미 만든 라벨에 칩 판과 판 위에서 읽히는 글자색을 입힌다")
	chip_label.free()
	var hud_face := GoStyle.hud_panel(pick_ink).get_theme_stylebox(&"panel")
	var chip_face := GoStyle.chip_panel(pick_ink).get_theme_stylebox(&"panel")
	var tinted_face := GoStyle.chip_panel(pick_ink, 0.5).get_theme_stylebox(&"panel")
	check(hud_face != null and hud_face.get_class() == GoUi.skin().floating_box(GoTheme.BOX_HUD, pick_ink).get_class()
		and chip_face != null and chip_face.get_class() == GoUi.skin().chip_box(pick_ink).get_class()
		and GoSkin.box_background(tinted_face).a > GoSkin.box_background(chip_face).a,
		"hud_panel·chip_panel: 스킨 판을 그대로 입힌다 · fill_alpha 는 더 짙게 채운다")
	# 🛑 HUD 판의 안쪽 여백 — 부르는 쪽이 준 값이 그대로 판에 실려야 한다. 이게 안 실리면 부르는 쪽이
	#    `padding()` 칸을 덧대어 여백이 두 겹이 되고, 좁은 칸의 말줄임 글자가 통째로 사라진다.
	var padded_face := GoStyle.hud_panel(pick_ink, 6.0, 5.0).get_theme_stylebox(&"panel")
	var plain_face := GoUi.skin().floating_box(GoTheme.BOX_HUD, pick_ink)
	check(padded_face.get_content_margin(SIDE_LEFT) == 6.0 and padded_face.get_content_margin(SIDE_RIGHT) == 6.0
		and padded_face.get_content_margin(SIDE_TOP) == 5.0 and padded_face.get_content_margin(SIDE_BOTTOM) == 5.0
		and hud_face.get_content_margin(SIDE_LEFT) == plain_face.get_content_margin(SIDE_LEFT)
		and hud_face.get_content_margin(SIDE_TOP) == plain_face.get_content_margin(SIDE_TOP),
		"hud_panel: 여백 인자는 판에 그대로 실리고 기본값이면 스킨 여백 그대로다 (준값 %s/%s · 기본 %s/%s)"
			% [padded_face.get_content_margin(SIDE_LEFT), padded_face.get_content_margin(SIDE_TOP),
				hud_face.get_content_margin(SIDE_LEFT), hud_face.get_content_margin(SIDE_TOP)])
	icon_chip.free(); both_chip.free(); chip_button.free(); filled_button.free()
	# 🔑 선택 격자 — 색 견본·아이콘·글자 카드. 하나만 선택, 칸마다 터치 하한, 고른 칸만 두꺼운 강조 테두리.
	var chosen := [-1]
	var grid := GoStyle.choice_grid([{"color": "ff0000", "tooltip": "Red"}, {"icon": GoIconSet.STAR, "text": "Star"}, "Plain"], 1,
		func(i: int) -> void: chosen[0] = i)
	root.add_child(grid); await frames(2)
	var cells := grid.get_children()
	var choice_group: ButtonGroup = grid.get_meta(&"group")
	check(cells.size() == 3 and choice_group.get_pressed_button() == cells[1], "choice_grid: 3칸 · 둘째 선택")
	(cells[0] as Button).button_pressed = true
	(cells[0] as Button).pressed.emit()
	check(chosen[0] == 0 and choice_group.get_pressed_button() == cells[0], "choice_grid: 누른 칸만 선택 · 콜백 index")
	var smallest := Vector2.INF
	for cell: Control in cells: smallest = smallest.min(cell.size)
	check(smallest.x >= GoUi.metric(GoTheme.TOUCH) - 0.5 and smallest.y >= GoUi.metric(GoTheme.TOUCH) - 0.5,
		"choice_grid: 칸마다 터치 하한 (%.0f×%.0f)" % [smallest.x, smallest.y])
	var red_swatch := cells[0].find_child("Swatch", true, false) as Panel
	check((cells[0] as Button).tooltip_text == "Red" and red_swatch != null
		and (red_swatch.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.is_equal_approx(Color.RED), "choice_grid: 견본은 실제 색 그대로 · 툴팁 = 이름")
	var picked_box := (cells[0] as Button).get_theme_stylebox(&"pressed")
	var idle_box := (cells[0] as Button).get_theme_stylebox(&"normal")
	check(near(picked_box.get_margin(SIDE_LEFT), idle_box.get_margin(SIDE_LEFT)), "choice_grid: 선택해도 칸 여백이 같다(흔들리지 않는다)")
	var picked_flat := picked_box as StyleBoxFlat
	check(picked_flat == null or (picked_flat.border_color.is_equal_approx(GoUi.color(GoTheme.ACCENT))
		and picked_flat.border_width_left > (idle_box as StyleBoxFlat).border_width_left), "choice_grid: 고른 칸은 더 두꺼운 강조색 테두리")
	var captions := cells[2].find_children("Caption", "Label", true, false)
	check(captions.size() == 1 and (captions[0] as Label).text == "Plain" and cells[1].find_child("Caption", true, false) != null,
		"choice_grid: 글자 카드·아이콘 카드에 이름표")
	grid.queue_free()
	var glass: StyleBox = GoUi.skin().overlay_box(4, 2)
	check(near(glass.get_margin(SIDE_LEFT), 4.0) and near(glass.get_margin(SIDE_TOP), 2.0), "overlay_box: 준 여백 그대로")
	var glass_default: StyleBox = GoUi.skin().overlay_box()
	check(near(glass_default.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X)), "overlay_box: 여백을 안 주면 작은 버튼 여백 토큰")
	var glass_flat := glass_default as StyleBoxFlat
	check(glass_flat == null or (is_equal_approx(glass_flat.bg_color.a, 0.82) and glass_flat.border_width_left == 1), "overlay_box: 바탕 불투명도 0.82 · 테두리 1")
	var bar := GoStyle.tabs(["One", "Two", "Three"], 1)
	check(bar is TabBar and bar.tab_count == 3 and bar.current_tab == 1 and bar.custom_minimum_size.y == GoUi.metric(GoTheme.TOUCH), "tabs: 3탭 · 둘째 선택 · 터치 높이")
	var crumbs := GoStyle.breadcrumb(["Home", "Inventory", "Weapons"])
	check(crumbs.get_child_count() == 5 and crumbs.get_child(4) is Label and crumbs.get_child(0) is Button, "breadcrumb: 항목 3 + 구분 2 · 마지막은 라벨")
	check((crumbs.get_child(4) as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (crumbs.get_child(0) as Button).autowrap_mode == TextServer.AUTOWRAP_OFF, "breadcrumb: 항목 줄바꿈 끔(자연 폭)")
	var area := GoStyle.textarea("hint", 3)
	check(area is TextEdit and area.placeholder_text == "hint" and area.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY and area.custom_minimum_size.y > GoUi.font_size(GoTheme.ROLE_BODY) * 3, "textarea: placeholder · 줄바꿈 · 3줄 높이")
	var av := GoStyle.avatar("Ada Lovelace", 40)
	check(av.custom_minimum_size == Vector2(40, 40) and av.get_child(0) is Label and (av.get_child(0) as Label).text == "AL", "avatar: 40 · 이니셜 AL")
	var sk := GoStyle.skeleton(0, 12)
	check(sk.size_flags_horizontal == Control.SIZE_EXPAND_FILL and sk.custom_minimum_size.y == 12, "skeleton: 가로 채움 · 높이")
	var al := GoStyle.alert("saved", GoTheme.SUCCESS)
	var al_row := al.get_child(0)
	check(al is PanelContainer and al_row.get_child_count() == 2 and al_row.get_child(1) is Label and (al_row.get_child(1) as Label).text == "saved", "alert: 아이콘 + 글")
	var tb := GoStyle.table(["A", "B"], [["1", "2"], ["3", "4"]])
	check(tb.columns == 2 and tb.get_child_count() == 6 and (tb.get_child(0) as Label).uppercase, "table: 2열 · 머리 2 + 셀 4 · 머리 대문자")
	var lb := GoStyle.list_button(GoIconSet.SETTINGS, "Settings", Callable(), Color.TRANSPARENT, "", false, GoIconSet.CHEVRON_RIGHT)
	var line := lb.get_child(0).get_child(0)
	check(line.get_child_count() == 3 and (line.get_child(2) as Control).size_flags_vertical == Control.SIZE_SHRINK_CENTER, "list_button trailing: 줄 끝 꺾쇠 · 세로 가운데")
	for n in [select, menu, radios, bar, crumbs, area, av, sk, al, tb, lb]: n.free()


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
