## 🧪 **Checks for the painted controls** — the widgets that draw Magnet Mayhem's painted controls the game's way:
## `GoSlider` (the fill past the handle, the held handle), `GoSwitch` (the centred pill and its captions) and
## `GoMapPreview` (shapes, links and start dots fitted into a well). Each runs in arcade_light (the game's art) and in
## a plain look (the fallbacks: no art, no errors).
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_painted_controls_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	GoUi.config.reduce_motion = true
	for look: StringName in [GoThemePresets.ARCADE_LIGHT, GoThemePresets.DEFAULT_DARK]:
		GoUi.use_preset(look)
		await frames(1)
		await _slider(look)
		await _switch(look)
		await _map_preview(look)
		await _focus(look)
	await _focus_follows_look()
	await _rtl_caption()
	GoUi.reset()
	print("gohud painted controls tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func frames(count: int) -> void:
	for i in count: await process_frame


## A Control under the look's theme, as a screen that sets `theme = GoUi.theme()` holds its widgets.
func _holder() -> Control:
	var holder := Control.new()
	holder.theme = GoUi.theme()
	holder.size = Vector2(400, 200)
	root.add_child(holder)
	return holder


# ── Slider ─────────────────────────────────────────────────────────────

func _slider(look: StringName) -> void:
	var holder := _holder()
	var slider := GoSlider.make(0.0, 1.0, 0.01)
	slider.value = 0.5
	holder.add_child(slider)
	slider.size = Vector2(260, 44)
	await frames(2)
	var handle := slider.handle_size()
	check(handle.x > 0.0 and handle.y > 0.0, "%s slider: the handle has a size (%s)" % [look, handle])
	check(is_equal_approx(slider.handle_center_x(), handle.x * 0.5 + 0.5 * (260.0 - handle.x)),
		"%s slider: the handle's edge touches each end (centre %.1f)" % [look, slider.handle_center_x()])
	var least := slider.get_combined_minimum_size()
	check(least.x >= GoSlider.MIN_WIDTH and least.y >= maxf(float(GoUi.metric(GoTheme.TOUCH)), handle.y),
		"%s slider: the least size is room to travel and a touch target (%s)" % [look, least])
	var bar := slider.bar_rect()
	check(is_equal_approx(bar.size.x, 260.0) and is_equal_approx(bar.get_center().y, slider.size.y * 0.5),
		"%s slider: the track spans the width, centred (%s)" % [look, bar])
	var fill := slider.fill_rect()
	check(is_equal_approx(fill.size.x, slider.handle_center_x() + GoSlider.FILL_PAST),
		"%s slider: the fill ends %.0f past the handle's centre (%.1f)" % [look, GoSlider.FILL_PAST, fill.size.x])
	slider.value = 0.0
	check(slider.fill_rect().size.x >= bar.size.y - 0.01, "%s slider: at the minimum the fill is a whole pill" % look)
	slider.value = 1.0
	check(is_equal_approx(slider.fill_rect().end.x, minf(260.0 - handle.x * 0.5 + GoSlider.FILL_PAST, 260.0)),
		"%s slider: at the maximum the fill still ends under the handle, never past the end" % look)
	check(slider.get_theme_icon(&"grabber").get_width() == int(handle.x) and slider.get_theme_stylebox(&"slider") is StyleBoxEmpty,
		"%s slider: the engine's own drawing is blanked, the grabber keeps the handle's width" % look)
	check(slider.part(&"slider") != null and not (slider.part(&"slider") is StyleBoxEmpty),
		"%s slider: the theme's track is kept to draw" % look)
	# The handle grows while it is held.
	slider.value = 0.5
	var resting := slider.handle_rect()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(slider.handle_center_x(), slider.size.y * 0.5)
	slider._gui_input(press)
	var held := slider.handle_rect()
	check(is_equal_approx(held.size.x, resting.size.x * GoSlider.HELD_SCALE) and held.get_center().is_equal_approx(resting.get_center()),
		"%s slider: a held handle grows %.2f× about its centre" % [look, GoSlider.HELD_SCALE])
	press.pressed = false
	slider._gui_input(press)
	check(slider.handle_rect().is_equal_approx(resting), "%s slider: let go, it shrinks back" % look)
	# A fill variation: the green fill on arcade_light.
	if look == GoThemePresets.ARCADE_LIGHT:
		var blue := slider.part(&"grabber_area")
		slider.theme_type_variation = &"GoSliderGreen"
		await frames(1)
		check(slider.part(&"grabber_area") != blue and slider.part(&"grabber_area") != null,
			"%s slider: GoSliderGreen gives its own fill" % look)
		check(slider.part(&"slider") != null and not (slider.part(&"slider") is StyleBoxEmpty),
			"%s slider: the variation keeps HSlider's track" % look)
	# The look changes: the parts are read again.
	var before := slider.part(&"slider")
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)
	holder.theme = GoUi.theme()
	await frames(1)
	check(slider.part(&"slider") != before, "%s slider: a new look's track is read again" % look)
	GoUi.use_preset(look)
	holder.queue_free()
	await frames(1)


