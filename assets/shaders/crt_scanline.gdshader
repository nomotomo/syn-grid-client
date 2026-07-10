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

// Neon glow halo (added post-#79 design review: this shader was attached to
// the wordmark but only ever did chromatic-fringe + scanlines - a different,
// much subtler effect than a glow, which is why the label never visibly
// glowed despite having a material assigned). Self-contained multi-tap blur
// of the glyph alpha mask, composited as a soft colored halo behind the
// sharp text - deliberately NOT a project-wide Glow/Bloom Environment, since
// this is 2D Control UI, not 3D world rendering, and a local canvas_item
// effect keeps the glow scoped to this one label.
uniform vec3 glow_color : source_color = vec3(0.0, 0.96, 0.83);
uniform float glow_radius : hint_range(0.0, 16.0) = 5.0;   // pixels
uniform float glow_strength : hint_range(0.0, 3.0) = 1.5;

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
	vec3 sharp_color = vec3(r, c.g, b) * tint;

	// Horizontal scanlines - darker rows on odd frequency positions.
	float scan = sin(UV.y * scanline_frequency) * 0.5 + 0.5;
	sharp_color *= 1.0 - scanline_intensity * (1.0 - scan);

	// 12-tap radial blur of the alpha mask builds the outer glow halo.
	float glow_alpha = 0.0;
	const int TAPS = 12;
	for (int i = 0; i < TAPS; i++) {
		float angle = float(i) / float(TAPS) * 6.28318530718;
		vec2 offset = vec2(cos(angle), sin(angle)) * glow_radius * TEXTURE_PIXEL_SIZE;
		glow_alpha += texture(TEXTURE, UV + offset).a;
	}
	glow_alpha = clamp((glow_alpha / float(TAPS)) * glow_strength, 0.0, 1.0);

	// Composite: sharp chromatic text on top, glow halo bleeding out from
	// behind it into currently-transparent glyph-adjacent pixels only.
	vec3 final_color = mix(glow_color * glow_alpha, sharp_color, c.a);
	float final_alpha = max(c.a, glow_alpha * (1.0 - c.a));
	COLOR = vec4(final_color, final_alpha);
}
