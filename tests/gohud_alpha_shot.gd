## 📸 **판 불투명도(컨테이너 투명도)를 실제로 그려** PNG 로 남긴다(가상 모니터 전용).
##
##   bash <godot 스킬>/scripts/xvfb_run.sh --out <폴더> --size 900x1400 \
##     -s res://addons/gohud/tests/gohud_alpha_shot.gd
##
## 🛑 `--headless` 로는 스크린샷이 나오지 않는다 — 그리지 않기 때문이다.
##
## ## 🔑 왜 값 검사만으로는 모자란가
## `bg_color.a == 0.8` 은 **숫자**다. "뒤가 실제로 보이는가", "그 위의 글자가 아직 읽히는가" 는
## 그려 봐야 안다 — 투명도는 그 두 가지가 전부인 기능이다. 그래서 **뒤에 눈에 띄는 무늬를 깔고**
## 그 위에 판을 얹어 찍는다. 무늬가 판을 통해 비쳐야 기능이 동작한 것이고, 무늬 때문에 글자를
## 못 읽으면 값이 너무 낮은 것이다.
##
## 🛑 컨테이너에 한글 글꼴이 없다 — 한글은 두부(□)로 나온다. 모양을 보는 것이 목적이므로 영문으로 쓴다.
extends SceneTree

var _dir := ""


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true   # 최종 모습을 찍는다 — 페이드 중간이 아니라
	await _shot_default()
	await _shot_levels()
	await _shot_solid()
	await _shot_light()
	await _shot_custom_boxes()
	print("✅ 촬영 끝 — %s" % _dir)
	quit(0)


## 뒤에 깔 **눈에 띄는 무늬** — 판을 통해 이것이 비쳐야 투명도가 동작한 것이다.
## 🔑 단색이 아니라 굵은 사선 띠다 — 단색 배경이면 판이 "조금 다른 색" 이 된 것과 구별되지 않는다.
func _stage(title: String) -> VBoxContainer:
	for child in root.get_children():
		if child is CanvasLayer or child is Control: child.queue_free()
	await process_frame
	var world := Control.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(world)
	var size := root.get_visible_rect().size
	var band := 0
	for y in range(-int(size.x), int(size.y) + int(size.x), 90):
		var stripe := ColorRect.new()
		stripe.color = [Color("#1f7a4d"), Color("#b8481f"), Color("#2a55a8"), Color("#a89620")][band % 4]
		stripe.size = Vector2(size.x * 2.4, 46)
		stripe.position = Vector2(-size.x * 0.7, y)
		stripe.rotation = deg_to_rad(-18.0)
		world.add_child(stripe)
		band += 1
	var pad := GoStyle.padding()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pad)
	var column := GoStyle.column()
	pad.add_child(column)
	var head := GoStyle.label(title, GoTheme.ROLE_SUBTITLE)
	GoStyle.text_shadow(head)
	column.add_child(head)
	return column


func _save(name: String) -> void:
	for _i in 6: await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	var err := image.save_png(path)
	print("  %s %s (%dx%d)" % ["✅" if err == OK else "🛑", path, image.get_width(), image.get_height()])


## 판 한 장에 글자를 담아 넣는다 — "뒤가 비치는데 글자는 읽히는가" 를 한 장에서 함께 본다.
func _filled(card: Control, label: String, note: String) -> Control:
	var body := GoStyle.card_body(card, GoUi.metric(GoTheme.PADDING_COMPACT), GoUi.metric(GoTheme.GAP_TINY))
	body.add_child(GoStyle.label(label, GoTheme.ROLE_BUTTON))
	var caption := GoStyle.label(note, GoTheme.ROLE_CAPTION)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(caption)
	return card


# ── ① 기본값 그대로 — 테마가 정한 80% ─────────────────────────────────

