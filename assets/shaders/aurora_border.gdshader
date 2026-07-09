// Neon Grimoire aurora border - animated teal↔purple gradient orbiting the
// rim of a rectangle. Rendered on a ColorRect overlay placed as a child of
// the Play button.
//
// This variant uses pure UV-space math (no TEXTURE_PIXEL_SIZE dependence)
// so it works on ColorRect nodes that carry no source texture, and on both
// the Vulkan and OpenGL 3 mobile fallback renderers.
shader_type canvas_item;

uniform vec3 color_a = vec3(0.0, 0.96, 0.83);       // ACCENT_TEAL
uniform vec3 color_b = vec3(0.48, 0.18, 0.75);      // ACCENT_PURPLE
uniform float aurora_speed : hint_range(0.05, 2.0) = 0.35;
// Rim thickness expressed as a fraction of the SHORT side of the rect
// (e.g. 0.04 -> 4% of the short axis).
uniform float rim_fraction : hint_range(0.005, 0.15) = 0.045;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.35;
uniform float halo_alpha : hint_range(0.0, 1.0) = 0.35;
// Actual pixel size of this node (set from the owning script - a canvas_item
// shader on a texture-less ColorRect has no built-in way to read its own
// rect size). Needed so the rim/halo follow the true corner curvature
// instead of a plain rectangle - without this, a fully-pilled button (radius
// = height/2, per ThemeBuilder.build_cta_style) shows a hard square corner
// where the rim ignores the rounded fill underneath.
uniform vec2 rect_size = vec2(0.0, 0.0);
// Over-specified like StyleBoxFlat corner radii elsewhere in this repo -
// clamped in-shader to half the short side, so callers can just pass a huge
// number for a full pill rather than computing an exact pixel value.
uniform float corner_radius_px : hint_range(0.0, 999.0) = 999.0;

// Signed distance (in the same units as `half_size`) from `p` to a rounded
// rectangle centered at the origin - negative inside, zero on the boundary,
// positive outside. Standard 2D rounded-box SDF.
float sd_round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	float dist;
	// 1.0 while inside the rounded-rect boundary, 0.0 once outside it - the
	// rectangle-metric fallback path is never negative, so this is a no-op
	// there. Needed because sd_round_box's distance goes negative outside
	// the shape, and without this gate the rim/halo smoothstep below would
	// saturate back to full opacity out at the ColorRect's own sharp
	// corners (the exact square-corner bug this rounded metric exists to fix).
	float inside_mask;
	if (rect_size.x > 0.0 && rect_size.y > 0.0) {
		vec2 half_size = rect_size * 0.5;
		float radius = min(corner_radius_px, min(half_size.x, half_size.y));
		vec2 p = (UV - 0.5) * rect_size;
		// Normalize the signed distance back into the same "fraction of
		// short side" units rim_fraction/halo already use.
		float short_side = min(rect_size.x, rect_size.y);
		dist = -sd_round_box(p, half_size, radius) / short_side;
		inside_mask = step(0.0, dist);
	} else {
		// rect_size not wired up - fall back to the plain-rectangle metric
		// this shader originally used.
		dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
		inside_mask = 1.0;
	}

	// Solid rim: on when we're within rim_fraction of the edge.
	float rim = 1.0 - smoothstep(rim_fraction * 0.85, rim_fraction, dist);
	// Soft glow bleeds from the edge a little further into the button interior.
	float halo = (1.0 - smoothstep(rim_fraction, rim_fraction * 3.0, dist)) * halo_alpha;

	// Orbit the aurora around the rim: angle -> mix parameter -> two-lobe gradient.
	vec2 c = UV - 0.5;
	float angle = atan(c.y, c.x);
	float t = fract(angle / 6.2831 + TIME * aurora_speed);
	float lobe = 0.5 - 0.5 * cos(t * 6.2831);
	vec3 color = mix(color_a, color_b, lobe);

	float alpha = clamp(rim + halo, 0.0, 1.0) * inside_mask;
	COLOR = vec4(color * glow_strength, alpha);
}
