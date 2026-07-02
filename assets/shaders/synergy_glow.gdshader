// Juice contract section 3: neon plasma gradient shader for synergy borders.
// Applied to the border CanvasItem between two synergy-linked items.
// glow_intensity is set from synergy.modifier_pct returned by ValidateGrid
// (contract-required mapping); intensity_boost/pulse_floor shape that value
// into a glow that stays visible on the dark bento background - exposed as
// uniforms per client-architecture.md section 6 (no magic numbers in shaders).
// Note: no blend_add here - it renders nothing under the Mobile renderer.
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float cycle_hz : hint_range(0.5, 5.0) = 2.0;
uniform float intensity_boost : hint_range(1.0, 6.0) = 3.2;
uniform float pulse_floor : hint_range(0.0, 1.0) = 0.45;
uniform vec3 color_a = vec3(0.0, 0.96, 0.83);   // neon teal  #00F5D4
uniform vec3 color_b = vec3(0.48, 0.18, 0.75);  // neon purple #7B2FBE

void fragment() {
	float pulse = sin(TIME * TAU * cycle_hz) * 0.5 + 0.5;
	float strength = clamp(glow_intensity * intensity_boost, 0.0, 1.0);
	float level = mix(pulse_floor, 1.0, pulse);
	// Soft falloff toward the strip edges so it reads as emitted light, not a bar.
	float falloff = smoothstep(0.0, 0.45, min(UV.x, 1.0 - UV.x))
		* smoothstep(0.0, 0.45, min(UV.y, 1.0 - UV.y));
	vec3 glow = mix(color_a, color_b, pulse) * (0.6 + 0.9 * level);
	COLOR = vec4(glow, level * strength * falloff);
}
