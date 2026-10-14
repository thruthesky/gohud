## 🧪 **Checks for the painted icon** — `GoTextureSprite`, the theme icon `arcade_light` draws its 3× slider handle and
## switch pills with. Its own file, like `gohud_stylebox_sprite_test.gd`.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_texture_sprite_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 It must lay out and draw at `draw_size`, whatever the art's pixel size — what the game's `draw_texture_rect` does.
extends SceneTree

const SAVE_PATH := "user://gohud_texture_sprite_test.tres"
const TINT := Color(0.6, 0.6, 0.66, 0.85)

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	_size()
	_regions()
	_tiles()
	_colour()
	_no_texture()
	_pixels()
	_image()
	_setters()
	_round_trip()
	print("gohud texture sprite tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


## 108 × 72 art: the left half opaque red, the right half clear.
func _art() -> Texture2D:
	var image := Image.create(108, 72, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 54, 72), Color.RED)
	return ImageTexture.create_from_image(image)


## The art drawn at a third: 36 × 24 units.
func _sprite() -> GoTextureSprite:
	var sprite := GoTextureSprite.new()
	sprite.texture = _art()
	sprite.draw_size = Vector2(36, 24)
	sprite.tint = TINT
	return sprite


func _size() -> void:
	var sprite := _sprite()
	check(sprite.get_size() == Vector2(36, 24), "size: draw_size, not the art's 108 × 72 (got %s)" % sprite.get_size())
	sprite.draw_size = Vector2(36.6, 23.4)
	check(sprite.get_width() == 37 and sprite.get_height() == 23,
		"size: a fractional draw_size rounds to whole units (got %s)" % sprite.get_size())
	sprite.draw_size = Vector2(-4, 10)
	check(sprite.get_width() == 0, "size: a negative draw_size is empty (got %d)" % sprite.get_width())


func _regions() -> void:
	var sprite := _sprite()
	check(sprite.art_scale().is_equal_approx(Vector2(3, 3)), "region: 3 art px per unit (got %s)" % sprite.art_scale())
	var got := sprite.source_rect(Rect2(6, 4, 12, 8))
	check(got.position.is_equal_approx(Vector2(18, 12)) and got.size.is_equal_approx(Vector2(36, 24)),
		"region: a drawn-unit source rect lands on the art's pixels (got %s)" % got)


func _tiles() -> void:
	var sprite := _sprite()
	var got := sprite.tile_rects(Rect2(10, 20, 80, 30))
	# 80 / 36 → 36, 36, 8 wide; 30 / 24 → 24, 6 tall: six copies, the last column and row cut.
	check(got.size() == 6, "tile: a copy every 36 × 24 units, not every 108 × 72 art px (got %d)" % got.size())
	if got.size() == 6:
		check(got[0][0] == Rect2(10, 20, 36, 24) and got[0][1] == Rect2(0, 0, 108, 72),
			"tile: a whole copy draws the whole art (got %s)" % [got[0]])
		check(got[2][0] == Rect2(82, 20, 8, 24) and got[2][1] == Rect2(0, 0, 24, 72),
			"tile: the last column is cut, the art with it (got %s)" % [got[2]])
		check(got[5][0] == Rect2(82, 44, 8, 6) and got[5][1] == Rect2(0, 0, 24, 18),
			"tile: the corner is cut both ways (got %s)" % [got[5]])
	var lying := sprite.tile_rects(Rect2(0, 0, 24, 36), true)
	check(lying.size() == 1 and lying[0][0] == Rect2(0, 0, 24, 36) and lying[0][1] == Rect2(0, 0, 108, 72),
		"tile: transposed, a copy is draw_size on its side (got %s)" % [lying])


func _colour() -> void:
	var sprite := _sprite()
	var modulate := Color(0.5, 1.0, 0.8, 0.5)
	check(sprite.draw_color(modulate).is_equal_approx(modulate * TINT), "colour: modulate × tint (got %s)"
		% sprite.draw_color(modulate))
	check(sprite.draw_color(Color.WHITE).is_equal_approx(TINT), "colour: tint alone under a white modulate")


func _no_texture() -> void:
	var sprite := GoTextureSprite.new()
	sprite.draw_size = Vector2(20, 10)
	check(sprite.get_size() == Vector2(20, 10), "no art: still takes draw_size")
	check(sprite.art_scale() == Vector2.ZERO, "no art: nothing to scale")
	check(sprite.tile_rects(Rect2(0, 0, 50, 50)).is_empty(), "no art: no tiles")
	check(sprite.get_image() == null, "no art: no image")
	check(not sprite._is_pixel_opaque(1, 1), "no art: nothing is opaque")
	# Drawing it is a no-op, never an error.
	var item := RenderingServer.canvas_item_create()
	sprite.draw(item, Vector2.ZERO)
	sprite.draw_rect(item, Rect2(0, 0, 40, 20), true)
	sprite.draw_rect_region(item, Rect2(0, 0, 40, 20), Rect2(0, 0, 10, 5))
	RenderingServer.free_rid(item)
	check(true, "no art: draw, draw_rect and draw_rect_region do nothing")


## Texture2D has no public is_pixel_opaque; the engine calls the virtual itself.
func _pixels() -> void:
	var sprite := _sprite()
	check(sprite._is_pixel_opaque(5, 12), "opaque: the red left half, in drawn units")
	check(not sprite._is_pixel_opaque(30, 12), "opaque: the clear right half")
	check(not sprite._is_pixel_opaque(40, 12) and not sprite._is_pixel_opaque(-1, 0), "opaque: outside is clear")


func _image() -> void:
	var sprite := _sprite()
	var image := sprite.get_image()
	check(image != null and image.get_size() == Vector2i(36, 24), "image: the art at the drawn size (got %s)"
		% (image.get_size() if image else "null"))
	if image == null: return
	check(image.get_pixel(5, 12).is_equal_approx(Color.RED) and image.get_pixel(30, 12).a == 0.0,
		"image: the art's pixels, resized")
	check(sprite.get_image() == image, "image: made once and kept")
	sprite.draw_size = Vector2(18, 12)
	check(sprite.get_image() != image and sprite.get_image().get_size() == Vector2i(18, 12),
		"image: made again when draw_size changes")


func _setters() -> void:
	var sprite := _sprite()
	var changed := [0]
	sprite.changed.connect(func() -> void: changed[0] += 1)
	sprite.texture = _art()
	sprite.draw_size = Vector2(10, 10)
	sprite.tint = Color.RED
	check(changed[0] == 3, "setters: every field emits changed (%d of 3)" % changed[0])
	var art := sprite.texture as ImageTexture
	var before: int = changed[0]
	art.set_image(Image.create(30, 30, false, Image.FORMAT_RGBA8))
	check(changed[0] > before, "setters: a change in the art is passed on")


func _round_trip() -> void:
	var sprite := _sprite()
	var err := ResourceSaver.save(sprite, SAVE_PATH)
	check(err == OK, "save: ResourceSaver writes the sprite (error %d)" % err)
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GoTextureSprite
	check(loaded != null, "load: comes back as a GoTextureSprite")
	if loaded != null:
		check(loaded.texture != null and loaded.texture.get_size() == Vector2(108, 72), "load: keeps the art")
		check(loaded.draw_size == sprite.draw_size and loaded.get_size() == Vector2(36, 24), "load: keeps draw_size")
		check(loaded.tint.is_equal_approx(TINT), "load: keeps tint")
		check(loaded.get_image() != null and loaded.get_image().get_size() == Vector2i(36, 24), "load: get_image works")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
