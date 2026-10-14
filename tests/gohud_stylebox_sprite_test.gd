## 🧪 **Checks for the painted 9-slice box** — `GoStyleBoxSprite`, the face `arcade_light` will draw its painted PNG
## art with. Its own file, so it never clashes with the widgets other people are adding to the other test files.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_stylebox_sprite_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 The maths must match the game's `SpriteBox` exactly — the same art has to come out as the same pixels.
extends SceneTree

const SAVE_PATH := "user://gohud_stylebox_sprite_test.tres"

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	_dest_rects()
	_source_rects()
	_duplicate()
	_frame_margin()
	_round_trip()
	print("gohud sprite tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


func _texture() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(90, 60, false, Image.FORMAT_RGBA8))


## A box drawn at a third of its art: 30/15/24/9 texture px → 10/5/8/3 canvas units.
func _box() -> GoStyleBoxSprite:
	var box := GoStyleBoxSprite.new()
	box.texture = _texture()
	box.edge = Vector4(30, 15, 24, 9)
	box.pixels_per_unit = 3.0
	box.tint = Color(0.8, 0.9, 1.0, 0.5)
	box.draw_center = false
	box.face_color = Color("#7BE36A")
	return box


func _rects_equal(got: Array[Rect2], want: Array[Rect2]) -> bool:
	if got.size() != want.size(): return false
	for i in got.size():
		if not got[i].position.is_equal_approx(want[i].position) or not got[i].size.is_equal_approx(want[i].size):
			return false
	return true


func _dest_rects() -> void:
	var box := _box()
	var got := box.dest_rects(Rect2(100, 50, 200, 40))
	var want: Array[Rect2] = [
		Rect2(100, 50, 10, 5), Rect2(110, 50, 182, 5), Rect2(292, 50, 8, 5),
		Rect2(100, 55, 10, 32), Rect2(110, 55, 182, 32), Rect2(292, 55, 8, 32),
		Rect2(100, 87, 10, 3), Rect2(110, 87, 182, 3), Rect2(292, 87, 8, 3),
	]
	check(_rects_equal(got, want), "dest: a normal rect slices at edge / pixels_per_unit (%s)" % str(got))
	# 9 wide against 10 + 8 of edge, 4 tall against 5 + 3: both pairs shrink by the same factor (0.5).
	got = box.dest_rects(Rect2(0, 0, 9, 4))
	want = [
		Rect2(0, 0, 5, 2.5), Rect2(5, 0, 0, 2.5), Rect2(5, 0, 4, 2.5),
		Rect2(0, 2.5, 5, 0), Rect2(5, 2.5, 0, 0), Rect2(5, 2.5, 4, 0),
		Rect2(0, 2.5, 5, 1.5), Rect2(5, 2.5, 0, 1.5), Rect2(5, 2.5, 4, 1.5),
	]
	check(_rects_equal(got, want), "dest: a rect smaller than the edges shrinks them proportionally (%s)" % str(got))


func _source_rects() -> void:
	var got := _box().source_rects()
	var want: Array[Rect2] = [
		Rect2(0, 0, 30, 15), Rect2(30, 0, 36, 15), Rect2(66, 0, 24, 15),
		Rect2(0, 15, 30, 36), Rect2(30, 15, 36, 36), Rect2(66, 15, 24, 36),
		Rect2(0, 51, 30, 9), Rect2(30, 51, 36, 9), Rect2(66, 51, 24, 9),
	]
	check(_rects_equal(got, want), "source: nine texture-pixel rects in the same order (%s)" % str(got))
	var empty := GoStyleBoxSprite.new()
	check(empty.source_rects().size() == 9, "source: no texture still gives nine rects")


func _duplicate() -> void:
	var box := _box()
	var copy := box.duplicate() as GoStyleBoxSprite
	check(copy != null, "duplicate: comes back as a GoStyleBoxSprite")
	if copy == null: return
	check(copy.texture == box.texture, "duplicate: keeps the texture")
	check(copy.edge == box.edge, "duplicate: keeps edge")
	check(copy.pixels_per_unit == box.pixels_per_unit, "duplicate: keeps pixels_per_unit")
	check(copy.tint == box.tint, "duplicate: keeps tint")
	check(copy.draw_center == box.draw_center, "duplicate: keeps draw_center")
	check(copy.face_color == box.face_color, "duplicate: keeps face_color")


func _frame_margin() -> void:
	var box := _box()
	check(is_equal_approx(box.frame_margin(SIDE_LEFT), 10.0), "frame: left = 30 / 3")
	check(is_equal_approx(box.frame_margin(SIDE_TOP), 5.0), "frame: top = 15 / 3")
	check(is_equal_approx(box.frame_margin(SIDE_RIGHT), 8.0), "frame: right = 24 / 3")
	check(is_equal_approx(box.frame_margin(SIDE_BOTTOM), 3.0), "frame: bottom = 9 / 3")
	check(is_equal_approx(GoSkin.frame_margin(box, SIDE_RIGHT), 8.0),
		"frame: GoSkin.frame_margin agrees (%.2f)" % GoSkin.frame_margin(box, SIDE_RIGHT))
	var changed := [0]
	box.changed.connect(func() -> void: changed[0] += 1)
	box.edge = Vector4(3, 3, 3, 3)
	box.pixels_per_unit = 2.0
	box.tint = Color.RED
	box.draw_center = true
	box.texture = null
	box.face_color = Color.BLUE
	check(changed[0] == 6, "setters: every field emits changed (%d of 6)" % changed[0])


func _round_trip() -> void:
	var box := _box()
	var err := ResourceSaver.save(box, SAVE_PATH)
	check(err == OK, "save: ResourceSaver writes the box (error %d)" % err)
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GoStyleBoxSprite
	check(loaded != null, "load: comes back as a GoStyleBoxSprite")
	if loaded != null:
		check(loaded.texture != null and loaded.texture.get_size() == Vector2(90, 60), "load: keeps the texture")
		check(loaded.edge == box.edge, "load: keeps edge")
		check(loaded.pixels_per_unit == box.pixels_per_unit, "load: keeps pixels_per_unit")
		check(loaded.tint.is_equal_approx(box.tint), "load: keeps tint")
		check(loaded.draw_center == box.draw_center, "load: keeps draw_center")
		check(loaded.face_color.is_equal_approx(box.face_color), "load: keeps face_color")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
