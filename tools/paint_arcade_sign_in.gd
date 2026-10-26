## 🎨 **Paints arcade_light's sign-in art**: the white and the black glossy keys a "Sign in with Google" / "Sign in with
## Apple" button stands on (`assets/arcade_light/painted/btn_white.png`, `btn_black.png`), and the mail glyph for an
## e-mail sign-in (`icons/arcade_light/mail.png`).
##
##   godot --headless -s addons/gohud/tools/paint_arcade_sign_in.gd -- addons/gohud
##
## 🔑 The keys are `btn_blue.png` recoloured pixel by pixel, so they keep its exact shape, navy rim, gloss marks and
##    9-slice edges: each blue pixel is read as a depth (its value: the rim ≈ 0.25, the shadow band ≈ 0.8, the face 1)
##    and a gloss (how far its saturation sits below the face's), and repainted on the new key's ramp. The white key
##    keeps the navy rim of every glossy pill; the black key's rim is black.
## 🔑 The mail glyph is drawn in the glyph set's style, as `person.png`: a navy (#010a36) rim, a white face with a pale
##    lip (#e1e2ed) under the lower edges (`paint_arcade_glyphs.gd`, `paint_arcade_multiplayer.gd`), the flap a navy fold.
extends SceneTree
const NAVY := "#010a36"
const FACE := "#f9f9f9"
const LIP := "#e1e2ed"
const LIP_DROP := 7.0
const RIM := 14
const W := 128
const H := 96

## The blue key's own face saturation: a pixel paler than this is gloss.
const BLUE_FACE_S := 0.77
## Each key: [face, shadow band, gloss colour, gloss strength, rim]. A transparent rim keeps the blue key's navy one;
## the black key's rim is black too, or the navy would read as a blue halo around it.
const KEYS := {
	"btn_white": [Color("#eef1f8"), Color("#c3c9dc"), Color("#ffffff"), 1.0, Color.TRANSPARENT],
	"btn_black": [Color("#26282f"), Color("#0b0c10"), Color("#ffffff"), 0.75, Color("#020205")],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the gohud folder: -- <addons/gohud>")
		quit(1)
		return
	var root: String = args[0]
	var blue := Image.load_from_file(root + "/assets/arcade_light/painted/btn_blue.png")
	if blue == null:
		push_error("no btn_blue.png under %s" % root)
		quit(1)
		return
	blue.convert(Image.FORMAT_RGBA8)
	for name: String in KEYS:
		var spec: Array = KEYS[name]
		_write(_recolour(blue, spec[0], spec[1], spec[2], spec[3], spec[4]), "%s/assets/arcade_light/painted/%s.png" % [root, name])
	var mail := _mail()
	if mail != null: _write(mail, root + "/icons/arcade_light/mail.png")
	quit()


## The blue key repainted: the rim kept (or [param rim]), the body on the ramp shadow → face, the gloss on top.
func _recolour(blue: Image, face: Color, shadow: Color, gloss_color: Color, gloss_strength: float, rim: Color) -> Image:
	var out := blue.duplicate() as Image
	for y in blue.get_height():
		for x in blue.get_width():
			var c := blue.get_pixel(x, y)
			if c.a <= 0.0: continue
			# Depth: 0.25 (rim) .. 0.8 (shadow band) .. 1 (face); a face pixel more saturated than the face is deeper.
			var body: Color
			if c.v >= 0.8:
				body = shadow.lerp(face, clampf((c.v - 0.8) / 0.2, 0.0, 1.0))
				body = body.lerp(shadow, clampf((c.s - BLUE_FACE_S) / (1.0 - BLUE_FACE_S), 0.0, 1.0) * 0.5)
			else:
				var edge := c if rim.a <= 0.0 else rim
				body = edge.lerp(shadow, smoothstep(0.3, 0.55, c.v))
			var gloss := clampf((BLUE_FACE_S - c.s) / BLUE_FACE_S, 0.0, 1.0) * smoothstep(0.85, 1.0, c.v)
			var painted := body.lerp(gloss_color, gloss * gloss_strength)
			painted.a = c.a
			out.set_pixel(x, y, painted)
	return out


## An envelope: a rounded body, the flap folded down to its middle.
func _mail() -> Image:
	var body := '<rect x="12" y="12" width="104" height="72" rx="14"/>'
	var outline := _render(body, NAVY, ' stroke="%s" stroke-width="%d" stroke-linejoin="round"' % [NAVY, RIM])
	var lip := _render(body, LIP, "")
	var face := _render(body, FACE, "")
	if outline == null or lip == null or face == null: return null
	var drop := int(LIP_DROP)
	var img := outline.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	for y in H:
		for x in W:
			if y + drop >= H: continue
			var top := face.get_pixel(x, y + drop)
			top.a = minf(top.a, lip.get_pixel(x, y).a)
			if top.a <= 0.0: continue
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top))
	# The flap: a navy fold from the top corners to the middle, on the face.
	var fold := _render('<path d="M22 20 L64 50 L106 20" fill="none"/>', "none",
		' stroke="%s" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"' % NAVY)
	if fold == null: return null
	img.blend_rect(fold, Rect2i(Vector2i.ZERO, fold.get_size()), Vector2i.ZERO)
	return img


func _write(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
		return
	print("wrote ", path, " ", img.get_size())


func _render(shapes: String, fill: String, extra: String) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g fill="%s"%s>%s</g></svg>' \
		% [W, H, W, H, fill, extra, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