func _shot_default() -> void:
	var page := await _stage("Default theme — panels at 80%")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "Card face at card_alpha (80). The stripes behind show through; the text stays sharp."))
	page.add_child(_filled(GoStyle.hud_panel(), "GoStyle.hud_panel()", "HUD dock at hud_alpha (80) — laid straight over the world."))
	page.add_child(GoStyle.alert("GoStyle.alert() follows card_alpha too — it is a container inside a card.", GoTheme.INFO))
	var pill := GoStyle.overlay_panel()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pill_text := GoStyle.label("overlay_panel()", GoTheme.ROLE_CAPTION)
	# 🛑 줄바꿈을 끈다 — `SHRINK_BEGIN` 에서는 최소 폭이 곧 실제 폭이라 한 글자씩 세로로 접힌다.
	pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(pill_text)
	page.add_child(pill)
	var notice := GoNotice.new()
	page.add_child(notice)
	notice.show_text("GoNotice at notice_alpha (80)", GoTheme.WARNING, 0.0)
	# 🔑 표면(대화상자)은 자체 층에 뜬다 — 카드 뒤로 띠가 비치는 것이 이 장의 핵심이다.
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var window := GoSurface.new()
	layer.add_child(window)
	window.max_height = 300.0
	window.set_title("GoSurface — panel_alpha 80")
	window.body.add_child(GoStyle.label("Dialogs, sheets and dropdowns all use this one shell, so they follow panel_alpha together.", GoTheme.ROLE_BODY))
	window.body.add_child(GoStyle.button("Buttons stay solid", Callable(), GoStyle.Tone.PRIMARY))
	await _save("alpha_default_80")


# ── ② 네 단계를 나란히 — 값이 무엇을 바꾸는가 ─────────────────────────

func _shot_levels() -> void:
	var page := await _stage("One card at four levels")
	for level: int in [100, 80, 55, 25]:
		page.add_child(_filled(GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, float(level) / 100.0),
			"alpha = %d%%" % level,
			"At 25% the stripes win and this line is hard to read — that is the floor, not a target."))
	await _save("alpha_levels")


# ── ③ 프로젝트 전체를 꽉 찬 색으로 되돌린다 ───────────────────────────

func _shot_solid() -> void:
	GoUi.config.container_alpha = 100
	GoUi.refresh()
	var page := await _stage("container_alpha = 100 — opaque again")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "One setting turns every panel back to a solid colour. Nothing behind shows through."))
	page.add_child(_filled(GoStyle.hud_panel(), "GoStyle.hud_panel()", "Projects with busy worlds want this."))
	await _save("alpha_solid_100")
	GoUi.config.container_alpha = -1
	GoUi.refresh()


# ── ④ 밝은 테마에서도 같은 규칙인가 ───────────────────────────────────

func _shot_light() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)
	var page := await _stage("Light theme — same 80%")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "A light panel at 80% picks up the stripes as a tint; dark text still reads."))
	page.add_child(GoStyle.alert("Alert on the light theme.", GoTheme.DANGER))
	await _save("alpha_light_80")


# ── ⑤ 커스텀 StyleBox 테마 — 평판이 아닌 판에서도 같은 규칙인가 ────────
#
# 🛑 **여기가 조용히 깨지는 자리다.** sci-fi 의 사선 판(`GoStyleBoxCut`)과 중세 판
#    (`GoStyleBoxMedieval`)은 `StyleBoxFlat` 이 아니라 `_draw()` 로 직접 그린다. 불투명도를
#    `StyleBoxFlat` 갈래에만 넣으면 이 테마들에서 **아무 일도 일어나지 않고**, 값 검사는 통과한다.

func _shot_custom_boxes() -> void:
	for preset: StringName in [GoThemePresets.SCIFI_DARK, GoThemePresets.MEDIEVAL_DARK]:
		GoUi.use_preset(preset)
		var page := await _stage("%s — panels at 80%%" % preset)
		page.add_child(_filled(GoStyle.card(), "GoStyle.card()",
			"A custom-drawn face (cut corners / iron frame) fades the same way — background only."))
		page.add_child(_filled(GoStyle.hud_panel(), "GoStyle.hud_panel()",
			"Glow and rivets keep their strength; only the fill thins out."))
		page.add_child(GoStyle.alert("GoStyle.alert() on a custom face.", GoTheme.WARNING))
		page.add_child(_filled(GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, 0.35),
			"alpha = 35%", "The same card forced lower, to prove the value reaches a custom face."))
		await _save("alpha_custom_%s" % preset)
