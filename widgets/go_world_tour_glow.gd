## A picture's selected halo: a soft warm-yellow outer glow. Its shape is baked once per island from the island's
## alpha (blurred, then turned back into a distance to the island) and cached, so each frame draws one textured quad.
@tool
class_name GoWorldTourGlow
extends Control

## The halo's reach beyond the island, as a share of the picture's height.
const HALO_REACH := 0.11
## Box-blur radius of the bake, in baked texels. Its passes together reach BLUR_RADIUS × BLUR_PASSES texels, which
## the bake's grid makes the halo's reach.
const BLUR_RADIUS := 3
const BLUR_PASSES := 3
const _FAR := 100000
## Neighbouring islands' corners inside an arcade island's atlas rectangle, in atlas pixels. Each matches a notch of
## GoWorldTourPicture._outline(); the halo must never grow from them.
const ISLAND_CUTS := {
	5: [Rect2i(1220, 647, _FAR, _FAR)],
	6: [Rect2i(-_FAR, -_FAR, _FAR + 435, _FAR + 325), Rect2i(-_FAR, 560, _FAR + 425, _FAR)],
	7: [Rect2i(250, -_FAR, _FAR, _FAR + 580)],
	8: [Rect2i(750, -_FAR, _FAR, _FAR + 657)],
	9: [Rect2i(-_FAR, -_FAR, _FAR + 1237, _FAR + 657)],
}

## Baked halos by source picture, rectangle and cuts.
static var _bakes := {}
## A straight edge blurred like a bake (see _edge_profile()).
static var _profile := PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow := ShaderMaterial.new()
	glow.shader = load("res://addons/gohud/themes/skins/world_tour_glow.gdshader")
	material = glow
	resized.connect(queue_redraw)


func _draw() -> void:
	var picture := get_parent()
	if picture == null or not picture.has_method(&"draw_art"): return
	var data: Dictionary = picture.call(&"_picture_data")
	if data.is_empty(): return
	var source: Texture2D = data.source
	var region: Rect2 = data.region
	var cuts: Array = ISLAND_CUTS.get(int(picture.get("stage")), []) if data.masked else []
	var pad := ceili(region.size.y * HALO_REACH)
	var start := Vector2i(region.position.floor())
	var bake_rect := Rect2i(start - Vector2i(pad, pad), Vector2i(region.end.ceil()) - start + Vector2i(pad, pad) * 2)
	var bake := baked_halo(source, region, cuts, bake_rect)
	if bake == null: return
	var texel := Vector2.ONE / source.get_size()
	var shader := material as ShaderMaterial
	shader.set_shader_parameter(&"atlas_texture", source)
	shader.set_shader_parameter(&"atlas_pixel_size", texel)
	shader.set_shader_parameter(&"atlas_region", Vector4(region.position.x * texel.x, region.position.y * texel.y,
			region.end.x * texel.x, region.end.y * texel.y))
	shader.set_shader_parameter(&"glow_rect", Vector4(bake_rect.position.x * texel.x, bake_rect.position.y * texel.y,
			bake_rect.size.x * texel.x, bake_rect.size.y * texel.y))
	for i in 2:
		var cut: Rect2i = cuts[i] if i < cuts.size() else Rect2i()
		shader.set_shader_parameter(&"cut_a" if i == 0 else &"cut_b",
				Vector4(cut.position.x, cut.position.y, cut.end.x, cut.end.y))
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	var origin := (size - region.size * scale_factor) * 0.5
	draw_texture_rect(bake, Rect2(origin + (Vector2(bake_rect.position) - region.position) * scale_factor,
			Vector2(bake_rect.size) * scale_factor), false)


