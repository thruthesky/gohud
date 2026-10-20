## 🎨 **Paints arcade_light's multiplayer glyph** (`icons/arcade_light/multiplayer.png`): three people — one in front, two a step
## behind on either side, the front one's navy rim cutting it out of the pair behind — in the glyph set's style, as
## `person.png`: a navy (#010a36) rim, white faces with a pale lip (#e1e2ed) under the lower edges
## (`paint_arcade_glyphs.gd`, `paint_arcade_killfeed.gd`).
##
##   godot --headless -s addons/gohud/tools/paint_arcade_multiplayer.gd -- addons/gohud/icons/arcade_light
##
extends SceneTree
const NAVY := "#010a36"
const FACE := "#f9f9f9"
const LIP := "#e1e2ed"
const LIP_DROP := 7.0
const RIM := 14
const W := 138
const H := 96
const BOTTOM := 88.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the folder to write to: -- <dir>")
		quit(1)
		return
	var out: String = args[0]
	# The pair behind, smaller and higher; then the one in front, painted over them.
	var back := _glyph(_person(31, 22, 0.8, true) + _person(107, 22, 0.8, true), _person(31, 22, 0.8, false) + _person(107, 22, 0.8, false))
	var front := _glyph(_person(69, 30, 1.0, true), _person(69, 30, 1.0, false))
	if back == null or front == null: return
	back.blend_rect(front, Rect2i(Vector2i.ZERO, front.get_size()), Vector2i.ZERO)
	_write(back, out + "/multiplayer.png")
	quit()


## One person centred on x = `cx`, the head's centre at y = `cy`, `s` its size: a round head over a body with a
## domed top, standing on the glyph's floor (BOTTOM); `rim` grows both by the navy rim.
func _person(cx: float, cy: float, s: float, rim: bool) -> String:
	var r := 17.0 * s
	var half := 29.0 * s
	var top := cy + r + 6.0 * s
	var bottom := BOTTOM
	var dome := 22.0 * s
	var body := "M%s %s V%s A%s %s 0 0 1 %s %s V%s Z" % [cx - half, bottom, top + dome, half, dome, cx + half, top + dome, bottom]
	var stroke := ' stroke="%s" stroke-width="%d" stroke-linejoin="round"' % [NAVY, RIM] if rim else ""
	return '<circle cx="%s" cy="%s" r="%s"%s/><path d="%s"%s/>' % [cx, cy, r, stroke, body, stroke]


## The outline, then the face lifted LIP_DROP px inside the lip, leaving the lip under every lower edge.
func _glyph(outer: String, inner: String) -> Image:
	var outline := _render(outer, NAVY)
	var lip := _render(inner, LIP)
	var face := _render(inner, FACE)
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
	return img


func _write(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
		return
	print("wrote ", path, " ", img.get_size())


func _render(shapes: String, fill: String) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g fill="%s">%s</g></svg>' \
		% [W, H, W, H, fill, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
