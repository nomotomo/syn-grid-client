class_name SynergyBorder
extends ColorRect

# Reusable synergy-glow strip (juice_manual.md section 3). GridPrepScene sizes
# and positions this as a thin rect on the shared edge between two synergy-
# linked cells - never a Line2D or StyleBoxFlat border, always this shader.
# The scene's ShaderMaterial is resource_local_to_scene so each border keeps
# its own glow_intensity.

@export var fade_in_duration: float = 0.35
@export var fade_out_duration: float = 0.20

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_glow_intensity(modifier_pct: float) -> void:
	material.set_shader_parameter("glow_intensity", modifier_pct)

# Ramp glow_intensity 0 -> modifier_pct so links bloom in rather than popping.
func fade_in_to(modifier_pct: float) -> void:
	set_glow_intensity(0.0)
	create_tween().tween_method(set_glow_intensity, 0.0, modifier_pct, fade_in_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func fade_out_and_free() -> void:
	var current: float = material.get_shader_parameter("glow_intensity")
	var tw := create_tween()
	tw.tween_method(set_glow_intensity, current, 0.0, fade_out_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
