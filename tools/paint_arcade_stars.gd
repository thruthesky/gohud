## 🎨 **Paints arcade_light's rating stars** (`assets/arcade_light/stage/star.png` and `star_empty.png`), which Magnet
## Mayhem's stage art never had, in the style of its painted check: a chubby rounded star with a thick navy (#010a36)
## rim, a face lit from the top with a darker lip under its lower edges — no white gloss or glint (owner's request,
## 2026-10-29: clean gold / grey fills in the dark rim). `star` is
## the earned star (the game's GOLD #ffc928), `star_empty` the slot of one still to earn (the grey-lavender of a locked
## card) — `GoStarRow` and `GoLevelCard.stars` draw them.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_stars.gd -- addons/gohud/assets/arcade_light/stage
##
## 🔑 The lip and the gloss are composited here, not in the SVG, as in `paint_arcade_glyphs.gd`.
extends SceneTree
const SIDE := 96
const NAVY := "#010a36"
## [face top, face bottom, lip] — the earned star and the empty slot.
const GOLD := ["#ffe27a", "#ffc928", "#e08a00"]
const EMPTY := ["#d6d9ea", "#b9bed6", "#8a8fb3"]
const LIP_DROP := 5
## The star: its centre sits a little low (the lower points are longer than the top one), outer and inner radii.
const CENTRE := Vector2(48.0, 52.0)
const OUTER := 37.0
const INNER := 19.5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the folder to write to: -- <dir>")
		quit(1)
		return
	var out: String = args[0]
	_save(out + "/star.png", GOLD, false)
	_save(out + "/star_empty.png", EMPTY, false)
	quit()


## The star's ten corners, the first one straight up.
func _points(outer: float, inner: float) -> String:
	var parts := PackedStringArray()
	for i in 10:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + PI * i / 5.0
		var p := CENTRE + Vector2(cos(angle), sin(angle)) * radius
		parts.append("%.2f,%.2f" % [p.x, p.y])
	return " ".join(parts)


## A star rounded by a stroke of its own colour as wide as [param round].
func _star(outer: float, inner: float, round: float, fill: String) -> String:
	return '<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' \
		% [_points(outer, inner), fill, fill, round]


func _save(path: String, colours: Array, gloss: bool) -> void:
	var defs := '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>' \
		% colours[0] + '<stop offset="1" stop-color="%s"/></linearGradient></defs>' % colours[1]
	var outline := _render(_star(OUTER, INNER, 16.0, NAVY))
	var lip := _render(_star(OUTER - 8.0, INNER - 4.0, 6.0, colours[2]))
	var face := _render(defs + _star(OUTER - 8.0, INNER - 4.0, 6.0, "url(#g)"))
	var shine := _render('<ellipse cx="36" cy="34" rx="9" ry="5.5" fill="#ffffff" fill-opacity="0.85" transform="rotate(-35 36 34)"/>')
	if outline == null or lip == null or face == null or shine == null: return
	var img := outline.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	# The face, lifted LIP_DROP px and kept inside the lip, leaves the lip showing under every lower edge.
	for y in SIDE:
		for x in SIDE:
			if y + LIP_DROP >= SIDE: continue
			var top := face.get_pixel(x, y + LIP_DROP)
			top.a = minf(top.a, lip.get_pixel(x, y).a)
			if top.a <= 0.0: continue
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top))
	if gloss:
		for y in SIDE:
			for x in SIDE:
				var light := shine.get_pixel(x, y)
				if light.a <= 0.0: continue
				light.a = minf(light.a, face.get_pixel(x, mini(SIDE - 1, y + LIP_DROP)).a)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(light))
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
