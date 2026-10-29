## 🧪 **Checks for the framed face** — `GoStyleBoxFrame` (a flat chamfered body under a painted 9-slice frame) and the
## two helpers that put its states on a control, `GoStyle.frame_states()` and `GoStyle.style_frame()` — plus the
## helpers around them: `frame_face()`, `pad_faces()`, `bare_button()`, `tint_button(…, disabled)`, `tint_field()`,
## `recolor_text()`.
## Its own file, so it never clashes with the widgets other people are adding to the other test files.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_stylebox_frame_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const SAVE_PATH := "user://gohud_stylebox_frame_test.tres"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	_is_a_sprite()
	_fill_outline()
	_colours()
	_draw_rect()
	_states()
	_style_frame()
	_helpers()
	_round_trip()
	print("gohud frame tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


## A 3× frame: 180 × 180 art with 30 px edges → 10 canvas units of frame on every side.
func _box() -> GoStyleBoxFrame:
	var box := GoStyleBoxFrame.new()
	box.texture = ImageTexture.create_from_image(Image.create(180, 180, false, Image.FORMAT_RGBA8))
	box.edge = Vector4(30, 30, 30, 30)
	box.pixels_per_unit = 3.0
	box.bg_color = Color("#0C7A99")
	box.fill_inset = 3.0
	box.fill_cut = 7.0
	box.set_content_margin_all(12.0)
	return box


func _is_a_sprite() -> void:
	var box := _box()
	check(box is GoStyleBoxSprite, "class: a GoStyleBoxFrame is a GoStyleBoxSprite (same nine-slice maths)")
	check(is_equal_approx(box.frame_margin(SIDE_LEFT), 10.0), "frame: 30 texture px at 3 px per unit = 10 units")
	check(is_equal_approx(GoSkin.frame_margin(box, SIDE_BOTTOM), 10.0), "frame: GoSkin.frame_margin agrees")
	check(is_equal_approx(box.content_margin_left, 12.0) and is_equal_approx(box.content_margin_bottom, 12.0),
		"padding: set_content_margin_all fills the built-in content margins")


func _fill_outline() -> void:
	var box := _box()
	var shape := box.fill_outline(Rect2(0, 0, 316, 56))
	check(shape.size() == 8, "body: eight points — every corner cut (%d)" % shape.size())
	if shape.size() == 8:
		check(shape[0].is_equal_approx(Vector2(3 + 7, 3)), "body: top edge starts after the inset and the cut (%s)" % shape[0])
		check(shape[1].is_equal_approx(Vector2(313 - 7, 3)), "body: top edge ends before the right cut (%s)" % shape[1])
		check(shape[2].is_equal_approx(Vector2(313, 3 + 7)), "body: the top-right corner is a diagonal (%s)" % shape[2])
		check(shape[4].is_equal_approx(Vector2(313 - 7, 53)), "body: bottom edge is inset by 3 (%s)" % shape[4])
		check(shape[7].is_equal_approx(Vector2(3, 3 + 7)), "body: closes on the left edge (%s)" % shape[7])
	# A 12 × 10 chip: the body is 6 × 4, so the cut shrinks to half the short side (2) instead of tangling.
	var small := box.fill_outline(Rect2(0, 0, 12, 10))
	check(small.size() == 8 and small[0].is_equal_approx(Vector2(5, 3)),
		"body: the cut never exceeds half the body's short side (%s)" % str(small))
	check(box.fill_outline(Rect2(0, 0, 4, 4)).is_empty(), "body: a rect smaller than the inset draws no body")
	box.fill_cut = 0.0
	check(box.fill_outline(Rect2(0, 0, 100, 40)).size() == 4, "body: cut 0 = a plain inset rectangle")


func _colours() -> void:
	var box := _box()
	check(box.face_color == box.bg_color, "contrast: bg_color is also the face colour checks measure against")
	box.bg_color = Color.RED
	check(box.face_color == Color.RED, "contrast: changing bg_color moves face_color with it")
	var changed := [0]
	box.changed.connect(func() -> void: changed[0] += 1)
	box.bg_color = Color.BLUE
	box.fill_inset = 2.0
	box.fill_cut = 5.0
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 4.0
	box.shadow_offset = Vector2(3, 3)
	check(changed[0] >= 6, "setters: every new field emits changed (%d of ≥ 6)" % changed[0])
	# The names StyleBoxFlat uses — `_flat_like` moves a framed face onto a flat one (brand buttons) by them.
	var flat := box.duplicate() as GoStyleBoxFrame
	check(flat != null and flat.bg_color == Color.BLUE and flat.shadow_offset == Vector2(3, 3),
		"duplicate: keeps the body colour and the shadow")


func _draw_rect() -> void:
	var box := _box()
	var rect := Rect2(10, 10, 100, 40)
	check(box._get_draw_rect(rect) == rect, "draw rect: no shadow → the rect itself")
	box.shadow_color = Color(0, 0, 0, 0.59)
	box.shadow_size = 4.0
	box.shadow_offset = Vector2(3, 3)
	var grown := box._get_draw_rect(rect)
	check(grown.encloses(rect.grow(4.0)) and grown.end.is_equal_approx(rect.end + Vector2(7, 7)),
		"draw rect: widened by the shadow's spread and offset (%s)" % grown)


func _states() -> void:
	var normal := _box()
	var states := GoStyle.frame_states(normal)
	for key in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		check(states.get(key) is GoStyleBoxFrame, "states: %s is a framed face" % key)
	var hover := states[&"hover"] as GoStyleBoxFrame
	var pressed := states[&"pressed"] as GoStyleBoxFrame
	var focus := states[&"focus"] as GoStyleBoxFrame
	var off := states[&"disabled"] as GoStyleBoxFrame
	check(states[&"normal"] == normal, "states: normal is the face given, not a copy")
	check(hover.bg_color.get_luminance() > normal.bg_color.get_luminance(), "states: hover lightens the body")
	check(pressed.bg_color.get_luminance() < normal.bg_color.get_luminance(), "states: pressed darkens the body")
	check(hover.texture == normal.texture and pressed.texture == normal.texture and hover.edge == normal.edge,
		"states: hover and pressed reuse the same frame art (the control keeps its size)")
	check(not focus.draw_center and focus.shadow_color.a == 0.0, "states: focus is the frame alone (drawn over the face)")
	check(off.bg_color.s < normal.bg_color.s, "states: disabled without its own cut is a desaturated body")
	var grey := _box()
	grey.bg_color = Color("#26384B")
	var ring := _box()
	ring.tint = Color(0.5, 1, 1)
	var given := GoStyle.frame_states(normal, {&"hover": normal}, grey, ring)
	check(given[&"disabled"] == grey, "states: a disabled cut given is used as it is")
	check((given[&"focus"] as GoStyleBoxFrame).tint == ring.tint, "states: a focus cut given becomes the ring")
	check(given[&"hover"] == normal, "states: overrides replace a computed state")


func _style_frame() -> void:
	var states := GoStyle.frame_states(_box())
	var button := Button.new()
	GoStyle.style_frame(button, states)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		check(button.has_theme_stylebox_override(state), "button: %s face is set" % state)
	check(button.get_theme_stylebox(&"hover_pressed") == states[&"pressed"], "button: hover_pressed = pressed")
	var field := LineEdit.new()
	GoStyle.style_frame(field, states)
	check(field.get_theme_stylebox(&"normal") == states[&"normal"] and field.get_theme_stylebox(&"focus") == states[&"focus"]
		and field.get_theme_stylebox(&"read_only") == states[&"disabled"], "field: normal · focus · read_only")
	var panel := PanelContainer.new()
	GoStyle.style_frame(panel, states)
	check(panel.get_theme_stylebox(&"panel") == states[&"normal"], "panel: the normal face is the panel")
	# Swapping faces later (a field showing an error) just replaces the overrides.
	var error := _box()
	error.bg_color = Color("#081A28")
	GoStyle.style_frame(field, {&"normal": error})
	check(field.get_theme_stylebox(&"normal") == error, "field: style_frame again swaps the face")
	check(field.get_theme_stylebox(&"focus") is StyleBoxEmpty, "field: a state not given falls back (focus → empty)")
	GoStyle.style_frame(button, {})
	check(button.get_theme_stylebox(&"normal") == states[&"normal"], "button: no normal face → nothing changes")
	# The face's own minimum size is what a control adds up (`Button._get_largest_stylebox_size`): the content margins,
	# since a GDScript StyleBox's `_get_style_margin` is never called. 🛑 Not `button.get_minimum_size()` here — the
	# button's theme cache is filled only once it is in a running tree, so a detached button reports the default theme's
	# face (32 × 16 on the office-windows runner, 2026-10-30).
	var minimum := (states[&"normal"] as StyleBox).get_minimum_size()
	check(minimum.x >= 24.0 and minimum.y >= 24.0, "face: content margins are its minimum size (%s)" % minimum)
	button.free()
	field.free()
	panel.free()


func _helpers() -> void:
	var art := ImageTexture.create_from_image(Image.create(120, 120, false, Image.FORMAT_RGBA8))
	var face := GoStyle.frame_face(art, 30.0, 3.0, Color("#10283B"), Vector2(16, 4), 3.0, 7.0, Color(0, 0, 0.04, 0.59),
		Vector2(3, 3), 4.0)
	check(face.texture == art and face.edge == Vector4(30, 30, 30, 30) and face.pixels_per_unit == 3.0,
		"frame_face: art and slices")
	check(face.bg_color == Color("#10283B") and face.fill_inset == 3.0 and face.fill_cut == 7.0, "frame_face: body")
	check(face.shadow_size == 4.0 and face.shadow_offset == Vector2(3, 3) and face.shadow_color.a > 0.5, "frame_face: shadow")
	check(face.content_margin_left == 16.0 and face.content_margin_right == 16.0 and face.content_margin_top == 4.0
		and face.content_margin_bottom == 4.0, "frame_face: padding x / y")
	check(GoStyle.frame_face(art, 30.0, 3.0, Color.BLACK) != GoStyle.frame_face(art, 30.0, 3.0, Color.BLACK),
		"frame_face: a new face every call")
	var deep := GoStyle.frame_states(_box(), {}, null, null, -0.06)
	check((deep[&"hover"] as GoStyleBoxFrame).bg_color.get_luminance() < _box().bg_color.get_luminance(),
		"frame_states: a negative hover shift deepens the body")
	# pad_faces: the button's own copies change; the shared face does not.
	var states := GoStyle.frame_states(face)
	var button := Button.new()
	GoStyle.style_frame(button, states)
	GoStyle.pad_faces(button, 40.0, 10.0)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var own := button.get_theme_stylebox(state)
		check(own.content_margin_left == 40.0 and own.content_margin_right == 10.0 and own.content_margin_top == 4.0,
			"pad_faces: %s gets left 40 · right 10 · top kept" % state)
	check(button.get_theme_stylebox(&"normal") != face and face.content_margin_left == 16.0,
		"pad_faces: the shared face is untouched (copies)")
	var field := LineEdit.new()
	GoStyle.style_frame(field, states)
	GoStyle.pad_faces(field, -1.0, 50.0)
	check(field.get_theme_stylebox(&"normal").content_margin_right == 50.0
		and field.get_theme_stylebox(&"normal").content_margin_left == 16.0, "pad_faces: a field's right side only")
	var bare := Button.new()
	GoStyle.bare_button(bare, 4.0)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var box := bare.get_theme_stylebox(state)
		check(box is StyleBoxEmpty and box.content_margin_left == 4.0 and box.content_margin_right == 4.0,
			"bare_button: %s is empty with 4 beside the label" % state)
	GoStyle.tint_button(bare, Color.WHITE, Color.CYAN, Color.GRAY)
	check(bare.get_theme_color(&"font_disabled_color") == Color.GRAY and bare.get_theme_color(&"icon_disabled_color") == Color.GRAY,
		"tint_button: the disabled ink (trailing argument)")
	check(bare.get_theme_color(&"font_hover_color") == Color.CYAN, "tint_button: the active ink still applies")
	GoStyle.tint_field(field, Color.WHITE, Color.GRAY, Color.CYAN)
	check(field.get_theme_color(&"font_color") == Color.WHITE and field.get_theme_color(&"font_placeholder_color") == Color.GRAY
		and field.get_theme_color(&"caret_color") == Color.CYAN, "tint_field: text · placeholder · caret")
	var label := Label.new()
	label.theme_type_variation = &"GoCaptionLabel"
	GoStyle.recolor_text(label, Color.RED)
	check(label.get_theme_color(&"font_color") == Color.RED and label.theme_type_variation == &"GoCaptionLabel",
		"recolor_text: the ink changes, the variation stays")
	button.free()
	field.free()
	bare.free()
	label.free()


func _round_trip() -> void:
	var box := _box()
	box.shadow_color = Color(0, 0, 0.04, 0.59)
	box.shadow_size = 4.0
	box.shadow_offset = Vector2(3, 3)
	var err := ResourceSaver.save(box, SAVE_PATH)
	check(err == OK, "save: ResourceSaver writes the box (error %d)" % err)
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GoStyleBoxFrame
	check(loaded != null, "load: comes back as a GoStyleBoxFrame")
	if loaded != null:
		check(loaded.texture != null and loaded.texture.get_size() == Vector2(180, 180), "load: keeps the frame art")
		check(loaded.edge == box.edge and loaded.pixels_per_unit == box.pixels_per_unit, "load: keeps the slices")
		check(loaded.bg_color.is_equal_approx(box.bg_color) and loaded.face_color.is_equal_approx(box.bg_color),
			"load: keeps the body colour (and the face colour with it)")
		check(loaded.fill_inset == box.fill_inset and loaded.fill_cut == box.fill_cut, "load: keeps the body geometry")
		check(loaded.shadow_color.is_equal_approx(box.shadow_color) and loaded.shadow_size == box.shadow_size
			and loaded.shadow_offset == box.shadow_offset, "load: keeps the shadow")
		check(is_equal_approx(loaded.content_margin_top, 12.0), "load: keeps the padding")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