# ── Switch ─────────────────────────────────────────────────────────────

func _switch(look: StringName) -> void:
	var holder := _holder()
	var flip := GoSwitch.make(false)
	holder.add_child(flip)
	flip.size = Vector2(200, 44)
	await frames(2)
	var pill := flip.pill_size()
	check(pill.x > 0.0 and pill.y > 0.0, "%s switch: the pill has a size (%s)" % [look, pill])
	check(flip.switch_rect().position == ((flip.size - pill) * 0.5).floor(),
		"%s switch: with no label the pill stands centred, on whole pixels (%s)" % [look, flip.switch_rect()])
	check(flip.get_combined_minimum_size().x >= pill.x + 8.0 and flip.get_combined_minimum_size().y >= float(GoUi.metric(GoTheme.TOUCH)),
		"%s switch: the least size is the pill and a touch target (%s)" % [look, flip.get_combined_minimum_size()])
	check(flip.get_theme_stylebox(&"normal") is StyleBoxEmpty and flip.get_theme_icon(&"checked").get_height() == 1,
		"%s switch: the engine's own drawing is blanked" % look)
	check(flip.part(&"checked") != null and flip.part(&"unchecked") != null and flip.part(&"checked") != flip.get_theme_icon(&"checked"),
		"%s switch: the theme's pills are kept to draw" % look)
	check(flip.pill_texture() == flip.part(&"unchecked"), "%s switch: off draws the unchecked pill" % look)
	flip.button_pressed = true
	check(flip.pill_texture() == flip.part(&"checked"), "%s switch: on draws the checked pill" % look)
	flip.disabled = true
	check(flip.pill_texture() == flip.part(&"checked_disabled") or flip.part(&"checked_disabled") == null,
		"%s switch: disabled draws the disabled pill" % look)
	flip.disabled = false
	# Captions: centred in the half the knob is not on, shrunk so the longer one fits.
	flip.set_texts("ON", "OFF")
	check(flip.caption() == "ON", "%s switch: on reads the on caption" % look)
	var room := flip.caption_room()
	check(is_equal_approx(room, pill.x - pill.y * GoSwitch.KNOB_SHARE - 2.0 * GoSwitch.TEXT_EDGE),
		"%s switch: the caption's room is the pill less the knob and two edges (%.1f)" % [look, room])
	check(flip.caption_font_size() == GoSwitch.TEXT_SIZE or room < 30.0, "%s switch: a short caption keeps its size" % look)
	var at := flip.caption_position()
	var width := flip.caption_width()
	var on_left := flip.switch_rect().position.x + GoSwitch.TEXT_EDGE
	check(is_equal_approx(at.x, on_left + (room - width) * 0.5),
		"%s switch: on, the caption is centred left of the knob (%.1f)" % [look, at.x])
	flip.button_pressed = false
	var off_left := flip.switch_rect().position.x + pill.y * GoSwitch.KNOB_SHARE + GoSwitch.TEXT_EDGE
	check(is_equal_approx(flip.caption_position().x, off_left + (room - flip.caption_width()) * 0.5),
		"%s switch: off, the caption is centred right of the knob" % look)
	flip.set_texts("EINGESCHALTET", "AUS")
	var fitted := flip.caption_font_size()
	check(fitted < GoSwitch.TEXT_SIZE and fitted >= GoStyle.fit_floor(GoSwitch.TEXT_SIZE),
		"%s switch: a long caption shrinks, never under the floor (%d)" % [look, fitted])
	# With a label the pill stands where the engine puts the check icon: at the far end.
	flip.text = "Music"
	await frames(1)
	check(is_equal_approx(flip.switch_rect().end.x, flip.size.x), "%s switch: with a label the pill sits at the end" % look)
	flip.text = ""
	# A new look: the pills are read again.
	var before := flip.part(&"checked")
	GoUi.use_preset(GoThemePresets.DEFAULT_LIGHT)
	holder.theme = GoUi.theme()
	await frames(1)
	check(flip.part(&"checked") != before, "%s switch: a new look's pills are read again" % look)
	GoUi.use_preset(look)
	holder.queue_free()
	await frames(1)


