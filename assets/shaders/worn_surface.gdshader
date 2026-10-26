shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.35, 0.33, 1.0);
// 0 — штукатурка, 1 — плитка, 2 — древесина, 3 — ткань.
uniform int surface_kind = 0;
uniform float pixel_density = 48.0;
varying vec3 world_position;
varying vec3 world_normal;

float grain(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = floor(world_position * pixel_density);
	float fine = grain(p);
	float stains = grain(floor(world_position * 3.0));
	float value = 0.87 + fine * 0.12 - step(stains, 0.14) * 0.08;
	if (surface_kind == 1) {
		vec2 tile = world_position.xz * 1.6;
		vec2 edge = min(fract(tile), 1.0 - fract(tile));
		float checker = mod(floor(tile.x) + floor(tile.y), 2.0);
		value *= mix(0.55, 1.0, checker);
		value *= mix(0.3, 1.0, step(0.025, min(edge.x, edge.y)));
	} else if (surface_kind == 2) {
		float streak = grain(vec3(floor(p.x * 0.18), floor(p.y * 0.25), floor(p.z * 0.025)));
		value *= 0.67 + streak * 0.45;
	} else if (surface_kind == 3) {
		value *= 0.86 + mod(p.y + p.z, 2.0) * 0.14;
	} else {
		float damp = 1.0 - smoothstep(0.2, 1.35, world_position.y);
		value *= 1.0 - damp * 0.28;
	}
	ALBEDO = tint.rgb * value;
	ROUGHNESS = 0.95;
}
