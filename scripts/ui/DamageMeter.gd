class_name DamageMeter
extends Control
# Thin contribution bar attached under a mini ItemCard in combat replay.
# Fill fraction is set externally (own_damage / current_match_max) - this
# component does no computation of its own, matching HpBar's "never computes
# damage" convention.

@export var fill_tween_duration: float = 0.10
@export var bar_height: float = 6.0

var _bg: ColorRect
var _fill: ColorRect

func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = SynGridPalette.PANEL_BG_ELEVATED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_fill = ColorRect.new()
	_fill.color = SynGridPalette.ACCENT_TEAL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	resized.connect(_relayout)
	_relayout()

func _relayout() -> void:
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(size.x, bar_height)
	_fill.position = Vector2.ZERO
	_fill.size.y = bar_height

func set_fraction(frac: float) -> void:
	var target_w := clampf(frac, 0.0, 1.0) * size.x
	var tw := create_tween()
	tw.tween_property(_fill, "size:x", target_w, fill_tween_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
