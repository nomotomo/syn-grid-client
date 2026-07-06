// Neon Grimoire circular round-timer ring for Combat Replay. Renders a
// counter-clockwise-filling arc whose colour smoothly transitions from
// ACCENT_TEAL (fresh) -> ACCENT_AMBER (< 30%) -> DANGER (< 10%). At any
// given `progress` the arc lights up from 12 o'clock down to the current
// angle; the untraversed portion is a dim etch so the ring's silhouette
// is always visible.
//
// `progress` is 0..1 remaining fraction (1.0 = full time left, 0.0 = expired),
// mapping cleanly to whatever ratio the client computes from ticks or seconds.
shader_type canvas_item;

uniform vec3 color_full = vec3(0.0, 0.96, 0.83);    // ACCENT_TEAL
uniform vec3 color_warn = vec3(0.83, 0.51, 0.24);   // ACCENT_AMBER
uniform vec3 color_danger = vec3(0.85, 0.10, 0.10); // DANGER
uniform vec3 track_color = vec3(0.15, 0.15, 0.19);  // PANEL_BG_HOVER
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float ring_thickness : hint_range(0.02, 0.4) = 0.10;
uniform float pulse_hz : hint_range(0.0, 6.0) = 2.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	// Angle from 12 o'clock (top), clockwise, 0..1
	float ang = atan(p.x, -p.y) / 6.2831;
	if (ang < 0.0) ang += 1.0;

	// Ring mask - centred at radius 0.4, thickness ring_thickness.
	float ring_center = 0.4;
	float half_t = ring_thickness * 0.5;
	float in_ring = smoothstep(half_t + 0.02, half_t, abs(r - ring_center));

	// Colour transition based on progress: teal above 0.30, amber 0.10..0.30, danger below.
	vec3 color;
	if (progress > 0.30) {
		color = mix(color_warn, color_full, smoothstep(0.30, 0.55, progress));
	} else {
		color = mix(color_danger, color_warn, smoothstep(0.10, 0.30, progress));
	}

	// Pulse the arc at danger threshold for urgency.
	float pulse = 1.0;
	if (progress <= 0.10) {
		pulse = 0.65 + 0.35 * (sin(TIME * 6.2831 * pulse_hz) * 0.5 + 0.5);
	}

	// Arc mask: light up the segment 0..progress, rest is dim track.
	float in_arc = step(ang, progress);
	vec3 rgb = mix(track_color, color * pulse, in_arc);

	// Add a soft outer glow when in the "full" band.
	float glow = smoothstep(half_t + 0.04, half_t, abs(r - ring_center)) * in_arc * 0.35;
	rgb += color * glow;

	COLOR = vec4(rgb, in_ring);
}
