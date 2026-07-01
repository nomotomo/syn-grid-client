class_name ScreenEffects
extends CanvasLayer
# Juice contract section 4: camera shake, white flash, hit-stop.
# Added as a CanvasLayer (layer 128) so effects render above all game content.

@export var shake_base_scalar: float = 12.0
@export var shake_decay: float = 0.85        # multiplied per frame until ~0
@export var flash_color: Color = Color(1, 1, 1, 1)

var _camera: Camera2D
var _flash_rect: ColorRect
var _shake_intensity: float = 0.0
var _shake_rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 128
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
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
	_shake_intensity = maxf(_shake_intensity, intensity)

func _apply_crit_flash() -> void:
	# 1-frame solid white flash (juice contract section 4).
	_flash_rect.color = flash_color
	await get_tree().process_frame
	_flash_rect.color = Color(1, 1, 1, 0)

func _process(_delta: float) -> void:
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
	_shake_intensity *= shake_decay
