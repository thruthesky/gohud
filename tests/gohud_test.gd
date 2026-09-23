## 🧪 gohud headless checks — they run on the add-on alone: no autoload, no server, no game.
##
## ```
## bash addons/gohud/tools/run_tests.sh                       # recommended — wall-clock limit and script-error verdict included
## godot --headless -s res://addons/gohud/tests/gohud_test.gd
## ```
##
## 🛑 A **parse error** in this file (or in a gohud script) never reaches `_initialize`, so there are 0 lines of
##    output and the process never ends — it looks "stuck" (measured 2026-09-12). Do not wait for it:
##    read the `SCRIPT ERROR` that `run_tests.sh` prints. If the right side of `:=` is a Variant (`dict.get()`,
##    an array element, …), **write the type out** — a failed inference is a parse error.
##
## 🛑 These checks must pass both **inside a host project** and in an **empty project** (`tools/new_project_check.sh`).
##    That is why expectations are computed from the viewport and safe area instead of written as fixed pixels.
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
	# Even if something waits forever somewhere, the checks have to finish.
	create_timer(150.0).timeout.connect(_on_watchdog)
	GoUi.reset()
	GoUi.config = GoConfig.new()
	# 🛑 The default `--headless` window is **64×64** and `root.size` does not grow it (measured 2026-09-12) —
	#    inside that, a card's minimum size is already bigger than the screen and every layout check fails falsely.
	#    Set the **stretch base size** to a phone portrait instead of the window and the logical viewport becomes that size.
	#    Expectations still do not hard-code this value — they are **computed from the real viewport and safe area**.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	# 🛑 **Check one screen only and the code that runs on the other screens goes entirely unchecked.**
	#    The form width cap was such a case — on a phone the cap is "none", so the rule never fired at all (iteration 15).
	#    Re-run the same checks at another size with `GOHUD_VIEWPORT=1280x800`.
	var wanted := Vector2i(390, 844)
	var asked := OS.get_environment("GOHUD_VIEWPORT")
	if asked.contains("x"):
		var parts := asked.split("x")
		wanted = Vector2i(maxi(200, int(parts[0])), maxi(200, int(parts[1])))
	root.content_scale_size = wanted
	await frames(2)
	# 🛑 The **host project** scales the UI on top of this: laryen3d's UiScale autoload sets
	#    `content_scale_factor` to 1.265, so a request for 844x390 came out as a 667x308 viewport and the size
	#    check failed for a reason outside gohud (measured 2026-09-23). The factor belongs to the host, but the
	#    stretch base is ours — ask for the base that lands on the wanted size under that factor.
	var factor := maxf(0.1, root.content_scale_factor)
	if not is_equal_approx(factor, 1.0):
		root.content_scale_size = Vector2i((Vector2(wanted) * factor).round())
		await frames(2)
	var view := root.get_visible_rect().size
	print("  viewport %s" % str(view))
	check(minf(view.x, view.y) >= 320.0, "test viewport is large enough (%s)" % str(view))
	await _section("back policy", _back_policy)
	await _section("tokens · themes", _tokens)
	await _section("presets · skins", _presets)
	await _section("medieval theme", _medieval)
	await _section("skin contrast", _skin_contrast)
	await _section("icon sets", _icons)
	await _section("localization", _i18n)
	await _section("text customisation", _text_customisation)
	await _section("scale functions", _scale)
	await _section("container alpha", _container_alpha)
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
	await _section("scroll drag", _scroll_drag)
	await _section("rtl", _rtl)
	await _section("standalone", _standalone)
	# 🛑 Leaving a lambda in a static variable can crash during shutdown — clear them before finishing.
	GoFeedback.sound_handler = Callable()
	GoFeedback.haptic_handler = Callable()
	GoUi.reset()
	print("gohud tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _on_watchdog() -> void:
	printerr("FAIL watchdog — did not finish within 150 seconds")
	quit(2)


func _section(title: String, body: Callable) -> void:
	var before := failures
	await body.call()
	print("  %s %s" % ["ok  " if failures == before else "FAIL", title])


# ── Back-button ownership ────────────────────────────────────────────

func _back_policy() -> void:
	var start := quit_on_go_back
	var baseline := GoBackPolicy.owners()
	GoBackPolicy.acquire(self)
	GoBackPolicy.acquire(self)
	check(not quit_on_go_back, "with a window open, Back does not quit the app")
	GoBackPolicy.release(self)
	check(not quit_on_go_back, "one owner left still blocks it")
	GoBackPolicy.release(self)
	check(GoBackPolicy.owners() == baseline, "the owner count is back where it started")
	if baseline == 0: check(quit_on_go_back == start, "when the last one lets go, the original value returns")


# ── Tokens · themes ──────────────────────────────────────────────────

func _tokens() -> void:
	var settings := GoUi.config
	check(GoUi.theme() == GoUi.DEFAULT_THEME, "with no config it is the default (dark) theme")
	check(GoUi.color(GoTheme.ACCENT) != Color.MAGENTA, "the accent token is there")
	check(GoUi.metric(GoTheme.TOUCH) == 48, "touch minimum 48")
	check(GoUi.metric(GoTheme.BUTTON_HEIGHT) == 52, "button height 52")
	check(GoUi.font_size(GoTheme.ROLE_TITLE) > GoUi.font_size(GoTheme.ROLE_BODY), "title > body")

	var colors: Dictionary[StringName, Color] = {GoTheme.ACCENT: Color.RED}
	settings.color_overrides = colors
	check(GoUi.color(GoTheme.ACCENT) == Color.RED, "color_overrides wins over the theme")
	settings.color_overrides.clear()
	var metrics: Dictionary[StringName, int] = {GoTheme.PADDING: 7}
	settings.metric_overrides = metrics
	check(GoUi.metric(GoTheme.PADDING) == 7, "metric_overrides")
	settings.metric_overrides.clear()
	settings.min_touch_size = 44
	check(GoUi.metric(GoTheme.TOUCH) == 44, "min_touch_size becomes the touch token")
	settings.min_touch_size = 48

	# A plain Theme with no tokens does not break anything.
	settings.theme = Theme.new()
	check(GoUi.color(GoTheme.SURFACE) == GoTheme.color_of(GoUi.DEFAULT_THEME, GoTheme.SURFACE), "a token-less Theme is filled in from the default tokens")
	settings.token_fallback = false
	check(GoUi.color(GoTheme.SURFACE) == Color.MAGENTA, "turning token_fallback off exposes the missing token")
	settings.token_fallback = true
	settings.theme = null

	var notified := [0]
	var watcher := func() -> void: notified[0] += 1
	GoUi.watch(watcher)
	settings.theme = GoUi.LIGHT_THEME
	check(int(notified[0]) >= 1, "changing the theme calls the watch callback")
	check(GoUi.color(GoTheme.BACKGROUND) != GoTheme.color_of(GoUi.DEFAULT_THEME, GoTheme.BACKGROUND), "the light theme background differs from the dark one")
	check(GoUi.color(GoTheme.TEXT).get_luminance() < 0.3, "light theme text is dark")
	var before: int = notified[0]
	GoUi.refresh()
	check(int(notified[0]) == before + 1, "GoUi.refresh() calls the callback")
	GoUi.unwatch(watcher)
	settings.theme = null

	# 🛑 With the `GoRuntime` autoload on, the shrink is already applied at boot (phone-sized viewport) —
	#    assuming "before the shrink" fails falsely. Set the baseline, then measure.
	GoUi.set_mobile_type(false)
	var body := GoUi.font_size(GoTheme.ROLE_BODY)
	GoUi.set_mobile_type(true)
	check(GoUi.font_size(GoTheme.ROLE_BODY) == body - 2, "mobile type shrinks by one step (%d → %d)" % [body, GoUi.font_size(GoTheme.ROLE_BODY)])
	check(GoUi.metric(GoTheme.TOUCH) == 48, "the mobile shrink leaves the touch size alone")
	GoUi.set_mobile_type(false)
	check(GoUi.font_size(GoTheme.ROLE_BODY) == body, "shrink released")


# ── Panel alpha (container transparency) ─────────────────────────────
#
# 🔑 The worth of this feature is **whether four layers stack in exactly the right order** — the theme is the
#    source of truth, the project config covers it, the per-kind config covers that, and the argument at the call
#    site wins last. One layer out of order and it becomes "why is my value ignored" — which the screen cannot tell you.
# 🛑 And **only panels may thin out** — let text, buttons, badges and quick slots thin along and the UI stops being readable.

func _container_alpha() -> void:
	var settings := GoUi.config
	var skin := GoUi.skin()

	# ── ① The theme is the source of truth ──────────────────────────────
	check(near(GoUi.surface_alpha(GoTheme.BOX_PANEL), 0.80, 0.001),
		"default theme: popup and sheet panels are 80%% (%.2f)" % GoUi.surface_alpha(GoTheme.BOX_PANEL))
	check(near(GoUi.surface_alpha(GoTheme.BOX_CARD), 0.80, 0.001)
		and near(GoUi.surface_alpha(GoTheme.BOX_HUD), 0.80, 0.001)
		and near(GoUi.surface_alpha(GoTheme.BOX_NOTICE), 0.80, 0.001),
		"card, HUD and notice panels are 80% too")
	# 🛑 Only the popup menu is solid — the engine may raise a `PopupMenu` as a window, and then it is not composited.
	check(near(GoUi.surface_alpha(GoTheme.BOX_POPUP), 1.0, 0.001), "the popup menu panel is solid by default")
	# An unknown kind follows the card rule — an unfamiliar panel neither vanishes nor jumps out.
	check(GoTheme.alpha_token(&"nonexistent") == GoTheme.CARD_ALPHA, "an unknown panel kind falls back to the card token")
	# The panel does not vanish even on a theme that knows no such token (missing means 100).
	check(near(float(GoTheme.metric_of(Theme.new(), GoTheme.PANEL_ALPHA, null, 100)), 100.0, 0.001),
		"a theme without the token falls back to 100 (solid) — the panel does not vanish")

	# ── ② The project-wide config covers the theme ──────────────────────
	settings.container_alpha = 0.50
	check(near(GoUi.surface_alpha(GoTheme.BOX_PANEL), 0.50, 0.001)
		and near(GoUi.surface_alpha(GoTheme.BOX_HUD), 0.50, 0.001),
		"container_alpha covers every panel kind at once")

	# ── ③ The per-kind config covers the project-wide one ───────────────
	settings.container_alpha_overrides = {GoTheme.BOX_HUD: 0.95}
	check(near(GoUi.surface_alpha(GoTheme.BOX_HUD), 0.95, 0.001)
		and near(GoUi.surface_alpha(GoTheme.BOX_PANEL), 0.50, 0.001),
		"the per-kind config wins over the project-wide one — only the named kind changes")
	# 🔑 A negative value means "not set" — it is passed down to the layer below (the same convention as the other fields).
	settings.container_alpha_overrides = {GoTheme.BOX_HUD: -1.0}
	check(near(GoUi.surface_alpha(GoTheme.BOX_HUD), 0.50, 0.001),
		"a negative in the per-kind config is skipped — the project-wide config takes over")
	# A metric override (a token of the same name) is a route too — for projects that keep every metric in one place.
	settings.container_alpha_overrides = {}
	settings.metric_overrides = {GoTheme.CARD_ALPHA: 30}
	check(near(GoUi.surface_alpha(GoTheme.BOX_CARD), 0.30, 0.001),
		"metric_overrides[card_alpha] is read as panel alpha as well")
	settings.metric_overrides = {}
	# Out-of-range values are clamped — one typo in the config must not make a panel vanish or be painted twice.
	settings.container_alpha_overrides = {GoTheme.BOX_CARD: 4.0}
	check(near(GoUi.surface_alpha(GoTheme.BOX_CARD), 1.0, 0.001), "a value above 1.0 is clamped to solid")
	settings.container_alpha_overrides = {}
	settings.container_alpha = -1.0

	# ── ④ Does it reach the panel · is it multiplied ────────────────────
	var solid := skin.surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0)
	var faded := skin.surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 0.5)
	var solid_a := GoSkin.box_background(solid).a
	check(near(GoSkin.box_background(faded).a, solid_a * 0.5, 0.01),
		"panel alpha **multiplies** the theme value — replacing it would erase the translucency the theme decided")
	# 🛑 Borders do not thin out — blur the outline and you cannot tell where the panel ends.
	var solid_flat := solid as StyleBoxFlat
	var faded_flat := faded as StyleBoxFlat
	check(solid_flat == null or faded_flat == null
		or near(faded_flat.border_color.a, solid_flat.border_color.a, 0.001),
		"only the fill thins out — the border keeps its strength")
	check(solid_flat == null or faded_flat == null
		or near(faded_flat.shadow_color.a, solid_flat.shadow_color.a, 0.001),
		"the shadow is unchanged too — the signal that it floats is not lost")
	# It is never applied twice — a panel vanishing under stacked `fade_box` calls is this feature's one trap.
	check(near(GoSkin.box_background(skin.floating_box(GoTheme.BOX_HUD, Color.TRANSPARENT, 0.5)).a,
		GoSkin.box_background(skin.floating_box(GoTheme.BOX_HUD, Color.TRANSPARENT, 1.0)).a * 0.5, 0.01),
		"a floating panel thins once as well (it goes through surface_box but is not multiplied twice)")

	# ── ⑤ Buttons and marks do not thin with it ─────────────────────────
	# 🔑 The yardstick is "is it **the same as before** the config changed" — a slot fill is the result of cooldown tint
	#    interpolation, so it cannot be measured against a fixed number (hard-code one and the check breaks on a skin with turned dials).
	var slot_before := GoSkin.box_background(skin.slot_box(GoUi.color(GoTheme.ACCENT), false)).a
	settings.container_alpha = 0.40
	check(near(GoSkin.box_background(skin.slot_box(GoUi.color(GoTheme.ACCENT), false)).a, slot_before, 0.01),
		"a quick slot does not follow panel alpha — it is a pressable cell and says its state with the cooldown tint")
	check(near(GoSkin.box_background(skin.segment_box(0, 2, &"normal")).a,
		GoSkin.box_background(skin.surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0)).a, 0.01),
		"a segmented choice (a button) does not follow panel alpha")
	check(near(GoSkin.box_background(skin.choice_box(&"normal")).a,
		GoSkin.box_background(skin.surface_box(GoTheme.BOX_CARD, Color.TRANSPARENT, 1.0)).a, 0.01),
		"a choice cell (a button) does not follow it either")
	var badge_alpha := GoSkin.box_background(skin.badge_box(GoUi.color(GoTheme.ACCENT))).a
	check(near(badge_alpha, 1.0, 0.01), "a badge does not follow — it is the mark that keeps two characters readable (%.2f)" % badge_alpha)
	# An alert box is a container — it follows. 🛑 It must be applied **after** the fill is overwritten with the tone colour, or the value is lost.
	check(near(GoSkin.box_background(skin.alert_box(GoUi.color(GoTheme.DANGER))).a, 0.40, 0.01),
		"an alert box follows because it is a container (it survives the fill being overwritten with the tone colour)")
	# The pill panel (over the map or world) follows too — the hard-coded 0.82 moved into a token.
	var pill := skin.overlay_box() as StyleBoxFlat
	check(pill == null or near(pill.bg_color.a, 0.40, 0.01), "the pill panel over artwork follows as well")
	settings.container_alpha = -1.0

	# ── ⑥ One widget on its own ─────────────────────────────────────────
	var window := GoSurface.new()
	root.add_child(window)
	await frames(1)
	var themed := GoSkin.box_background(window.card.get_theme_stylebox(&"panel")).a
	check(near(themed, 0.80, 0.02), "the surface card is drawn at the theme value (80%%) (%.2f)" % themed)
	window.alpha = 0.35
	await frames(1)
	check(near(GoSkin.box_background(window.card.get_theme_stylebox(&"panel")).a, 0.35, 0.02),
		"one surface at 35% — every other window is unchanged")
	# 🛑 Redrawn many times it still thins once (the original panel is recorded).
	window._on_ui_changed()
	window._on_ui_changed()
	await frames(1)
	check(near(GoSkin.box_background(window.card.get_theme_stylebox(&"panel")).a, 0.35, 0.02),
		"redrawing does not thin it further — it is recomputed from the original panel")
	window.alpha = 1.0
	await frames(1)
	check(not window.card.has_theme_stylebox_override(&"panel"),
		"back at 1.0 the panel override is removed — just as the theme variation drew it")
	window.queue_free()

	# The same rule is applied to somebody else's panel that already exists.
	var host := PanelContainer.new()
	root.add_child(host)
	await frames(1)
	var host_solid := GoSkin.box_background(host.get_theme_stylebox(&"panel")).a
	GoStyle.fade_panel(host, 0.5)
	check(near(GoSkin.box_background(host.get_theme_stylebox(&"panel")).a, host_solid * 0.5, 0.02),
		"fade_panel applies the same rule to a panel gohud did not build")
	GoStyle.fade_panel(host, 0.5)
	GoStyle.fade_panel(host, 0.5)
	check(near(GoSkin.box_background(host.get_theme_stylebox(&"panel")).a, host_solid * 0.5, 0.02),
		"calling fade_panel three times still thins it once")
	GoStyle.fade_panel(host, 1.0)
	check(not host.has_theme_stylebox_override(&"panel"), "fade_panel(1.0) removes the override")
	host.queue_free()

	# ── ⑦ Every widget's `alpha` field uses one unit ────────────────────
	# 🛑 The same name must mean the same unit. Let one widget take a percent and the caller has to memorise it per widget,
	#    and `drawer.alpha = 0.7` is clamped to **0** instead of "almost transparent" and the panel vanishes (it really did on 2026-09-16).
	#    So every field, the `@export`ed ones in the inspector included, is a ratio (0.0~1.0), and that is what is measured here.
	var dialogs_probe := GoDialogs.new()
	var drawer_probe := GoDrawer.new()
	var sheet_probe := GoSheet.new()
	root.add_child(dialogs_probe)
	root.add_child(drawer_probe)
	root.add_child(sheet_probe)
	await frames(2)
	for probe: Dictionary in [
		{"name": "GoDialogs", "node": dialogs_probe, "face": dialogs_probe._surface.card},
		{"name": "GoDrawer", "node": drawer_probe, "face": drawer_probe.panel},
		{"name": "GoSheet", "node": sheet_probe, "face": sheet_probe.surface.card},
	]:
		var node: Node = probe["node"]
		node.set(&"alpha", 0.45)
		await frames(1)
		var face: Control = probe["face"]
		check(near(GoSkin.box_background(face.get_theme_stylebox(&"panel")).a, 0.45, 0.02),
			"%s.alpha is a ratio — give it 0.45 and the panel fill is 0.45" % probe["name"])
		node.set(&"alpha", -1.0)
	dialogs_probe.queue_free()
	drawer_probe.queue_free()
	sheet_probe.queue_free()

	# ── ⑧ The per-call argument on cards and alert boxes ────────────────
	var loud_card := GoStyle.card(Color.TRANSPARENT, -1.0, -1.0, -1.0, 0.25)
	check(near(GoSkin.box_background(loud_card.get_theme_stylebox(&"panel")).a, 0.25, 0.02),
		"GoStyle.card(…, alpha) affects that one card only")
	# 🔑 **A card with no argument follows panel alpha too** (80% by default) — but it does not build a new panel.
	#    It reads the panel the theme variation (`GoCard`) draws and **multiplies the alpha only.** So if the host defined
	#    `GoCard` differently in its own theme, that definition wins on shape. The corners are measured alongside to confirm it.
	var plain_card := GoStyle.card()
	var card_ratio := GoUi.surface_alpha(GoTheme.BOX_CARD)
	var faded_face := plain_card.get_theme_stylebox(&"panel")
	# 🛑 Do not read the add-on theme directly — read **the panel the node actually receives**. If the host project
	#    defines `GoCard` differently in its own theme, that wins (as it really does in Laryen 3D),
	#    and the promise this check guards is exactly "that panel is used as-is". Remove the override and that panel appears.
	# 🛑 **In the tree, a frame later** — asked right after it is made, a node answers from the engine's default theme, and
	#    this check once matched `card()` recording that bare face (a project with no theme of its own, 2026-09-23).
	root.add_child(plain_card)
	await frames(1)
	plain_card.remove_theme_stylebox_override(&"panel")
	var base_face := plain_card.get_theme_stylebox(&"panel")
	var faded_fill := GoSkin.box_background(faded_face)
	var base_fill := GoSkin.box_background(base_face)
	check(faded_face != null and base_face != null
		and faded_face.get_class() == base_face.get_class()
		and near(faded_fill.r, base_fill.r, 0.01) and near(faded_fill.g, base_fill.g, 0.01)
		and near(faded_fill.b, base_fill.b, 0.01)
		and near(faded_fill.a, base_fill.a * card_ratio, 0.02),
		"card with no argument: panel kind and hue exactly as the theme gave them · only the fill thins to %.0f%%" % [card_ratio * 100.0])
	# 🛑 At 100% there must be **no override at all** — only a panel identical to the old one keeps projects that
	#    do not use alpha from noticing this change.
	GoUi.config.container_alpha = 1.0
	var solid_card := GoStyle.card()
	check(not solid_card.has_theme_stylebox_override(&"panel"),
		"a card at 100% alpha does not override the panel — it uses the host-defined GoCard variation as-is")
	GoUi.config.container_alpha = -1.0
	solid_card.queue_free()
	loud_card.queue_free()
	plain_card.queue_free()


