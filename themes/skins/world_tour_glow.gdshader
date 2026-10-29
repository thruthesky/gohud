shader_type canvas_item;

varying float vertex_alpha;
uniform int island_stage = 0;
uniform vec2 atlas_pixel_size = vec2(0.000598, 0.001063);
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);
// The halo's reach in atlas pixels; GoWorldTourGlow sets it from HALO_REACH.
uniform float reach = 44.0;

float island_mask(vec2 coordinate) {
	// A shared atlas can contain other pictures immediately outside this island's region. Sampling those pixels
	// creates disconnected yellow patches inside the selected picture, even when its own pixels are transparent.
	if (coordinate.x < atlas_region.x || coordinate.y < atlas_region.y || coordinate.x >= atlas_region.z || coordinate.y >= atlas_region.w) return 0.0;
	vec2 pixel = coordinate / atlas_pixel_size;
	// The source atlas rectangles overlap at their corners. Do not draw a halo from a neighbouring island.
	if (island_stage == 5 && pixel.x >= 1220.0 && pixel.y >= 647.0) return 0.0;
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
	// Nearest island pixel within reach, sampled on 12 rays x 6 rings: a bright warm-yellow rim fading softly outward.
	float center = texture(TEXTURE, UV).a * island_mask(UV);
	float near = 0.0;
	for (int ring = 1; ring <= 6; ring++) {
		float r = reach * float(ring) / 6.0;
		float weight = 1.0 - (float(ring) - 1.0) / 6.0;
		for (int k = 0; k < 12; k++) {
			float a = float(k) * 0.523599 + float(ring) * 0.26;
			vec2 p = UV + vec2(cos(a), sin(a)) * r * atlas_pixel_size;
			near = max(near, texture(TEXTURE, p).a * island_mask(p) * weight);
		}
	}
	float glow = smoothstep(0.0, 0.85, near);
	vec3 colour = mix(vec3(1.0, 0.80, 0.0), vec3(1.0, 0.98, 0.55), smoothstep(0.65, 1.0, near));
	COLOR = vec4(colour, glow * (1.0 - center) * vertex_alpha);
}
