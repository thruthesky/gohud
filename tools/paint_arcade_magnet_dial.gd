## 🎨 **Paints arcade_light's magnet dial** — the art `GoMagnetDial`, `GoItemBox` and the desktop key hints wear, all in
## `assets/arcade_light/hud/` with the HUD's navy (#011037) ink line:
##
## | file | what | px |
## |---|---|---|
## | `dial_attract.png` | the dial's left half: the blue ATTRACT face | 160 × 320 |
## | `dial_repulse.png` | the right half: the red REPULSE face | 160 × 320 |
## | `dial_off.png` | the right half in grey — REPULSE cooling, and both halves of a dial powered down | 160 × 320 |
## | `dial_arrow.png` | one white chevron pointing right (drawn flipped, in rows, flowing) | 64 |
## | `mouse_left.png`, `mouse_right.png` | a mouse with its left / right button painted — the key glyph of a mouse bind | 96 |
## | `powerup_super_magnet.png` | the SUPER MAGNET power-up: a gold horseshoe magnet throwing sparks | 96 |
## | `item_box.png` | the item box's gold frame | 132 |
## | `item_box_empty.png` | the same box with nothing held: a faint dashed frame | 132 |
##
##   godot --headless -s addons/gohud/tools/paint_arcade_magnet_dial.gd -- addons/gohud/assets/arcade_light
##
## 🔑 The halves are drawn mirrored from one shape, so the two faces always meet on the dial's centre line.
extends SceneTree
const NAVY := "#011037"
## A half disc: its radius in px, the rim round the arc and half the centre divider.
const HALF_R := 160.0
const HALF_RIM := 9.0
const HALF_SEAM := 4.5
const ICON := 96
const BOX := 132


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("name the art folder: -- <path>/assets/arcade_light")
		quit(1)
		return
	var hud: String = args[0] + "/hud/"
	var jobs: Array = [
		[_half("#5b97ff", "#2f6bff", "#1f4fd6", true), "dial_attract.png"],
		[_half("#ff6b6b", "#ef3340", "#c4202c", false), "dial_repulse.png"],
		[_half("#a9aec2", "#7d8296", "#5f6478", false), "dial_off.png"],
		[_square(_arrow(), 64), "dial_arrow.png"],
		[_square(_mouse(true), ICON), "mouse_left.png"],
		[_square(_mouse(false), ICON), "mouse_right.png"],
		[_square(_super_magnet(), ICON), "powerup_super_magnet.png"],
		[_square(_item_box(false), BOX), "item_box.png"],
		[_square(_item_box(true), BOX), "item_box_empty.png"],
	]
	for job: Array in jobs:
		var img := job[0] as Image
		if img == null:
			quit(1)
			return
		var err := img.save_png(hud + String(job[1]))
		if err != OK:
			push_error("%s: %s" % [job[1], error_string(err)])
			quit(1)
			return
		print("wrote ", hud + String(job[1]), " ", img.get_size())
	quit()


## One half of the dial's disc, [param left] or right: the navy rim, the face (a top-to-bottom gradient), a darker lip
## along the bottom of the arc and a glare along its top.
func _half(top: String, bottom: String, lip: String, left: bool) -> Image:
	var r := HALF_R
	var inner := r - HALF_RIM
	var reach := sqrt(inner * inner - HALF_SEAM * HALF_SEAM)
	var face := "M%s,%s A%s,%s 0 0 1 %s,%s Z" % [HALF_SEAM, r - reach, inner, inner, HALF_SEAM, r + reach]
	var gloss_r := inner - 16.0
	var a0 := deg_to_rad(-78.0)
	var a1 := deg_to_rad(-22.0)
	var lip_r := inner - 7.0
	var b0 := deg_to_rad(28.0)
	var b1 := deg_to_rad(80.0)
	var shapes := '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>' % top \
		+ '<stop offset="1" stop-color="%s"/></linearGradient></defs>' % bottom \
		+ '<g transform="%s">' % ("translate(%s 0) scale(-1 1)" % r if left else "") \
		+ '<path d="M0,0 A%s,%s 0 0 1 0,%s Z" fill="%s"/>' % [r, r, r * 2.0, NAVY] \
		+ '<path d="%s" fill="url(#g)"/>' % face \
		+ '<path d="M%s,%s A%s,%s 0 0 0 %s,%s" fill="none" stroke="%s" stroke-width="14" stroke-linecap="round"/>' \
			% [cos(b1) * lip_r, r + sin(b1) * lip_r, lip_r, lip_r, cos(b0) * lip_r, r + sin(b0) * lip_r, lip] \
		+ '<path d="M%s,%s A%s,%s 0 0 1 %s,%s" fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="10" stroke-linecap="round"/>' \
			% [cos(a0) * gloss_r, r + sin(a0) * gloss_r, gloss_r, gloss_r, cos(a1) * gloss_r, r + sin(a1) * gloss_r] \
		+ '</g>'
	return _render(shapes, int(r), int(r * 2.0))


