class_name GearIcon
extends Control

# Top-bar Settings-button glyph (issue #79 scope item 1: "gear icon").
# Hand-drawn per the same no-icon-asset-pipeline convention as NavIcon.gd -
# a circle with radial teeth reads as "gear" at small sizes without a
# sourced icon font/texture.

@export var glyph_color: Color = Color.WHITE
@export var line_width: float = 2.0
@export var tooth_count: int = 8

func set_glyph_color(color: Color) -> void:
	glyph_color = color
	queue_redraw()

func _draw() -> void:
	var outer: float = min(size.x, size.y) * 0.5
	if outer <= 0.0:
		return
	var inner: float = outer * 0.62
	var tooth_len: float = outer * 0.28
	var center: Vector2 = size * 0.5
	draw_arc(center, inner, 0.0, TAU, 24, glyph_color, line_width, true)
	for i in tooth_count:
		var angle: float = i * TAU / tooth_count
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * inner, center + dir * (inner + tooth_len), glyph_color, line_width, true)
