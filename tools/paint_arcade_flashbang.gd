## 🎨 **Paints arcade_light's flashbang power-up** — its HUD icon (`assets/arcade_light/hud/powerup_flashbang.png`,
## 96 px, beside `powerup_bomb`) and its item key (`assets/arcade_light/touch/btn_flashbang.png`, 256 px, the purple
## glossy disc of `btn_banana` with the icon on it). A toy stun grenade — olive canister with two dark bands, a silver
## cap and spoon lever, a gold pull ring — going off in a white-and-yellow burst at its fuse, all with the HUD's navy
## (#011037) ink line. The disc's colours are measured from `btn_banana.png`: the navy rim, the face's top-to-bottom
## purple (#9b3ffb → #7520fb), the dark purple lip (#4c03d0) under it and the lilac glare (#c183fa) along the top.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_flashbang.gd -- addons/gohud/assets/arcade_light
##
## 🔑 Like `paint_arcade_close_key.gd`, every layer is its own SVG and the lip is composited here: ThorVG draws one
## clean shape per call.
extends SceneTree
const ICON := 96
const KEY := 256
const NAVY := "#011037"
const LIP := "#4c03d0"
const FACE_TOP := "#9b3ffb"
const FACE_BOTTOM := "#7520fb"
const GLARE := "#c183fa"
## The key's rim and how far its face sits above the lip, in px (`btn_banana.png`: about 12 and 14).
const RIM := 12.0
const LIP_DROP := 14
## The icon's share of the key and how far above the key's centre it sits (the lip shows under it).
const KEY_ICON_SHARE := 0.7
const KEY_ICON_LIFT := 8

## The grenade, in a 96-unit box (shrunk a little so the burst's tips stay inside): the burst at the fuse (up-right), then the canister tilted back, the lever and the
## ring over it.
const GRENADE := """
<defs>
<linearGradient id="body" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#9aa77f"/><stop offset="0.55" stop-color="#6f7b55"/><stop offset="1" stop-color="#4d5638"/>
</linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#d4dbe3"/><stop offset="1" stop-color="#8e9aa8"/>
</linearGradient>
</defs>
<g transform="translate(3 5) scale(0.93)">
<g transform="translate(62 22)">
<path d="M0,-21 L5,-8 L18,-14 L10,-3 L22,4 L8,5 L12,19 L2,9 L-6,20 L-5,6 L-19,9 L-9,-1 L-18,-12 L-5,-7 Z"
 fill="#ffe14a" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M0,-10 L3,-4 L9,-6 L5,-1 L10,3 L4,3 L5,9 L1,4 L-3,9 L-2,3 L-9,4 L-4,0 L-8,-6 L-2,-4 Z" fill="#ffffff"/>
</g>
<g transform="rotate(-16 44 56)">
<rect x="27" y="36" width="34" height="50" rx="9" fill="url(#body)" stroke="%s" stroke-width="4"/>
<rect x="29" y="47" width="30" height="6" fill="#3e4630"/>
<rect x="29" y="70" width="30" height="6" fill="#3e4630"/>
<circle cx="38" cy="61.5" r="2.2" fill="#3e4630"/><circle cx="46" cy="61.5" r="2.2" fill="#3e4630"/>
<circle cx="54" cy="61.5" r="2.2" fill="#3e4630"/>
<rect x="32" y="39" width="5" height="42" rx="2.5" fill="#ffffff" fill-opacity="0.35"/>
<rect x="33" y="26" width="22" height="12" rx="3" fill="url(#metal)" stroke="%s" stroke-width="4"/>
<path d="M53,29 C64,31 67,42 64,66" fill="none" stroke="%s" stroke-width="10" stroke-linecap="round"/>
<path d="M53,29 C64,31 67,42 64,66" fill="none" stroke="url(#metal)" stroke-width="4.5" stroke-linecap="round"/>
<circle cx="30" cy="24" r="7.5" fill="none" stroke="%s" stroke-width="7.5"/>
<circle cx="30" cy="24" r="7.5" fill="none" stroke="#ffd23f" stroke-width="3"/>
</g>
</g>
"""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the art folder: -- <path>/assets/arcade_light")
		quit(1)
		return
	var root: String = args[0]
	var shapes := GRENADE % [NAVY, NAVY, NAVY, NAVY, NAVY]
	var icon := _render(shapes, ICON, 1.0)
	var key := _key(shapes)
	if icon == null or key == null:
		quit(1)
		return
	for pair: Array in [[icon, root + "/hud/powerup_flashbang.png"], [key, root + "/touch/btn_flashbang.png"]]:
		var err: Error = (pair[0] as Image).save_png(pair[1])
		if err != OK:
			push_error("%s: %s" % [pair[1], error_string(err)])
			quit(1)
			return
		print("wrote ", pair[1], " ", (pair[0] as Image).get_size())
	quit()


## The item key: the disc (rim, lip, face lifted LIP_DROP px, glare) with the icon on it.
func _key(shapes: String) -> Image:
	var c := KEY * 0.5
	var inner := c - RIM
	var rim := _render('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [c, c, c, NAVY], KEY, 1.0)
	var lip := _render('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % [c, c, inner, LIP], KEY, 1.0)
	var face := _render('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>' % FACE_TOP
		+ '<stop offset="1" stop-color="%s"/></linearGradient></defs>' % FACE_BOTTOM
		+ '<circle cx="%s" cy="%s" r="%s" fill="url(#g)"/>' % [c, c, inner], KEY, 1.0)
	var glare := _render('<path d="M%s,%s A%s,%s 0 0 1 %s,%s" fill="none" stroke="%s" stroke-width="9" stroke-linecap="round"/>'
		% [c - inner * 0.62, c - inner * 0.62, inner - 12, inner - 12, c + inner * 0.62, c - inner * 0.62, GLARE], KEY, 1.0)
	var side := int(KEY * KEY_ICON_SHARE)
	var art := _render(shapes, ICON, float(side) / ICON)
	if rim == null or lip == null or face == null or glare == null or art == null:
		return null
	var img := rim.duplicate() as Image
	img.blend_rect(lip, Rect2i(Vector2i.ZERO, lip.get_size()), Vector2i.ZERO)
	for y in KEY - LIP_DROP:
		for x in KEY:
			var top := face.get_pixel(x, y + LIP_DROP)
			top.a = minf(top.a, lip.get_pixel(x, y).a)
			if top.a <= 0.0: continue
			img.set_pixel(x, y, img.get_pixel(x, y).blend(top))
	img.blend_rect(glare, Rect2i(Vector2i.ZERO, glare.get_size()), Vector2i.ZERO)
	var at := Vector2i((KEY - art.get_width()) / 2, (KEY - art.get_height()) / 2 - KEY_ICON_LIFT)
	img.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)
	return img


func _render(shapes: String, box: int, scale: float) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' \
		% [box, box, box, box, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