## A chevron pointing right, white on the navy line, in a 64 box.
func _arrow() -> String:
	return '<path d="M20,10 L46,32 L20,54" fill="none" stroke="%s" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>' % NAVY \
		+ '<path d="M20,10 L46,32 L20,54" fill="none" stroke="#ffffff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'


## A mouse seen from above, its [param left] or right button painted (blue for the left, red for the right — the
## dial's two halves), in a 96 box.
func _mouse(left: bool) -> String:
	var paint := "#2f6bff" if left else "#ef3340"
	var button := "M27,42 V35 A21,24 0 0 1 48,11 V42 Z" if left else "M69,42 V35 A21,24 0 0 0 48,11 V42 Z"
	return '<rect x="24" y="8" width="48" height="80" rx="24" fill="#ffffff" stroke="%s" stroke-width="6"/>' % NAVY \
		+ '<path d="%s" fill="%s"/>' % [button, paint] \
		+ '<path d="M24,42 H72 M48,8 V42" fill="none" stroke="%s" stroke-width="5"/>' % NAVY \
		+ '<rect x="44" y="18" width="8" height="15" rx="4" fill="#ffffff" stroke="%s" stroke-width="3.5"/>' % NAVY


## The SUPER MAGNET: a gold horseshoe magnet with silver tips, tilted, throwing a cyan bolt and white sparks.
func _super_magnet() -> String:
	var star := "M0,-11 L3,-3 L11,0 L3,3 L0,11 L-3,3 L-11,0 L-3,-3 Z"
	return '<defs><linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff07a"/>' \
		+ '<stop offset="0.5" stop-color="#ffc531"/><stop offset="1" stop-color="#f08a00"/></linearGradient>' \
		+ '<linearGradient id="tip" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff"/>' \
		+ '<stop offset="1" stop-color="#aeb9c8"/></linearGradient></defs>' \
		+ '<g transform="rotate(-18 48 50)">' \
		+ '<path d="M29,30 V52 A19,19 0 0 0 67,52 V30" fill="none" stroke="%s" stroke-width="27"/>' % NAVY \
		+ '<path d="M29,31 V52 A19,19 0 0 0 67,52 V31" fill="none" stroke="url(#gold)" stroke-width="18"/>' \
		+ '<path d="M24,36 V52 A24,24 0 0 0 30,68" fill="none" stroke="#ffffff" stroke-opacity="0.6" stroke-width="3.5" stroke-linecap="round"/>' \
		+ '<rect x="17.5" y="14" width="23" height="18" rx="3" fill="url(#tip)" stroke="%s" stroke-width="4.5"/>' % NAVY \
		+ '<rect x="55.5" y="14" width="23" height="18" rx="3" fill="url(#tip)" stroke="%s" stroke-width="4.5"/>' % NAVY \
		+ '</g>' \
		+ '<path d="M44,6 L36,24 L45,24 L39,40 L56,19 L47,19 L52,6 Z" fill="#6ff0ff" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % NAVY \
		+ '<path d="%s" transform="translate(80 22)" fill="#ffffff" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [star, NAVY] \
		+ '<path d="%s" transform="translate(13 60) scale(0.7)" fill="#ffffff" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % [star, NAVY]


## The item box, 132 px for a 66 dp slot: the navy line, the gold frame and a deep blue well — or, [param empty], a faint
## well in a dashed white frame.
func _item_box(empty: bool) -> String:
	if empty:
		return '<rect x="7" y="7" width="118" height="118" rx="32" fill="#17235a" fill-opacity="0.35"/>' \
			+ '<rect x="7" y="7" width="118" height="118" rx="32" fill="none" stroke="#ffffff" stroke-opacity="0.7" stroke-width="6" stroke-dasharray="17 12" stroke-linecap="round"/>'
	return '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2f3f8a"/>' \
		+ '<stop offset="1" stop-color="#17235a"/></linearGradient>' \
		+ '<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe066"/>' \
		+ '<stop offset="1" stop-color="#ffb412"/></linearGradient></defs>' \
		+ '<rect x="0" y="0" width="132" height="132" rx="38" fill="%s"/>' % NAVY \
		+ '<rect x="5" y="5" width="122" height="122" rx="33" fill="url(#f)"/>' \
		+ '<rect x="14" y="14" width="104" height="104" rx="25" fill="%s"/>' % NAVY \
		+ '<rect x="17" y="17" width="98" height="98" rx="22" fill="url(#g)"/>' \
		+ '<path d="M30,25 H84" fill="none" stroke="#ffffff" stroke-opacity="0.28" stroke-width="6" stroke-linecap="round"/>'


func _square(shapes: String, box: int) -> Image:
	return _render(shapes, box, box)


func _render(shapes: String, width: int, height: int) -> Image:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' \
		% [width, height, width, height, shapes]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("svg: %s" % error_string(err))
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img
