## 🎨 **Paints arcade_light's kill-feed glyphs** (`icons/arcade_light/`): `magnet_arrow` (the arcade horseshoe magnet
## lying on its side, poles to the right, three yellow force waves ")))" coming out of them — "who pulled whom off")
## and `fall` (a down arrow beside the ledge it left — "fell on their own"), in the glyph set's style: a navy (#010a36)
## rim, white faces with a pale lip (#e1e2ed) under the lower edges, as `magnet.png`, `skull.png` and
## `paint_arcade_glyphs.gd`.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_killfeed.gd -- addons/gohud/icons/arcade_light
##
extends SceneTree
const NAVY := "#010a36"
const FACE := "#f9f9f9"
const LIP := "#e1e2ed"
const LIP_DROP := 7.0
const RED := "#ef3340"
const RED_DARK := "#c41e2e"
const RED_LIGHT := "#ff7a83"
const YELLOW := "#ffc928"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the folder to write to: -- <dir>")
		quit(1)
		return
	var out: String = args[0]
	_magnet_arrow(out)
	# fall: a fat down arrow (shaft and head) beside a ledge it dropped off.
	var arrow_outer := _rect(50, 0, 40, 58, 14) + '<path d="M28 44 H112 L70 94 Z" stroke="%s" stroke-width="14" stroke-linejoin="round"/>' % NAVY
	var arrow_inner := _rect(57, 7, 26, 52, 8) + '<path d="M40 51 H100 L70 86 Z" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % "none"
	var ledge_outer := _rect(0, 2, 40, 22, 9)
	var ledge_inner := _rect(7, 9, 26, 8, 4)
	_save(out + "/fall.png", 112, 96, arrow_outer + ledge_outer, arrow_inner + ledge_inner)
	quit()


## The arcade magnet lying on its side, its poles (the open end) to the right, and three yellow force waves ")))"
## leaving them — red body, white pole tips with a pale lip, everything rimmed in navy like the other glyphs.
func _magnet_arrow(out: String) -> void:
	var w := 186
	var h := 100
	# The horseshoe: centre (50, 50), outer radius 44, inner 18, arms reaching x = 104.
	var shoe := "M104 6 H50 A44 44 0 0 0 50 94 H104 V68 H50 A18 18 0 0 1 50 32 H104 Z"
	var art := '<path d="%s" fill="%s" stroke="%s" stroke-width="10" stroke-linejoin="round"/>' % [shoe, NAVY, NAVY]
	art += '<path d="%s" fill="%s"/>' % [shoe, RED]
	# A darker red under the lower curve, a light streak along the top arm.
	art += '<path d="M50 94 A44 44 0 0 1 9 62 L20 60 A32 32 0 0 0 50 84 H80 V94 Z" fill="%s"/>' % RED_DARK
	art += '<rect x="26" y="12" width="50" height="6" rx="3" fill="%s"/>' % RED_LIGHT
	# The pole tips: white, a pale lip under each, a navy seam where the red ends.
	for top: int in [6, 68]:
		art += '<rect x="80" y="%d" width="24" height="26" fill="%s"/>' % [top, FACE]
		art += '<rect x="80" y="%d" width="24" height="7" fill="%s"/>' % [top + 19, LIP]
		art += '<rect x="78" y="%d" width="5" height="26" fill="%s"/>' % [top, NAVY]
	art += '<path d="%s" fill="none" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % [shoe, NAVY]
	# The waves: ")))" from the poles, yellow over a navy rim, round ends.
	var waves := ""
	for wave: Array in [[120, 18, 24], [138, 30, 38], [156, 42, 52]]:
		var d := "M%d %d A%d %d 0 0 1 %d %d" % [wave[0], 50 - wave[1], wave[2], wave[2], wave[0], 50 + wave[1]]
		waves += '<path d="%s" fill="none" stroke="%s" stroke-width="15" stroke-linecap="round"/>' % [d, NAVY]
	for wave: Array in [[120, 18, 24], [138, 30, 38], [156, 42, 52]]:
		var d := "M%d %d A%d %d 0 0 1 %d %d" % [wave[0], 50 - wave[1], wave[2], wave[2], wave[0], 50 + wave[1]]
		waves += '<path d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % [d, YELLOW]
	var img := _render(w, h, art + waves, NAVY)
	if img == null: return
	_write(img, out + "/magnet_arrow.png")


func _rect(x: float, y: float, w: float, h: float, r: float) -> String:
	return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"/>' % [x, y, w, h, r]


func _save(path: String, w: int, h: int, outer: String, inner: String) -> void:
	var outline := _render(w, h, outer, NAVY)
	var lip := _render(w, h, inner, LIP)
	var face := _render(w, h, inner, FACE)
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
	_write(img, path)


func _write(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("%s: %s" % [path, error_string(err)])
		return
	print("wrote ", path, " ", img.get_size())


func _render(w: int, h: int, shapes: String, fill: String) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><g fill="%s">%s</g></svg>' \
		% [w, h, w, h, fill, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
