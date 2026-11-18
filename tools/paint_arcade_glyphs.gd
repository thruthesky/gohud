## 🎨 **Paints arcade_light's plus, minus, close and home glyphs** (`icons/arcade_light/`), which Magnet Mayhem's glyph set
## never had, in that set's style: a white face, a navy (#010a36) outline about 7 px on a 96 px glyph, and a pale lip
## (#e1e2ed) under every lower edge — measured from `pause.png` and `check.png`.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_glyphs.gd -- addons/gohud/icons/arcade_light
##
## 🔑 The lip is composited here, not in the SVG: ThorVG drew a clipped, shifted face as nothing at all.
extends SceneTree
const NAVY := "#010a36"
const FACE := "#f9f9f9"
const LIP := "#e1e2ed"
const LIP_DROP := 7.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the folder to write to: -- <dir>")
		quit(1)
		return
	var out: String = args[0]
	# Each glyph: [view width, view height, outer (outline) shapes, inner (face) shapes, transform].
	var plus_outer := _rect(24, 0, 48, 96, 18) + _rect(0, 24, 96, 48, 18)
	var plus_inner := _rect(31, 7, 34, 82, 11) + _rect(7, 31, 82, 34, 11)
	_save(out + "/plus.png", 96, 96, plus_outer, plus_inner, "")
	_save(out + "/minus.png", 96, 48, _rect(0, 0, 96, 48, 18), _rect(7, 7, 82, 34, 11), "")
	var x_outer := _rect(2, 26, 92, 44, 17) + _rect(26, 2, 44, 92, 17)
	var x_inner := _rect(9, 33, 78, 30, 10) + _rect(33, 9, 30, 78, 10)
	_save(out + "/close.png", 96, 96, x_outer, x_inner, "rotate(45 48 48)")
	# The house: a roof (a triangle, its corners rounded by a stroke of its own colour) over the walls; the doorway
	# is the outline's navy, open to the ground. Wider than tall, like the set's other glyphs.
	var house_outer := _roof("48,6 89,47 7,47", 10) + _rect(16, 40, 64, 48, 12)
	var house_inner := _roof("48,13 79,44 17,44", 6) + _rect(23, 44, 50, 22, 6) \
			+ _rect(23, 44, 15, 37, 6) + _rect(58, 44, 15, 37, 6)
	_save(out + "/home.png", 96, 88, house_outer, house_inner, "")
	quit()


func _rect(x: float, y: float, w: float, h: float, r: float) -> String:
	return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"/>' % [x, y, w, h, r]


## A triangle with round corners; "{c}" is the colour _render paints with.
func _roof(points: String, stroke: float) -> String:
	return '<polygon points="%s" stroke="{c}" stroke-width="%s" stroke-linejoin="round"/>' % [points, stroke]


func _save(path: String, w: int, h: int, outer: String, inner: String, turn: String) -> void:
	var outline := _render(w, h, outer, turn, NAVY)
	var lip := _render(w, h, inner, turn, LIP)
	var face := _render(w, h, inner, turn, FACE)
	if outline == null or lip == null or face == null: return
	# The face, lifted LIP_DROP px and kept inside the lip, leaves the lip showing under every lower edge.
	var drop := int(LIP_DROP)
	var img := outline.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	for y in h:
		for x in w:
			if y + drop >= h: continue
			var top := face.get_pixel(x, y + drop)
			top.a = minf(top.a, lip.get_pixel(x, y).a)
			if top.a <= 0.0: continue
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top))
	var err := img.save_png(path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
		return
	print("wrote ", path, " ", img.get_size())


func _render(w: int, h: int, shapes: String, turn: String, fill: String) -> Image:
	var t := ' transform="%s"' % turn if turn != "" else ""
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g fill="%s"%s>%s</g></svg>' \
		% [w, h, w, h, fill, t, shapes.replace("{c}", fill)]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