## The halo of `region` of `source` without the `cuts`, over `bake_rect` (all atlas pixels; the rectangle's padding is
## the reach): an L8 texture of how near each texel is to the island, 1 on it, fading linearly to 0 at the reach.
## Baked once per picture and cached.
static func baked_halo(source: Texture2D, region: Rect2, cuts: Array, bake_rect: Rect2i) -> Texture2D:
	var key := "%d|%s|%s|%s" % [source.get_instance_id(), region, bake_rect, cuts]
	if _bakes.has(key): return _bakes[key]
	var image := GoWorldTourPicture.atlas_image(source)
	if image == null or image.is_empty(): return null
	if image.is_compressed() or image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
	# The island alone: its own rectangle copied into a transparent canvas grown by the reach, neighbours' corners cut.
	var island := Image.create(bake_rect.size.x, bake_rect.size.y, false, Image.FORMAT_RGBA8)
	var start := Vector2i(region.position.floor())
	var own := Rect2i(start, Vector2i(region.end.ceil()) - start).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	island.blit_rect(image, own, own.position - bake_rect.position)
	for cut: Rect2i in cuts:
		var local := Rect2i(cut.position - bake_rect.position, cut.size).intersection(Rect2i(Vector2i.ZERO, bake_rect.size))
		if local.has_area(): island.fill_rect(local, Color.TRANSPARENT)
	# Down to a grid where the reach is the blur's (Lanczos averages every source pixel), then a separable box blur.
	var reach_texels := float(BLUR_RADIUS * BLUR_PASSES)
	var step := maxf(float(start.y - bake_rect.position.y), 1.0) / reach_texels
	var w := maxi(1, roundi(bake_rect.size.x / step))
	var h := maxi(1, roundi(bake_rect.size.y / step))
	island.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var bytes := island.get_data()
	var field := PackedFloat32Array()
	field.resize(w * h)
	for i in w * h: field[i] = bytes[i * 4 + 3] / 255.0
	for i in BLUR_PASSES:
		field = _box_pass(field, w, h, true)
		field = _box_pass(field, w, h, false)
	# A blurred value tells how far outside a straight edge its texel lies: nearness falls linearly with that distance.
	if _profile.is_empty(): _profile = _edge_profile()
	var out := PackedByteArray()
	out.resize(w * h)
	for i in w * h:
		out[i] = roundi(clampf(1.0 - _distance(field[i]) / reach_texels, 0.0, 1.0) * 255.0)
	var bake := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, out))
	_bakes[key] = bake
	return bake


## One box-blur pass of BLUR_RADIUS along rows (`horizontal`) or columns; outside the field counts as empty.
static func _box_pass(field: PackedFloat32Array, w: int, h: int, horizontal: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(field.size())
	var lines := h if horizontal else w
	var n := w if horizontal else h
	var stride := 1 if horizontal else w
	var scale := 1.0 / float(BLUR_RADIUS * 2 + 1)
	for line in lines:
		var base := line * w if horizontal else line
		var sum := 0.0
		for i in mini(BLUR_RADIUS + 1, n): sum += field[base + i * stride]
		for i in n:
			out[base + i * stride] = sum * scale
			var add := i + BLUR_RADIUS + 1
			if add < n: sum += field[base + add * stride]
			var drop := i - BLUR_RADIUS
			if drop >= 0: sum -= field[base + drop * stride]
	return out


## A straight edge blurred like a bake: entry i is the value i + 0.5 texels outside it, falling from below 0.5 to 0.
static func _edge_profile() -> PackedFloat32Array:
	var n := BLUR_RADIUS * BLUR_PASSES * 2 + 2
	var line := PackedFloat32Array()
	line.resize(n)
	for i in n: line[i] = 1.0 if i < n / 2 else 0.0
	for i in BLUR_PASSES: line = _box_pass(line, n, 1, true)
	return line.slice(n / 2)


## How far outside the island a blurred `value` lies, in baked texels; 0 on or inside its edge (value 0.5 or more).
static func _distance(value: float) -> float:
	if value >= 0.5: return 0.0
	if value >= _profile[0]: return 0.5 * (0.5 - value) / maxf(0.5 - _profile[0], 0.000001)
	if value <= 0.0: return float(_profile.size())
	var low := 0
	var high := _profile.size() - 1
	while high - low > 1:
		var mid := (low + high) / 2
		if _profile[mid] >= value: low = mid
		else: high = mid
	if _profile[high] >= value: return float(high) + 0.5
	return float(low) + 0.5 + (_profile[low] - value) / maxf(_profile[low] - _profile[high], 0.000001)
