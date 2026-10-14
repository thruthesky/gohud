## 🧪 **Checks for the arcade_light painted art** — the painted sprites in `assets/arcade_light/painted/` and the white
## glyphs in `icons/arcade_light/`, brought over from Magnet Mayhem, and the icon set the `arcade_light` preset draws
## them with (`icons/arcade_light/arcade_light_icons.tres`). Its own file, so it never clashes with the other checks.
##
##   GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_arcade_painted_assets_test.gd" bash addons/gohud/tools/run_tests.sh
##
## 🔑 The sprites must come out pixel-for-pixel as the game imports them: lossless (no VRAM compression) and with the
##    game's mipmap choice per file. The glyphs answer gohud's own names (`home` is the exit door, `settings` the gear)
##    and everything they do not draw still comes from the default set.
extends SceneTree

const PAINTED := "res://addons/gohud/assets/arcade_light/painted"
const GLYPHS := "res://addons/gohud/icons/arcade_light"
const LIGHT := "res://addons/gohud/themes/presets/arcade_light.tres"
const DARK := "res://addons/gohud/themes/presets/arcade_dark.tres"

## Every painted sprite → does the game import it with mipmaps (its `.import` says `mipmaps/generate`).
const SPRITES := {
	"badge_blue": false, "badge_green": false, "btn_blue": true, "btn_green": true, "btn_grey": true, "btn_red": true,
	"card": true, "inset": true, "keycap": true, "ribbon_gold": true, "ribbon_red": false, "slider_blue": true,
	"slider_cyan": true, "slider_green": true, "slider_handle": true, "slider_track": true, "toggle_off": true,
	"toggle_on": true,
}

## Every glyph → its mipmap choice, as above. magnet and skull stay in the game.
const GLYPH_FILES := {
	"back": true, "check": true, "exit": true, "gear": true, "globe": true, "help": true, "pause": true, "play": true,
	"retry": false, "skip": false, "sound_low": true, "sound_off": true, "sound_on": true, "trophy": false,
}

var passed := 0
var failed: Array[String] = []


func _initialize() -> void:
	GoUi.reset()
	_painted_sprites()
	_glyph_files()
	_light_icons()
	_dark_icons()
	print("gohud painted tests: %d/%d passed" % [passed, passed + failed.size()])
	for line in failed: print("FAIL %s" % line)
	quit(0 if failed.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if condition: passed += 1
	else: failed.append(label)


## The picture as stored in the PNG itself, skipping the importer — what the texture has to match.
func _source(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _imports_like_the_game(path: String, mipmaps: bool) -> void:
	var texture := load(path) as Texture2D
	check(texture != null, "%s loads as a Texture2D" % path)
	if texture == null: return
	var source := _source(path)
	check(source != null and texture.get_size() == Vector2(source.get_size()),
		"%s is as big as its PNG (%s, PNG %s)" % [path, texture.get_size(), source.get_size() if source else "?"])
	var image := texture.get_image()
	check(image != null and not image.is_compressed(), "%s is imported lossless, not VRAM-compressed" % path)
	if image == null or source == null: return
	check(image.has_mipmaps() == mipmaps, "%s mipmaps %s, as the game imports it" % [path, mipmaps])
	# The top level must be the PNG's pixels. `process/fix_alpha_border` (on in the game too) recolours the RGB of
	# almost-transparent edge pixels, so those compare by alpha alone; every visible pixel compares whole.
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	source.convert(Image.FORMAT_RGBA8)
	var same := image.get_size() == source.get_size()
	if same:
		for y in range(0, source.get_height(), 3):
			for x in range(0, source.get_width(), 3):
				var want := source.get_pixel(x, y)
				var got := image.get_pixel(x, y)
				if not is_equal_approx(got.a, want.a) or (want.a >= 0.25 and not got.is_equal_approx(want)):
					same = false
					break
			if not same: break
	check(same, "%s keeps the PNG's pixels (alpha everywhere, colour where visible)" % path)


func _painted_sprites() -> void:
	for name: String in SPRITES:
		_imports_like_the_game("%s/%s.png" % [PAINTED, name], SPRITES[name])


func _glyph_files() -> void:
	for name: String in GLYPH_FILES:
		_imports_like_the_game("%s/%s.png" % [GLYPHS, name], GLYPH_FILES[name])
	check(not ResourceLoader.exists(GLYPHS + "/magnet.png"), "the magnet glyph stays in the game")
	check(not ResourceLoader.exists(GLYPHS + "/skull.png"), "the skull glyph stays in the game")


func _glyph(file: String) -> Texture2D:
	return load("%s/%s.png" % [GLYPHS, file]) as Texture2D


func _light_icons() -> void:
	var preset := load(LIGHT) as GoThemePreset
	check(preset != null and preset.icons != null, "the arcade_light preset has an icon set")
	if preset == null or preset.icons == null: return
	var icons := preset.icons
	var expect := {
		&"home": "exit", &"refresh": "retry", &"settings": "gear", &"back": "back", &"forward": "skip",
		&"crown": "trophy", &"check": "check", &"play": "play", &"pause": "pause", &"help": "help", &"globe": "globe",
		&"volume_high": "sound_on", &"volume_low": "sound_low", &"volume_off": "sound_off",
		&"exit": "exit", &"retry": "retry", &"gear": "gear", &"skip": "skip", &"trophy": "trophy",
		&"sound_on": "sound_on", &"sound_low": "sound_low", &"sound_off": "sound_off",
	}
	for name: StringName in expect:
		var want := _glyph(expect[name])
		check(want != null and icons.texture(name) == want, "arcade_light draws '%s' with the %s glyph" % [name, expect[name]])
	# Not a glyph here — the default set still draws it.
	for name: StringName in [&"close", &"trash", &"star"]:
		var drawn := icons.texture(name)
		check(drawn != null and drawn == GoUi.DEFAULT_ICONS.texture(name),
			"arcade_light falls back to the default set for '%s'" % name)
	check(icons.fallback == GoUi.DEFAULT_ICONS, "the arcade_light set falls back to gohud's default set")
	# What a widget actually asks for once the preset is chosen.
	GoUi.use_preset(preset)
	check(GoUi.icons().texture(&"home") == _glyph("exit"), "with arcade_light chosen, GoUi.icons() draws home with the exit glyph")
	check(GoUi.icons().texture(&"close") == GoUi.DEFAULT_ICONS.texture(&"close"), "with arcade_light chosen, close is gohud's")
	GoUi.reset()


func _dark_icons() -> void:
	var preset := load(DARK) as GoThemePreset
	check(preset != null and preset.icons == null, "the arcade_dark preset keeps the default icons (icons left empty)")
