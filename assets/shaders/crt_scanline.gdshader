// Neon Grimoire CRT scanline + chromatic aberration overlay for the SYN-GRID
// wordmark. Renders a subtle horizontal scanline pattern and a very small
// R/B channel shift so the title reads as "arcane terminal boot", not stock
// pixel art. Meant to be applied as a canvas_item material on the TitleLabel.
//
// The label already renders opaque text on its glyphs; the shader modulates
// existing texture output rather than replacing it, so it stays cheap on the
// Godot Mobile renderer.
shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 0.6) = 0.22;
uniform float scanline_frequency : hint_range(40.0, 800.0) = 220.0;
uniform float chromatic_shift : hint_range(0.0, 4.0) = 0.8;   // pixels
uniform float jitter_rate : hint_range(0.0, 4.0) = 0.35;      // hz
uniform float jitter_amount : hint_range(0.0, 4.0) = 0.6;     // pixels
uniform vec3 tint = vec3(1.0, 1.0, 1.0);

void fragment() {
	// Time-based jitter for the CRT roll effect (very subtle - a soft "wobble"
	// every few seconds, not a permanent shake).
	float t = TIME * jitter_rate;
	float jitter = (sin(t * 6.28) * cos(t * 4.13)) * jitter_amount * TEXTURE_PIXEL_SIZE.x;

	// Sample R and B with a horizontal offset for chromatic aberration; G stays
	// centred. This produces the subtle "colour fringe" characteristic of old
	// tube-based displays.
	float dx = chromatic_shift * TEXTURE_PIXEL_SIZE.x;
	vec4 c = texture(TEXTURE, UV + vec2(jitter, 0.0));
	float r = texture(TEXTURE, UV + vec2(dx + jitter, 0.0)).r;
	float b = texture(TEXTURE, UV + vec2(-dx + jitter, 0.0)).b;
	vec3 color = vec3(r, c.g, b) * tint;

	// Horizontal scanlines - darker rows on odd frequency positions.
	float scan = sin(UV.y * scanline_frequency) * 0.5 + 0.5;
	color *= 1.0 - scanline_intensity * (1.0 - scan);

	// Preserve original alpha - we're an overlay, not a fill.
	COLOR = vec4(color, c.a);
}
