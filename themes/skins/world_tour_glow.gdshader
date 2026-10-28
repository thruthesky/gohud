shader_type canvas_item;

varying float vertex_alpha;
uniform int island_stage = 0;
uniform vec2 atlas_pixel_size = vec2(0.000598, 0.001063);

float island_mask(vec2 coordinate) {
	vec2 pixel = coordinate / atlas_pixel_size;
	// The source atlas rectangles overlap at their corners. Do not draw a halo from a neighbouring island.
	if (island_stage == 6 && pixel.x < 435.0 && pixel.y < 325.0) return 0.0;
	if (island_stage == 7 && pixel.x > 250.0 && pixel.y < 580.0) return 0.0;
	if (island_stage == 8 && pixel.x > 750.0 && pixel.y < 657.0) return 0.0;
	if (island_stage == 9 && pixel.x < 1237.0 && pixel.y < 657.0) return 0.0;
	return 1.0;
}

void vertex() {
	vertex_alpha = COLOR.a;
}

void fragment() {
	vec2 step_size = atlas_pixel_size * 14.0;
	float center = texture(TEXTURE, UV).a * island_mask(UV);
	float halo = 0.0;
	vec2 p = UV + vec2(step_size.x, 0.0); halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV - vec2(step_size.x, 0.0); halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV + vec2(0.0, step_size.y); halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV - vec2(0.0, step_size.y); halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV + step_size * 0.707; halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV - step_size * 0.707; halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV + vec2(step_size.x, -step_size.y) * 0.707; halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	p = UV + vec2(-step_size.x, step_size.y) * 0.707; halo = max(halo, texture(TEXTURE, p).a * island_mask(p));
	COLOR = vec4(1.0, 0.92, 0.28, max(0.0, halo - center) * vertex_alpha * 0.8);
}
