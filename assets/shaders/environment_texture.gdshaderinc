// Отражённое повторение обеспечивает непрерывность даже у AI-изображений
// с несовпадающими краями. Производные берутся ДО сворачивания UV для mipmaps.
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool detail_enabled = false;
uniform vec3 detail_average = vec3(0.3);
uniform vec2 detail_meters = vec2(1.0);

vec3 material_detail(vec2 metric_uv) {
	vec2 q = metric_uv / detail_meters;
	vec2 folded = 1.0 - abs(mod(q, 2.0) - 1.0);
	vec2 direction = mix(vec2(1.0), vec2(-1.0), step(vec2(1.0), mod(q, 2.0)));
	vec3 color = textureGrad(detail_albedo, folded, dFdx(q) * direction, dFdy(q) * direction).rgb;
	return clamp(color / detail_average, vec3(0.45), vec3(1.65));
}
