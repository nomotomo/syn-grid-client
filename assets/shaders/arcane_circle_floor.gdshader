// Neon Grimoire arcane-circle floor - a slowly-rotating rune glyph disc that
// sits under a team's 4x4 combat grid. Enemy floor is red-tinted (amber -> danger),
// friendly floor is teal-tinted (ACCENT_TEAL). Renders entirely as fragment
// output on a ColorRect so no sprites are needed.
//
// The disc has three visual layers:
//   1. A soft radial vignette in `tint_color` that fades from opaque center
//      to transparent edge - grounds the grid in the arcane pool.
//   2. A dashed outer ring at 60% of the radius.
//   3. Six rotating rune glyphs (variant shapes) evenly spaced on an inner ring,
//      slowly orbiting.
shader_type canvas_item;

uniform vec3 tint_color = vec3(0.0, 0.96, 0.83);   // ACCENT_TEAL for player
uniform float base_alpha : hint_range(0.0, 1.0) = 0.32;
uniform float ring_thickness : hint_range(0.004, 0.05) = 0.012;
uniform float rotation_speed : hint_range(0.0, 1.0) = 0.08;
uniform int rune_count = 6;

// Small SDF for the rune glyph placed at the rune ring positions.
float rune(vec2 uv) {
	vec2 c = uv - 0.5;
	float d = abs(abs(c.x) + abs(c.y) - 0.30);          // diamond outline
	float glyph = smoothstep(0.035, 0.0, d);
	float dot_ = smoothstep(0.06, 0.0, length(c));
	return max(glyph, dot_ * 0.7);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float ang = atan(p.y, p.x);

	// 1) Radial vignette pool.
	float pool = smoothstep(0.5, 0.15, r);
	vec3 color = tint_color * pool;
	float alpha = pool * base_alpha;

	// 2) Dashed outer ring at r ~ 0.42.
	float outer_ring = smoothstep(ring_thickness, 0.0, abs(r - 0.42));
	// Dash mask: 12 dashes around the circle
	float dash = step(0.5, sin(ang * 24.0) * 0.5 + 0.5);
	color += tint_color * outer_ring * dash * 0.9;
	alpha = max(alpha, outer_ring * dash * 0.65);

	// 3) Six rotating rune glyphs on inner ring at r ~ 0.34.
	// Convert to polar tile: each glyph gets 1/N of the angular sweep.
	float t = TIME * rotation_speed;
	float sector = 1.0 / float(rune_count);
	float ang01 = fract(ang / 6.2831 + t + 1.0);           // 0..1
	float k = floor(ang01 / sector);
	float local = fract(ang01 / sector);                    // 0..1 within sector
	// Only render near the inner ring radius.
	float rune_band = smoothstep(0.08, 0.0, abs(r - 0.34));
	// Center each glyph at local=0.5 and r=0.34; map (local, r) to a local uv.
	vec2 rune_uv = vec2(local, (r - 0.28) / 0.12);
	float g = rune(rune_uv) * rune_band;
	color += tint_color * g * 1.2;
	alpha = max(alpha, g * 0.85);

	// Fade everything outside the disc.
	float disc = smoothstep(0.52, 0.48, r);
	COLOR = vec4(color, alpha * disc);
}