# ── Map preview ────────────────────────────────────────────────────────

func _map_preview(look: StringName) -> void:
	var holder := _holder()
	var map := GoMapPreview.new()
	holder.add_child(map)
	map.size = Vector2(100, 60)
	await frames(1)
	check(map.clip_contents, "%s map: clips to its box, as the game's MapPreview" % look)
	check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s map: the press goes to the card under it" % look)
	check(map.map_scale() == 0.0, "%s map: with no areas nothing is fitted" % look)
	check(map.background_box() is StyleBoxFlat, "%s map: the flat dark box is the default background" % look)
	# Two areas 25 x 10 world units overall (-5..20 by -5..5): fitted into the box less the padding, centred.
	map.add_rect(Vector2(0, 0), Vector2(5, 5), Color.RED)
	map.add_circle(Vector2(15, 0), 5.0, Color.BLUE)
	map.add_link(Vector2(0, 0), Vector2(15, 0), 2.0, Color.GREEN)
	map.set_starts(PackedVector2Array([Vector2(0, 0), Vector2(15, 0)]))
	await frames(1)
	var room := map.size - Vector2.ONE * GoMapPreview.PADDING * 2.0
	check(is_equal_approx(map.map_scale(), minf(room.x / 25.0, room.y / 10.0)),
		"%s map: the areas' bounds fill the room inside the padding (%.2f)" % [look, map.map_scale()])
	check(map.to_canvas(Vector2(7.5, 0)).is_equal_approx(map.size * 0.5),
		"%s map: the bounds' centre lands on the box's centre (%s)" % [look, map.to_canvas(Vector2(7.5, 0))])
	check(map.area_count() == 2 and map.link_count() == 1 and map.start_count() == 2,
		"%s map: the areas, links and starts are kept" % look)
	check(map.area_color(0) == Color.RED and map.link_color(0) == Color.GREEN, "%s map: unlocked, each part has its colour" % look)
	map.locked = true
	check(map.area_color(0) == GoMapPreview.LOCKED_AREA and map.link_color(0) == GoMapPreview.LOCKED_LINK,
		"%s map: locked, the parts turn the grey silhouette" % look)
	check(not map.starts_shown(), "%s map: locked, the starts are hidden" % look)
	map.locked = false
	check(map.starts_shown(), "%s map: unlocked, the starts show" % look)
	# A free polygon counts in the bounds too.
	map.add_polygon(PackedVector2Array([Vector2(0, 20), Vector2(10, 20), Vector2(5, 25)]), Color.WHITE)
	await frames(1)
	check(is_equal_approx(map.map_scale(), minf(room.x / 25.0, room.y / 30.0)),
		"%s map: a polygon widens the bounds (%.2f)" % [look, map.map_scale()])
	# The well: the theme's GoWell where it has one, with the well's wider padding.
	map.set_well()
	await frames(1)
	var has_well := GoUi.theme().has_stylebox(&"panel", &"GoWell")
	check(map.padding == GoMapPreview.WELL_PADDING, "%s map: the well keeps more room round the map" % look)
	check(not has_well or map.background_box() == GoUi.theme().get_stylebox(&"panel", &"GoWell"),
		"%s map: the well is the theme's GoWell" % look)
	map.show_background = false
	check(map.background_box() == null, "%s map: with no background nothing is drawn behind" % look)
	map.clear()
	await frames(1)
	check(map.area_count() == 0 and map.link_count() == 0 and map.start_count() == 0 and map.map_scale() == 0.0,
		"%s map: clear() empties it" % look)
	holder.queue_free()
	await frames(1)


# ── Focus ──────────────────────────────────────────────────────────────

