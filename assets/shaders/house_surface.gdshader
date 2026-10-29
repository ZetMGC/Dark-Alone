shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Локальная метрическая проекция: рисунок остаётся на открывающейся дверце.
uniform vec4 tint : source_color = vec4(0.4, 0.4, 0.4, 1.0);
// Штукатурка, дуб, доски, ткань, керамическая плитка, камень, металл, эмаль, окно.
uniform int kind = 0;
uniform float roughness_value = 0.7;
uniform float relief = 0.12;
varying vec3 p;
varying vec3 n;

float hash(vec3 q) {
	q = fract(q * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise3(vec3 q) {
	vec3 a = floor(q), f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(a), hash(a+vec3(1,0,0)), f.x), mix(hash(a+vec3(0,1,0)), hash(a+vec3(1,1,0)), f.x), f.y), mix(mix(hash(a+vec3(0,0,1)), hash(a+vec3(1,0,1)), f.x), mix(hash(a+vec3(0,1,1)), hash(a+vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	p = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	n = NORMAL;
}
void fragment() {
	vec3 an = abs(n);
	vec2 uv = an.y > 0.6 ? p.xz : (an.x > 0.6 ? p.zy : p.xy);
	float fine = noise3(p * 115.0);
	float broad = noise3(p * 3.5);
	float value = 0.91 + broad * 0.14 + fine * 0.055;
	float h = fine * 0.003;
	float rough = roughness_value;
	if (kind == 1 || kind == 2) {
		vec2 w = uv;
		if (kind == 2) {
			float row = floor(w.x / 0.32);
			float end = w.y + hash(vec3(row)) * 1.8;
			vec2 cell = vec2(fract(w.x / 0.32), fract(end / 1.65));
			vec2 edge = min(cell, 1.0-cell) * vec2(0.32, 1.65);
			float seam = smoothstep(0.0015, 0.005, min(edge.x, edge.y));
			value *= (0.82 + hash(vec3(row, floor(end/1.65), 2.0)) * 0.26) * mix(0.27, 1.0, seam);
			h += seam * 0.001;
		}
		float warp = noise3(vec3(w * vec2(2.2, 0.9), 1.0));
		float grain = noise3(vec3(w.x * 90.0 + warp * 7.0, w.y * 2.4, 3.0));
		float rings = sin(w.x * 155.0 + warp * 14.0) * 0.5 + 0.5;
		value *= 0.89 + grain * 0.13 + rings * 0.025;
		h = fine * 0.00025 + grain * 0.0004;
		rough += grain * 0.12;
	} else if (kind == 3) {
		float weave = sin(uv.x * 950.0) * sin(uv.y * 950.0);
		float fade = clamp(1.0 - length(fwidth(uv)) * 600.0, 0.0, 1.0);
		value *= 0.93 + 0.055 * weave * fade;
		h = fine * 0.001 + weave * fade * 0.00025;
	} else if (kind == 4) {
		vec2 t = uv / vec2(0.24, 0.12);
		t.x += mod(floor(t.y), 2.0) * 0.5;
		vec2 e = min(fract(t), 1.0-fract(t)) * vec2(0.24, 0.12);
		float grout = smoothstep(0.001, 0.004, min(e.x, e.y));
		value *= mix(0.38, 0.94 + hash(vec3(floor(t), 3.0)) * 0.1, grout);
		h = grout * 0.0015;
		rough = mix(0.96, roughness_value, grout);
	} else if (kind == 5) {
		value *= 0.85 + noise3(p * 42.0) * 0.18;
		h = fine * 0.0007;
	} else if (kind == 6) {
		value *= 0.92 + noise3(p * vec3(260, 4, 6)) * 0.08;
		h = 0.0;
	} else if (kind == 7) {
		h = fine * 0.0001;
	} else if (kind == 8) {
		float mist = noise3(vec3(uv * vec2(60.0, 2.0), 0.0));
		value = 0.65 + mist * 0.13 + smoothstep(-0.7, 0.9, uv.y) * 0.42;
		EMISSION = tint.rgb * value * 0.28;
		h = 0.0;
	}
	ALBEDO = tint.rgb * value;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = kind == 6 ? 0.72 : 0.0;
	SPECULAR = kind == 8 ? 0.05 : 0.35;
	// Микрорельеф через производные: без tangent/UV зависимости у процедурных мешей.
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
	float det = dot(dx, r1);
	if (abs(det) > 0.00000001) {
		NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * relief);
	}
}
