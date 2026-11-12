## 🎨 **Paints arcade_light's reward burst** (`GoRewardBurst`): the light behind a reward and the sparkles round it, in
## `assets/arcade_light/rewards/`. Every piece is drawn additively over the burst's navy dim, so each is a warm white-gold
## on a clear background whose alpha is the light's strength.
##
##   godot --headless -s addons/gohud/tools/paint_arcade_reward_fx.gd -- addons/gohud/assets/arcade_light/rewards [heap.png]
##
## | file | size | what |
## |---|---|---|
## | `fx_rays.png` | 512 | 16 soft wedges from the centre, fading out to the rim (the long, slow layer) |
## | `fx_rays_thin.png` | 512 | 10 narrower, brighter wedges (the short layer turning the other way) |
## | `fx_glow.png` | 256 | a round warm glow, white at the heart |
## | `fx_ring.png` | 256 | the burst's shockwave: a thin bright ring with a gold fringe |
## | `fx_sparkle.png` | 64 | a four-point twinkle: the particles of the trail, the burst and the twinkles |
## | `fx_glint.png` | 128 | a crisp four-point star with long thin arms: the glint on the coin's rim |
## | `coin_heap.png` | 320 | (given a heap picture) the heap trimmed to its pixels and fitted to 320 px on its long side |
##
## 🔑 The colours are the look's gold (`warning_fill` #ffc928) lifted towards white, as the preview the owner approved
##    drew them in code; baking them here keeps every colour of the effect in gohud's art.
extends SceneTree

const WARM := Color("#fff1b8")
const GOLD := Color("#ffd75a")
const HEAP_SIDE := 320


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("give the rewards folder")
		quit(2)
		return
	var out: String = args[0]
	_save(_rays(512, 16, 0.55, 0.62), out + "/fx_rays.png")
	_save(_rays(512, 10, 0.35, 0.85), out + "/fx_rays_thin.png")
	_save(_glow(256), out + "/fx_glow.png")
	_save(_ring(256), out + "/fx_ring.png")
	_save(_star(64, 0.9, 3.0), out + "/fx_sparkle.png")
	_save(_glint(128), out + "/fx_glint.png")
	if args.size() > 1:
		_save(_heap(args[1]), out + "/coin_heap.png")
	quit(0)


func _save(image: Image, path: String) -> void:
	var err := image.save_png(path)
	print("%s %s (%dx%d)" % ["wrote" if err == OK else "FAILED", path, image.get_width(), image.get_height()])


## `count` wedges, each `width` of its step wide, soft at its sides and fading from `strength` at the centre to clear at
## the rim. Wedge 0 points right.
func _rays(n: int, count: int, width: float, strength: float) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var step := TAU / count
	var half := step * width * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var r := p.length()
			if r >= 1.0:
				img.set_pixel(x, y, Color(WARM, 0.0))
				continue
			var a := fposmod(p.angle() + step * 0.5, step) - step * 0.5
			var side := clampf((1.0 - absf(a) / half) * 2.5, 0.0, 1.0) # flat across, soft at its sides
			side = side * side * (3.0 - 2.0 * side)
			var fall := pow(1.0 - r, 1.1)
			var core := clampf(1.0 - r * 4.0, 0.0, 1.0) # the centre fills in under the wedges
			var alpha := clampf(maxf(side * fall, core * 0.8) * strength, 0.0, 1.0)
			img.set_pixel(x, y, Color(WARM.lerp(GOLD, r), alpha))
	return img


func _glow(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := (Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE).length()
			var alpha := 0.0
			if r < 0.25: alpha = lerpf(1.0, 0.7, r / 0.25)
			elif r < 0.6: alpha = lerpf(0.7, 0.18, (r - 0.25) / 0.35)
			elif r < 1.0: alpha = lerpf(0.18, 0.0, (r - 0.6) / 0.4)
			img.set_pixel(x, y, Color(Color.WHITE.lerp(WARM, clampf(r * 1.6, 0.0, 1.0)), alpha))
	return img


func _ring(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := (Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE).length()
			var alpha := 0.0
			var ink := Color.WHITE
			if r >= 0.8 and r < 0.9: alpha = lerpf(0.0, 0.95, (r - 0.8) / 0.1)
			elif r >= 0.9 and r < 0.95:
				alpha = lerpf(0.95, 0.5, (r - 0.9) / 0.05)
				ink = WARM
			elif r >= 0.95 and r < 1.0:
				alpha = lerpf(0.5, 0.0, (r - 0.95) / 0.05)
				ink = GOLD
			img.set_pixel(x, y, Color(ink, alpha))
	return img


## A four-point star: arms along the axes, `thin` how sharply they narrow, a round core.
func _star(n: int, reach: float, core_scale: float) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := absf((x + 0.5) / n * 2.0 - 1.0)
			var v := absf((y + 0.5) / n * 2.0 - 1.0)
			var star := clampf(1.0 - (sqrt(u) + sqrt(v)) * reach, 0.0, 1.0)
			var core := clampf(1.0 - sqrt(u * u + v * v) * core_scale, 0.0, 1.0)
			var alpha := clampf(star * 1.6 + core, 0.0, 1.0)
			img.set_pixel(x, y, Color(Color.WHITE.lerp(WARM, clampf((u + v) * 1.2, 0.0, 1.0)), alpha))
	return img


func _glint(n: int) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := absf((x + 0.5) / n * 2.0 - 1.0)
			var v := absf((y + 0.5) / n * 2.0 - 1.0)
			# Two thin arms (a cross) that taper to the edge, and a small bright heart.
			var arm_h := clampf(1.0 - v / maxf(0.002, 0.07 * (1.0 - u)), 0.0, 1.0) * (1.0 - u)
			var arm_v := clampf(1.0 - u / maxf(0.002, 0.07 * (1.0 - v)), 0.0, 1.0) * (1.0 - v)
			var heart := clampf(1.0 - sqrt(u * u + v * v) * 5.0, 0.0, 1.0)
			var alpha := clampf(maxf(arm_h, arm_v) + heart, 0.0, 1.0)
			img.set_pixel(x, y, Color(Color.WHITE.lerp(WARM, clampf(maxf(u, v), 0.0, 1.0)), alpha))
	return img


func _heap(source: String) -> Image:
	var img := Image.load_from_file(source)
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	img = img.get_region(used)
	var k := float(HEAP_SIDE) / maxf(used.size.x, used.size.y)
	img.resize(maxi(1, roundi(used.size.x * k)), maxi(1, roundi(used.size.y * k)), Image.INTERPOLATE_LANCZOS)
	return img
