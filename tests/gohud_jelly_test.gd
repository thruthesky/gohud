## 🧪 **Checks for the jelly look** — `GoStyleBoxJelly`, the kids looks drawn with it, and the three skin hooks that dress
## a window's head and a press (`title_plate_box`, `dress_close_button`, `press_feedback`). Its own file, so it never
## clashes with the widgets other people are adding to `gohud_extra_test.gd`.
##
##   godot --headless --path <project> -s res://addons/gohud/tests/gohud_jelly_test.gd
##
## 🔑 The other looks must come through untouched — a hook that does nothing by default is checked to do nothing.
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.config.reduce_motion = true
	_box()
	await _kids_theme()
	await _kids_parts()
	await _window_head()
	await _title_fit()
	await _press()
	print("gohud jelly tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


func _margins(box: StyleBox) -> Array[float]:
	var out: Array[float] = []
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: out.append(box.get_margin(side))
	return out


## The face on its own: padding it copies and keeps, the colours it derives, the room it reports.
func _box() -> void:
	var flat := StyleBoxFlat.new()
	flat.content_margin_left = 16
	flat.content_margin_top = 8.5
	flat.content_margin_right = 16
	flat.content_margin_bottom = 11.5
	var jelly := GoStyleBoxJelly.new().keep_margins(flat)
	check(_margins(jelly) == _margins(flat), "box: keep_margins copies every side (%s)" % str(_margins(jelly)))
	jelly.lip = 4.0
	jelly.pad(12.0, 10.0)
	check(is_equal_approx(jelly.content_margin_top + jelly.content_margin_bottom, 20.0),
		"box: pad() keeps the vertical sum (%.1f + %.1f)" % [jelly.content_margin_top, jelly.content_margin_bottom])
	check(jelly.content_margin_top < jelly.content_margin_bottom, "box: pad() lifts the label by half the lip")
	jelly.bg_color = Color("#FFFFFF")
	jelly.border_color = Color("#22704A")
	check(jelly.edge() == Color("#22704A"), "box: an outline colour given is the one drawn")
	check(not jelly.shade().is_equal_approx(Color("#FFFFFF")) and jelly.shade().g > jelly.shade().r,
		"box: the band leans towards the outline, not grey (%s)" % jelly.shade().to_html(false))
	var auto := GoStyleBoxJelly.new()
	auto.bg_color = Color("#FFAA00")
	check(auto.edge().get_luminance() < auto.bg_color.get_luminance(), "box: without an outline colour, a deep shade of the body")
	var copy := jelly.duplicate() as GoStyleBoxJelly
	check(copy != null and copy.lip == jelly.lip and copy.bg_color == jelly.bg_color, "box: duplicate() keeps the face")
	jelly.shadow_color = Color(0, 0, 0, 0.3)
	jelly.shadow_size = 6
	var rect := Rect2(0, 0, 100, 40)
	check(jelly._get_draw_rect(rect).encloses(rect.grow(6)), "box: the draw rect makes room for the shadow")
	jelly.expand_margin_left = -4.0
	check(jelly._get_draw_rect(Rect2(0, 0, 100, 40)).position.x > -7.0, "box: a negative expand margin shrinks what is drawn")
	check(jelly.get_minimum_size() == Vector2(jelly.content_margin_left + jelly.content_margin_right,
		jelly.content_margin_top + jelly.content_margin_bottom), "box: the minimum size is the padding — the lip adds nothing")


## The kids themes are drawn with it; the other looks are not.
func _kids_theme() -> void:
	for id: StringName in [&"kids_light", &"kids_dark"]:
		GoUi.use_preset(id)
		var theme := GoUi.theme()
		for spot: Array in [[&"Button", &"normal"], [&"GoPrimaryButton", &"normal"], [&"GoListButton", &"normal"],
				[&"LineEdit", &"normal"], [&"ProgressBar", &"fill"], [&"GoPanel", &"panel"], [&"GoHud", &"hud"]]:
			check(theme.get_stylebox(spot[1], spot[0]) is GoStyleBoxJelly, "%s: %s/%s is jelly" % [id, spot[0], spot[1]])
		var down := theme.get_stylebox(&"pressed", &"GoPrimaryButton") as GoStyleBoxJelly
		check(down != null and down.pressed, "%s: a pressed key is a sunk jelly" % id)
		var well := theme.get_stylebox(&"normal", &"LineEdit") as GoStyleBoxJelly
		check(well != null and well.sunken, "%s: a text field is a well" % id)
		# A key keeps its size from state to state — no jump as it is pressed.
		var key := GoStyle.button("Play", Callable(), GoStyle.Tone.PRIMARY)
		root.add_child(key)
		await frames(2)
		var heights: Array[float] = []
		for state in [&"normal", &"hover", &"pressed"]:
			heights.append(key.get_theme_stylebox(state).get_minimum_size().y)
		check(heights.max() - heights.min() < 0.01, "%s: a key's face is the same height in every state %s" % [id, str(heights)])
		key.queue_free()
		check(GoUi.skin() is GoSkinKids, "%s: the skin is the kids skin" % id)
		check(GoUi.skin().title_plate_box() is GoStyleBoxJelly, "%s: a window title gets a ribbon" % id)
	for id: StringName in [&"default_light", &"default_dark", &"scifi_dark", &"medieval_light", &"material_light"]:
		GoUi.use_preset(id)
		check(not (GoUi.theme().get_stylebox(&"normal", &"Button") is GoStyleBoxJelly), "%s: keys are not jelly" % id)
		check(GoUi.skin().title_plate_box() == null, "%s: no title ribbon" % id)
	await frames(1)


## The parts the kids skin draws in code.
func _kids_parts() -> void:
	GoUi.use_preset(&"kids_light")
	var skin := GoUi.skin()
	var idle := skin.slot_box(GoUi.color(GoTheme.INFO), false) as GoStyleBoxJelly
	var lit := skin.slot_box(GoUi.color(GoTheme.INFO), true) as GoStyleBoxJelly
	check(idle != null and not idle.pressed, "parts: a quick slot is a candy")
	check(lit != null and lit.pressed, "parts: a cooling slot is pressed in")
	var none: Array[float] = [0.0, 0.0, 0.0, 0.0]
	check(idle != null and _margins(idle) == none, "parts: a slot face has no padding (the slot lays it out)")
	var badge := skin.badge_box(GoUi.color(GoTheme.DANGER)) as StyleBoxFlat
	check(badge != null and badge.corner_radius_top_left >= 99, "parts: a badge is a round sticker")
	var disc := skin.disc_box(40.0, GoUi.color(GoTheme.INFO)) as GoStyleBoxJelly
	check(disc != null and disc.radius >= 19.0, "parts: a disc is a round candy (%s)" % (disc.radius if disc else -1.0))
	var first := skin.segment_box(0, 3, &"normal") as StyleBoxFlat
	var middle := skin.segment_box(1, 3, &"normal") as StyleBoxFlat
	check(first != null and middle != null and first.corner_radius_top_left > 0 and middle.corner_radius_top_left == 0,
		"parts: a segmented row is one flat block, round at its ends")
	var chip := skin.chip_box(GoUi.color(GoTheme.SUCCESS)) as GoStyleBoxJelly
	check(chip != null and chip.radius <= 13.0, "parts: a chip is a jelly with a radius the cell audit can satisfy")
	var alert := skin.alert_box(GoUi.color(GoTheme.DANGER))
	check(alert is GoStyleBoxJelly and (alert as GoStyleBoxJelly).border_color.a >= 0.99,
		"parts: an alert is a sticker note with a solid rim")
	var floating := skin.floating_box(GoTheme.BOX_HUD) as GoStyleBoxJelly
	check(floating != null and floating.shadow_size > 0, "parts: a floating panel casts a shadow")
	# A colour check on the face actually painted still works (the readers look `bg_color` up).
	check(GoSkin.box_background(idle).a > 0.0, "parts: box_background reads a jelly")
	await frames(1)


func _surface(title: String) -> GoSurface:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var surface := GoSurface.new()
	surface.max_width = 300
	surface.set_title(title)
	layer.add_child(surface)
	return surface


## A window's head in the kids look, and back to plain when the look changes.
func _window_head() -> void:
	GoUi.use_preset(&"kids_light")
	var surface := _surface("Settings")
	await frames(3)
	var title := surface.title_label
	check(title.get_theme_stylebox(&"normal") is GoStyleBoxJelly, "head: the title sits on a ribbon")
	check(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "head: the title is centred on it")
	check(surface.close_button.get_theme_stylebox(&"normal") is GoStyleBoxJelly, "head: the close button is a candy")
	check(surface.close_button.icon_tint == Color.WHITE, "head: with a white cross")
	GoUi.use_preset(&"default_light")
	await frames(3)
	check(not title.has_theme_stylebox_override(&"normal"), "head: another look takes the ribbon off")
	check(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "head: and gives the title its own alignment back")
	check(not surface.close_button.has_theme_stylebox_override(&"normal") and surface.close_button.icon_tint.a == 0.0,
		"head: and the plain close button back")
	surface.get_parent().queue_free()
	# A host's own alignment, set before the window opens, comes back when the ribbon goes.
	GoUi.use_preset(&"kids_light")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var own := GoSurface.new()
	own.set_title("Mine")
	own.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(own)
	await frames(2)
	check(own.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "head: on the ribbon the host's title is centred")
	GoUi.use_preset(&"default_light")
	await frames(3)
	check(own.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"head: a title the host aligned keeps that alignment once the ribbon goes")
	own.get_parent().queue_free()
	await frames(1)


## On a ribbon a long title shrinks to stay on one line; a short one keeps its size.
func _title_fit() -> void:
	GoUi.use_preset(&"kids_light")
	var long := _surface("A rather long window title that needs the room")
	var short := _surface("Hi")
	await frames(4)
	var natural := GoUi.font_size(long.title_label.get_meta(&"go_text_role", GoTheme.ROLE_SUBTITLE))
	var size := long.title_label.get_theme_font_size(&"font_size")
	check(size < natural and size >= GoUi.skin().title_plate_min_size(),
		"fit: a long title shrinks (%d < %d, not below %d)" % [size, natural, GoUi.skin().title_plate_min_size()])
	check(not short.title_label.has_theme_font_size_override(&"font_size"), "fit: a short title keeps its size")
	long.get_parent().queue_free()
	short.get_parent().queue_free()
	GoUi.use_preset(&"default_light")
	var plain := _surface("A rather long window title that needs the room")
	await frames(3)
	check(not plain.title_label.has_theme_font_size_override(&"font_size"), "fit: without a ribbon nothing shrinks")
	plain.get_parent().queue_free()
	await frames(1)


## The press hook: connected once; the default does nothing; headless runs keep the real rectangle.
func _press() -> void:
	GoUi.use_preset(&"default_light")
	var key := GoStyle.button("Go")
	GoStyle.press_feel(key)
	GoStyle.press_feel(key)
	check(key.button_down.get_connections().size() == 1, "press: press_feel connects once (%d)" % key.button_down.get_connections().size())
	root.add_child(key)
	await frames(1)
	key.button_down.emit()
	await frames(2)
	check(key.scale == Vector2.ONE, "press: the default look leaves the button as it is")
	GoUi.use_preset(&"kids_light")
	key.button_down.emit()
	await frames(2)
	check(key.scale == Vector2.ONE, "press: a headless run keeps the real rectangle (no squish to measure)")
	var slot := GoSlot.new()
	check(slot.button_down.get_connections().size() >= 1, "press: a quick slot hands its press to the look")
	var icon := GoIconButton.new()
	check(icon.button_down.get_connections().size() >= 1, "press: an icon button hands its press to the look")
	slot.free()
	icon.free()
	key.queue_free()
	await frames(1)
