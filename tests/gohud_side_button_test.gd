## 🧪 **Checks for `GoSideButton`** — the picture over the word in every look, the touch floor, the word that shrinks
## to its room and never under the fit floor (German too), the count on the picture's corner, a press anywhere on the
## key, the press and disabled tints, the focus the look decides, a look change, and arcade_light's menu art.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_side_button_test.gd" bash addons/gohud/tools/run_tests.sh
extends SceneTree

const LOOKS: Array[StringName] = [GoThemePresets.DEFAULT_DARK, GoThemePresets.DEFAULT_LIGHT, GoThemePresets.SCIFI_DARK,
	GoThemePresets.SCIFI_LIGHT, GoThemePresets.MEDIEVAL_DARK, GoThemePresets.MEDIEVAL_LIGHT,
	GoThemePresets.MATERIAL_LIGHT, GoThemePresets.MATERIAL_DARK, GoThemePresets.ARCADE_DARK,
	GoThemePresets.ARCADE_LIGHT, GoThemePresets.COMIC_DARK, GoThemePresets.COMIC_LIGHT, GoThemePresets.KIDS_DARK,
	GoThemePresets.KIDS_LIGHT]
## Words a menu key carries, short and long, as translations run.
const WORDS: Array[String] = ["DAILY", "ACHIEVEMENTS", "TÄGLICHE MISSIONEN", "ЕЖЕДНЕВНЫЕ", "日替わり"]

var passed := 0
var failed: Array[String] = []
var host: Control


