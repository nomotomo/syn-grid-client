// Juice contract section 4: 1-frame full-viewport white flash on critical hits.
// Applied to a full-screen ColorRect in ScreenEffects autoload.
// alpha_value is set to 1.0 for one frame then 0.0 by ScreenEffects.gd.
shader_type canvas_item;

uniform float alpha_value : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	COLOR = vec4(flash_color, alpha_value);
}
