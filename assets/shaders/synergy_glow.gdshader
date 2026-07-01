// Juice contract section 3: neon plasma gradient shader for synergy borders.
// Applied to the border CanvasItem between two synergy-linked items.
// glow_intensity is set from synergy.modifier_pct returned by ValidateGrid.
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float cycle_hz : hint_range(0.5, 5.0) = 2.0;
uniform vec3 color_a = vec3(0.0, 0.96, 0.83);   // neon teal  #00F5D4
uniform vec3 color_b = vec3(0.48, 0.18, 0.75);  // neon purple #7B2FBE

void fragment() {
	float pulse = sin(TIME * TAU * cycle_hz) * 0.5 + 0.5;
	vec3 glow = mix(color_a, color_b, pulse) * glow_intensity;
	COLOR = vec4(glow, pulse * glow_intensity);
}
