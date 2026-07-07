extends CanvasLayer
# Juice contract section 4: camera shake, white flash, hit-stop.
# Added as a CanvasLayer (layer 128) so effects render above all game content.

const FLASH_SHADER: Shader = preload("res://assets/shaders/screen_flash.gdshader")

@export var shake_base_scalar: float = 12.0
@export var shake_decay: float = 0.85        # per 60fps-frame multiplier, delta-corrected
@export var flash_color: Color = Color(1, 1, 1, 1)
@export var hitstop_frames: int = 2
@export var crit_zoom_scale: float = 0.95
@export var crit_zoom_return_duration: float = 0.12

var _camera: Camera2D
var _flash_rect: ColorRect
var _flash_material: ShaderMaterial
var _shake_intensity: float = 0.0
var _shake_rng := RandomNumberGenerator.new()
var _in_hitstop: bool = false

func _ready() -> void:
	layer = 128
	# Hit-stop freezes gameplay via Engine.time_scale; this layer must keep
	# processing so the flash can clear and the freeze can end.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	_flash_material.set_shader_parameter("alpha_value", 0.0)
	_flash_material.set_shader_parameter(
		"flash_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	_flash_rect = ColorRect.new()
	_flash_rect.material = _flash_material
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	_shake_rng.randomize()

func set_camera(cam: Camera2D) -> void:
	_camera = cam

# Called by CombatLogPlayer for every TickEvent.
# damage_dealt and max_target_hp come from the server's TickEvent fields.
func shake_from_hit(damage_dealt: float, max_target_hp: float, is_crit: bool) -> void:
	var intensity := (damage_dealt / max_target_hp) * shake_base_scalar
	if is_crit:
		intensity *= 2.5
		_apply_crit_flash()
		_apply_crit_zoom()
		hitstop()
	_shake_intensity = maxf(_shake_intensity, intensity)

# Freeze ALL animations for exactly hitstop_frames frames (juice contract
# section 4). Tweens, particles, and timers all run on scaled time, so
# zeroing Engine.time_scale halts every animation at once.
func hitstop(frames: int = -1) -> void:
	if _in_hitstop:
		return
	_in_hitstop = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = 0.0
	for _i in (frames if frames > 0 else hitstop_frames):
		await get_tree().process_frame
	Engine.time_scale = previous_scale
	_in_hitstop = false

func _apply_crit_flash() -> void:
	# 1-frame solid white flash (juice contract section 4).
	_flash_material.set_shader_parameter("alpha_value", 1.0)
	await get_tree().process_frame
	_flash_material.set_shader_parameter("alpha_value", 0.0)

func _apply_crit_zoom() -> void:
	if _camera == null:
		return
	_camera.zoom = Vector2(crit_zoom_scale, crit_zoom_scale)
	for _i in hitstop_frames:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(_camera, "zoom", Vector2.ONE, crit_zoom_return_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	if _camera == null or _shake_intensity < 0.01:
		if _camera != null:
			_camera.offset = Vector2.ZERO
		_shake_intensity = 0.0
		return
	var offset := Vector2(
		_shake_rng.randf_range(-1.0, 1.0),
		_shake_rng.randf_range(-1.0, 1.0)
	) * _shake_intensity
	_camera.offset = offset
	# Decay is authored as a per-frame multiplier at 60fps; correct by delta so
	# shake feels identical at 120Hz mobile displays.
	_shake_intensity *= pow(shake_decay, delta * 60.0)
