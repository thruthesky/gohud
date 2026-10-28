shader_type canvas_item;

uniform vec2 control_size = vec2(100.0, 100.0);
uniform float corner_radius = 20.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 half_size = control_size * 0.5;
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	vec2 q = abs(local_position - half_size) - (half_size - vec2(radius));
	float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float edge = max(fwidth(distance), 0.5);
	COLOR.a *= 1.0 - smoothstep(-edge, edge, distance);
}