# ── Look presets · skins ─────────────────────────────────────────────

func _presets() -> void:
	# ── Skin dials — change only the numbers in the resource ────────────
	# 🔑 Numbers that used to be hard-coded moved out to `@export` (2026-09-13). Whether those values reach the real
	#    panel, and whether the table the scaffolding uses (`tools/skin_dials.json`) matches the GDScript defaults, are both
	#    measured here — if the table drifts, a new theme's JSON is written out with the wrong defaults.
	var dialed := GoSkin.new()
	dialed.slot_border_lit = 3
	dialed.badge_pad_x = 9
	var dial_box := dialed.slot_box(Color.RED, true) as StyleBoxFlat
	check(dial_box != null and dial_box.border_width_top == 3, "the slot border dial reaches the panel (%s)"
		% (str(dial_box.border_width_top) if dial_box != null else "null"))
	check(int(dialed.badge_box(Color.RED).content_margin_left) == 9, "the badge padding dial reaches the panel")
	# The depth of a floating card is a dial too — a shadow (round panel) or a glow (cut panel).
	var lifted := GoSkin.new()
	lifted.float_shadow_size = 21
	lifted.float_shadow_lift = 6
	var lifted_box := lifted.floating_box(GoTheme.BOX_CARD) as StyleBoxFlat
	check(lifted_box != null and lifted_box.shadow_size == 21 and lifted_box.shadow_offset.y == 6.0,
		"the floating card's shadow dial reaches the panel (%s)" % (str(lifted_box.shadow_size) if lifted_box != null else "null"))
	# 🛑 The cut panel comes from the **theme** — build a skin instance alone and measure, and the default theme's round panel arrives with no glow field
	#    (it really failed that way). Switch the preset to sci-fi, measure, then switch back.
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	var glowing := GoSkinSciFi.new()
	glowing.float_glow_size = 13.0
	var glow_box := glowing.floating_box(GoTheme.BOX_HUD)
	check(&"glow_size" in glow_box and is_equal_approx(float(glow_box.get(&"glow_size")), 13.0),
		"a cut panel follows the glow dial while it floats (%s)" % (str(glow_box.get(&"glow_size")) if &"glow_size" in glow_box else "none"))
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.preset = &""
	var scifi_dialed := GoSkinSciFi.new()
	scifi_dialed.cut_slot = 9.0
	var cut_box := scifi_dialed.slot_box(Color.RED, false)
	check(&"cut" in cut_box and is_equal_approx(float(cut_box.get(&"cut")), 9.0), "the sci-fi cut-corner dial reaches the panel")
	# Store ZIPs omit tools/. The ZIP harness supplies the same fixture beside this
	# external test script, keeping the installed add-on identical to the shipped ZIP.
	var table_path := "res://addons/gohud/tools/skin_dials.json"
	if not FileAccess.file_exists(table_path):
		table_path = String(get_script().resource_path).get_base_dir().path_join("skin_dials.json")
	var table_text := FileAccess.get_file_as_string(table_path)
	var table: Variant = JSON.parse_string(table_text) if not table_text.is_empty() else null
	check(table is Dictionary, "tools/skin_dials.json is read")
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
		check(off.is_empty(), "the dial table matches the GDScript defaults %s" % str(off))

	# ── A preset dropped in the folder shows up with no code change ─────
	# 🛑 If adding a theme also meant editing a registry constant, that would not match the request to bring in more
	#    themes (2026-09-13). Dropping a `.tres` in the folder has to be the whole job, and this check is what keeps it so.
	var probe_dir := "user://gohud_presets_probe"
	DirAccess.make_dir_recursive_absolute(probe_dir)
	var probe := GoThemePreset.new()
	probe.id = &"probe_theme"
	probe.title = "Probe"
	probe.theme = GoUi.DEFAULT_THEME
	var saved := ResourceSaver.save(probe, probe_dir + "/probe_theme.tres")
	check(saved == OK, "a preset resource saves into a temporary folder")
	var seen := GoThemePresets.scan_folder(probe_dir)
	check(seen.has(&"probe_theme"), "a preset in the folder is found by its file name %s" % str(seen))
	# In an exported game a text resource may carry a `.remap` tail — that tail is stripped too.
	var remap := FileAccess.open(probe_dir + "/shipped.tres.remap", FileAccess.WRITE)
	if remap != null: remap.close()
	check(GoThemePresets.scan_folder(probe_dir).has(&"shipped"), "the .remap tail is stripped to get the name")
	DirAccess.remove_absolute(probe_dir + "/probe_theme.tres")
	DirAccess.remove_absolute(probe_dir + "/shipped.tres.remap")
	check(GoThemePresets.names().size() >= GoThemePresets.BUILTIN.size()
		and GoThemePresets.names()[0] == GoThemePresets.DEFAULT_DARK,
		"names() keeps the built-in order and appends the folder's presets %s" % str(GoThemePresets.names()))

	# 🛑 Below 4.6 this add-on **dies at the parse stage** — reaching this line already proves it passed, but
	#    recording the engine actually used in the log lets you ask later "which version did it pass on".
	var info := Engine.get_version_info()
	check(GoUi.engine_supported(), "engine %d.%d is at least %s — inside the supported range" % [
		info.major, info.minor, GoUi.min_engine_string()])

	var ids := GoThemePresets.ids()
	for wanted in [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT,
			GoThemePresets.SCIFI_DARK, GoThemePresets.SCIFI_LIGHT,
			GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		check(ids.has(wanted), "the preset is there — %s" % wanted)
	for preset in GoThemePresets.all():
		check(preset.theme != null and preset.skin != null and not preset.label().is_empty(),
			"%s: theme, skin and label are filled in" % preset.id)

	check(GoUi.skin() is GoSkin, "the default skin is GoSkin")
	var plain := GoUi.skin()
	check(GoUi.skin() == plain, "the default skin is not rebuilt every time")

	# 🛑 From here on the look is swapped — it must be put back at the end of the section.
	GoUi.use_preset(GoThemePresets.SCIFI_DARK)
	check(GoUi.theme() != GoUi.DEFAULT_THEME, "the theme switches to sci-fi")
	check(GoUi.skin() is GoSkinSciFi, "the skin switches to sci-fi")

	# A theme that changes shape hands out a **custom StyleBox** — that is what sets it apart from one that only changes colour.
	var panel := GoUi.box(GoTheme.BOX_PANEL)
	check(panel is GoStyleBoxCut, "the sci-fi panel is a cut panel (GoStyleBoxCut)")
	check((panel as GoStyleBoxCut).cut > 0.0, "the cut size is not 0")
	check(GoStyle.surface(GoTheme.BOX_PANEL) is GoStyleBoxCut, "GoStyle.surface() passes the custom shape straight through")
	# 🛑 The promise to older call sites — `box()` is a StyleBoxFlat on any theme.
	check(GoStyle.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "GoStyle.box() is a StyleBoxFlat on sci-fi too")
	# 🛑 Moving to a flat box still carries the panel's padding, colour and border over — an empty flat box (zero padding) glues the host card's text to the border
	#    (2026-09-15 Laryen look switch · every old `box()` call in the host takes this route).
	var cut_card := GoStyle.surface(GoTheme.BOX_CARD) as GoStyleBoxCut
	var flat_card := GoStyle.box(GoTheme.BOX_CARD)
	check(cut_card != null and flat_card.content_margin_left == cut_card.content_margin_left
		and flat_card.content_margin_top == cut_card.content_margin_top and flat_card.bg_color == cut_card.bg_color
		and flat_card.border_color == cut_card.border_color and flat_card.border_width_top == roundi(cut_card.border_width),
		"the GoStyle.box() flat box inherits the cut panel's padding, colour and border (padding %.0f / panel %.0f)" % [flat_card.content_margin_left, cut_card.content_margin_left if cut_card != null else -1.0])

	var missing: Array[StringName] = []
	for key in [GoTheme.BACKGROUND, GoTheme.SURFACE, GoTheme.SURFACE_SOFT, GoTheme.SURFACE_HIGH,
			GoTheme.BORDER, GoTheme.TEXT, GoTheme.SECONDARY, GoTheme.MUTED, GoTheme.ACCENT,
			GoTheme.ON_ACCENT, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER, GoTheme.INFO,
			GoTheme.SCRIM, GoTheme.SHADOW, GoTheme.TRACK]:
		if GoUi.color(key) == Color.MAGENTA: missing.append(key)
	check(missing.is_empty(), "the sci-fi theme has every colour token (missing: %s)" % str(missing))
	check(GoUi.metric(GoTheme.RADIUS) > 0 and GoUi.metric(GoTheme.PADDING) > 0, "sci-fi metric tokens")

	# Do the places the code draws itself really change shape as well
	var slot := GoSlot.new()
	root.add_child(slot)
	await frames(2)
	check(slot.get_node(^"Face").get_theme_stylebox(&"panel") is GoStyleBoxCut, "the quick slot panel switches to a cut panel")
	check(GoUi.skin().coach_ring_box(Color.CYAN) is GoStyleBoxBracket, "the coach-mark ring switches to corner brackets")
	check(GoStyle.chip("x").get_theme_stylebox(&"panel") is GoStyleBoxCut, "the chip switches to a cut panel")
	var pad := GoJoystick.new()
	root.add_child(pad)
	await frames(2)
	check(is_instance_valid(pad), "the joystick draws with the sci-fi skin")
	slot.queue_free()
	pad.queue_free()
	await frames(1)

	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	check(GoUi.theme() == GoUi.DEFAULT_THEME, "it returns to the default")
	check(GoUi.box(GoTheme.BOX_PANEL) is StyleBoxFlat, "the default panel is a flat box as before")
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


# ── Contrast of the colours the skin makes ───────────────────────────
#
# 🛑 `tools/check_contrast.py` reads theme `.tres` files only. The colours a skin makes **at run time**
#    (a chip's same-hue tint, the slot panel, the alert box) fall outside it and are caught only here.

func _skin_contrast() -> void:
	var tones := [GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER, GoTheme.INFO, GoTheme.SECONDARY]
	for preset in [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT,
			GoThemePresets.SCIFI_DARK, GoThemePresets.SCIFI_LIGHT,
			GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT]:
		GoUi.use_preset(preset)
		var skin := GoUi.skin()
		var under := GoSkin.blend(GoUi.color(GoTheme.SURFACE_SOFT), GoUi.color(GoTheme.BACKGROUND))
		# 🛑 **Keep it in an array.** A GDScript lambda **captures outer locals by value**, so writing
		#    `worst = value` inside the lambda never reaches the outside — and then this check passes no matter
		#    what it measures. It really did (2026-09-13: it stayed green with all three corrections removed).
		#    Arrays and dictionaries are captured by reference, so writes inside them are visible outside.
		var worst := [99.0, ""]

		var note := func(name: String, ink: Color, back: Color) -> void:
			var value := GoSkin.contrast_ratio(GoSkin.blend(ink, back), back)
			if value < worst[0]:
				worst[0] = value
				worst[1] = name

		for tone in tones:
			var ink: Color = GoUi.color(tone)
			# 🛑 Read from **a chip that was really built** — measuring the skin method alone never shows whether the widget uses that value.
			var chip := GoStyle.chip("42", ink)
			root.add_child(chip)
			await frames(1)
			var back := GoSkin.blend(GoSkin.box_background(chip.get_theme_stylebox(&"panel")), under)
			var label := chip.get_child(0) as Label
			note.call("chip %s" % tone, label.get_theme_color(&"font_color"), back)
			chip.queue_free()
			await frames(1)

		var accent := GoUi.color(GoTheme.ACCENT)
		# 🛑 Read **the font colour that is really drawn**. Measuring only what the skin method returns misses the case where
		#    the widget paints a fixed colour instead — the quantity on an empty slot did that (2026-09-13: 3.97:1 during cooldown).
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
				# Text inside a badge sits on the **badge panel** — not on the slot panel.
				var under_label := face
				var badge_panel := label.get_parent() as PanelContainer
				if badge_panel != null:
					under_label = GoSkin.blend(GoSkin.box_background(badge_panel.get_theme_stylebox(&"panel")), face)
				note.call("slot %s (quantity %d)" % [child, state["q"]],
					label.get_theme_color(&"font_color"), under_label)
			# 🛑 **Measure the icon too.** While only labels were measured, icons stayed pinned at `Color.WHITE`,
			#    and on a light theme a white potion sank entirely into a white panel (measured in the 2026-09-13 gallery).
			#    The colour drawn is the cell's `modulate` multiplied by the glyph's own `modulate`.
			var icon_slot := probe.get_node_or_null(^"Face/IconSlot") as Control
			# 🛑 While a cooldown runs the icon is **deliberately** pulled toward the panel colour — the information is then carried
			#    by the remaining-time badge above it, whose text is measured above. An inactive-state indicator is also a WCAG 1.4.3 exception.
			if state["cd"] <= 0.0 and icon_slot != null and icon_slot.get_child_count() > 0:
				var glyph := icon_slot.get_child(0) as CanvasItem
				note.call("slot icon (quantity %d)" % state["q"],
					icon_slot.modulate * glyph.modulate, face)
			probe.queue_free()
			await frames(1)

		# 🛑 **Glyphs that fall through to a child label.** A name with no texture (or a font icon set) is drawn inside the
		#    button as a Label, and the button theme's `icon_normal_color` never reaches a child —
		#    without setting the colour it turns white and sinks into the panel on a light theme.
		var glyph_button := GoIconButton.new()
		glyph_button.icon_name = &"no_such_icon_for_test"
		root.add_child(glyph_button)
		await frames(2)
		var glyph_label := glyph_button.get_node_or_null(^"Icon") as Label
		if glyph_label != null:
			note.call("icon button glyph", glyph_label.get_theme_color(&"font_color"),
				GoSkin.blend(GoSkin.box_background(glyph_button.get_theme_stylebox(&"normal")), under))
		glyph_button.queue_free()
		await frames(1)

		for tone in [GoTheme.INFO, GoTheme.SUCCESS, GoTheme.WARNING, GoTheme.DANGER]:
			var ink2: Color = GoUi.color(tone)
			var back2 := GoSkin.blend(GoSkin.box_background(skin.alert_box(ink2)), under)
			note.call("alert %s body" % tone, GoUi.color(GoTheme.TEXT), back2)

		# ── Bar fill ───────────────────────────────────────────────────────
		# 🛑 **Chase contrast with colour alone and you lose the colour.** Yellow is inherently high in luminance, so it
		#    never reaches 3:1 over any grey ground, and lowering its value to meet the bar turns the XP bar **brown**
		#    (on the light theme it really was `#A05000`). So **both** things are required —
		#    ① it must stand apart from the ground (where colour falls short, an outline stands in) ② the colour must not die.
		var track := GoSkin.blend(GoUi.color(GoTheme.TRACK), GoUi.color(GoTheme.SURFACE))
		for pair in [[GoTheme.SUCCESS_FILL, "success"], [GoTheme.WARNING_FILL, "warning"],
				[GoTheme.DANGER_FILL, "danger"], [GoTheme.INFO_FILL, "info"]]:
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
			check(seen >= 3.0, "%s: the %s bar stands apart from the ground (%.2f:1 — by colour or by outline)"
				% [preset, pair[1], seen])
			# Has it sunk into brown? Brown is saturated too, so it is measured by **value** (#A05000 is 0.63).
			check(fill.v >= 0.70, "%s: the %s bar colour has not died (value %.2f)"
				% [preset, pair[1], fill.v])

		check(worst[0] >= 4.5, "%s: the colours the skin makes clear the body contrast too (lowest %.2f:1 — %s)"
			% [preset, worst[0], worst[1]])
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	GoUi.config.preset = &""


# ── Icon sets ────────────────────────────────────────────────────────

func _icons() -> void:
	var icon_set := GoUi.icons()
	var names := icon_set.icon_names()
	check(names.size() == 84, "84 built-in icons (actually %d)" % names.size())
	var script: Script = load(ADDON + "/core/go_icon_set.gd")
	var constants := script.get_script_constant_map()
	var missing: Array = []
	for key in constants:
		var value: Variant = constants[key]
		if value is StringName and not icon_set.has_icon(value): missing.append(value)
	check(missing.is_empty(), "every GoIconSet name constant is in the built-in set %s" % str(missing))

	var close := icon_set.texture(GoIconSet.CLOSE)
	check(close != null, "the close texture")
	check(close is DPITexture, "built-in icons are DPITexture — they re-rasterise as the scale grows (%s)" % (close.get_class() if close != null else "null"))
	var drawn := icon_set.node(GoIconSet.SETTINGS, 20)
	check(drawn is TextureRect and drawn.custom_minimum_size == Vector2(20, 20), "node() — a texture set gives a TextureRect at the requested size")
	drawn.free()
	var unknown := icon_set.node(&"no_such_icon_for_test", 16)
	check(unknown is Label and unknown.custom_minimum_size == Vector2(16, 16), "an unknown name still takes up its space")
	unknown.free()

	var custom := GoIconSet.new()
	custom.fallback = icon_set
	var mine := PlaceholderTexture2D.new()
	mine.size = Vector2(24, 24)
	var textures: Dictionary[StringName, Texture2D] = {GoIconSet.CLOSE: mine}
	custom.textures = textures
	check(custom.texture(GoIconSet.CLOSE) == mine, "partial replacement — an overridden name gives the new texture")
	check(custom.texture(GoIconSet.SETTINGS) == icon_set.texture(GoIconSet.SETTINGS), "partial replacement — the rest come from the fallback set")
	check(custom.icon_names().size() == names.size(), "a partial set's name list includes the fallback")

	var font_set := GoIconSet.new()
	font_set.font = SystemFont.new()
	var points: Dictionary[StringName, int] = {GoIconSet.CLOSE: 0x78}
	font_set.codepoints = points
	var glyph := font_set.node(GoIconSet.CLOSE, 18)
	check(glyph is Label and (glyph as Label).text == "x", "icon font set — it draws the codepoint character")
	check(font_set.glyph_font(GoIconSet.CLOSE) != null and font_set.glyph(GoIconSet.CLOSE) == "x", "glyph()·glyph_font()")
	glyph.free()

	var first := GoIconSet.new()
	var second := GoIconSet.new()
	first.fallback = second
	second.fallback = first
	check(not first.has_icon(&"missing"), "a fallback cycle does not hang")
	first.fallback = null
	second.fallback = null

	GoUi.config.icons = custom
	check(GoUi.icons() == custom, "GoConfig.icons swaps the set")
	GoUi.config.icons = null
	check(GoUi.icons() == GoUi.DEFAULT_ICONS, "cleared, the built-in set returns")


# ── Translations ─────────────────────────────────────────────────────

func _i18n() -> void:
	var original := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(GoUi.text(&"close") == "Close", "en translation (%s)" % GoUi.text(&"close"))
	TranslationServer.set_locale("ko")
	check(GoUi.text(&"close") == "닫기", "ko translation (%s)" % GoUi.text(&"close"))
	TranslationServer.set_locale("ar")
	check(GoUi.text(&"cancel") == "إلغاء", "ar translation")
	TranslationServer.set_locale("ja")
	check(GoUi.text(&"confirm") == "確認", "ja translation")
	var overrides: Dictionary[StringName, String] = {&"close": "X"}
	GoUi.config.text_overrides = overrides
	check(GoUi.text(&"close") == "X", "text_overrides wins over the translation")
	GoUi.config.text_overrides.clear()
	check(GoUi.text_key(&"close") == "gohud_close", "text_key is the translation key")

	# 🛑 If a CSV column and `GoUi.LOCALES` drift apart, that one language quietly comes out in English **with no error**.
	#    The import builds the .translation files, but without an entry in LOCALES they are never registered.
	#    The other way round — in LOCALES with no CSV column — the file is missing and it passes silently. Both directions are checked.
	var header := ""
	var f := FileAccess.open(GoUi.BUILTIN_TRANSLATIONS, FileAccess.READ)
	if f != null:
		header = f.get_line()
		f.close()
	var columns := header.split(",")
	var csv_locales: Array[String] = []
	for i in range(1, columns.size()):
		csv_locales.append(columns[i].strip_edges())
	check(not csv_locales.is_empty(), "the CSV header was read (%d columns)" % csv_locales.size())
	for locale: String in csv_locales:
		check(GoUi.LOCALES.has(locale), "CSV column %s is in GoUi.LOCALES" % locale)
	for locale: String in GoUi.LOCALES:
		check(csv_locales.has(locale), "%s from GoUi.LOCALES has a CSV column" % locale)

	# For every declared language, check the text really **comes out** — a bare key means the .translation file is not attached.
	for locale: String in GoUi.LOCALES:
		TranslationServer.set_locale(locale)
		var got := tr("gohud_confirm")
		check(got != "gohud_confirm" and got != "", "text comes out in %s (%s)" % [locale, got])

	# Samples of the languages added on 2026-09-12 — a shifted column order is caught here (the slot fits, the content is wrong).
	TranslationServer.set_locale("tr")
	check(tr("gohud_cancel") == "İptal", "tr translation")
	TranslationServer.set_locale("th")
	check(tr("gohud_close") == "ปิด", "th translation")
	TranslationServer.set_locale("vi")
	check(tr("gohud_retry") == "Thử lại", "vi translation")
	TranslationServer.set_locale("id")
	check(tr("gohud_next") == "Berikutnya", "id translation")
	# 🛑 Traditional must be **Taiwanese vocabulary**, not converted Simplified — 搜尋, not 搜索 (mainland).
	TranslationServer.set_locale("zh_TW")
	check(tr("gohud_search") == "搜尋", "zh_TW uses Taiwanese vocabulary (%s)" % tr("gohud_search"))
	TranslationServer.set_locale("zh")
	check(tr("gohud_search") == "搜索", "zh uses mainland vocabulary (%s)" % tr("gohud_search"))
	TranslationServer.set_locale("he")
	check(tr("gohud_done") == "סיום", "he translation")

	TranslationServer.set_locale(original)


# ── Text customisation ───────────────────────────────────────────────

## 🛑 **The host must be able to change every word on screen.** If a widget hard-codes its text,
##    that one line stays gohud's forever — however much the project wants "Yes" instead of "Confirm",
##    however different its translation system, there is no way to touch it. This section closes that gap.
func _text_customisation() -> void:
	# ① The add-on proper (examples and checks excluded) carries **no literal that goes on screen**.
	#    A new widget writing `label.text = "Retry"` is caught right here.
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
	check(offenders.is_empty(), "no on-screen literal in the add-on proper (%s)" % ", ".join(offenders.slice(0, 3)))

	# ② **Every name** the config lists is covered by an override — one leak and that text cannot be changed.
	var names: Array = GoUi.config.text_keys.keys()
	check(names.size() >= 16, "%d text names" % names.size())
	var overrides: Dictionary[StringName, String] = {}
	for name: StringName in names:
		overrides[name] = "«%s»" % name
	GoUi.config.text_overrides = overrides
	var leaked: Array[String] = []
	for name: StringName in names:
		if GoUi.text(name) != "«%s»" % name:
			leaked.append(String(name))
	check(leaked.is_empty(), "every name is covered by text_overrides (%s)" % ", ".join(leaked))

	# ③ The widget really uses that value — a name that exists but goes unused passes ② while the screen never changes.
	var bar := GoBar.new()
	bar.readout = GoBar.Readout.FRACTION
	root.add_child(bar)
	bar.set_values(3.0, 10.0, false)
	await frames(1)
	var bar_line := _first_label_text(bar)
	check(bar_line.contains("«bar_fraction»"), "the GoBar fraction format goes through the config (%s)" % bar_line)
	bar.readout = GoBar.Readout.PERCENT
	await frames(1)
	check(_first_label_text(bar).contains("«bar_percent»"), "the GoBar percent format goes through the config")
	bar.queue_free()

	var slot := GoSlot.new()
	root.add_child(slot)
	slot.quantity = 3
	slot.refresh()
	await frames(1)
	check(_label_texts(slot).any(func(t: String) -> bool: return t.contains("«slot_quantity»")),
		"the GoSlot quantity format goes through the config")
	slot.queue_free()

	# ④ A format string survives **a vanished placeholder** — translators do drop `{value}`.
	var broken: Dictionary[StringName, String] = overrides.duplicate()
	broken[&"bar_fraction"] = "자리표시자 없음"
	GoUi.config.text_overrides = broken
	var safe := GoBar.new()
	safe.readout = GoBar.Readout.FRACTION
	root.add_child(safe)
	safe.set_values(3.0, 10.0, false)
	await frames(1)
	check(_first_label_text(safe) == "자리표시자 없음", "a missing placeholder does not kill the screen")
	safe.queue_free()

	# ⑤ Number abbreviation is replaced through a hook — for languages where **the arithmetic itself differs**, such as units of 10,000 and 100,000,000.
	GoUi.config.text_overrides = {}
	GoUi.config.number_formatter = func(amount: float) -> String: return "▲%d" % int(amount)
	check(GoBar.format_amount(12345.0) == "▲12345", "the number_formatter hook replaces the abbreviation (%s)"
		% GoBar.format_amount(12345.0))
	GoUi.config.number_formatter = Callable()
	check(GoBar.format_amount(12345.0) == "12.3k", "clearing the hook returns to the built-in rule (%s)"
		% GoBar.format_amount(12345.0))

	# ⑥ Changing the language changes assembled strings to the new format too (this spot never goes through the engine's automatic translation).
	#    Turkish puts the percent sign **in front** — which is why the format itself has to be translated.
	var before := TranslationServer.get_locale()
	var live := GoBar.new()
	live.readout = GoBar.Readout.PERCENT
	root.add_child(live)
	live.set_values(5.0, 10.0, false)
	TranslationServer.set_locale("en")
	await frames(1)
	check(_first_label_text(live) == "50%", "en percent (%s)" % _first_label_text(live))
	TranslationServer.set_locale("tr")
	await frames(1)
	check(_first_label_text(live) == "%50", "changing the language changes the percent format with it (%s)"
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


# ── Pure scale functions ─────────────────────────────────────────────

func _scale() -> void:
	check(GoScale.breakpoint_for_dp(360) == GoScale.Bp.MOBILE, "360dp is mobile")
	check(GoScale.breakpoint_for_dp(576) == GoScale.Bp.MOBILE, "the 576dp boundary is mobile")
	check(GoScale.breakpoint_for_dp(800) == GoScale.Bp.TABLET, "800dp is tablet")
	check(GoScale.breakpoint_for_dp(1200) == GoScale.Bp.DESKTOP, "1200dp is desktop")
	check(near(GoScale.display_scale(0.9, 300, Vector2i(720, 1600)), 1.875, 0.001), "a handheld goes by DPI — screen_get_scale 0.9 is not trusted")
	check(near(GoScale.display_scale(2.0, 144, Vector2i(3024, 1964)), 2.0, 0.001), "desktop goes by screen_get_scale")
	check(near(GoScale.display_scale(0.0, 192, Vector2i(3840, 2160)), 2.0, 0.001), "with screen_get_scale unimplemented (0) it is DPI/96")
	check(near(GoScale.gain_for(GoScale.Bp.MOBILE, true), 1.10, 0.001), "mobile readability gain 1.10")
	check(near(GoScale.gain_for(GoScale.Bp.DESKTOP, false), 1.0, 0.001), "desktop extra gain defaults to 1.0")
	var logical := GoScale.logical_size_for(Vector2i(720, 1600), 1.875, 1.10)
	check(near(logical.x, 349.09, 0.1), "logical width 349 on a 720px·300dpi phone (%.2f)" % logical.x)
	check(GoScale.form_width_for(GoScale.Bp.DESKTOP) == 480 and GoScale.form_width_for(GoScale.Bp.MOBILE) == 0, "form maximum width")


# ── Factory functions ────────────────────────────────────────────────

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
	check(normal.custom_minimum_size.y == 52, "a normal button's height = button_height")
	check(compact.custom_minimum_size.y == 48, "a compact button keeps the touch minimum too")
	check(primary.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON, "the primary button variation")
	check(normal.mouse_filter == Control.MOUSE_FILTER_PASS, "buttons are PASS — they do not block a scroll drag")
	# 🔑 The compact button padding contract — panel padding equals the token, and the audit really catches a zero-padding panel (positive control).
	var pad_x := float(GoUi.metric(GoTheme.COMPACT_PADDING_X))
	var pad_y := float(GoUi.metric(GoTheme.COMPACT_PADDING_Y))
	var compact_face := compact.get_theme_stylebox(&"normal")
	check(pad_x > 0.0 and pad_y > 0.0 and near(compact_face.get_margin(SIDE_LEFT), pad_x) and near(compact_face.get_margin(SIDE_RIGHT), pad_x)
		and near(compact_face.get_margin(SIDE_TOP), pad_y),
		"compact button panel padding = token (panel %.0f·%.0f · token %.0f·%.0f)" % [compact_face.get_margin(SIDE_LEFT), compact_face.get_margin(SIDE_TOP), pad_x, pad_y])
	check(GoStyle.audit_compact_padding(host).is_empty(), "compact buttons on the default theme keep the padding contract %s" % str(GoStyle.audit_compact_padding(host)))
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
		"the audit catches a zero-padding panel and skips a text-less icon button %s" % str(caught))
	check(GoStyle.audit_compact_padding(host).is_empty(), "an overridden panel is skipped by default (an intended exception)")
	glued.queue_free()
	glyph_only.queue_free()

	var row := GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "Name and avatar", false)
	host.add_child(row)
	await frames(3)
	check(row.custom_minimum_size.y >= 48, "a list row keeps the touch minimum")
	check(row.custom_minimum_size.y < 120, "given a width, a two-line row does not swell (%.0f)" % row.custom_minimum_size.y)
	var inset := row.get_child(0) as MarginContainer
	check(inset != null and row.custom_minimum_size.y >= inset.get_combined_minimum_size().y - 0.5, "the content, padding included, fits inside the row")
	var list_line := inset.get_child(0) as HBoxContainer
	var text_stack := list_line.get_child(1) as VBoxContainer
	var list_title := text_stack.get_child(0) as Label
	var description := text_stack.get_child(1) as Label
	var top := list_title.global_position.y - row.global_position.y
	var bottom := row.get_global_rect().end.y - description.get_global_rect().end.y
	check(top >= 8.0 and bottom >= 8.0 and near(top, bottom), "a two-line row keeps balanced padding above and below")
	# Even when the row takes the container's spare height, no gap is inserted between the lines of text.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	await frames(3)
	check(row.size.y > row.get_combined_minimum_size().y + 20.0, "the list alignment check really works on a stretched row")
	var text_center := (list_title.global_position.y + description.get_global_rect().end.y) * 0.5
	check(near(text_center, row.get_global_rect().get_center().y),
		"even on a stretched list row, title and summary stay vertically centred")
	check(near(list_title.size.y, list_title.get_combined_minimum_size().y)
		and near(description.size.y, description.get_combined_minimum_size().y)
		and description.global_position.y - list_title.get_global_rect().end.y <= 8.0,
		"title and summary keep their natural height and a short gap")
	row.size_flags_vertical = Control.SIZE_FILL
	description.text = "A longer description that wraps onto several lines without touching the row border."
	await frames(4)
	check(description.get_line_count() > 1, "the list padding check really works on a wrapped summary")
	top = list_title.global_position.y - row.global_position.y
	bottom = row.get_global_rect().end.y - description.get_global_rect().end.y
	check(top >= 8.0 and bottom >= 8.0 and near(top, bottom), "after wrapping, the row keeps its padding balanced above and below")

	var wrap := GoStyle.wrap_row(-1, FlowContainer.ALIGNMENT_CENTER, FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN)
	check(wrap is HFlowContainer and wrap.last_wrap_alignment == FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN, "flow row · last-line alignment")
	host.add_child(wrap)
	var flowing := GoStyle.button("Primary", Callable(), GoStyle.Tone.PRIMARY)
	wrap.add_child(flowing)
	GoStyle.form(host)   # applying the form rules must not take the natural width away
	await frames(1)
	check(flowing.autowrap_mode == TextServer.AUTOWRAP_OFF, "a button in a flow row does not wrap")
	check(flowing.get_combined_minimum_size().x > 48.0, "its natural width is as wide as its text — it does not split down the page (%.0f)" % flowing.get_combined_minimum_size().x)
	var fold := GoStyle.foldable("Advanced", true)
	check(fold is FoldableContainer and fold.title == "Advanced" and fold.folded, "a FoldableContainer section")
	fold.free()
	var chip := GoStyle.chip("new", GoUi.color(GoTheme.SUCCESS))
	check(chip.get_child_count() == 1, "a chip")
	chip.free()

	var grid := GoStyle.responsive_grid(150.0)
	root.add_child(grid)
	for i in 6:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(40, 20)
		grid.add_child(cell)
	await frames(1)
	# 🛑 The cells must **share the spare width**. `GridContainer` hands spare width only to children carrying
	#    `SIZE_EXPAND`, so left at the defaults a card folds to its content's minimum width (nearly 0 for a wrapping label) —
	#    the text ran down one character per line (measured 2026-09-13: cards 25px at every window width).
	check((grid.get_child(0) as Control).size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"grid cells share the spare width — a card does not fold to one character wide")

	# 🛑 Long text has to wrap. Without it one line stretches out and its minimum width runs past the screen.
	var wrapper := GoStyle.button("A fairly long button label that must wrap")
	check(wrapper.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"button text wraps — it does not stretch out in one line past the screen")
	wrapper.free()
	var long_label := GoStyle.label("A sentence long enough that it must wrap inside a narrow card")
	check(long_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"label text wraps — without it the minimum width runs past the screen and both sides are clipped")
	long_label.free()
	grid.size = Vector2(700, 0)
	await frames(1)
	check(grid.columns == 4, "responsive grid — 4 columns at width 700 with a 150 minimum (%d)" % grid.columns)
	grid.size = Vector2(320, 0)
	await frames(1)
	check(grid.columns == 2, "2 columns at width 320 (%d)" % grid.columns)
	grid.queue_free()
	host.queue_free()
	await frames(1)

	# ── 🏷 Brand button (external spec) · quiet tint · panel-less container · notice panel · mono text box · popup rows ───
	var brand_host := VBoxContainer.new()
	brand_host.size = Vector2(320, 600)
	root.add_child(brand_host)
	var brand := GoStyle.button("Continue with Example")
	brand_host.add_child(brand)
	var base_face := GoStyle.box(GoTheme.BOX_CARD)
	base_face.set_corner_radius_all(12)   # plant a recognisable value to see whether the shape is inherited
	GoStyle.style_brand_button(brand, Color.BLACK, Color.WHITE, Color(1, 1, 1, 0.35), 18, 12, 16.0, base_face)
	await frames(2)
	var brand_face := brand.get_theme_stylebox(&"normal") as StyleBoxFlat
	check(brand_face != null and brand_face.bg_color == Color.BLACK and brand_face.border_color == Color(1, 1, 1, 0.35)
		and brand_face.get_border_width(SIDE_LEFT) == 1,
		"brand button — panel colour and border are the caller's values exactly (not the skin palette)")
	check(brand_face.corner_radius_top_left == 12, "brand button — the shape (corner radius) is inherited from the panel passed in (%d)" % brand_face.corner_radius_top_left)
	check(near(brand_face.content_margin_left, 16.0) and near(brand_face.content_margin_right, 16.0)
		and near(brand_face.content_margin_top, 0.0),
		"brand button — side padding is the spec value, top and bottom are 0 (the caller sets the height)")
	check(brand.get_theme_constant(&"icon_max_width") == 18 and brand.get_theme_constant(&"h_separation") == 12,
		"brand button — mark size and spacing are exactly the values passed in")
	check(brand.get_theme_color(&"font_color") == Color.WHITE and brand.get_theme_color(&"icon_normal_color") == Color.WHITE,
		"brand button — the font colour is the spec value and the mark stays white (a four-colour official mark is not tinted by the theme)")
	check(brand.alignment == HORIZONTAL_ALIGNMENT_LEFT and brand.icon_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"🛑 brand button — mark and text are both left-aligned (icon_alignment = CENTER draws the mark on top of the text)")
	check((brand.get_theme_stylebox(&"hover") as StyleBoxFlat).bg_color.get_luminance() > Color.BLACK.get_luminance(),
		"a dark brand panel brightens on hover")
	var white_brand := GoStyle.button("Continue with Example")
	brand_host.add_child(white_brand)
	GoStyle.style_brand_button(white_brand, Color.WHITE, Color("1f1f1f"), Color("747775"), 24, 10, 12.0)
	check((white_brand.get_theme_stylebox(&"hover") as StyleBoxFlat).bg_color.get_luminance() < Color.WHITE.get_luminance(),
		"a light brand panel darkens on hover")
	check(not (white_brand.get_theme_stylebox(&"focus") as StyleBoxFlat).draw_center,
		"the focus panel draws no centre so the shared focus ring shows through")
	# Mark and text centred together — left padding = (width − mark − gap − text width) / 2, floored at the spec padding
	var brand_left := GoStyle.center_button_content(brand, 16.0)
	var brand_text := brand.get_theme_font(&"font").get_string_size(brand.atr(brand.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			brand.get_theme_font_size(&"font_size")).x
	var want_left := maxf(16.0, floorf((brand.size.x - 18.0 - 12.0 - brand_text) * 0.5))
	check(near(brand_left, want_left) and near(brand.get_theme_stylebox(&"normal").content_margin_left, want_left),
		"mark and text sit centred on the panel — left padding %.0f (expected %.0f · width %.0f)" % [brand_left, want_left, brand.size.x])
	check(near(brand.get_theme_stylebox(&"disabled").content_margin_left, want_left),
		"the centring goes into every state panel — the text does not jump when pressed")
	var narrow := GoStyle.button("Continue with a very long provider name indeed")
	root.add_child(narrow)
	GoStyle.style_brand_button(narrow, Color.WHITE, Color.BLACK, Color("747775"), 24, 10, 12.0)
	narrow.size = Vector2(120, 56)
	check(near(GoStyle.center_button_content(narrow, 12.0), 12.0), "however narrow, the padding never drops below the spec minimum")
	var unsized := GoStyle.button("Zero")
	check(GoStyle.center_button_content(unsized, 12.0) < 0.0, "while the width is still 0 it writes nothing")
	unsized.free()
	# 🛑 Bring the icon inside the panel padding — widen both sides together so the text never rides over the icon (the child-label route).
	# 🔑 The built-in set is textures and goes through `Button.icon`, so **a deliberately unknown name** is passed to take the child-label route
	#    (the route a host using a font set takes). The single "not in the icon set" warning line in the log is intended.
	var iconed := GoStyle.button("Log in with email")
	brand_host.add_child(iconed)
	GoStyle.apply_icon(iconed, &"gohud_test_no_such_icon", 24, GoUi.color(GoTheme.TEXT), 20.0)
	var iconed_glyph := iconed.get_node_or_null("IconGlyph") as Control
	check(iconed_glyph != null, "font set route — the icon attached as a child label (this verdict underpins the overlap check below)")
	if iconed_glyph != null:
		var iconed_face := iconed.get_theme_stylebox(&"normal")
		check(near(iconed_glyph.offset_left, 20.0), "the icon glyph comes inward by the panel padding (%.0f)" % iconed_glyph.offset_left)
		check(iconed_face.content_margin_left >= iconed_glyph.offset_right,
			"🛑 the text padding covers the icon's edge — on a narrow full-width button the text never rides over the icon (%.0f ≥ %.0f)"
				% [iconed_face.content_margin_left, iconed_glyph.offset_right])
		check(near(iconed_face.content_margin_left, iconed_face.content_margin_right),
			"both sides widen together — the text is still centred")
	# The quiet button — colour only, no panel
	var quiet := GoStyle.button("Terms", Callable(), GoStyle.Tone.BARE)
	brand_host.add_child(quiet)
	GoStyle.tint_button(quiet, GoUi.color(GoTheme.MUTED), GoUi.color(GoTheme.ACCENT))
	check(quiet.get_theme_color(&"font_color") == GoUi.color(GoTheme.MUTED)
		and quiet.get_theme_color(&"font_pressed_color") == GoUi.color(GoTheme.ACCENT)
		and quiet.get_theme_color(&"icon_hover_color") == GoUi.color(GoTheme.ACCENT),
		"quiet button — muted at rest, accent when pressed")
	var kept := GoStyle.button("Notice", Callable(), GoStyle.Tone.BARE)
	brand_host.add_child(kept)
	GoStyle.typography(kept, GoTheme.ROLE_CAPTION, GoUi.color(GoTheme.SECONDARY))
	GoStyle.tint_button(kept, Color.TRANSPARENT, GoUi.color(GoTheme.ACCENT))
	check(kept.get_theme_color(&"font_color") == GoUi.color(GoTheme.SECONDARY),
		"pass transparent and that colour is left alone — the resting colour typography gave stays")
	# A font size fixed by an external spec
	GoStyle.pin_font_size(brand, 18)
	check(brand.get_theme_font_size(&"font_size") == 18, "a spec font size is pinned in pixels")
	var rich := RichTextLabel.new()
	brand_host.add_child(rich)
	GoStyle.pin_font_size(rich, 13)
	check(rich.get_theme_font_size(&"normal_font_size") == 13 and rich.get_theme_font_size(&"bold_font_size") == 13,
		"RichTextLabel pins all four sizes together")
	# Panel-less container · notice panel
	var plain := PanelContainer.new()
	brand_host.add_child(plain)
	GoStyle.bare_panel(plain)
	check(plain.get_theme_stylebox(&"panel") is StyleBoxEmpty, "a container that draws no panel — the space stays, only the box goes")
	var notice_box := PanelContainer.new()
	brand_host.add_child(notice_box)
	GoStyle.style_notice_panel(notice_box, GoUi.color(GoTheme.DANGER), 0.14)
	var notice_face := notice_box.get_theme_stylebox(&"panel")
	var want_bg := (GoUi.color(GoTheme.BACKGROUND) as Color).lerp(GoUi.color(GoTheme.DANGER), 0.14)
	var got_bg := GoSkin.box_background(notice_face)
	# 🔑 **Hue and alpha are read separately** — which way it is tinted (colour) and how much shows through (alpha) are different decisions.
	check(notice_face != null and near(got_bg.r, want_bg.r, 0.01) and near(got_bg.g, want_bg.g, 0.01)
		and near(got_bg.b, want_bg.b, 0.01),
		"notice panel — the fill is pulled toward the tone colour (no new palette is invented)")
	check(near(got_bg.a, want_bg.a * GoUi.surface_alpha(GoTheme.BOX_NOTICE), 0.01),
		"notice panel — the alpha is the notice_alpha token (%.2f)" % GoUi.surface_alpha(GoTheme.BOX_NOTICE))
	var notice_solid := PanelContainer.new()
	brand_host.add_child(notice_solid)
	GoStyle.style_notice_panel(notice_solid, GoUi.color(GoTheme.DANGER), 0.14, -1, 1.0)
	check(near(GoSkin.box_background(notice_solid.get_theme_stylebox(&"panel")).a, want_bg.a, 0.01),
		"notice panel — give the alpha directly and that value stands")
	check(near(notice_face.content_margin_left, float(GoUi.metric(GoTheme.PADDING_COMPACT))),
		"notice panel padding = the padding_compact token (%.0f)" % notice_face.content_margin_left)
	# Monospace text box
	var code := RichTextLabel.new()
	brand_host.add_child(code)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace"])
	GoStyle.style_mono_text(code, mono, Color(0, 0.5, 1, 0.35), Color.WHITE)
	check(code.get_theme_font(&"normal_font") == mono, "mono text box — it uses the caller's font (gohud ships no fonts)")
	check(code.get_theme_color(&"selection_color") == Color(0, 0.5, 1, 0.35)
		and code.get_theme_color(&"font_selected_color") == Color.WHITE,
		"selection colours — so light text does not sink into the default light grey")
	# Popup row spacing
	var menu := GoStyle.dropdown("Menu", ["One", "Two"])
	brand_host.add_child(menu)
	GoStyle.style_popup(menu.get_popup())
	check(menu.get_popup().get_theme_constant(&"v_separation") == GoUi.metric(GoTheme.GAP),
		"popup row spacing = the gap token — items are never thinner than a finger")
	menu.get_popup().clear()
	menu.get_popup().add_item("Three")
	check(menu.get_popup().get_theme_constant(&"v_separation") == GoUi.metric(GoTheme.GAP),
		"clearing and refilling the items keeps the row spacing")

	# 🔑 HUD geometry — spacings and insets that no token expresses are given as values.
	var overlap := GridContainer.new()
	GoStyle.spacing(overlap, -8, 0)
	check(overlap.get_theme_constant(&"h_separation") == -8 and overlap.get_theme_constant(&"v_separation") == 0,
		"spacing: it takes a **negative gap** that overlaps touch boxes, and 0, exactly as given")
	var stack := GoStyle.column()
	GoStyle.spacing(stack, 0)
	check(stack.get_theme_constant(&"separation") == 0, "spacing: a vertical box uses the single separation constant")
	var edge := MarginContainer.new()
	GoStyle.edge_insets(edge, 12, -1, -1, 4)
	check(edge.get_theme_constant(&"margin_left") == 12 and edge.get_theme_constant(&"margin_bottom") == 4
		and not edge.has_theme_constant_override(&"margin_top"),
		"edge_insets: only the sides given change; sides passed negative are left alone")

	# 🔑 The HUD disc — no centre drawn, radius half the diameter. A fixed radius turns a differently sized button into a pill.
	var orb := Panel.new()
	GoStyle.style_hud_disc(orb, 36.0)
	var orb_face := orb.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(orb_face != null and orb_face.corner_radius_top_left == 18 and not orb_face.draw_center
		and orb_face.border_width_left == 0 and orb_face.shadow_size == 0
		and near(orb_face.get_margin(SIDE_LEFT), 0.0),
		"style_hud_disc: radius = half the diameter · no centre, border or shadow · zero padding")
	GoStyle.style_hud_disc(orb, 40.0, 2.0, Color.RED, Color(0, 0, 1, 1), 8)
	var lit_face := orb.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(lit_face != null and lit_face.corner_radius_top_left == 20 and lit_face.border_width_left == 2
		and lit_face.border_color.is_equal_approx(Color.RED) and lit_face.draw_center
		and lit_face.corner_detail == 8,
		"style_hud_disc: border colour and width · given a fill it draws the centre · the curve detail can be raised")

	# 🔑 The quick slot panel — the skin decides the shape (a host that built its own slot gets the same panel).
	var slot_face_host := Panel.new()
	GoStyle.style_slot_face(slot_face_host, GoUi.color(GoTheme.DANGER), true)
	var slot_lit := slot_face_host.get_theme_stylebox(&"panel")
	GoStyle.style_slot_face(slot_face_host, GoUi.color(GoTheme.DANGER), false)
	var slot_idle := slot_face_host.get_theme_stylebox(&"panel")
	# 🛑 Some skins hand out custom panels (cut, medieval), so the width is compared only where a width field exists.
	var slot_thicker := slot_lit != null and slot_idle != null
	if slot_thicker and slot_lit is StyleBoxFlat and slot_idle is StyleBoxFlat:
		slot_thicker = (slot_lit as StyleBoxFlat).border_width_left > (slot_idle as StyleBoxFlat).border_width_left
	check(slot_thicker, "style_slot_face: the skin's slot panel · while lit the border is thicker")

	# 🔑 The filled badge — a count has to stand out (a different job from the pale `GoSkin.badge_box`).
	var count := GoStyle.label("9")
	GoStyle.style_count_badge(count, GoUi.color(GoTheme.WARNING), GoUi.color(GoTheme.ON_ACCENT),
		GoUi.color(GoTheme.ON_ACCENT), 2, 10, 4.0)
	var count_face := count.get_theme_stylebox(&"normal") as StyleBoxFlat
	check(count_face != null and count_face.bg_color.is_equal_approx(GoUi.color(GoTheme.WARNING))
		and count_face.draw_center and count_face.corner_radius_top_left == 10
		and count_face.border_width_left == 2 and near(count_face.get_margin(SIDE_LEFT), 4.0)
		and count.get_theme_color(&"font_color").is_equal_approx(GoUi.color(GoTheme.ON_ACCENT)),
		"style_count_badge: **filled** with the tone colour, a contrasting border · side padding · font colour")

	# 🔑 Only the glyph's size and colour are re-applied — on a button, pressed, hover and focus must share that colour or it jumps.
	var glyph_host := Button.new()
	GoStyle.glyph_type(glyph_host, 22, Color.AQUA)
	check(glyph_host.get_theme_font_size(&"font_size") == 22
		and glyph_host.get_theme_color(&"font_color").is_equal_approx(Color.AQUA)
		and glyph_host.get_theme_color(&"font_hover_pressed_color").is_equal_approx(Color.AQUA),
		"glyph_type: size and colour · on a button the state font colours match too")
	GoStyle.glyph_type(glyph_host, -1, Color.TRANSPARENT)
	check(glyph_host.get_theme_font_size(&"font_size") == 22,
		"glyph_type: a negative size is left alone (on a HUD the caller sets the geometry)")
	for node: Node in [overlap, stack, edge, orb, slot_face_host, count, glyph_host]: node.queue_free()

	narrow.queue_free()
	brand_host.queue_free()
	await frames(1)


# ── Icon button ──────────────────────────────────────────────────────

func _icon_button() -> void:
	var mark := GoStyle.icon_button(GoIconSet.CLOSE)
	mark.tooltip_text_name = &"close"
	root.add_child(mark)
	await frames(2)
	var visual := mark.size.x
	check(near(visual, 36.0), "visible size 36 (%.1f)" % visual)
	var reach := (48.0 - visual) * 0.5
	check(mark._has_point(Vector2(-reach + 0.5, visual * 0.5)), "the touch area widens out to 48")
	check(not mark._has_point(Vector2(-reach - 1.5, visual * 0.5)), "beyond 48 nothing is taken")
	check(mark.icon is DPITexture, "a texture set → Button.icon")
	var cap := mark.get_theme_constant(&"icon_max_width")
	check(cap > 0 and cap < int(visual), "icon_max_width caps the glyph size (%d)" % cap)
	TranslationServer.set_locale("en")
	mark.notification(NOTIFICATION_TRANSLATION_CHANGED)
	check(mark.accessibility_name == "Close", "accessibility name = the tooltip text (%s)" % mark.accessibility_name)
	check(mark.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER and mark.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER, "a texture icon is centre-aligned (Button defaults to the left)")
	mark.native_texture_size = true
	check(not mark.expand_icon and not mark.has_theme_constant_override(&"icon_max_width") and mark.icon is DPITexture, "native_texture_size: no stretching, and icon_max_width is released too")
	mark.native_texture_size = false
	check(mark.expand_icon and mark.get_theme_constant(&"icon_max_width") == cap, "turn native_texture_size off and it is capped back to the glyph size")
	mark.queue_free()
	await frames(1)


# ── Surface ──────────────────────────────────────────────────────────

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
	check(GoSurface.is_any_open(), "a surface is open")
	check(GoBackPolicy.owners() == baseline + 2, "each surface owns the back button (%d)" % GoBackPolicy.owners())
	check(b.is_top() and not a.is_top(), "the surface on the higher layer is topmost")

	var closes := [0, 0]
	a.close_requested.connect(func() -> void: closes[0] += 1)
	b.close_requested.connect(func() -> void: closes[1] += 1)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	a._input(cancel)
	b._input(cancel)
	check(int(closes[0]) == 0 and int(closes[1]) == 1, "one Escape closes only the topmost window")
	b.hide()
	await frames(1)
	check(a.is_top(), "when the upper window hides, the lower one becomes topmost")

	var view := a.get_viewport_rect().size
	check(a.card.size.x <= GoUi.config.surface_max_width + 0.5, "card maximum width")
	check(a.card.position.x >= -0.5 and a.card.get_global_rect().end.x <= view.x + 0.5,
		"the card is on screen (pos %s size %s view %s)" % [str(a.card.position), str(a.card.size), str(view)])
	check(near(a.close_button.size.x, GoUi.config.close_button_visual), "the close button's visible size")
	check(a.back_button.autowrap_mode == TextServer.AUTOWRAP_OFF, "the back button does not wrap (no empty pill)")

	a.body.add_child(GoStyle.label("short"))
	await frames(3)
	var short_height := a.card.size.y
	for i in 40:
		a.body.add_child(GoStyle.list_button(GoIconSet.BOX, "Row %d" % i, Callable(), Color.TRANSPARENT, "", false))
	await frames(4)
	var area := GoSafeArea.usable_rect(a.get_window())
	check(a.card.size.y > short_height, "as the content grows the card grows (%.0f → %.0f)" % [short_height, a.card.size.y])
	# 🔑 A centred card with `fit_content` grows **past the default ratio** until the content fits — scroll the body
	#    while screen space remains and a user who never notices the scroll submits with the unseen fields left empty.
	check(a.card.size.y > area.size.y * GoUi.config.surface_height_ratio,
		"with plenty of content it grows past the default ratio (%d%%) (%.0f > %.0f)"
			% [roundi(GoUi.config.surface_height_ratio * 100), a.card.size.y, area.size.y * GoUi.config.surface_height_ratio])
	check(a.card.size.y <= area.size.y * GoUi.config.surface_fit_max_height_ratio + 1.0,
		"height cap %d%% (%.0f ≤ %.0f)" % [roundi(GoUi.config.surface_fit_max_height_ratio * 100),
			a.card.size.y, area.size.y * GoUi.config.surface_fit_max_height_ratio])
	# 🛑 Even then it **never covers the whole screen** — the outside has to show above and below for it to read as a "floating window".
	check(a.card.size.y < area.size.y, "the card does not cover the whole screen (%.0f < %.0f)" % [a.card.size.y, area.size.y])
	# On a drag-resizable sheet the height is the user's choice — overflowing content does not stretch it.
	a.resizable = true
	a.relayout()
	check(a.card.size.y <= area.size.y * GoUi.config.surface_max_height_ratio + 1.0,
		"a draggable sheet keeps the default cap (%.0f)" % a.card.size.y)
	a.resizable = false
	a.relayout()
	# 🛑 Card size and position are integers — with a fractional centred position the size is stored as "position + size", 184 becomes 183.99997,
	#    the inner MarginContainer rounds the child size down and the body ended up 1px short (a scrollbar beside a one-line body · measured on a 2026-09-15 Laryen
	#    phone-portrait window — it did not reproduce at headless logical sizes). An odd cap is applied only while judging, to force a fractional position.
	var saved_max_height := a.max_height
	var saved_max_width := a.max_width
	a.max_height = 301.0
	a.max_width = 301.0
	a.relayout()
	check(a.card.size == a.card.size.round() and a.card.position == a.card.position.round(),
		"card size and position are integers (pos %s size %s)" % [str(a.card.position), str(a.card.size)])
	a.max_height = saved_max_height
	a.max_width = saved_max_width
	a.relayout()

	var desired := a._desired_height()
	a.toolbar.add_child(GoStyle.line_edit("search"))
	a.toolbar.visible = true
	await frames(1)
	check(a._desired_height() > desired + 40.0, "the pinned toolbar row counts into the desired height too (%.0f → %.0f)" % [desired, a._desired_height()])

	# ── Pinned status row — "the passwords do not match" never hides off-scroll ───
	check(not a.status.visible and a.status_label == null, "the status row is hidden by default · the node does not exist either")
	var status_desired := a._desired_height()
	a.set_status_text("오류가 있습니다", GoTheme.DANGER)
	await frames(1)
	check(a.status.visible and a.status_label != null and a.status_label.text == "오류가 있습니다",
		"the status row appears")
	check(not a.scroll.is_ancestor_of(a.status_label),
		"🛑 the status row is pinned **outside** the scroll — on a long form an error off screen looks like nothing happened")
	# **Below** the body (the scroll) and **above** the footer. 🛑 The position is measured by **order** in the card's column — the scroll box
	#    pushes its bounds outward so the glow is not clipped (`use_panel_edge`), and measured as rectangles they look overlapped.
	a.footer.visible = true
	await frames(1)
	var order := func(node: Control) -> int:
		var ancestor := node
		while ancestor != null and ancestor.get_parent() != a._column:
			ancestor = ancestor.get_parent() as Control
		return -1 if ancestor == null else ancestor.get_index()
	check(order.call(a.status) > order.call(a.scroll) and order.call(a.status) < order.call(a.footer),
		"the status row sits between the body and the footer (body %d · status %d · footer %d)"
			% [order.call(a.scroll), order.call(a.status), order.call(a.footer)])
	check(a.status_label.get_global_rect().end.y <= a.footer.get_global_rect().position.y + 1.0,
		"the status row does not cover the footer buttons")
	check(a._desired_height() > status_desired, "the status row counts into the desired height too (%.0f → %.0f)"
		% [status_desired, a._desired_height()])
	check(a.status_label.get_theme_color(&"font_color") == GoUi.color(GoTheme.DANGER), "the status row's colour token")
	a.set_status_key("close")
	await frames(1)
	check(a.status_label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_ALWAYS, "it can be raised with a translation key too")
	a.clear_status()
	await frames(1)
	check(not a.status.visible, "the status row hides")

	# ── Reveal — it takes you to the field that errored ─────────────────
	var deep := GoStyle.line_edit("deep")
	a.body.add_child(deep)
	await frames(3)
	a.scroll.scroll_vertical = 0
	await frames(1)
	await a.scroll.reveal(deep)
	await frames(1)
	var seen := a.scroll.get_global_rect().intersection(deep.get_global_rect())
	check(seen.size.y >= deep.size.y - 1.0, "a field outside the scroll is revealed (visible %.0f/%.0f)" % [seen.size.y, deep.size.y])
	deep.queue_free()

	a.placement = GoSurface.Placement.BOTTOM
	a.relayout()
	var edge := minf(float(GoUi.metric(GoTheme.SCREEN_MARGIN)), minf(area.size.x, area.size.y) * 0.1)
	check(near(a.card.get_global_rect().end.y, area.end.y - edge, 1.5), "BOTTOM sticks to the bottom edge")

	var anchor := Button.new()
	anchor.position = Vector2(40, 40)
	anchor.size = Vector2(80, 40)
	root.add_child(anchor)
	a.placement = GoSurface.Placement.ANCHOR
	a.anchor_control = anchor
	a.relayout()
	check(a.card.position.y >= anchor.get_global_rect().end.y,
		"ANCHOR attaches below its target (card y %.0f · anchor end %.0f)" % [a.card.position.y, anchor.get_global_rect().end.y])

	a.hide()
	await frames(1)
	check(not GoSurface.is_any_open(), "hide them all and 0 surfaces are open")
	check(GoBackPolicy.owners() == baseline, "the back-button ownership is handed back")
	low.queue_free()
	high.queue_free()
	anchor.queue_free()
	await frames(2)


# ── Sheet ────────────────────────────────────────────────────────────

func _sheet() -> void:
	GoUi.config.dismiss_on_scrim = true
	var sheet := GoSheet.new()
	sheet.dismissable = false
	root.add_child(sheet)
	await frames(2)
	check(not sheet.surface.dismiss_on_scrim, "an explicit dismissable=false is not overwritten by the config default (true)")
	GoUi.config.dismiss_on_scrim = false

	sheet.open("Bag")
	await frames(1)
	check(sheet.visible and sheet.surface.placement == GoSurface.Placement.BOTTOM, "a sheet comes up from the bottom")
	sheet.set_back(func() -> void: pass)
	check(sheet.surface.back_button.visible, "set_back gives a back button")
	sheet.toolbar().add_child(GoStyle.line_edit("Search"))
	sheet.toolbar().visible = true
	var kept := Label.new()                      # a spot the whole sheet uses (a snackbar and such) — footer().add_child
	sheet.footer().add_child(kept)
	var page_close := sheet.add_footer(GoStyle.button("Close", sheet.close, GoStyle.Tone.PRIMARY))
	check(sheet.footer().visible and page_close.get_parent() == sheet.footer(), "add_footer() puts it in the footer and switches the footer on")
	sheet.open("Other")
	check(not sheet.surface.back_button.visible, "open() switches off the previous page's back button")
	check(not sheet.toolbar().visible and sheet.toolbar().get_child_count() == 0, "open() empties the pinned toolbar row and switches it off")
	# 🛑 Only the page's own buttons are cleared — merely switching off piled buttons up on screens that add a Close per page (2026-09-15),
	#    while emptying it wholesale would take away a snackbar that is added once and kept.
	check(not sheet.footer().visible and page_close.get_parent() == null and kept.get_parent() == sheet.footer(),
		"open() removes only what add_footer() added and keeps nodes added with footer().add_child() (%d children)"
		% sheet.footer().get_child_count())
	sheet.add_footer(GoStyle.button("Close", sheet.close))
	sheet.open("Third")
	check(sheet.footer().get_child_count() == 1,
		"opening page after page does not pile up footer buttons (%d children)" % sheet.footer().get_child_count())
	var closed := [false]
	sheet.closed.connect(func() -> void: closed[0] = true)
	sheet.close()
	check(bool(closed[0]) and not sheet.visible, "close()")
	sheet.queue_free()
	await frames(2)


# ── Confirm · alert dialogs ──────────────────────────────────────────

func _dialogs() -> void:
	var dialogs := GoDialogs.new()
	root.add_child(dialogs)
	await frames(2)

	# 🪟 Container alpha — this field is an `@export`, so a **percent**, while the surface takes a **ratio**.
	# 🛑 A wrong conversion between the two units breaks quietly (80 becomes 8000% or 0.8 becomes 0) —
	#    on screen it only looks "a bit darker", which is hard to notice. So both directions are measured.
	check(dialogs.alpha < 0.0 and dialogs._surface.alpha < 0.0,
		"dialog: alpha defaults to 'the theme value as-is' (negative)")
	dialogs.alpha = 0.90
	check(near(dialogs._surface.alpha, 0.90, 0.001),
		"dialog: the card alpha reaches the surface unchanged (%.2f)" % dialogs._surface.alpha)
	await frames(1)
	check(near(GoSkin.box_background(dialogs._surface.card.get_theme_stylebox(&"panel")).a, 0.90, 0.02),
		"dialog: that value reaches the real panel")
	dialogs.alpha = -1.0
	await frames(1)
	check(near(GoSkin.box_background(dialogs._surface.card.get_theme_stylebox(&"panel")).a,
		GoUi.surface_alpha(GoTheme.BOX_PANEL), 0.02),
		"dialog: back at a negative it returns to the theme and config value")

	var seen := [""]
	create_timer(0.05).timeout.connect(func() -> void:
		seen[0] = dialogs._body.text
		dialogs._ok.pressed.emit())
	var yes: bool = await dialogs.confirm("Delete", "Delete \"{name}\"?", "", "", "", {"name": "Aria"})
	check(yes, "confirm → OK")
	check(str(seen[0]) == "Delete \"Aria\"?", "args fill in {name} (%s)" % str(seen[0]))
	# 🛑 **The title takes the same args** — filling the body alone left `Drop {item}?` showing literally (2026-09-15).
	var titled := ["", -1]
	var read_title := func() -> void:
		titled[0] = dialogs._surface.title_label.text
		titled[1] = dialogs._surface.title_label.auto_translate_mode
		dialogs._ok.pressed.emit()
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm("Drop {item}?", "Drop {count} × {item}?", "", "", "", {"item": "Potion", "count": 3})
	check(str(titled[0]) == "Drop Potion?", "args fill in the title's {item} too (%s)" % str(titled[0]))
	var probe_locale := TranslationServer.get_locale()
	var drop := Translation.new()
	drop.locale = "xx"
	drop.add_message("probe_drop_title", "Drop {item}?")
	TranslationServer.add_translation(drop)
	TranslationServer.set_locale("xx")
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm_key("probe_drop_title", "probe_drop_body", "", "", "", {"item": "Potion"})
	check(str(titled[0]) == "Drop Potion?", "a translation-key title is translated first, then filled with args (%s)" % str(titled[0]))
	create_timer(0.05).timeout.connect(read_title)
	await dialogs.confirm_key("probe_drop_title", "probe_drop_body")
	check(str(titled[0]) == "probe_drop_title" and int(titled[1]) == Node.AUTO_TRANSLATE_MODE_ALWAYS,
		"with no args a key title keeps the key and is auto-translated as before (%s · mode %d)" % [str(titled[0]), int(titled[1])])
	TranslationServer.set_locale(probe_locale)
	TranslationServer.remove_translation(drop)
	check(dialogs._ok.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON,
		"an ordinary confirm uses the accent button (%s)" % dialogs._ok.theme_type_variation)

	# 🛑 **For an irreversible action the colour has to speak first.** A pale danger button was not enough — with a pale
	#    panel the text must be pushed very dark to stay readable (`#9B2626` on the light theme) and ends up simply black.
	#    A filled danger button reaches 5.7:1 with white text.
	create_timer(0.05).timeout.connect(func() -> void: dialogs._ok.pressed.emit())
	var removed: bool = await dialogs.confirm("Delete", "Sure?", "", "", "", {}, true)
	check(removed and dialogs._ok.theme_type_variation == GoTheme.VAR_DANGER_SOLID_BUTTON,
		"when destructive, the confirm button is filled danger (%s)" % dialogs._ok.theme_type_variation)
	# 🛑 A single window is **reused** — without putting it back, the next ordinary confirm comes up red as well.
	create_timer(0.05).timeout.connect(func() -> void: dialogs._ok.pressed.emit())
	await dialogs.confirm("Save", "Save now?")
	check(dialogs._ok.theme_type_variation == GoTheme.VAR_PRIMARY_BUTTON,
		"the next confirm returns to the accent colour (%s)" % dialogs._ok.theme_type_variation)

	create_timer(0.05).timeout.connect(func() -> void: dialogs._cancel.pressed.emit())
	var no: bool = await dialogs.confirm("Question", "Body")
	check(not no, "confirm → cancel")

	var cancel_shown := [true]
	create_timer(0.05).timeout.connect(func() -> void:
		cancel_shown[0] = dialogs._cancel.visible
		dialogs._ok.pressed.emit())
	await dialogs.alert("Title", "Body")
	check(not bool(cancel_shown[0]), "an alert has no cancel button")

	dialogs._open = true
	var refused: bool = await dialogs.confirm("A", "B")
	check(not refused, "while one is already up, a second confirm returns false at once")
	dialogs._open = false
	check(not dialogs.is_open(), "closed")

	# 🔑 Button layout — vertical by default · one row · automatic · single use. 🛑 The button row is built **on first open** (zero cost to enter as an autoload).
	var fresh := GoDialogs.new()
	check(fresh._actions == null and fresh._surface.footer.get_child_count() == 2, "right after construction there is no button-row node (just the two buttons in the footer)")
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
	check(dialogs._actions != null and shape["vertical"] and not shape["same_row"], "the default layout is vertical (%s)" % str(shape))

	dialogs.action_layout = GoDialogs.ActionLayout.HORIZONTAL
	dialogs.action_gap = 8
	dialogs.body_gap = 20
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(not shape["vertical"] and shape["same_row"] and shape["cancel_left"], "HORIZONTAL — one row · cancel first (%s)" % str(shape))
	check(near(shape["gap_x"], 8.0, 1.5), "gap between buttons = action_gap (%.1f)" % shape["gap_x"])
	check(near(shape["body_to_actions"], 20.0, 1.5), "gap after the body = body_gap (%.1f)" % shape["body_to_actions"])
	check(near(shape["bottom_gap"], shape["inset"], 1.5), "padding below the last button = the card's inner padding (%.1f · %.1f)" % [shape["bottom_gap"], shape["inset"]])

	# 🛑 On a narrow screen the section gap is one step smaller — count the height with the `gap` token and the space after the body opens up by that much.
	dialogs._surface.compact = true
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(near(shape["body_to_actions"], 20.0, 1.5), "on a narrow screen too, the gap after the body = body_gap — the section gap is counted at its real value (%.1f)" % shape["body_to_actions"])
	check(near(shape["bottom_gap"], shape["inset"], 1.5), "on a narrow screen too, the card is no bigger than it needs to be (%.1f · %.1f)" % [shape["bottom_gap"], shape["inset"]])
	dialogs._surface.compact = false

	dialogs.action_layout = GoDialogs.ActionLayout.AUTO
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Delete", "Sure?", "Permanently remove this character and every item it carries", "Keep the character as it is")
	check(shape["vertical"], "AUTO — it goes vertical when one row will not fit in half the width (%s)" % str(shape))
	var long_min: float = shape["ok_min_w"]
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Save", "Save now?", "OK", "No")
	check(not shape["vertical"], "AUTO — short labels stay on one row (%s)" % str(shape))
	check(float(shape["ok_min_w"]) < long_min, "a short label after a long one does not keep the old minimum button width (%.0f < %.0f)" % [shape["ok_min_w"], long_min])

	dialogs.action_layout = GoDialogs.ActionLayout.VERTICAL
	dialogs.set_next_action_layout(GoDialogs.ActionLayout.HORIZONTAL)
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(not shape["vertical"], "set_next_action_layout — one row for this window only")
	create_timer(0.1).timeout.connect(answer_after_measure)
	await dialogs.confirm("Log out", "Do you want to log out?", "Log out", "Cancel")
	check(shape["vertical"], "the next window returns to action_layout (vertical)")
	dialogs.action_gap = -1
	dialogs.body_gap = -1
	dialogs.queue_free()
	await frames(2)


# ── Notice ───────────────────────────────────────────────────────────

func _notice() -> void:
	var notice := GoNotice.new()
	root.add_child(notice)
	await frames(1)
	check(notice.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "the whole notice subtree takes no input")
	check(notice.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED, "a notice does not steal focus")
	var expired := [false]
	notice.expired.connect(func() -> void: expired[0] = true)
	notice.show_text("hello", GoTheme.SUCCESS, 0.1)
	check(notice.visible, "show_text makes it visible")
	await create_timer(0.35).timeout
	check(bool(expired[0]) and not notice.visible, "it goes away once the time is up")
	TranslationServer.set_locale("en")
	notice.show_key("gohud_close")
	check(notice.label.text == "Close", "show_key translates")
	var content := HBoxContainer.new(); var inner := Button.new(); content.add_child(inner)
	notice.set_content(content)
	check(content.mouse_filter == Control.MOUSE_FILTER_IGNORE and inner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "set_content: the content subtree's mouse_filter is IGNORE too")
	notice.queue_free()
	await frames(1)


# ── Prompt card ──────────────────────────────────────────────────────

func _prompt() -> void:
	var card := GoPromptCard.new()
	root.add_child(card)
	await frames(1)
	var hits := [0]
	card.set_actions([{"text": "Accept", "action": func() -> void: hits[0] += 1, "primary": true}, {"text": "No"}])
	var first := card.actions.get_child(0) as Button
	var first_id := first.get_instance_id()
	card.set_actions([{"text": "Accept", "action": func() -> void: hits[0] += 10, "primary": true}, {"text": "No"}])
	check(card.actions.get_child(0).get_instance_id() == first_id, "the same shape does not rebuild the buttons — a tap in progress survives")
	first.pressed.emit()
	check(int(hits[0]) == 10, "the action is refreshed with the new Callable")
	card.set_actions([{"text": "Other"}])
	await frames(1)
	check(card.actions.get_child_count() == 1 and card.actions.get_child(0).get_instance_id() != first_id, "a changed shape rebuilds them")
	card.set_icon(GoIconSet.USER_PLUS, Color.WHITE, true)
	check(card.icon_slot.visible and card.icon_slot.get_node_or_null(^"Disc") != null, "the round badge icon")
	card.fit_width(300)
	check(near(card.custom_minimum_size.x, 300.0), "fit_width")
	card.queue_free()
	await frames(1)


# ── Value bar ────────────────────────────────────────────────────────

func _bar() -> void:
	var bar := GoBar.new()
	root.add_child(bar)
	await frames(1)
	bar.set_values(320, 500, false)
	var value_label := bar.get_node(^"Column/Head/Value") as Label
	check(value_label != null and value_label.text == "320 / 500", "fraction readout")
	bar.readout = GoBar.Readout.PERCENT
	check(value_label.text == "64%", "percent readout")
	var fill := bar.get_node(^"Column/Fill") as ProgressBar
	check(near(fill.value, 0.64, 0.001), "the bar ratio")
	check(fill.get_theme_stylebox(&"fill").get_margin(SIDE_TOP) <= 1.0, "the fill style does not drag the card padding along with it")
	check(bar.get_combined_minimum_size().y >= 24.0, "the bar's minimum height holds both the name row and the bar — they do not overlap (%.0f)" % bar.get_combined_minimum_size().y)
	check(GoBar.abbreviate(999) == "999" and GoBar.abbreviate(12345) == "12.3k" and GoBar.abbreviate(1234567) == "1.2m", "large numbers are abbreviated")
	bar.queue_free()
	await frames(1)


# ── Quick slot ───────────────────────────────────────────────────────

func _slot() -> void:
	# 🛑 By default **the slot node itself is 48dp** (`_ready` sets `custom_minimum_size` that way) —
	#    only the visible panel is 44dp, and the touch-expansion code does not fire then. The expansion really does its work
	#    **when the host forces a slot smaller than 48dp**. That case is reproduced to see the minimum hold.
	var reachable := GoSlot.new()
	root.add_child(reachable)
	await frames(2)
	reachable.custom_minimum_size = Vector2(30, 30)
	reachable.size = Vector2(30, 30)
	await frames(2)
	check(reachable.touch_hit(Vector2(-5, 15)),
		"a slot forced small is still pressable beyond the node (48dp minimum · actually %.0fdp)" % reachable.size.x)
	check(not reachable.touch_hit(Vector2(-40, 15)), "which does not make it pressable just anywhere")
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
	check(not quantity.is_visible_in_tree(), "NONE draws no quantity row")
	a.quantity = GoSlot.UNKNOWN
	check(quantity.is_visible_in_tree() and quantity.text == "…", "UNKNOWN shows …")
	a.quantity = 12
	check(quantity.text == "×12", "quantity ×12")
	check(near((a.get_node(^"Face") as Panel).size.x, 44.0), "the visible panel is a single 44")
	var peers: Array[Control] = [a, b]
	a.touch_peers = peers
	b.touch_peers = peers
	var point := Vector2(46, 24)
	check(not a._has_point(point - a.global_position) and b._has_point(point - b.global_position), "where they overlap, the slot with the nearer centre takes it")
	a.start_cooldown(1.0)
	await frames(1)
	check((a.get_node(^"Face/TimerBadge/Timer") as Label).is_visible_in_tree(), "the cooldown's remaining time is shown")
	a.queue_free()
	b.queue_free()
	await frames(1)


# ── Joystick ─────────────────────────────────────────────────────────

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
	check(near(pad.vector().x, 1.0, 0.01) and near(pad.vector().y, 0.0, 0.01), "dragged beyond the radius, the length stays 1")
	drag.position = center + Vector2(pad.radius * 0.05, 0)
	pad._gui_input(drag)
	check(pad.vector() == Vector2.ZERO, "inside the dead zone it is 0")
	var released := [false]
	pad.released.connect(func() -> void: released[0] = true)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = center
	pad._gui_input(up)
	check(bool(released[0]) and pad.vector() == Vector2.ZERO and not pad.is_active(), "on release it is 0 · released")
	pad.queue_free()
	await frames(1)


# ── HUD spot ─────────────────────────────────────────────────────────

func _anchor() -> void:
	# 🛑 **Code that runs only in landscape is never caught by a portrait check.** The screen is really turned on its side.
	var was := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(3)
	var turned := GoHudAnchor.new()
	turned.spot = GoHudAnchor.Spot.BOTTOM_CENTER
	turned.landscape_spot = GoHudAnchor.Spot.BOTTOM_RIGHT
	root.add_child(turned)
	await frames(2)
	check(turned.active_spot() == GoHudAnchor.Spot.BOTTOM_RIGHT,
		"in landscape the HUD moves to landscape_spot")
	root.content_scale_size = Vector2i(390, 844)
	await frames(3)
	check(turned.active_spot() == GoHudAnchor.Spot.BOTTOM_CENTER, "back in portrait it returns to its original spot")
	turned.queue_free()

	# In landscape there is width to spare, so the card uses **a smaller share** of the screen width.
	# 🛑 The maximum width cap is **lifted** to look — on a wide screen both ratios are clipped at the 480dp cap
	#    and the difference never shows (844×0.72 and 844×0.94 both come to 480).
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
		"in landscape a window uses a smaller share of the screen width (portrait %.2f · landscape %.2f)"
		% [portrait_share, landscape_share])
	card_surface.queue_free()
	GoUi.config.surface_max_width = cap_was
	root.content_scale_size = was
	await frames(3)

	# ── Someone who works by keyboard alone ─────────────────────────────
	# 🛑 **If Tab escapes to the screen behind while a window is up, Enter presses a button nobody can see.**
	#    The other way round, if focus vanishes after closing, a keyboard user is left nowhere on the screen at all.
	#    Neither rule shows up under a finger, so without a check they break quietly.
	var outside := GoStyle.button("바깥")
	root.add_child(outside)
	await frames(2)
	outside.grab_focus()
	await frames(2)
	check(root.gui_get_focus_owner() == outside, "the background button holds focus")

	# 🛑 **Announce that the keyboard is in use.** gohud watches the last input device and deliberately keeps the focus
	#    ring off a window opened by pointer (a ring flashing on a tap-opened window is irritating). So to check keyboard
	#    traversal, **one key event has to be pushed through** to put it in that state.
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
		"opening a window brings focus inside it (%s)" % (holder.name if holder != null else "none"))

	outside.grab_focus()
	await frames(5)
	holder = root.gui_get_focus_owner()
	check(holder != null and win.is_ancestor_of(holder),
		"focus that leaked outside the window is brought back (%s)" % (holder.name if holder != null else "none"))

	# 🛑 Focus has to be inside the window **just before** closing for the return afterwards to mean anything — without this line
	#    "it came back to where it was" could really be "it never left".
	holder = root.gui_get_focus_owner()
	check(holder != null and win.is_ancestor_of(holder),
		"just before closing, focus is inside the window (%s)" % (holder.name if holder != null else "none"))
	# 🛑 `GoSurface` has no `close()` — `request_close()` only **emits a signal**, and the one that really closes it is
	#    whoever owns the window (a sheet or a dialog). The window itself closes by hiding.
	win.hide()
	await frames(6)
	check(root.gui_get_focus_owner() == outside, "closing the window returns focus to where it was (%s)"
		% (root.gui_get_focus_owner().name if root.gui_get_focus_owner() != null else "none"))
	win.queue_free()
	outside.queue_free()
	await frames(2)

	# ── Tooltip ─────────────────────────────────────────────────────────
	# 🛑 **For an icon button the tooltip is the only description there is.** The engine's default tooltip leaves wrapping on
	#    and computes a maximum width of 1dp, which split `settings` **one character per line** (measured 2026-09-13: width 1 · height 186).
	#    gohud sets the width itself and never leans on that computation.
	var tip_button := GoIconButton.new()
	tip_button.icon_name = GoIconSet.SETTINGS
	tip_button.tooltip_text_name = &"settings"
	root.add_child(tip_button)
	await frames(2)
	var short_tip := tip_button._make_custom_tooltip("settings") as Label
	check(short_tip != null, "an icon button builds its own tooltip")
	if short_tip != null:
		root.add_child(short_tip)
		await frames(2)
		check(short_tip.get_combined_minimum_size().x > 24.0,
			"a short tooltip stays on one line — the minimum width holds the text (%.0f dp)" % short_tip.get_combined_minimum_size().x)
		check(short_tip.autowrap_mode == TextServer.AUTOWRAP_OFF, "a short label is not folded")
		short_tip.queue_free()
	var long_text := "이 버튼은 아주 긴 설명을 담고 있어서 한 줄로는 도저히 담기지 않는다"
	var long_tip := tip_button._make_custom_tooltip(long_text) as Label
	if long_tip != null:
		root.add_child(long_tip)
		await frames(2)
		check(long_tip.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and long_tip.custom_minimum_size.x > 24.0,
			"a long tooltip folds at **the width we set** (%.0f dp)" % long_tip.custom_minimum_size.x)
		long_tip.queue_free()
	tip_button.queue_free()
	await frames(1)

	# A quick slot stays out of the Tab order by default, but must be switchable on where **keyboard-only operation** is needed.
	var key_slot := GoSlot.new()
	root.add_child(key_slot)
	await frames(2)
	check(key_slot.focus_mode == Control.FOCUS_NONE, "a slot stays out of the Tab order by default")
	key_slot.keyboard_focus = true
	await frames(1)
	check(key_slot.focus_mode == Control.FOCUS_ALL, "with keyboard_focus on, the keyboard reaches it")
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
	check(near(rect.end.x, area.end.x) and near(rect.end.y, area.end.y), "BOTTOM_RIGHT — the corner inside the margin")
	check(near(spot.size.x, 100.0) and near(spot.size.y, 40.0), "as large as the child's minimum size (%s · area left %s)" % [str(spot.size), str(area.size)])
	box.custom_minimum_size = Vector2(160, 60)
	await frames(2)
	check(near(spot.size.x, 160.0) and near(spot.get_global_rect().end.x, area.end.x),
		"it grows with the child and keeps to the corner (%s)" % str(spot.get_global_rect()))
	spot.queue_free()
	await frames(1)

	# ── Avoiding pinned boxes ───────────────────────────────────────────
	# 🛑 **The nine spots only divide the space; they promise nothing about overlap.** A snackbar raised at top centre
	#    is wide enough that it sat straight on the health bar at top right — the value was covered and health could not be read (measured).
	var bars_spot := GoHudAnchor.new()
	bars_spot.spot = GoHudAnchor.Spot.TOP_RIGHT
	var bars_box := Control.new()
	bars_box.custom_minimum_size = Vector2(180, 100)
	bars_spot.add_child(bars_box)
	root.add_child(bars_spot)
	var toast_spot := GoHudAnchor.new()
	toast_spot.spot = GoHudAnchor.Spot.TOP_CENTER
	var toast_box := Control.new()
	# 🛑 Hard-code the width and **on a wide screen they never overlap in the first place**, which breaks the check's premise (at 844dp
	#    a 300dp notice never touches a 180dp health bar). Sizes are taken in proportion to the screen so they overlap anywhere.
	var usable := GoSafeArea.usable_rect(root).grow(-GoUi.metric(GoTheme.SCREEN_MARGIN))
	toast_box.custom_minimum_size = Vector2(maxf(300.0, usable.size.x * 0.9), 44)
	toast_spot.add_child(toast_box)
	root.add_child(toast_spot)
	await frames(4)

	# ① Left alone they overlap — the nine spots alone do not solve it.
	check(bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"a wide notice overlaps the corner HUD (notice %s · HUD %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])

	# ② Told to move aside, it drops down and settles there.
	var toast_x := toast_spot.global_position.x
	toast_spot.avoid_peers = true
	await frames(4)
	check(not bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"avoid_peers — the notice %s avoids the HUD %s"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	check(toast_spot.global_position.y >= bars_spot.get_global_rect().end.y,
		"a box at the top moves aside **downward** (notice top %.0f · HUD bottom %.0f)"
		% [toast_spot.global_position.y, bars_spot.get_global_rect().end.y])
	# 🛑 It never jumps sideways — appearing somewhere different each time it is raised, the eye cannot follow it.
	check(near(toast_spot.global_position.x, toast_x),
		"the centring is unchanged (before %.0f · after %.0f)" % [toast_x, toast_spot.global_position.x])

	# ③ Pinned boxes do not avoid each other — if both moved they would swap places forever.
	var before := bars_spot.global_position
	await frames(3)
	check(bars_spot.global_position == before, "a box that does not avoid stays where it is")

	# ④ **A box that is not pinned is nothing to avoid.** Letting the transient ones avoid each other sent the notice
	#    running from the prompt card all the way into the middle of the screen (measured in landscape 2026-09-13).
	bars_spot.reserve_space = false
	await frames(4)
	check(bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"transient boxes do not avoid each other (notice %s · peer %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	bars_spot.reserve_space = true
	await frames(4)

	# ⑤ **When a pinned box grows, the avoiding box follows it down.** A notice has no way of knowing on its own
	#    that the health bar grew — untold, it stays where it moved to and overlaps again.
	var toast_y := toast_spot.global_position.y
	bars_box.custom_minimum_size = Vector2(180, 170)
	await frames(6)
	check(toast_spot.global_position.y > toast_y,
		"when the pinned box grows, the avoiding box follows it down (%.0f → %.0f)"
		% [toast_y, toast_spot.global_position.y])
	check(not bars_spot.get_global_rect().intersects(toast_spot.get_global_rect()),
		"after the growth they still do not overlap (notice %s · HUD %s)"
		% [str(toast_spot.get_global_rect()), str(bars_spot.get_global_rect())])
	bars_spot.queue_free()
	toast_spot.queue_free()
	await frames(1)


# ── Guided tour ──────────────────────────────────────────────────────

func _coach() -> void:
	# ── The card never covers a pinned box ──────────────────────────────
	# 🛑 On a landscape screen the rule that sent the card to the very top or bottom covered the header's controls (measured in the
	#    2026-09-13 demo). It now sits **at the same height as its target** and avoids pinned HUDs (`reserve_space`) and `keep_clear`.
	var was_size := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(4)
	var mark := Button.new()
	mark.text = "Target"
	mark.position = Vector2(300, 60)          # upper left of the screen — the card goes to its right
	mark.size = Vector2(120, 40)
	root.add_child(mark)
	var guide := GoCoachMark.new()
	root.add_child(guide)
	await frames(3)
	guide.start([{"target": mark, "title": "T", "body": "b"}])
	await frames(5)
	# 🛑 Measure **before** the pinned box is raised — with it up, avoidance moves the card and hides the "target height" rule
	#    (a mutation test really did miss that rule).
	var card_rect := guide.card.get_global_rect()
	check(near(card_rect.position.y, mark.get_global_rect().position.y, 1.0),
		"in landscape the card sits at its target's height (card y %.0f · target y %.0f)" % [card_rect.position.y, mark.get_global_rect().position.y])
	var fixture := GoHudAnchor.new()          # a pinned box at top right — exactly where the card was placed
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
		"the card avoids the pinned HUD (card %s · HUD %s)" % [str(card_rect), str(fixture.get_global_rect())])
	check(not card_rect.intersects(mark.get_global_rect()), "moving aside, it still does not cover its target")
	# Things that are not anchors (a header band, a toolbar) are declared through `keep_clear`.
	var bar := Panel.new()
	bar.position = Vector2(0, 100)
	bar.size = Vector2(844, 60)
	root.add_child(bar)
	guide.keep_clear = [bar]
	guide.call("_layout")
	await frames(3)
	check(not guide.card.get_global_rect().intersects(bar.get_global_rect()),
		"what is put in keep_clear is avoided too (card %s · band %s)" % [str(guide.card.get_global_rect()), str(bar.get_global_rect())])
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
	check(tour.visible and tour.progress_label.text == "1 / 2", "the tour starts (%s)" % tour.progress_label.text)
	check(GoBackPolicy.owners() == baseline + 1, "the tour holds the back button too")
	first.pressed.emit()
	await frames(2)
	check(tour.step == 1, "really pressing the control it points at moves to the next step")
	tour.next_button.pressed.emit()
	await frames(2)
	check(bool(done[0]) and bool(done[1]) and not tour.visible, "after the last step it completes")
	check(GoBackPolicy.owners() == baseline, "on completion the back button is handed back")
	tour.queue_free()
	first.queue_free()
	second.queue_free()
	await frames(1)


# ── Form ─────────────────────────────────────────────────────────────

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
	check(near(form.get_theme_constant(&"margin_left"), roundf(area.position.x + side)), "side margins = the breakpoint's maximum form width")
	check(form.scroll == scroll, "it finds the Scroll child")

	# ── Field group — the label sticks to its own field ─────────────────
	var edit := GoStyle.line_edit("you@example.com")
	var group := GoStyle.field("close", edit, "", true)
	column.add_child(group)
	GoStyle.form(column)
	await frames(2)
	check(group is VBoxContainer and group.get_child_count() == 2, "one group of label + field")
	check(group.get_child(0) is Label and group.get_child(1) == edit, "the label sits above the field")
	check(group.get_theme_constant(&"separation") == GoUi.metric(GoTheme.GAP_TINY),
		"🛑 inside a group it is `gap_tiny` — the form does not overwrite it (currently %d)" % group.get_theme_constant(&"separation"))
	check(column.get_theme_constant(&"separation") == GoUi.metric(GoTheme.GAP), "**between** groups it is the form's `gap`")
	var gap_tiny := float(GoUi.metric(GoTheme.GAP_TINY))
	check(edit.get_global_rect().position.y - (group.get_child(0) as Control).get_global_rect().end.y <= gap_tiny + 1.0,
		"label and field stay together")
	var hinted := GoStyle.field("close", GoStyle.line_edit(), "back", true)
	check(hinted.get_child_count() == 3 and hinted.get_child(2) is Label, "given a hint line it attaches below the field")
	check(GoStyle.field("", edit) == edit, "with neither label nor hint the control comes back as-is")
	hinted.queue_free()
	group.queue_free()
	await frames(1)
	# 🛑 **Room for the glow not to be clipped.** A scroll always clips at its own bounds, so the left glow of a full-width
	#    button was sliced off down the side (2026-09-13 user report). The scroll bounds have to be wider than the content on the
	#    left, top and bottom — on the right, the rail's space already does that job.
	var inset := scroll.get_node_or_null(^"ContentInset") as Control
	check(inset != null, "the scroll wraps its content in an inner inset")
	if inset != null and inset.get_child_count() > 0:
		# 🛑 The `ContentInset` container itself fills the scroll — the inset applies to its **child**.
		#    Measuring the container gave "left 0" and turned the light red even though the implementation was right (2026-09-13).
		var outer := scroll.get_global_rect()
		var inner := (inset.get_child(0) as Control).get_global_rect()
		check(inner.position.x - outer.position.x >= 8.0 and inner.position.y - outer.position.y >= 8.0
			and outer.end.y - inner.end.y >= 8.0,
			"the scroll bounds are wider than the content on the left, top and bottom — room for the glow (left %.0f · top %.0f · bottom %.0f)"
			% [inner.position.x - outer.position.x, inner.position.y - outer.position.y, outer.end.y - inner.end.y])
		# The content's left edge is exactly where the form put it — the inset was borrowed, the content was not pushed.
		check(near(inner.position.x, form.get_global_rect().position.x + form.get_theme_constant(&"margin_left"), 1.0),
			"the content's position is unchanged (content %.0f · form inset %.0f)"
			% [inner.position.x, form.get_global_rect().position.x + form.get_theme_constant(&"margin_left")])
	var late := Label.new()
	late.text = "a long sentence that has to wrap on narrow phones"
	column.add_child(late)
	await frames(1)
	check(late.autowrap_mode != TextServer.AUTOWRAP_OFF, "a label added later is guaranteed to wrap too")

	# ── Button text folds only at word boundaries ───────────────────────
	# 🛑 A button with wrapping on **drops the text width** from its minimum. So as a natural-width button narrowed, `Done`
	#    split into `Don`/`e` (measured on the 2026-09-13 coach mark). A single word never folds, and with several words the
	#    width that fits the longest word on one line is guaranteed.
	var one := GoStyle.button("Done", Callable(), GoStyle.Tone.PRIMARY)
	one.custom_minimum_size.x = 72
	one.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(one)
	await frames(1)
	check(one.autowrap_mode == TextServer.AUTOWRAP_OFF, "a one-word button does not fold (%d)" % one.autowrap_mode)
	var many := GoStyle.button("Delete everything permanently", Callable(), GoStyle.Tone.PRIMARY)
	column.add_child(many)
	await frames(1)
	var font := many.get_theme_font(&"font")
	var longest := font.get_string_size("permanently", HORIZONTAL_ALIGNMENT_LEFT, -1.0, many.get_theme_font_size(&"font_size")).x
	check(many.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and many.custom_minimum_size.x >= longest,
		"a multi-word button folds, but its longest word stays on one line (minimum %.0f ≥ word %.0f)" % [many.custom_minimum_size.x, longest])
	# 🛑 **The decision is made on the visible text, not the translation key** (I-57). The key `probe_two_words` is one word, but its
	#    translation is two — go by the key and it decides not to fold, then splits inside a word as it narrows. When a language change brings a
	#    one-word translation, the form is notified and decides again.
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
		"a two-word translation folds even when the key is one word (%d)" % keyed_button.autowrap_mode)
	TranslationServer.set_locale("yy")
	await frames(3)
	check(keyed_button.autowrap_mode == TextServer.AUTOWRAP_OFF,
		"when a language change makes it one word, the form decides again (%d)" % keyed_button.autowrap_mode)
	TranslationServer.set_locale(probe_locale)
	TranslationServer.remove_translation(two)
	TranslationServer.remove_translation(one_word)
	await frames(2)

	# ── The two kinds of dropdown must look like one part ───────────────
	# 🛑 `select()` (OptionButton) and `dropdown()` (MenuButton) sit one above the other in the demo, and their text alignment and
	#    arrow sizes differed enough that they looked like different parts (measured in the 2026-09-13 demo shots).
	var choose := GoStyle.select(["A", "B"], "Choose")
	var more := GoStyle.dropdown("More", ["x", "y"])
	column.add_child(choose)
	column.add_child(more)
	await frames(2)
	check(more.alignment == HORIZONTAL_ALIGNMENT_LEFT, "a MenuButton dropdown keeps its text on the left too")
	var arrow_w := choose.get_theme_icon(&"arrow").get_width()
	check(more.get_theme_constant(&"icon_max_width") == arrow_w,
		"both dropdowns have the same arrow size (OptionButton %d · MenuButton %d)" % [arrow_w, more.get_theme_constant(&"icon_max_width")])
	# 🛑 Not just the size but the **position** — OptionButton insets by `arrow_margin`, MenuButton by the panel's right padding.
	#    If the two differ, the arrow's x is off by 12dp (measured in the 2026-09-13 demo).
	check(choose.get_theme_constant(&"arrow_margin") == int(more.get_theme_stylebox(&"normal").content_margin_right),
		"both dropdowns put the arrow in the same place (arrow_margin %d · panel padding %d)"
		% [choose.get_theme_constant(&"arrow_margin"), int(more.get_theme_stylebox(&"normal").content_margin_right)])
	choose.queue_free(); more.queue_free()

	# Called again after the text changes, the rule is re-applied — the route a coach mark takes from `Next` to `Done`.
	many.text = "Done"
	GoStyle.fit_words(many)
	check(many.autowrap_mode == TextServer.AUTOWRAP_OFF, "calling fit_words after a text change returns it to the one-word rule")
	# 🛑 The toggle is kept **outside the form** — inside one, `GoStyle.form()` re-applies the same rule to descendant buttons and
	#    the light stays green even with `toggle()`'s own rule removed (a mutation test really did miss it that way).
	var toggle_one := GoStyle.toggle("Haptics", false)
	var toggle_many := GoStyle.toggle("Enable haptic feedback on every press", false)
	root.add_child(toggle_one)
	root.add_child(toggle_many)
	await frames(1)
	check(toggle_one.autowrap_mode == TextServer.AUTOWRAP_OFF and toggle_many.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"a toggle follows the same word rule (one word %d · several words %d)" % [toggle_one.autowrap_mode, toggle_many.autowrap_mode])
	toggle_one.queue_free()
	toggle_many.queue_free()
	form.queue_free()
	await frames(1)

	# 🛑 The form's **width cap never fires on a phone** — the mobile maximum width is 0 (no cap).
	#    So checking at phone size alone leaves this rule as good as untested. A desktop width is made to confirm it.
	var restore := root.content_scale_size
	root.content_scale_size = Vector2i(1280, 800)
	await frames(3)
	var wide := GoForm.new()
	root.add_child(wide)
	await frames(3)
	var desktop_cap := GoScale.form_width_for(GoScale.breakpoint_for_dp(800.0))
	check(desktop_cap > 0, "a desktop form maximum width is defined (%d dp)" % desktop_cap)
	var side_margin := wide.get_theme_constant(&"margin_left")
	check(side_margin > GoUi.metric(GoTheme.PADDING) * 2,
		"on a wide screen the form caps its width and grows the margins (%d dp — default margin %d)"
		% [side_margin, GoUi.metric(GoTheme.PADDING)])
	wide.queue_free()
	root.content_scale_size = restore
	await frames(3)

	# 🛑 The virtual keyboard **never comes up** in a desktop check — its height is fed in to reproduce it.
	#    Without that, nobody keeps the rule that says "avoid the keyboard".
	var keyed := GoForm.new()
	root.add_child(keyed)
	await frames(2)
	var bottom_before := keyed.get_theme_constant(&"margin_bottom")
	keyed._on_keyboard(300)
	await frames(2)
	check(keyed.get_theme_constant(&"margin_bottom") > bottom_before,
		"when the virtual keyboard rises, the form moves above it (%d → %d)"
		% [bottom_before, keyed.get_theme_constant(&"margin_bottom")])
	keyed._on_keyboard(0)
	await frames(2)
	check(keyed.get_theme_constant(&"margin_bottom") == bottom_before, "when the keyboard goes down it comes back")
	keyed.queue_free()
	await frames(1)

	# ── The back button of a form assembled in code ─────────────────────
	# 🛑 `_ready` moves the scroll into the border box. The engine's `reparent()` restores the owner only for descendants sharing
	#    **the same owner** as the scroll, so on a form owning only the button the owner was erased, `%BackButton` could not be found and Android Back went quietly dead
	#    (measured 2026-09-15). It never shows in a `.tscn` where the scene root owns everything, so only assembly in code catches it.
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
		if mode == "holder": coded.owner = holder          # owns the form and the button only — the scroll and the fields have no owner
		back.owner = keeper
		back.unique_name_in_owner = true
		root.add_child(holder)
		await frames(2)
		check(coded_scroll.get_parent() != coded and back.owner == keeper and coded._back_button == back and coded._holds_back,
			"code form (owner=%s) — after the scroll moves, %%BackButton is still there and holds Back (moved %s · owner kept %s · found %s · held %s)"
			% [mode, coded_scroll.get_parent() != coded, back.owner == keeper, coded._back_button == back, coded._holds_back])
		holder.queue_free()
		await frames(1)
	# ── Avoiding a floating HUD ─────────────────────────────────────────
	# 🛑 **Overlap has only ever been caught by eye.** The scrolled body running behind the health bar and mixing the text,
	#    and an input field hidden behind a quick slot, both only showed when a screenshot was opened (2026-09-13). Whether two rectangles
	#    overlap can be measured in coordinates — and here it is measured.
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
	# 🛑 **Do not measure by the child's rectangle.** A container re-places its children on the **frame after** the margins
	#    change, so reading the child shows the layout of one beat ago (they missed each other by 16dp).
	#    What is guaranteed is the **inner area the form hands out**, and that is exact immediately.
	var body := func() -> Rect2:
		return screen.get_global_rect().grow_individual(
			-screen.get_theme_constant(&"margin_left"), -screen.get_theme_constant(&"margin_top"),
			-screen.get_theme_constant(&"margin_right"), -screen.get_theme_constant(&"margin_bottom"))
	check(hud_rect.call().get_area() > 0.0, "the HUD box takes up space %s" % str(hud_rect.call()))
	# 🛑 **Do not judge by the margins.** A form's side margins also come from the per-breakpoint width cap —
	#    on a wide screen that is far larger, and reading the margins alone misjudges it as "it moved aside" (it really did:
	#    at 768×1024 the right-hand 164 was the width cap and the HUD avoidance was 0). The avoidance alone is read separately.
	# ① The default is the behaviour as it always was — nothing moves aside.
	check(screen._hud_pad == Vector4.ZERO, "with avoid_hud off, no space is cleared (the existing behaviour) %s"
		% str(screen._hud_pad))

	# ② Switched on, they do not overlap.
	# 🛑 The HUD sets its own size in a **deferred call** and the form catches that change up on the next frame —
	#    four frames was too tight and, depending on the screen size, they missed each other by 16dp. Wait generously.
	screen.avoid_hud = true
	await frames(10)
	check(not body.call().intersects(hud_rect.call()),
		"avoid_hud — the body %s avoids the HUD %s" % [str(body.call()), str(hud_rect.call())])

	# ③ **Which way does it move.** Stop at "they no longer overlap" and you miss that on a landscape screen it retreats
	#    vertically only and the body loses 27% of the screen (that is what I-38 did).
	#    🛑 The direction is never hard-coded — 1280×800 is landscape, but at a ratio of 1.6:1 downward is marginally
	#       cheaper (136k vs 141k). Hard-code it and the check is wrong even where the algorithm is right. **The rule itself** is measured.
	var pad := screen._hud_pad
	var full := GoSafeArea.usable_rect(screen.get_window())
	var mark := hud_rect.call() as Rect2
	# 🛑 **Measure in the same area as the implementation.** The form looks for overlap inside its own place minus the side margins (on a wide
	#    screen the width cap has already gathered it in the centre), so measuring the whole safe area gives the check a different answer.
	var side_now := maxf(float(screen._side_margin()),
		(full.size.x - float(screen._max_width())) * 0.5 if screen._max_width() > 0 else 0.0)
	full = full.grow_individual(-side_now, 0.0, -side_now, 0.0)
	var cost := [
		(mark.end.x - full.position.x) * full.size.y,     # to the left
		(mark.end.y - full.position.y) * full.size.x,     # upward
		(full.end.x - mark.position.x) * full.size.y,     # to the right
		(full.end.y - mark.position.y) * full.size.x,     # downward
	]
	if pad == Vector4.ZERO:
		# 🔑 **On a wide screen there is nothing to push.** The width cap has already gathered the form in the centre, so it
		#    never touches the HUD in the corner — push it anyway and the body leans left and the centring breaks
		#    (on a 1280 screen it really leaned by 214dp).
		check(not body.call().intersects(hud_rect.call()),
			"already clear of it, nothing is pushed (body %s · HUD %s)"
			% [str(body.call()), str(hud_rect.call())])
	else:
		var took := 2 if pad.z > 0.0 else 3               # this HUD sits in the bottom-right corner
		# 🛑 **Directions that fall outside are not counted** (their depth is negative) — the implementation filters them the same way.
		var reachable: Array = []
		for value in cost:
			if value > 0.0: reachable.append(value)
		var cheapest: float = reachable.min() if not reachable.is_empty() else cost[took]
		check(is_equal_approx(cost[took], cheapest),
			"it moves aside in the cheapest direction (chosen %.0f · cheapest %.0f)" % [cost[took], cheapest])

	# ④ **In landscape the vertical space is protected.** This was I-38's original symptom — at 844×390, moving downward only
	#    shrinks the body height from 390 to 286 and cuts off a whole row of buttons.
	var restore_size := root.content_scale_size
	root.content_scale_size = Vector2i(844, 390)
	await frames(5)
	check(screen._hud_pad.z > screen._hud_pad.w,
		"on a landscape phone it moves sideways and protects the height (right %.0f · bottom %.0f)"
		% [screen._hud_pad.z, screen._hud_pad.w])
	# ⑤ **On a wide screen nothing is pushed at all.** The width cap has already gathered it in the centre, so it never
	#    touches the HUD in the corner — push it anyway and the body leans left and the centring breaks.
	#    🛑 This rule **never shows on a phone screen** (with no cap the form uses the whole screen).
	root.content_scale_size = Vector2i(1280, 800)
	await frames(8)
	check(screen._hud_pad == Vector4.ZERO,
		"on a wide screen nothing is pushed needlessly (pad %s)" % str(screen._hud_pad))
	root.content_scale_size = restore_size
	await frames(4)

	# ⑤ A box that declined to reserve space is looked past — the joystick that appears only under a hand is one.
	corner.reserve_space = false
	await frames(4)
	check(screen._hud_pad == Vector4.ZERO, "a box with reserve_space off takes no space %s"
		% str(screen._hud_pad))
	screen.queue_free()
	corner.queue_free()
	await frames(1)

	# The horizontal scroll factory — only the settings are split out so a subclass can rebuild it on its own instance.
	var lane := GoScroll.horizontal()
	var own := GoScroll.new()
	var made := GoScroll.as_horizontal(own)
	check(made == own and lane.horizontal_scroll_mode == made.horizontal_scroll_mode and made.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and made.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and made.mouse_filter == Control.MOUSE_FILTER_PASS, "as_horizontal = the settings of horizontal · it returns the same instance")
	lane.free(); own.free()


# ── Sound · haptics ──────────────────────────────────────────────────

func _feedback() -> void:
	var cues := []
	var buzz := []
	GoFeedback.sound_handler = func(cue: String) -> void: cues.append(cue)
	GoFeedback.haptic_handler = func(ms: int, amplitude: float) -> void: buzz.append([ms, amplitude])
	GoFeedback.opened()
	GoFeedback.failed()
	check(cues == ["ui_open", "ui_error"], "cue name → the project's sound name (%s)" % str(cues))
	check(buzz.size() == 2 and int(buzz[0][0]) == 20 and int(buzz[1][0]) == 40, "open 20ms · error 40ms")
	GoUi.config.haptics_enabled = false
	GoFeedback.tapped()
	check(buzz.size() == 2, "with haptics_enabled=false there is no buzz")
	GoUi.config.haptics_enabled = true
	var remapped: Dictionary[StringName, String] = {GoFeedback.OPENED: "door"}
	GoUi.config.sound_cues = remapped
	GoFeedback.opened()
	check(cues.back() == "door", "sound_cues swaps the sound name")
	GoUi.config.sound_cues = GoConfig.new().sound_cues
	GoFeedback.sound_handler = Callable()
	GoFeedback.haptic_handler = Callable()


# ── Finger drag on a scroll ───────────────────────────────────────────

## 🛑 Dragging a list by a row must move the list, not the row's highlight — the focus the press handed out, the
##    hover under the finger and the jump to a half-hidden row all read as "the buttons are being dragged".
##    Headless has no touchscreen, so the engine never starts a drag itself; the start and stop are raised the way
##    `ScrollContainer` raises them, and the pointer events are real.
func _scroll_drag() -> void:
	var scroll := GoScroll.new()
	scroll.size_flags_vertical = Control.SIZE_FILL
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(300, 260)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var rows: Array[Button] = []
	var presses := [0]
	for i in 20:
		var row := Button.new()
		row.text = "Row %d" % i
		row.custom_minimum_size = Vector2(0, 48)
		row.pressed.connect(func() -> void: presses[0] += 1)
		column.add_child(row)
		rows.append(row)
	root.add_child(scroll)
	await frames(3)
	check(not scroll.follow_focus, "the engine's follow_focus is off — GoScroll follows key focus itself")
	# The row the bottom edge cuts through: pressing its visible part must not pull the list.
	var bottom := scroll.get_global_rect().end.y
	var cut: Button = null
	for row in rows:
		var rect := row.get_global_rect()
		if rect.position.y < bottom and rect.end.y > bottom: cut = row
	check(cut != null, "a row is cut by the bottom edge")
	if cut == null:
		scroll.queue_free()
		return
	var point := Vector2(cut.get_global_rect().get_center().x, (cut.get_global_rect().position.y + bottom) * 0.5)
	_pointer(point, true, true)
	await frames(2)
	check(root.gui_get_focus_owner() == cut and cut.is_hovered(), "the press lands on the half-hidden row")
	check(scroll.scroll_vertical == 0, "a finger press does not pull the list to the row (%d)" % scroll.scroll_vertical)
	scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	scroll.scroll_started.emit()
	await frames(1)
	check(root.gui_get_focus_owner() == null, "the drag drops the focus the press handed out")
	check(not cut.is_hovered(), "the row under the finger loses its hover once the drag starts")
	for step in 6:
		point.y -= 30.0
		_pointer(point, true, false)
		await frames(1)
	var lit := rows.filter(func(row: Button) -> bool: return row.is_hovered())
	check(lit.is_empty(), "no row lights up as the finger passes over it (%d lit)" % lit.size())
	_pointer(point, false, true)
	await frames(1)
	check(presses[0] == 0, "releasing after a drag presses nothing")
	scroll.scroll_ended.emit()
	check(column.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED, "the rows take the mouse again once the list stops")
	_pointer(point, false, false)
	await frames(1)
	check(rows.any(func(row: Button) -> bool: return row.is_hovered()), "hover works again after the drag")
	rows[15].grab_focus()
	await frames(1)
	check(scroll.scroll_vertical > 0, "keyboard focus still scrolls the row into view (%d)" % scroll.scroll_vertical)
	scroll.queue_free()
	await frames(1)


func _pointer(point: Vector2, held: bool, button: bool) -> void:
	var event: InputEventMouse
	if button:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = held
		event = click
	else:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, -30)
		event = motion
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))


