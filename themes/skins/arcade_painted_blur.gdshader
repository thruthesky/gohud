// The painted arcade scrim (GoSkinArcadePainted.scrim_material): a copy of Magnet Mayhem's BlurBackdrop shader
// (src/ui/blur_backdrop.gd) — nine even taps of the screen behind at a mip level, washed faintly blue. Same uniforms and
// defaults; the skin sets blur_lod and spread from its `arcade_scrim_blur` dial (3 gives the game's 3.0 and 6.0).
// It ignores the scrim node's own colour and draws opaque, as the game's backdrop does.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 3.0;
uniform float spread = 6.0;
uniform vec4 wash : source_color = vec4(0.12, 0.28, 0.6, 0.22);
void fragment() {
	vec2 px = spread / vec2(textureSize(screen_tex, 0));
	vec3 sum = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, blur_lod).rgb;
		}
	}
	COLOR = vec4(mix(sum / 9.0, wash.rgb, wash.a), 1.0);
}
