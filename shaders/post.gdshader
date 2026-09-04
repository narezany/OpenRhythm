shader_type canvas_item;
// Post-processing: chromatic aberration driven by shake, vignette, warm flashes.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float shake = 0.0;
uniform float flash = 0.0;
uniform float miss_flash = 0.0;
uniform float beat = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float ca = 0.0012 + shake * 0.014 + beat * 0.0015;
	float r = texture(screen_tex, uv + dir * ca).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - dir * ca).b;
	vec3 col = vec3(r, g, b);

	float d = length(dir) * 1.35;
	col *= 1.0 - 0.45 * smoothstep(0.42, 1.05, d);

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.14);

	col += flash * vec3(1.0, 0.80, 0.72) * 0.45;
	col = mix(col, vec3(0.85, 0.08, 0.18), miss_flash * 0.30);

	COLOR = vec4(col, 1.0);
}