# ── Left-to-right and right-to-left ──────────────────────────────────

func _rtl() -> void:
	var scroll := GoScroll.new()
	var content := VBoxContainer.new()
	scroll.add_child(content)
	root.add_child(scroll)
	await frames(1)
	check(scroll.layout_direction == Control.LAYOUT_DIRECTION_LTR, "the scroll rail stays physically on the right")
	check(content.layout_direction == Control.LAYOUT_DIRECTION_APPLICATION_LOCALE, "the content follows the app locale's direction")
	var pad := GoJoystick.new()
	check(pad.layout_direction == Control.LAYOUT_DIRECTION_LTR, "the joystick keeps the physical direction")
	# 🛑 ar is not the only RTL language — he was added, so both are checked to see the engine treats them as RTL.
	#    The widgets defer to LAYOUT_DIRECTION_APPLICATION_LOCALE, so if the verdict is right the layout is right.
	var before := TranslationServer.get_locale()
	for locale: String in ["ar", "he"]:
		TranslationServer.set_locale(locale)
		check(TranslationServer.get_locale().begins_with(locale), "the %s locale is applied" % locale)
		check(not TranslationServer.get_tool_locale().is_empty(), "the locale is not empty under %s" % locale)

	# 🛑 **Numbers never mirror with the language.** In Arabic too the order of `320 / 500` stays as it is —
	#    mirrored, the remaining health and the maximum would read swapped.
	var numbers := GoBar.new()
	root.add_child(numbers)
	await frames(2)
	numbers.set_values(320, 500, false)
	var readout := numbers.get_node(^"Column/Head/Value") as Label
	check(readout.text_direction == Control.TEXT_DIRECTION_LTR, "the bar's numbers read left to right even under RTL")
	numbers.queue_free()

	# 🛑 **Does what should mirror really mirror.** Checking the value alone misses "the setting is right but the screen is unchanged".
	#    Arabic is switched on and whether the list row's icon and text swap places is read **in coordinates**.
	TranslationServer.set_locale("ar")
	var mirrored := GoStyle.list_button(GoIconSet.USER, "Profile", Callable(), Color.TRANSPARENT, "", false)
	root.add_child(mirrored)
	mirrored.size = Vector2(300, 56)
	await frames(3)
	var line := mirrored.get_child(0).get_child(0) as Control
	var glyph := line.get_child(0) as Control
	var words := line.get_child(1) as Control
	check(glyph.global_position.x > words.global_position.x,
		"under RTL a list row mirrors (icon %.0f · text %.0f)"
		% [glyph.global_position.x, words.global_position.x])
	TranslationServer.set_locale(before)
	await frames(3)
	check(glyph.global_position.x < words.global_position.x, "back in LTR the original order returns")
	mirrored.queue_free()
	await frames(1)

	TranslationServer.set_locale(before)
	pad.free()
	scroll.queue_free()
	await frames(1)


