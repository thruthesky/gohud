shader_type canvas_item;

// GoWorldTourGlow draws the halo baked once per island (TEXTURE: how near the island is, 1 on it, 0 at the reach) over
// the island's rectangle grown by the reach. Per pixel: one fetch of the bake, one of the island's alpha, a colour ramp.
varying float vertex_alpha;
uniform sampler2D atlas_texture : filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_pixel_size = vec2(0.000598, 0.001063);
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);
// The drawn rectangle in atlas UV: start in xy, size in zw.
uniform vec4 glow_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Neighbouring islands' corners inside this island's atlas rectangle, in atlas pixels (x0, y0, x1, y1); empty = none.
uniform vec4 cut_a = vec4(0.0);
uniform vec4 cut_b = vec4(0.0);

bool in_cut(vec2 pixel, vec4 cut) {
	return pixel.x >= cut.x && pixel.y >= cut.y && pixel.x < cut.z && pixel.y < cut.w;
}

float island_mask(vec2 coordinate) {
	// A shared atlas can contain other pictures immediately outside this island's region.
	if (coordinate.x < atlas_region.x || coordinate.y < atlas_region.y || coordinate.x >= atlas_region.z || coordinate.y >= atlas_region.w) return 0.0;
	vec2 pixel = coordinate / atlas_pixel_size;
	// The source atlas rectangles overlap at their corners; each cut matches a notch of GoWorldTourPicture._outline().
	if (in_cut(pixel, cut_a) || in_cut(pixel, cut_b)) return 0.0;
	return 1.0;
}

void vertex() {
	vertex_alpha = COLOR.a;
}

void fragment() {
	// A bright warm-yellow rim tight to the island, fading softly outward; never over the island itself.
	float near = texture(TEXTURE, UV).r;
	vec2 atlas_uv = glow_rect.xy + UV * glow_rect.zw;
	float center = texture(atlas_texture, atlas_uv).a * island_mask(atlas_uv);
	float glow = smoothstep(0.0, 0.85, near);
	vec3 colour = mix(vec3(1.0, 0.80, 0.0), vec3(1.0, 0.98, 0.55), smoothstep(0.65, 1.0, near));
	COLOR = vec4(colour, glow * (1.0 - center) * vertex_alpha);
}
