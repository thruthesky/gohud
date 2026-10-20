## 🎨 **Paints arcade_light's HUD shield** (`assets/arcade_light/hud/shield.png`), which Magnet Mayhem's HUD art never
## had, in the style of its painted bolt (`hud/bolt.png`): a solid 64 px shield with a thick navy (#010a36) rim, a warm
## face running from the stability bar's gold (#ffc24a) at the top left to its orange (#ff8a3d) at the bottom right, a
## darker lip down its right and lower edges, the right half a shade deeper (the shield's ridge) and a soft white gloss
## on the upper left. `GoUi.skin().widget_art(&"shield")` returns it — a HUD's stability bar wears it.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_shield.gd -- addons/gohud/assets/arcade_light/hud
##
## 🔑 The lip, the ridge and the gloss are composited here, not in the SVG, as in `paint_arcade_stars.gd`.
extends SceneTree
const SIDE := 64
const NAVY := "#010a36"
## The face's two paints (top left → bottom right), the lip under it and the ridge's shade on the right half.
const FACE_TOP := "#ffc24a"
const FACE_BOTTOM := "#ff8a3d"
const LIP := "#d9561c"
const RIDGE := "#e8682a"
const RIDGE_OPACITY := 0.35
## How far the face is lifted up and left off its lip (px) — the lip shows down the right and under the bottom.
const LIP_SHIFT := Vector2i(2, 3)
## The navy rim's width outside the face (px) — the bolt's is about 4.
const RIM := 4.0
## The shield: a flat top with rounded shoulders, straight sides, a point at the bottom.
const SHIELD := "M32 6 L50 11 Q53 12 53 15 L53 29 C53 43 44 52 32 58 C20 52 11 43 11 29 L11 15 Q11 12 14 11 Z"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the folder to write to: -- <dir>")
		quit(1)
		return
	_save(args[0] + "/shield.png")
	quit()


func _save(path: String) -> void:
	var defs := '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0.15" stop-color="%s"/>' \
		% FACE_TOP + '<stop offset="0.85" stop-color="%s"/></linearGradient></defs>' % FACE_BOTTOM
	var outline := _render('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' \
		% [SHIELD, NAVY, NAVY, RIM * 2.0])
	var lip := _render('<path d="%s" fill="%s"/>' % [SHIELD, LIP])
	var face := _render(defs + '<path d="%s" fill="url(#g)"/>' % SHIELD)
	var ridge := _render('<rect x="30" y="0" width="34" height="64" fill="%s" fill-opacity="%s"/>' % [RIDGE, RIDGE_OPACITY])
	var shine := _render('<ellipse cx="22" cy="20" rx="7.5" ry="4.5" fill="#ffffff" fill-opacity="0.8" '
		+ 'transform="rotate(-30 22 20)"/><circle cx="16.5" cy="29" r="2.2" fill="#ffffff" fill-opacity="0.6"/>')
	if outline == null or lip == null or face == null or ridge == null or shine == null: return
	var img := outline.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	# The face, lifted LIP_SHIFT up and left and kept inside the lip, leaves the lip showing down the right and under
	# the bottom; the ridge and the gloss stay inside the face.
	for y in SIDE:
		for x in SIDE:
			var sx := x + LIP_SHIFT.x
			var sy := y + LIP_SHIFT.y
			if sx >= SIDE or sy >= SIDE: continue
			var top := face.get_pixel(sx, sy)
			var inside := minf(top.a, lip.get_pixel(x, y).a)
			if inside <= 0.0: continue
			top.a = inside
			var shade := ridge.get_pixel(x, y)
			shade.a *= inside
			var light := shine.get_pixel(x, y)
			light.a *= inside
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top).blend(shade).blend(light))
	var err := img.save_png(path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
		return
	print("wrote ", path, " ", img.get_size())


func _render(shapes: String) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' \
		% [SIDE, SIDE, SIDE, SIDE, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