# ── Standalone ───────────────────────────────────────────────────────

## If the add-on leans on its host project, it breaks in the project of whoever downloaded it from the store.
func _standalone() -> void:
	var outside_ref := RegEx.create_from_string("res://[A-Za-z0-9_./%-]+")
	# 🛑 No host project class name is hard-coded — there is no telling which project it gets installed into.
	#    Reaching with `X.` for something that is neither a name the add-on declares nor a name the engine knows is an external dependency.
	var known := _own_symbols()
	var static_access := RegEx.create_from_string("(?<![A-Za-z0-9_.\"'])([A-Z][A-Za-z0-9_]*)\\s*\\.")
	var trailing_comment := RegEx.create_from_string("\\s#.*$")
	# 🛑 Inside a string is not code — a full stop ending an English sentence ("… placement CENTER. It respects …")
	#    looked like `X.` and raised a false positive. The symbol check strips the literals first (the res:// check reads the original).
	var literal := RegEx.create_from_string("\"[^\"]*\"|'[^']*'")
	var problems: Array[String] = []
	for path in _files(ADDON, ["gd", "tscn", "tres", "cfg"]):
		# 🛑 The demo is **a separate project** with its own project.godot — a `res://` inside it points at the demo's root.
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
				problems.append("%s:%d %s (external symbol)" % [path.get_file(), number, symbol])
			if "\"/root/" in line: problems.append("%s:%d /root/ path" % [path.get_file(), number])
	check(problems.is_empty(), "it leans on no res:// outside the add-on, no host project symbol and no autoload path %s" % str(problems.slice(0, 6)))
	check(FileAccess.file_exists(ADDON + "/LICENSE") and FileAccess.file_exists(ADDON + "/THIRD_PARTY_NOTICES.md"), "the licence notice files are there")
	var plugin := ConfigFile.new()
	check(plugin.load(ADDON + "/plugin.cfg") == OK and str(plugin.get_value("plugin", "version", "")) == GoUi.VERSION, "plugin.cfg version = GoUi.VERSION")