func _initialize() -> void:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(800, 360)
		await frames(2)
	GoUi.reset()
	GoUi.config.reduce_motion = true
	for look in LOOKS:
		GoUi.use_preset(look)
		await frames(1)
		_make_host()
		await _shape(look)
		await _word_fits(look)
		host.free()
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	_make_host()
	await _arcade_look()
	await _art_is_registered()
	await _badge()
	await _press_anywhere()
	await _tints()
	await _setters_batch()
	await _follows_the_look()
	host.free()
	await frames(2)
	print("gohud side button tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func _make_host() -> void:
	host = Control.new()
	host.theme = GoUi.theme()
	host.size = Vector2(800, 360)
	root.add_child(host)


func _key(words := "DAILY", picture := 72, room := 0.0) -> GoSideButton:
	var key := GoSideButton.make(words, PlaceholderTexture2D.new())
	key.picture_size = picture
	key.label_width = room
	host.add_child(key)
	key.refresh()
	key.size = key.get_combined_minimum_size()
	return key


## The picture stands over the word, both inside the node, which keeps the touch floor.
func _shape(look: StringName) -> void:
	for picture: int in [24, 72]:
		var key := _key("DAILY", picture)
		await frames(1)
		var least := key.get_combined_minimum_size()
		check(least.x >= GoUi.touch_size() and least.y >= GoUi.touch_size(), "%s: %d dp keeps the touch floor (%s)" % [
			look, picture, least])
		check(key.picture.size == Vector2.ONE * picture, "%s: the picture is its square" % look)
		var whole := Rect2(Vector2.ZERO, key.size).grow(0.5)
		check(whole.encloses(key.picture.get_rect()), "%s: the picture inside the key" % look)
		check(whole.encloses(key.label.get_rect()), "%s: the word inside the key" % look)
		check(key.label.position.y >= key.picture.position.y + picture, "%s: the word under the picture" % look)
		check(is_equal_approx(key.picture.get_rect().get_center().x, key.size.x * 0.5) or \
			absf(key.picture.get_rect().get_center().x - key.size.x * 0.5) <= 1.0, "%s: the picture centred" % look)
		key.free()
	var bare := _key("", 72)
	await frames(1)
	check(not bare.label.visible, "%s: no word, no label" % look)
	check(bare.get_combined_minimum_size().y == maxf(72.0, GoUi.touch_size()), "%s: and no room kept for one" % look)
	bare.free()


## Every word fits its room or stops at the floor; the node is never narrower than the word drawn.
func _word_fits(look: StringName) -> void:
	for words in WORDS:
		var key := _key(words, 72, 110.0)
		await frames(1)
		var base := GoUi.font_size(GoTheme.ROLE_BUTTON)
		var fitted := key.fitted_font_size()
		check(fitted >= GoStyle.fit_floor(base), "%s: '%s' never under the fit floor (%d)" % [look, words, fitted])
		check(fitted <= base, "%s: '%s' never grows (%d)" % [look, words, fitted])
		var drawn := GoStyle.row_width(key.label.get_theme_font(&"font"), PackedStringArray([words]), fitted)
		if fitted > GoStyle.fit_floor(base):
			check(drawn <= 110.0 + 0.5, "%s: '%s' fits its 110 dp (%.1f)" % [look, words, drawn])
		check(key.get_combined_minimum_size().x + 0.5 >= minf(drawn, 110.0), "%s: '%s' the key holds it" % [look, words])
		key.free()


func _arcade_look() -> void:
	var key := _key()
	await frames(1)
	check(key.label.theme_type_variation == &"GoOutlineLabel", "arcade_light: the outlined HUD text")
	check(key.focus_mode == Control.FOCUS_NONE, "arcade_light: out of the focus order like its other keys")
	check(key.accessibility_name == "DAILY", "a screen reader says the word")
	key.free()


func _art_is_registered() -> void:
	for art: StringName in [&"menu_daily", &"menu_achievements"]:
		var picture := GoUi.skin().widget_art(art)
		check(picture != null, "%s is registered" % art)
		if picture != null:
			check(maxi(picture.get_width(), picture.get_height()) == 192, "%s is 192 px on its long side" % art)


func _badge() -> void:
	var key := _key()
	check(key.badge() == null, "no badge before one is asked for")
	var shown := key.set_badge(3)
	await frames(2)
	check(shown != null and shown.get_parent() == key.picture, "the count hangs on the picture")
	check(shown.visible and shown.count() == 3, "it shows 3")
	check(shown.text_role == GoTheme.ROLE_SUBTITLE, "in the key's bigger role")
	check(key.badge() == shown, "badge() finds it")
	check(key.set_badge(5) == shown, "one badge, reused")
	await frames(1)
	# Pulled in onto the art (BADGE_INSET of the picture each way), not centred on the square's empty corner — and still
	# hanging past it, as a count on a mobile game's event icon does.
	var corner := key.picture.size
	var centre := shown.position + shown.size * 0.5
	var inset := roundf(float(key.picture_size) * GoSideButton.BADGE_INSET)
	check(inset > 0.0 and shown.corner_inset == Vector2.ONE * inset, "pulled in by %s (%s)" % [inset, shown.corner_inset])
	check(absf(centre.x - (corner.x - inset)) <= 1.0 and absf(centre.y - inset) <= 1.0,
		"centred %s in from the picture's top-right (%s)" % [inset, centre])
	check(shown.position.x + shown.size.x > corner.x and shown.position.y < 0.0, "it still hangs past the corner")
	key.picture_size = 120
	await frames(2)
	check(shown.corner_inset == Vector2.ONE * roundf(120.0 * GoSideButton.BADGE_INSET), "the inset follows the picture")
	key.set_badge(0)
	check(not shown.visible, "0 hides it")
	key.badge_role = GoTheme.ROLE_CAPTION
	check(shown.text_role == GoTheme.ROLE_CAPTION, "the role follows")
	key.free()


## A click on the word presses the key as a click on the picture does.
func _press_anywhere() -> void:
	var key := _key()
	key.position = Vector2(100, 50)
	await frames(2)
	var presses := [0]
	key.pressed.connect(func() -> void: presses[0] += 1)
	for at: Vector2 in [key.picture.get_global_rect().get_center(), key.label.get_global_rect().get_center()]:
		_click(at)
		await frames(1)
	check(presses[0] == 2, "the picture and the word both press it (%d)" % presses[0])
	key.disabled = true
	_click(key.picture.get_global_rect().get_center())
	await frames(1)
	check(presses[0] == 2, "a disabled key takes no press")
	key.free()


func _click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		root.push_input(event, true)


func _tints() -> void:
	var key := _key()
	await frames(1)
	check(key.face_tint() == Color.WHITE, "at rest the picture shows as painted")
	key.disabled = true
	check(key.face_tint().a == GoSideButton.DISABLED_ALPHA, "disabled fades")
	key.disabled = false
	key.toggle_mode = true
	key.button_pressed = true
	check(key.face_tint() == GoUi.skin().picture_press_tint(), "held: the look's press tint")
	key.free()


## Changes in one frame lay out once, at its end; refresh() lays out at once.
func _setters_batch() -> void:
	var key := _key()
	key.text = "ACHIEVEMENTS"
	key.picture_size = 96
	check(key.label.text == "DAILY", "not yet")
	await frames(1)
	check(key.label.text == "ACHIEVEMENTS" and key.picture.size.y == 96.0, "at the frame's end")
	key.text = "GO"
	key.refresh()
	check(key.label.text == "GO", "refresh() at once")
	key.free()


func _follows_the_look() -> void:
	var key := _key()
	GoUi.use_preset(GoThemePresets.DEFAULT_DARK)
	await frames(1)
	check(key.label.theme_type_variation == &"", "a look without the outlined text: the plain label")
	check(key.label.get_theme_constant(&"outline_size") >= 2, "with the name plate's edge")
	GoUi.use_preset(GoThemePresets.ARCADE_LIGHT)
	await frames(1)
	check(key.label.theme_type_variation == &"GoOutlineLabel", "and back")
	key.free()


func frames(count: int) -> void:
	for i in count: await process_frame


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)
