shader_type canvas_item;
// Background: the black and blood theme - gradient, red sparks, a perspective
// floor grid and a beat pulse. Hue stays in the red-orange band (~0.98-1.02).

uniform float i_time = 0.0;
uniform float beat = 0.0;
uniform float flash = 0.0;
uniform float hue = 0.985;
uniform vec2 res = vec2(1280.0, 720.0);

// How far the floor goes before it stops. Anything beyond this is thinner than
// the pixels available to draw it, so it is not drawn.
const float GRID_FAR = 17.0;

vec3 hsv(float h, float s, float v) {
	vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), rgb, s);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv * res - res * 0.5) / res.y;
	float horizon = 0.22;

	vec3 col = mix(vec3(0.020, 0.004, 0.007), vec3(0.085, 0.010, 0.020), uv.y);
	col = mix(col, vec3(0.006, 0.002, 0.004), smoothstep(0.2, 0.0, uv.y));

	// red sparks in the upper half
	vec2 sp = vec2(uv.x * (res.x / res.y), uv.y) * 42.0;
	vec2 cell = floor(sp);
	vec2 fr = fract(sp) - 0.5;
	float h = hash(cell);
	float star = smoothstep(0.14, 0.0, length(fr)) * step(0.92, h)
		* (0.35 + 0.65 * (0.5 + 0.5 * sin(i_time * 2.0 + h * 40.0)));
	col += vec3(1.0, 0.45, 0.35) * star * 0.40 * step(uv.y, 0.55);

	// horizon glow
	float hor = exp(-abs(p.y - horizon) * 7.0);
	col += hsv(hue, 0.90, 1.0) * hor * (0.20 + beat * 0.25);

	// Floor grid.
	//
	// It used to run to infinity: depth is one over the distance from the
	// horizon, so the lines packed tighter and tighter until a whole cell was
	// narrower than a pixel - and the brightness was highest exactly there,
	// because the fade was measured from the horizon rather than from the
	// viewer. What the card was asked to draw was a shimmering mess of
	// half-pixel lines, and what you saw was the floor tearing itself up.
	//
	// So: the floor ends at GRID_FAR, the last stretch of it fades out so the
	// end is not a seam, and a line's width is measured in screen pixels with
	// fwidth - which is what keeps a line a line however far away it is,
	// instead of a flicker between lit and unlit pixels.
	if (p.y > horizon) {
		float d = p.y - horizon;
		float depth = 1.0 / max(d, 1.0 / GRID_FAR);
		vec2 g = vec2(p.x * depth, depth * 0.55 - i_time * (1.2 + beat * 5.0));
		vec2 gw = fwidth(g);
		vec2 gv = abs(fract(g) - 0.5);
		vec2 lines = vec2(1.0) - smoothstep(vec2(0.0), gw * 1.3 + 0.008, gv);
		float grid = max(lines.x, lines.y);
		float far = 1.0 - smoothstep(GRID_FAR * 0.40, GRID_FAR, depth);
		float fade = exp(-d * 1.9) * far;
		col += hsv(fract(hue + 0.015), 0.85, 1.0) * grid * fade * (0.18 + beat * 0.50);
	}

	// pulse from the centre plus the global flash
	col += vec3(1.0, 0.25, 0.18) * beat * 0.10 * exp(-length(p) * 1.6);
	col += flash * vec3(1.0, 0.85, 0.80) * 0.55;

	COLOR = vec4(col, 1.0);
}