## Names the add-on declares itself (class_name, enum) plus the engine's built-in Variant types.
## 🛑 Variant types (Vector2, Color, …) are not in ClassDB, so they are granted here separately.
# ── Widget factories (choosers · menus · readouts) ───────────────────

func _widgets() -> void:
	var select := GoStyle.select(["a", "b", "c"], "pick")
	check(select is OptionButton and select.item_count == 3 and select.selected == -1 and select.text == "pick", "select: 3 items · a placeholder while nothing is picked")
	var menu := GoStyle.dropdown("Actions", ["Rename", {"text": "Delete", "disabled": true}])
	check(menu is MenuButton and menu.get_popup().item_count == 2 and menu.get_popup().is_item_disabled(1)
		and menu.custom_minimum_size.y == GoUi.metric(GoTheme.BUTTON_HEIGHT), "dropdown: 2 items · the second disabled · button height")
	var radios := GoStyle.radio_group(["x", "y", "z"], 2)
	var group: ButtonGroup = radios.get_meta(&"group")
	check(radios.get_child_count() == 3 and group != null and group.get_pressed_button() == radios.get_child(2)
		and (radios.get_child(0) as Control).custom_minimum_size.y == GoUi.metric(GoTheme.TOUCH), "radio_group: 3 items · the third selected · touch minimum")
	var picked := [-1]
	var seg := GoStyle.segmented(["Day", "Week"], 0, func(i: int) -> void: picked[0] = i)
	root.add_child(seg); await frames(1)
	(seg.get_child(1) as Button).button_pressed = true
	(seg.get_child(1) as Button).pressed.emit()
	check((seg.get_meta(&"group") as ButtonGroup).get_pressed_button() == seg.get_child(1) and picked[0] == 1, "segmented: only one pressed · the callback index")
	check((seg.get_child(0) as Button).autowrap_mode == TextServer.AUTOWRAP_OFF and (seg.get_child(0) as Control).size.x >= 40, "segmented: wrapping off · natural width (the text does not split down the page)")
	seg.queue_free()
	# 🔑 Compact cells — for narrow chrome (a pill over the map). Cell minimum width = touch, cell panel padding = the compact button token, only the pressed cell in the accent colour.
	var tight := GoStyle.segmented(["Nearby", "Overview"], 1, Callable(), false, true)
	root.add_child(tight); await frames(1)
	var tight_first := tight.get_child(0) as Button
	var tight_face := tight_first.get_theme_stylebox(&"normal")
	check(near(tight_first.custom_minimum_size.x, GoUi.metric(GoTheme.TOUCH)) and near(tight_face.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X))
		and near(tight_face.get_margin(SIDE_TOP), GoUi.metric(GoTheme.COMPACT_PADDING_Y)),
		"segmented(compact): cell minimum width = touch · panel padding = the compact button token (%.0f · %.0f)" % [tight_first.custom_minimum_size.x, tight_face.get_margin(SIDE_LEFT)])
	var picked_face := (tight.get_child(1) as Button).get_theme_stylebox(&"pressed") as StyleBoxFlat
	check(picked_face == null or picked_face.bg_color.is_equal_approx(GoUi.color(GoTheme.ACCENT)), "segmented(compact): the pressed cell is filled with the accent colour")
	check(near(tight_first.get_theme_stylebox(&"pressed").get_margin(SIDE_LEFT), tight_face.get_margin(SIDE_LEFT)),
		"segmented(compact): cell padding is the same across states (the width does not wobble when pressed)")
	var idle_face := tight_first.get_theme_stylebox(&"normal")
	check(idle_face is StyleBoxEmpty or (idle_face is StyleBoxFlat and (idle_face as StyleBoxFlat).bg_color.a < 0.01 and (idle_face as StyleBoxFlat).border_width_left == 0),
		"segmented(compact): an unpicked cell draws no panel — no double border inside the outer pill")
	var focus_face := tight_first.get_theme_stylebox(&"focus")
	check(focus_face != null and near(focus_face.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X)) and not (focus_face is StyleBoxEmpty),
		"segmented(compact): keyboard focus shows as a pale ring · the padding is unchanged")
	tight.queue_free()
	# 🔑 The choice card — zero panel padding in every state · toggle or list-style selection · disabled dimmed or unchanged · mouse_filter changed only when given.
	var pick_ink := Color(0.9, 0.3, 0.2)
	var pick := Button.new()
	GoStyle.style_choice_card(pick, pick_ink)
	root.add_child(pick); await frames(1)
	var zero_margins := true
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var face := pick.get_theme_stylebox(state)
		zero_margins = zero_margins and face != null and near(face.get_margin(SIDE_LEFT), 0.0) and near(face.get_margin(SIDE_TOP), 0.0)
	check(zero_margins and pick.toggle_mode and pick.text == "",
		"style_choice_card: zero panel padding in every state (a picked card does not widen) · toggle · no text")
	check(pick.mouse_filter == Control.MOUSE_FILTER_STOP, "style_choice_card: with no filter given, mouse_filter is left alone")
	check(GoSkin.box_background(pick.get_theme_stylebox(&"pressed")) != GoSkin.box_background(pick.get_theme_stylebox(&"normal")),
		"style_choice_card: the picked panel differs in fill from the resting panel")
	check(GoSkin.box_background(pick.get_theme_stylebox(&"disabled")).a < GoSkin.box_background(pick.get_theme_stylebox(&"normal")).a,
		"style_choice_card: the disabled panel is dimmed (dim_disabled by default)")
	pick.queue_free()
	var listed := Button.new()
	GoStyle.style_choice_card(listed, pick_ink, true, false, false, Control.MOUSE_FILTER_PASS)
	check(not listed.toggle_mode and listed.mouse_filter == Control.MOUSE_FILTER_PASS
		and listed.get_theme_stylebox(&"normal") == listed.get_theme_stylebox(&"pressed")
		and listed.get_theme_stylebox(&"disabled") == listed.get_theme_stylebox(&"normal"),
		"style_choice_card(selected, no toggle): the resting panel is the picked panel · disabled uses the same panel (colour and width do not jump) · the given filter stands")
	listed.free()
	# 🔑 The card's content box · passing input through · a one-line label — the assembly that fills a choice card.
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
		"card_body: the given inner padding 9 · row spacing 3")
	check(tile_desc.get_line_count() > 1 and tile.size.y >= tile_inset.get_combined_minimum_size().y - 0.5,
		"card_body: the card's height wraps around the wrapped content (%.0f ≥ %.0f)" % [tile.size.y, tile_inset.get_combined_minimum_size().y])
	check(tile_inset.mouse_filter == Control.MOUSE_FILTER_IGNORE and tile_body.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and tile_row.mouse_filter == Control.MOUSE_FILTER_IGNORE and tile_name.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and tile_desc.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"let_input_through: no control inside the card takes input (the card is what is pressed)")
	check(tile_name.autowrap_mode == TextServer.AUTOWRAP_OFF and tile_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
		and tile_name.clip_text and tile_name.get_line_count() == 1,
		"line: wrapping off · ellipsis · clipping · one line")
	tile.queue_free()
	# 🔑 Chips — icon only · icon + text · an urgent border · a pressable chip button (filled).
	var icon_chip := GoStyle.chip("", pick_ink, false, GoIconSet.HEART, 20)
	var icon_face := icon_chip.get_theme_stylebox(&"panel")
	# 🔑 Depending on the set, the icon box is a glyph label or a texture — either way it takes the same box.
	check(icon_chip.get_child_count() == 1 and icon_chip.get_child(0) is Control
		and (icon_chip.get_child(0) as Control).custom_minimum_size == Vector2(20, 20)
		and near(icon_face.get_margin(SIDE_LEFT), icon_face.get_margin(SIDE_TOP)),
		"chip(icon): with no text it holds one icon box and the panel is square too (left %.1f · top %.1f · children %d)"
			% [icon_face.get_margin(SIDE_LEFT), icon_face.get_margin(SIDE_TOP), icon_chip.get_child_count()])
	# 🛑 Neither text nor icon — an empty pill, not `add_child(null)` (a name that has not arrived yet).
	var bare_chip := GoStyle.chip("")
	check(bare_chip != null and bare_chip.get_child_count() == 0, "chip(\"\"): an empty chip holds nothing and raises no error")
	bare_chip.free()
	var both_chip := GoStyle.chip("12", pick_ink, false, GoIconSet.HEART, 16)
	var both_row := both_chip.get_child(0) as HBoxContainer
	check(both_row != null and both_row.get_child_count() == 2 and both_row.get_child(1) is Label
		and (both_row.get_child(1) as Label).text == "12",
		"chip(icon, text): the text comes after the icon")
	var calm_face := GoStyle.chip("x", pick_ink).get_theme_stylebox(&"panel")
	var urgent_face := GoStyle.chip("x", pick_ink, false, &"", -1, true).get_theme_stylebox(&"panel")
	check(&"border_color" not in calm_face or calm_face.get(&"border_color") != urgent_face.get(&"border_color"),
		"chip(urgent): the urgent border differs from an ordinary chip")
	var chip_button := Button.new()
	GoStyle.style_chip_button(chip_button, pick_ink)
	var filled_button := Button.new()
	GoStyle.style_chip_button(filled_button, pick_ink, 0.85)
	check(chip_button.mouse_filter == Control.MOUSE_FILTER_STOP
		and chip_button.get_theme_stylebox(&"normal") != null and chip_button.get_theme_stylebox(&"disabled") != null
		and not chip_button.has_theme_stylebox_override(&"focus")
		and chip_button.has_theme_color_override(&"font_color") and chip_button.has_theme_color_override(&"font_hover_color"),
		"style_chip_button: it applies the state panels and a font colour readable on them, and leaves mouse_filter and the focus panel alone")
	check(GoSkin.box_background(filled_button.get_theme_stylebox(&"normal")).a
		> GoSkin.box_background(chip_button.get_theme_stylebox(&"normal")).a,
		"style_chip_button(filled): it fills with the tone colour")
	var chip_label := GoStyle.label("42")
	GoStyle.style_chip_label(chip_label, pick_ink)
	check(chip_label.get_theme_stylebox(&"normal") != null and chip_label.has_theme_color_override(&"font_color"),
		"style_chip_label: it gives an existing label the chip panel and a font colour readable on it")
	chip_label.free()
	var hud_face := GoStyle.hud_panel(pick_ink).get_theme_stylebox(&"panel")
	var chip_face := GoStyle.chip_panel(pick_ink).get_theme_stylebox(&"panel")
	var tinted_face := GoStyle.chip_panel(pick_ink, 0.5).get_theme_stylebox(&"panel")
	check(hud_face != null and hud_face.get_class() == GoUi.skin().floating_box(GoTheme.BOX_HUD, pick_ink).get_class()
		and chip_face != null and chip_face.get_class() == GoUi.skin().chip_box(pick_ink).get_class()
		and GoSkin.box_background(tinted_face).a > GoSkin.box_background(chip_face).a,
		"hud_panel · chip_panel: the skin's panel is applied as-is · fill_alpha fills it more strongly")
	# 🛑 The HUD panel's inner padding — the value the caller gives has to ride on the panel as it is. Without that the caller
	#    pads with a `padding()` box, the padding doubles, and the ellipsised text in a narrow box disappears entirely.
	var padded_face := GoStyle.hud_panel(pick_ink, 6.0, 5.0).get_theme_stylebox(&"panel")
	var plain_face := GoUi.skin().floating_box(GoTheme.BOX_HUD, pick_ink)
	check(padded_face.get_content_margin(SIDE_LEFT) == 6.0 and padded_face.get_content_margin(SIDE_RIGHT) == 6.0
		and padded_face.get_content_margin(SIDE_TOP) == 5.0 and padded_face.get_content_margin(SIDE_BOTTOM) == 5.0
		and hud_face.get_content_margin(SIDE_LEFT) == plain_face.get_content_margin(SIDE_LEFT)
		and hud_face.get_content_margin(SIDE_TOP) == plain_face.get_content_margin(SIDE_TOP),
		"hud_panel: the padding argument rides on the panel as-is, and the default keeps the skin's padding (given %s/%s · default %s/%s)"
			% [padded_face.get_content_margin(SIDE_LEFT), padded_face.get_content_margin(SIDE_TOP),
				hud_face.get_content_margin(SIDE_LEFT), hud_face.get_content_margin(SIDE_TOP)])
	icon_chip.free(); both_chip.free(); chip_button.free(); filled_button.free()
	# 🔑 The choice grid — colour swatch, icon and text cards. One pick only, the touch minimum per cell, and a thick accent border on the picked cell alone.
	var chosen := [-1]
	var grid := GoStyle.choice_grid([{"color": "ff0000", "tooltip": "Red"}, {"icon": GoIconSet.STAR, "text": "Star"}, "Plain"], 1,
		func(i: int) -> void: chosen[0] = i)
	root.add_child(grid); await frames(2)
	var cells := grid.get_children()
	var choice_group: ButtonGroup = grid.get_meta(&"group")
	check(cells.size() == 3 and choice_group.get_pressed_button() == cells[1], "choice_grid: 3 cells · the second picked")
	(cells[0] as Button).button_pressed = true
	(cells[0] as Button).pressed.emit()
	check(chosen[0] == 0 and choice_group.get_pressed_button() == cells[0], "choice_grid: only the pressed cell is picked · the callback index")
	var smallest := Vector2.INF
	for cell: Control in cells: smallest = smallest.min(cell.size)
	check(smallest.x >= GoUi.metric(GoTheme.TOUCH) - 0.5 and smallest.y >= GoUi.metric(GoTheme.TOUCH) - 0.5,
		"choice_grid: every cell keeps the touch minimum (%.0f×%.0f)" % [smallest.x, smallest.y])
	var red_swatch := cells[0].find_child("Swatch", true, false) as Panel
	check((cells[0] as Button).tooltip_text == "Red" and red_swatch != null
		and (red_swatch.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.is_equal_approx(Color.RED), "choice_grid: a swatch keeps its real colour · the tooltip is its name")
	var picked_box := (cells[0] as Button).get_theme_stylebox(&"pressed")
	var idle_box := (cells[0] as Button).get_theme_stylebox(&"normal")
	check(near(picked_box.get_margin(SIDE_LEFT), idle_box.get_margin(SIDE_LEFT)), "choice_grid: picking keeps the cell padding the same (nothing wobbles)")
	var picked_flat := picked_box as StyleBoxFlat
	check(picked_flat == null or (picked_flat.border_color.is_equal_approx(GoUi.color(GoTheme.ACCENT))
		and picked_flat.border_width_left > (idle_box as StyleBoxFlat).border_width_left), "choice_grid: the picked cell gets a thicker accent border")
	var captions := cells[2].find_children("Caption", "Label", true, false)
	check(captions.size() == 1 and (captions[0] as Label).text == "Plain" and cells[1].find_child("Caption", true, false) != null,
		"choice_grid: text cards and icon cards carry a name label")
	grid.queue_free()
	var glass: StyleBox = GoUi.skin().overlay_box(4, 2)
	check(near(glass.get_margin(SIDE_LEFT), 4.0) and near(glass.get_margin(SIDE_TOP), 2.0), "overlay_box: the given padding stands")
	var glass_default: StyleBox = GoUi.skin().overlay_box()
	check(near(glass_default.get_margin(SIDE_LEFT), GoUi.metric(GoTheme.COMPACT_PADDING_X)), "overlay_box: with no padding given it takes the compact button padding token")
	var glass_flat := glass_default as StyleBoxFlat
	# 🛑 No number is hard-coded — the fill's alpha is set by the theme's `hud_alpha` token and may differ per palette.
	var glass_want := GoUi.surface_alpha(GoTheme.BOX_HUD)
	check(glass_flat == null or (is_equal_approx(glass_flat.bg_color.a, glass_want) and glass_flat.border_width_left == 1),
		"overlay_box: fill alpha = the hud_alpha token (%.2f) · border 1" % glass_want)
	var glass_fixed := GoUi.skin().overlay_box(-1, -1, 0.5) as StyleBoxFlat
	check(glass_fixed == null or is_equal_approx(glass_fixed.bg_color.a, 0.5),
		"overlay_box: give the alpha directly and that value stands")
	# 🔑 The pill panel container over map or world artwork — the caller never builds the panel.
	var overlay := GoStyle.overlay_panel(4, 2)
	var overlay_face := overlay.get_theme_stylebox(&"panel")
	check(overlay is PanelContainer and overlay_face != null
		and near(overlay_face.get_margin(SIDE_LEFT), 4.0) and near(overlay_face.get_margin(SIDE_TOP), 2.0),
		"overlay_panel: a container wearing the pill panel · the padding is exactly what was given")
	# 🛑 Each of the four sides on its own — a pill whose right end is a touch-sized icon button and so needs no panel padding (a map legend · ?).
	GoStyle.face_insets(overlay_face, -1.0, -1.0, 0.0, -1.0)
	check(near(overlay_face.get_margin(SIDE_RIGHT), 0.0) and near(overlay_face.get_margin(SIDE_LEFT), 4.0),
		"face_insets: only the sides given change and sides passed negative stay (left %.1f · right %.1f)"
			% [overlay_face.get_margin(SIDE_LEFT), overlay_face.get_margin(SIDE_RIGHT)])
	# 🔑 Token variants of a floating panel — `hud` for a HUD dock, `card` for a sheet spread over the world.
	var sheet_face := GoStyle.hud_panel(pick_ink, -1.0, -1.0, GoTheme.BOX_CARD).get_theme_stylebox(&"panel")
	check(sheet_face != null and sheet_face.get_class()
		== GoUi.skin().floating_box(GoTheme.BOX_CARD, pick_ink).get_class()
		and near(sheet_face.get_margin(SIDE_LEFT),
			GoUi.skin().floating_box(GoTheme.BOX_CARD, pick_ink).get_margin(SIDE_LEFT)),
		"hud_panel(variant): it raises the card variant · the padding stays the skin's")
	# 🔑 A badge whose tone colour changes with its value — the panel is re-applied without rebuilding the node.
	var restyled := GoStyle.hud_panel()
	GoStyle.style_hud_panel(restyled, GoUi.color(GoTheme.DANGER))
	check(restyled.get_theme_stylebox(&"panel") != null
		and GoSkin.box_background(restyled.get_theme_stylebox(&"panel")) != Color.TRANSPARENT,
		"style_hud_panel: it re-applies to a panel container that already exists")
	# 🔑 The round control button — six states · zero padding · radius half the diameter · only the pressed state filled with the tone colour.
	var orb := Button.new()
	GoStyle.style_disc_button(orb, 48.0, GoUi.color(GoTheme.ACCENT), GoUi.color(GoTheme.SURFACE))
	var orb_normal := orb.get_theme_stylebox(&"normal") as StyleBoxFlat
	var orb_pressed := orb.get_theme_stylebox(&"pressed") as StyleBoxFlat
	var orb_focus := orb.get_theme_stylebox(&"focus") as StyleBoxFlat
	check(orb.get_theme_stylebox(&"disabled") != null and orb_normal != null and orb_pressed != null and orb_focus != null
		and orb_normal.corner_radius_top_left == 24 and near(orb_normal.get_margin(SIDE_LEFT), 0.0)
		and orb_pressed.bg_color.is_equal_approx(Color(GoUi.color(GoTheme.ACCENT), 0.34))
		and orb_focus.border_width_left > orb_normal.border_width_left,
		"style_disc_button: six states · radius %d · zero padding · the tone colour when pressed · a thicker border on focus alone"
			% orb_normal.corner_radius_top_left)
	# 🔑 A box where the text itself is the icon — font and text move together and the width is measured without asking the node back.
	# 🛑 The built-in set is textures and has no glyphs (`glyph()` returns an empty string) — a font set is built to try it.
	var font_icons := GoIconSet.new()
	font_icons.font = ThemeDB.fallback_font
	var probe_codes: Dictionary[StringName, int] = {&"probe_list": 0x41, &"probe_down": 0x42}
	font_icons.codepoints = probe_codes
	var mark_button := Button.new()
	GoStyle.glyph_text(mark_button, [&"probe_list", &"probe_down"], 16, Color.TRANSPARENT, font_icons)
	var mark_width := GoStyle.glyph_width([&"probe_list", &"probe_down"], 16, font_icons)
	var one_width := GoStyle.glyph_width([&"probe_list"], 16, font_icons)
	check(mark_button.text == "A B" and mark_button.has_theme_font_override(&"font")
		and mark_button.get_theme_font_size(&"font_size") == 16 and mark_width > one_width,
		"glyph_text: it joins two glyphs with one space · glyph_width measures that width (text %s · %.1f > %.1f)"
			% [mark_button.text, mark_width, one_width])
	# 🛑 `font_role` changes the size only and leaves the variation alone — erasing the icon font returns it to ordinary text.
	mark_button.theme_type_variation = GoTheme.VAR_COMPACT_BUTTON
	GoStyle.font_role(mark_button, GoTheme.ROLE_CAPTION)
	check(not mark_button.has_theme_font_override(&"font")
		and mark_button.get_theme_font_size(&"font_size") == GoUi.font_size(GoTheme.ROLE_CAPTION)
		and mark_button.theme_type_variation == GoTheme.VAR_COMPACT_BUTTON,
		"font_role: it erases the icon font and applies the role size only · the variation is untouched")
	# 🔑 A card's accent border and padding — to make one card in a list stand out (the last thing picked, a warning that must be read).
	var quiet_card := GoStyle.card(pick_ink)
	var loud_card := GoStyle.card(pick_ink, 0.9, 3.0, 7.0)
	var plain_card := GoStyle.card()
	var quiet_card_face := quiet_card.get_theme_stylebox(&"panel") as StyleBoxFlat
	var loud_card_face := loud_card.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(quiet_card_face != null and loud_card_face != null
		and loud_card_face.border_width_top == 3 and loud_card_face.border_width_top > quiet_card_face.border_width_top
		and near(loud_card_face.border_color.a, 0.9, 0.01) and near(loud_card_face.get_margin(SIDE_LEFT), 7.0)
		# 🔑 A card with no argument gets no accent border — the check that such a card wears **panel alpha only** lives in
		#    the `container alpha` section. Measured on the border the accent paints (the fill was a false yardstick: it
		#    only differed while `card()` wore the engine's bare face).
		and not (plain_card.get_theme_stylebox(&"panel") is StyleBoxFlat
			and (plain_card.get_theme_stylebox(&"panel") as StyleBoxFlat).border_width_top == 3
			and near((plain_card.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color.r, loud_card_face.border_color.r, 0.001)),
		"card(accent): border width %d · strength %.2f · padding %.0f come from the arguments · a card with no argument gets none of that accent"
			% [loud_card_face.border_width_top, loud_card_face.border_color.a, loud_card_face.get_margin(SIDE_LEFT)])
	# 🔑 The plate laid behind — it overrides only the values given, has zero shadow and padding, and lets input through.
	var backdrop := GoStyle.plate(GoTheme.BOX_HUD, Color(pick_ink, 0.14), Color(pick_ink, 0.36), 8.0, 1.0)
	var backdrop_face := backdrop.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(backdrop is Panel and backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE and backdrop_face != null
		and near(backdrop_face.bg_color.a, 0.14, 0.01) and near(backdrop_face.border_color.a, 0.36, 0.01)
		and backdrop_face.border_width_top == 1 and backdrop_face.corner_radius_top_left == 8
		and backdrop_face.shadow_size == 0 and near(backdrop_face.get_margin(SIDE_LEFT), 0.0),
		"plate: fill, border and radius come from the arguments · zero shadow and padding · input passes through")
	# 🔑 The same disc applied to a box, a label and an existing panel (a ▶ mark, a number badge, a preview that changes colour).
	var well := GoStyle.disc_panel(36.0, pick_ink, 0.12, 0.42)
	var well_face := well.get_theme_stylebox(&"panel") as StyleBoxFlat
	var index_badge := Label.new()
	GoStyle.style_disc_label(index_badge, 18.0, pick_ink, 0.92, 1.0)
	var index_face := index_badge.get_theme_stylebox(&"normal") as StyleBoxFlat
	var repainted := Panel.new()
	GoStyle.style_disc_panel(repainted, 36.0, GoUi.color(GoTheme.DANGER))
	check(well.custom_minimum_size == Vector2(36, 36) and well.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and well_face != null and index_face != null and near(well_face.bg_color.a, 0.12, 0.01)
		and well_face.corner_radius_top_left > 0 and near(index_face.bg_color.a, 0.92, 0.01)
		and repainted.get_theme_stylebox(&"panel") != null,
		"disc_panel · style_disc_label · style_disc_panel: one disc onto a box, a label and an existing panel")
	# 🔑 Where a whole card is the tap target — it draws no panel and tints faintly on hover and press alone.
	var tap_area := Button.new()
	GoStyle.style_overlay_button(tap_area, pick_ink, 0.10)
	var tap_idle := tap_area.get_theme_stylebox(&"normal") as StyleBoxFlat
	var tap_lit := tap_area.get_theme_stylebox(&"hover") as StyleBoxFlat
	check(tap_idle != null and tap_lit != null and tap_idle.border_width_top == 0
		and tap_idle.shadow_size == 0 and near(tap_idle.get_margin(SIDE_LEFT), 0.0)
		and not tap_idle.draw_center and tap_lit.draw_center and near(tap_lit.bg_color.a, 0.10, 0.01)
		and tap_area.get_theme_stylebox(&"pressed") != null and tap_area.get_theme_stylebox(&"disabled") != null,
		"style_overlay_button: zero border, shadow and padding · nothing drawn at rest, a faint fill on hover and press only")
	# 🔑 The shadow of text over the world — an axis passed negative keeps the value the theme set.
	var lit_text := Label.new()
	GoStyle.text_shadow(lit_text)
	check(lit_text.has_theme_color_override(&"font_shadow_color")
		and lit_text.get_theme_constant(&"shadow_offset_y") == 1
		and not lit_text.has_theme_constant_override(&"shadow_offset_x"),
		"text_shadow: the shadow colour + one step vertically · an axis passed negative stays the theme's")
	overlay.free(); restyled.free(); orb.free(); mark_button.free()
	quiet_card.free(); loud_card.free(); plain_card.free(); backdrop.free()
	well.free(); index_badge.free(); repainted.free(); tap_area.free(); lit_text.free()
	var bar := GoStyle.tabs(["One", "Two", "Three"], 1)
	check(bar is TabBar and bar.tab_count == 3 and bar.current_tab == 1 and bar.custom_minimum_size.y == GoUi.metric(GoTheme.TOUCH), "tabs: 3 tabs · the second selected · touch height")
	var crumbs := GoStyle.breadcrumb(["Home", "Inventory", "Weapons"])
	check(crumbs.get_child_count() == 5 and crumbs.get_child(4) is Label and crumbs.get_child(0) is Button, "breadcrumb: 3 items + 2 separators · the last is a label")
	check((crumbs.get_child(4) as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (crumbs.get_child(0) as Button).autowrap_mode == TextServer.AUTOWRAP_OFF, "breadcrumb: item wrapping off (natural width)")
	var area := GoStyle.textarea("hint", 3)
	check(area is TextEdit and area.placeholder_text == "hint" and area.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY and area.custom_minimum_size.y > GoUi.font_size(GoTheme.ROLE_BODY) * 3, "textarea: placeholder · wrapping · three lines high")
	var av := GoStyle.avatar("Ada Lovelace", 40)
	check(av.custom_minimum_size == Vector2(40, 40) and av.get_child(0) is Label and (av.get_child(0) as Label).text == "AL", "avatar: 40 · the initials AL")
	var sk := GoStyle.skeleton(0, 12)
	check(sk.size_flags_horizontal == Control.SIZE_EXPAND_FILL and sk.custom_minimum_size.y == 12, "skeleton: fills horizontally · height")
	var al := GoStyle.alert("saved", GoTheme.SUCCESS)
	var al_row := al.get_child(0)
	check(al is PanelContainer and al_row.get_child_count() == 2 and al_row.get_child(1) is Label and (al_row.get_child(1) as Label).text == "saved", "alert: icon + text")
	var tb := GoStyle.table(["A", "B"], [["1", "2"], ["3", "4"]])
	check(tb.columns == 2 and tb.get_child_count() == 6 and (tb.get_child(0) as Label).uppercase, "table: 2 columns · 2 headers + 4 cells · headers upper-cased")
	var lb := GoStyle.list_button(GoIconSet.SETTINGS, "Settings", Callable(), Color.TRANSPARENT, "", false, GoIconSet.CHEVRON_RIGHT)
	var line := lb.get_child(0).get_child(0)
	check(line.get_child_count() == 3 and (line.get_child(2) as Control).size_flags_vertical == Control.SIZE_SHRINK_CENTER, "list_button trailing: a chevron at the end of the row · vertically centred")
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
	# 🛑 **An inner class is one of our own names too.** Leave out what a file declares inside itself, such as
	#    `class Ticket extends RefCounted`, and the lines using it are wrongly flagged as "an external symbol leaning on the host project"
	#    (2026-09-16: `GoDialogs.Ticket` and `GoSnackbar.Ticket` were caught that way).
	var declared := RegEx.create_from_string("^\\s*(?:class_name\\s+|class\\s+|enum\\s+|const\\s+)([A-Z][A-Za-z0-9_]*)")
	for path in _files(ADDON, ["gd"]):
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			var found := declared.search(raw)
			if found != null: known[found.get_string(1)] = true
	return known


## 🛑 **Not everything in the repository is the add-on.** These two never go into the release yet look like add-on
##    code, so scanning them breaks the checks **in both directions**.
##      · `builds/` — unpacked copies of older versions left behind by `package.sh`. The `examples/demo/` inside them
##        does not match `_standalone`'s exclusion path (`ADDON + "/examples/demo/"`) as a string, so it is never filtered out and
##        **invents failures that do not exist** (measured 2026-09-16: 498/499, and 499/499 once removed).
##      · `examples/usage/` — **a separate project** that installs the add-on to try it (it has its own `project.godot`).
##        A `res://` inside it points at that root, and its copy of the add-on lags behind, so
##        `_own_symbols()` **grants "our own" status even to names already deleted**, blunting the check.
const SKIP_DIRS := ["builds", "examples/usage"]


func _files(dir: String, extensions: Array) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension() in extensions: found.append(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("."): continue
		var path := dir.path_join(sub)
		# Read as a path relative to the add-on root — a subfolder with the same name is never filtered out by mistake.
		if SKIP_DIRS.has(path.trim_prefix(ADDON + "/")): continue
		found.append_array(_files(path, extensions))
	return found
