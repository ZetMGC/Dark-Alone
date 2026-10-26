shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height = 360.0;

void fragment() {
	vec2 grid = vec2(virtual_height * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, virtual_height);
	vec2 pixel = floor(SCREEN_UV * grid);
	vec2 uv = (pixel + 0.5) / grid;
	vec3 sample_color = textureLod(screen_texture, uv, 0.0).rgb;
	// Неподвижная матрица: без временного шума, вспышек и дрожания камеры.
	float pattern = mod(pixel.x, 2.0) * 2.0 + mod(pixel.y, 2.0);
	sample_color = floor(sample_color * 31.0 + 0.5 + (pattern / 4.0 - 0.375) * 0.4) / 31.0;
	vec2 radius = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - 0.16 * smoothstep(0.35, 1.5, dot(radius, radius));
	COLOR = vec4(sample_color * vignette, 1.0);
}
