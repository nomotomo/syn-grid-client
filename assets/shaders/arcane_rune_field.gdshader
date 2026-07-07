// Neon Grimoire menu backdrop: slow drifting field of dim rune glyphs on the
// VOID color, with occasional teal pings. Renders entirely in the fragment
// shader so no sprites are needed. Uses SCREEN_PIXEL_SIZE for the pixel-space
// cell grid (works on both Vulkan and the OpenGL 3 mobile fallback path).
//
// Nothing sits on top of live numeric values on the main menu (the stats HUD
// panels are fully opaque L2 pills), so this backdrop stays compliant with
// juice_manual.md section 1's ban on glass behind live numbers.
shader_type canvas_item;

uniform vec3 base_color = vec3(0.04, 0.04, 0.06);   // SynGridPalette.VOID
uniform vec3 rune_color = vec3(0.0, 0.96, 0.83);    // ACCENT_TEAL
uniform vec3 spark_color = vec3(0.48, 0.18, 0.75);  // ACCENT_PURPLE
uniform float pan_speed : hint_range(0.0, 0.3) = 0.04;
uniform vec2 grid_dims = vec2(6.0, 12.0);           // ~6x12 rune cells across the screen
uniform float rune_alpha : hint_range(0.0, 0.6) = 0.28;
uniform float spark_alpha : hint_range(0.0, 1.0) = 0.75;

float hash21(vec2 p) {
	p = fract(p * vec2(213.7, 91.3));
	p += dot(p, p + 47.13);
	return fract(p.x * p.y);
}

float rune_glyph(vec2 uv, int variant) {
	vec2 c = uv - 0.5;
	if (variant == 0) {
		float d = abs(length(c) - 0.28);
		return smoothstep(0.04, 0.0, d);
	}
	if (variant == 1) {
		float d = abs(abs(c.x) + abs(c.y) - 0.28);
		return smoothstep(0.03, 0.0, d);
	}
	if (variant == 2) {
		float h = smoothstep(0.03, 0.0, abs(c.y)) * step(abs(c.x), 0.28);
		float v = smoothstep(0.03, 0.0, abs(c.x)) * step(abs(c.y), 0.28);
		return max(h, v);
	}
	float box = smoothstep(0.03, 0.0, max(abs(c.x), abs(c.y)) - 0.24);
	float dot_ = smoothstep(0.06, 0.0, length(c));
	return max(box * 0.6, dot_);
}

void fragment() {
	// UV is 0..1 across the ColorRect; scale into grid cells with a slow drift.
	vec2 uv = UV * grid_dims + vec2(TIME * pan_speed, TIME * pan_speed * 0.55);
	vec2 cell = floor(uv);
	vec2 cell_uv = fract(uv);

	float h = hash21(cell);
	int variant = int(floor(h * 4.0));
	float presence = step(0.55, hash21(cell + vec2(17.0, 31.0)));

	float g = rune_glyph(cell_uv, variant) * presence;
	vec3 color = mix(base_color, rune_color, g * rune_alpha);

	// Rare pinging cells - flash purple then fade, cycling on their own phase.
	float rare = step(0.94, hash21(cell + 71.0));
	float phase = fract(TIME * 0.30 + hash21(cell + 3.0));
	float ping = smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.15, 0.55, phase));
	float ping_g = rune_glyph(cell_uv, variant) * rare * ping;
	color = mix(color, spark_color, ping_g * spark_alpha);

	// Vignette so the wordmark and CTAs on top still read at max contrast.
	float vign = smoothstep(1.3, 0.5, length(UV - 0.5) * 1.5);
	color *= mix(0.6, 1.0, vign);

	COLOR = vec4(color, 1.0);
}
