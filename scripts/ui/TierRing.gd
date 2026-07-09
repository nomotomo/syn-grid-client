class_name TierRing
extends Control
# One-shot expanding ring outline, tier-colored. Self-frees on completion.

@export var start_radius: float = 20.0
@export var end_radius: float = 70.0
@export var duration: float = 0.5
@export var ring_width: float = 4.0

var _color: Color = Color.WHITE
var _radius: float

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(color: Color) -> void:
	_color = color
	_radius = start_radius
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_radius, start_radius, end_radius, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _set_radius(r: float) -> void:
	_radius = r
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 48, _color, ring_width, true)
