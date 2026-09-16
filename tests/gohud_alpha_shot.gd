## 📸 **Really draws container alpha (panel transparency)** and saves it as a PNG (virtual monitor only).
##
##   bash <godot skill>/scripts/xvfb_run.sh --out <folder> --size 900x1400 \
##     -s res://addons/gohud/tests/gohud_alpha_shot.gd
##
## 🛑 `--headless` produces no screenshot — it does not draw.
##
## ## 🔑 Why checking values is not enough
## `bg_color.a == 0.8` is a **number**. "Does what is behind really show through", "is the text on top still
## readable" — only drawing answers those, and those two are all this feature is. So we **lay a loud pattern
## behind** and put the panel on top. The pattern must show through the panel for the feature to work, and if
## the pattern makes the text unreadable the value is too low.
##
## 🛑 The container has no Korean font — Korean renders as tofu (□). Shapes are the point here, so write in English.
extends SceneTree

var _dir := ""


func _initialize() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir.is_empty(): _dir = "/out"
	GoUi.reset()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.reduce_motion = true   # shoot the final look — not the middle of a fade
	await _shot_default()
	await _shot_levels()
	await _shot_solid()
	await _shot_light()
	await _shot_custom_boxes()
	print("✅ shots done — %s" % _dir)
	quit(0)


## The **loud pattern** laid behind — it must show through the panel for alpha to have worked.
## 🔑 Bold diagonal stripes, not a flat colour — on a flat background a panel that merely turned "a slightly different colour" looks the same.
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


## Puts text on one panel — "the back shows through, but is the text still readable" seen in a single picture.
func _filled(card: Control, label: String, note: String) -> Control:
	var body := GoStyle.card_body(card, GoUi.metric(GoTheme.PADDING_COMPACT), GoUi.metric(GoTheme.GAP_TINY))
	body.add_child(GoStyle.label(label, GoTheme.ROLE_BUTTON))
	var caption := GoStyle.label(note, GoTheme.ROLE_CAPTION)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(caption)
	return card


# ── ① Defaults as they come — the 80% the theme sets ──────────────────

func _shot_default() -> void:
	var page := await _stage("Default theme — panels at 80%")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "Card face at card_alpha (80). The stripes behind show through; the text stays sharp."))
	page.add_child(_filled(GoStyle.hud_panel(), "GoStyle.hud_panel()", "HUD dock at hud_alpha (80) — laid straight over the world."))
	page.add_child(GoStyle.alert("GoStyle.alert() follows card_alpha too — it is a container inside a card.", GoTheme.INFO))
	var pill := GoStyle.overlay_panel()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pill_text := GoStyle.label("overlay_panel()", GoTheme.ROLE_CAPTION)
	# 🛑 Turn wrapping off — under `SHRINK_BEGIN` the minimum width is the actual width, so text folds one character per line.
	pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(pill_text)
	page.add_child(pill)
	var notice := GoNotice.new()
	page.add_child(notice)
	notice.show_text("GoNotice at notice_alpha (80)", GoTheme.WARNING, 0.0)
	# 🔑 The surface (dialog) floats on its own layer — the stripes showing through behind the card is the point of this shot.
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


# ── ② Four steps side by side — what the value changes ────────────────

func _shot_levels() -> void:
	var page := await _stage("One card at four levels")
	for level: int in [100, 80, 55, 25]:
		page.add_child(_filled(GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, float(level) / 100.0),
			"alpha = %d%%" % level,
			"At 25% the stripes win and this line is hard to read — that is the floor, not a target."))
	await _save("alpha_levels")


# ── ③ Put the whole project back to solid colour ──────────────────────

func _shot_solid() -> void:
	GoUi.config.container_alpha = 1.0
	GoUi.refresh()
	var page := await _stage("container_alpha = 1.0 — opaque again")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "One setting turns every panel back to a solid colour. Nothing behind shows through."))
	page.add_child(_filled(GoStyle.hud_panel(), "GoStyle.hud_panel()", "Projects with busy worlds want this."))
	await _save("alpha_solid_100")
	GoUi.config.container_alpha = -1.0
	GoUi.refresh()


# ── ④ Is the rule the same on a light theme ───────────────────────────

func _shot_light() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)
	var page := await _stage("Light theme — same 80%")
	page.add_child(_filled(GoStyle.card(), "GoStyle.card()", "A light panel at 80% picks up the stripes as a tint; dark text still reads."))
	page.add_child(GoStyle.alert("Alert on the light theme.", GoTheme.DANGER))
	await _save("alpha_light_80")


# ── ⑤ Custom StyleBox themes — same rule on panels that are not flat ──
#
# 🛑 **This is where it breaks quietly.** The sci-fi cut panel (`GoStyleBoxCut`) and the medieval panel
#    (`GoStyleBoxMedieval`) are not `StyleBoxFlat` — they draw themselves in `_draw()`. Put alpha only on
#    the `StyleBoxFlat` branch and **nothing happens** in these themes, while the value checks still pass.

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
