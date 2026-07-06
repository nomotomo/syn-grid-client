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

void fragment() {
	// Signed pseudo-distance to the rounded-rect edge in UV space.
	// dist = smallest gap between UV and any of the four sides.
	float dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));

	// Solid rim: on when we're within rim_fraction of the edge.
	float rim = 1.0 - smoothstep(rim_fraction * 0.85, rim_fraction, dist);
	// Soft outer halo bleeds slightly past the edge into the button interior.
	float halo = (1.0 - smoothstep(rim_fraction, rim_fraction * 3.0, dist)) * halo_alpha;

	// Orbit the aurora around the rim: angle -> mix parameter -> two-lobe gradient.
	vec2 c = UV - 0.5;
	float angle = atan(c.y, c.x);
	float t = fract(angle / 6.2831 + TIME * aurora_speed);
	float lobe = 0.5 - 0.5 * cos(t * 6.2831);
	vec3 color = mix(color_a, color_b, lobe);

	float alpha = clamp(rim + halo, 0.0, 1.0);
	COLOR = vec4(color * glow_strength, alpha);
}