## The controls a look builds. arcade_light's are FOCUS_NONE like the game's (GlossButton, PaintedSlider, PaintedSwitch,
## StageCard, OptionButton); every other look keeps them in the keyboard and gamepad order.
func _focused_controls() -> Array[Control]:
	return [GoGlyphButton.make("Play", &"play"), GoSlider.make(), GoSwitch.make(), GoLevelCard.make("STAGE 1", "", GoLevelCard.State.OPEN),
		GoStyle.button("Play"), GoStyle.toggle("Sound"), GoStyle.checkbox("Sound"), GoStyle.slider(), GoStyle.picker()]


func _focus(look: StringName) -> void:
	var painted := look == GoThemePresets.ARCADE_LIGHT
	var want := Control.FOCUS_NONE if painted else Control.FOCUS_ALL
	check(GoUi.skin().control_focus_mode() == want, "%s focus: the skin's focus mode" % look)
	var holder := _holder()
	for node: Control in _focused_controls():
		holder.add_child(node)
	await frames(1)
	for node: Control in holder.get_children():
		check(node.focus_mode == want, "%s focus: %s is %s (got %d)" % [look, node.get_class(), "FOCUS_NONE" if painted else "FOCUS_ALL", node.focus_mode])
		if not painted:
			node.grab_focus()
			check(node.has_focus(), "%s focus: the keyboard reaches %s" % [look, node.get_class()])
	holder.queue_free()
	await frames(1)


## A widget that is in the tree follows a look change; a focus mode the project set itself is left alone.
func _focus_follows_look() -> void:
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	var holder := _holder()
	var plain := GoGlyphButton.make("Play")
	var chosen := GoSlider.make()
	var card := GoLevelCard.make("STAGE 1", "", GoLevelCard.State.OPEN)
	var flip := GoSwitch.make()
	for node: Control in [plain, chosen, card, flip]: holder.add_child(node)
	chosen.focus_mode = Control.FOCUS_CLICK
	await frames(1)
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(2)
	check(plain.focus_mode == Control.FOCUS_NONE and card.focus_mode == Control.FOCUS_NONE and flip.focus_mode == Control.FOCUS_NONE,
		"focus: the widgets follow a change to arcade_light")
	check(chosen.focus_mode == Control.FOCUS_CLICK, "focus: a focus mode the project chose survives the look change")
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(2)
	check(plain.focus_mode == Control.FOCUS_ALL and card.focus_mode == Control.FOCUS_ALL and flip.focus_mode == Control.FOCUS_ALL,
		"focus: and back to the keyboard order in another look")
	check(chosen.focus_mode == Control.FOCUS_CLICK, "focus: the project's choice still stands")
	holder.queue_free()
	await frames(1)


# ── RTL caption side, touch floor following the look ───────────────────

## In RTL the caption sits in the half the drawn pill's knob is not on: a mirrored pill has its knob on the other side.
func _rtl_caption() -> void:
	for look: StringName in [GoThemePresets.ARCADE_DARK, GoThemePresets.DEFAULT_DARK, GoThemePresets.ARCADE_LIGHT]:
		GoUi.use_preset(look)
		await frames(1)
		var holder := _holder()
		var flip := GoSwitch.make(false)
		flip.set_texts("ON", "OFF")
		holder.add_child(flip)
		flip.size = Vector2(200, 44)
		flip.layout_direction = Control.LAYOUT_DIRECTION_RTL
		await frames(2)
		var plain := flip.part(&"unchecked")
		var mirrored := flip.part(&"unchecked_mirrored")
		var real_mirror := mirrored != null and mirrored != plain and flip.pill_texture() == mirrored \
			and mirrored.get_image().get_data() != plain.get_image().get_data()
		var at := flip.switch_rect()
		var knob_edge := at.size.y * GoSwitch.KNOB_SHARE
		var mid := flip.caption_position().x + flip.caption_width() * 0.5
		var free_mid_ltr := at.position.x + GoSwitch.TEXT_EDGE + knob_edge + flip.caption_room() * 0.5   # off, knob left
		var free_mid_flipped := at.position.x + GoSwitch.TEXT_EDGE + flip.caption_room() * 0.5
		if real_mirror:
			check(absf(mid - free_mid_flipped) < 0.01, "%s rtl switch: a mirrored off pill puts the caption on the other side (%.1f)" % [look, mid])
		else:
			check(absf(mid - free_mid_ltr) < 0.01, "%s rtl switch: an unmirrored pill keeps the caption side (%.1f)" % [look, mid])
		holder.queue_free()
		await frames(1)
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
