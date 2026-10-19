## 🎨 **Paints arcade_light's close key face** (`assets/arcade_light/painted/close_key.png`): the red of `btn_red.png`
## as a disc — the navy (#011a3e) rim, the face's top-to-bottom red (#fd5d59 → #e71f1f) and the dark red lip
## (#b50d10) under it, measured from `btn_red.png` — but no white glare: on a key this small the gloss read as plastic.
## 138 px across, `btn_red.png`'s height, so it draws at the same 2 px per dp.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_close_key.gd -- addons/gohud/assets/arcade_light/painted/close_key.png
##
## 🔑 The lip is composited here, not in the SVG (as `paint_arcade_glyphs.gd`): ThorVG drew a clipped, shifted face
## as nothing at all.
extends SceneTree
const SIZE := 138
const NAVY := "#011a3e"
const LIP := "#b50d10"
const FACE_TOP := "#fd5d59"
const FACE_BOTTOM := "#e71f1f"
## The rim's width and how far the face sits above the lip, in px (`btn_red.png`: about 10 and 12).
const RIM := 10.0
const LIP_DROP := 12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the file to write: -- <path>.png")
		quit(1)
		return
	var c := SIZE * 0.5
	var inner := c - RIM
	var rim := _render('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [c, c, c, NAVY])
	var lip := _render('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [c, c, inner, LIP])
	var face := _render('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>' % FACE_TOP
		+ '<stop offset="1" stop-color="%s"/></linearGradient></defs>' % FACE_BOTTOM
		+ '<circle cx="%s" cy="%s" r="%s" fill="url(#g)"/>' % [c, c, inner])
	if rim == null or lip == null or face == null:
		quit(1)
		return
	var img := rim.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	# The face, lifted LIP_DROP px and kept inside the lip, leaves the lip showing along the lower edge.
	for y in SIZE - LIP_DROP:
		for x in SIZE:
			var top := face.get_pixel(x, y + LIP_DROP)
			top.a = minf(top.a, lip.get_pixel(x, y).a)
			if top.a <= 0.0: continue
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top))
	var err := img.save_png(args[0])
	if err != OK:
		push_error("%s: %s" % [args[0], error_string(err)])
		quit(1)
		return
	print("wrote ", args[0], " ", img.get_size())
	quit()


func _render(shapes: String) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' \
		% [SIZE, SIZE, SIZE, SIZE, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
